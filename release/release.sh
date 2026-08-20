#!/usr/bin/env bash
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$RELEASE_DIR")"
INPUT_DIR="$RELEASE_DIR/input"
OUT_DIR="$RELEASE_DIR/out"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"

APP=""
NOTES=""
NOTES_FILE=""
ASSUME_YES=0

usage() {
  cat >&2 <<EOF
Usage: release/release.sh -m "release notes" [options]

  -m, --notes TEXT     Release notes body (required unless --notes-file)
  -F, --notes-file F   Read release notes from file F
  -a, --app PATH       App bundle to release (default: release/input/Gleam.app)
  -y, --yes            Publish without confirmation
  -h, --help           Show this help

Export your notarized .app to release/input/Gleam.app, then run this.
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--notes)      NOTES="${2:-}"; shift 2 ;;
    -F|--notes-file) NOTES_FILE="${2:-}"; shift 2 ;;
    -a|--app)        APP="${2:-}"; shift 2 ;;
    -y|--yes)        ASSUME_YES=1; shift ;;
    -h|--help)       usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "$NOTES_FILE" ] && NOTES="$(cat "$NOTES_FILE")"
[ -z "$NOTES" ] && { echo "Release notes are required (-m or -F)." >&2; usage; }
[ -z "$APP" ] && APP="$INPUT_DIR/Gleam.app"

fail() { echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

step "Preflight"
for tool in create-dmg gh xcrun ditto; do
  command -v "$tool" >/dev/null || fail "$tool not found on PATH"
done
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated (run: gh auth login)"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "Notary profile '$NOTARY_PROFILE' missing. Create it with:
  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --key <AuthKey.p8> --key-id <ID> --issuer <UUID>"

[ -d "$APP" ] || fail "No app bundle at $APP
Export your Developer ID build there, then re-run."

GENERATE_APPCAST="${GENERATE_APPCAST:-$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*artifacts/sparkle/Sparkle/bin/generate_appcast' 2>/dev/null | head -1)}"
[ -n "$GENERATE_APPCAST" ] || fail "generate_appcast not found. Build the project once so SwiftPM fetches Sparkle."

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
TAG="v$VERSION"
DMG_NAME="Gleam.dmg"
DOWNLOAD_PREFIX="https://github.com/$REPO/releases/download/$TAG/"
echo "repo    $REPO"
echo "app     $APP"
echo "version $VERSION"

step "Verifying app signature"
codesign --verify --deep --strict "$APP" || fail "App failed signature verification"
APP_SIGN_INFO="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
case "$APP_SIGN_INFO" in
  *"Authority=Developer ID Application"*) ;;
  *) fail "App is not signed with a Developer ID Application certificate" ;;
esac
APP_ENTS="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)"
case "$APP_ENTS" in
  *app-sandbox*) echo "sandboxed: yes" ;;
  *) echo "sandboxed: no" ;;
esac

step "Ensuring app is notarized and stapled"
if xcrun stapler validate "$APP" >/dev/null 2>&1; then
  echo "Already stapled, skipping app notarization."
else
  echo "Not stapled. Submitting app for notarization."
  APP_ZIP="$(mktemp -d)/Gleam-app.zip"
  ditto -c -k --keepParent "$APP" "$APP_ZIP"
  xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 30m \
    || fail "App notarization failed"
  xcrun stapler staple "$APP" || fail "Stapling the app failed"
  rm -rf "$(dirname "$APP_ZIP")"
fi
APP_SPCTL="$(spctl -a -t exec -vv "$APP" 2>&1 || true)"
case "$APP_SPCTL" in
  *"source=Notarized Developer ID"*) ;;
  *) fail "Gatekeeper does not accept the app as Notarized Developer ID: $APP_SPCTL" ;;
esac

step "Building DMG"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
( cd "$OUT_DIR" && create-dmg "$APP" "$OUT_DIR" ) || fail "create-dmg failed"
BUILT_DMG="$(find "$OUT_DIR" -maxdepth 1 -name '*.dmg' | head -1)"
[ -n "$BUILT_DMG" ] || fail "create-dmg produced no .dmg"
mv "$BUILT_DMG" "$OUT_DIR/$DMG_NAME"
codesign --verify --strict "$OUT_DIR/$DMG_NAME" || fail "DMG is not validly signed"
DMG_SIGN_INFO="$(codesign -dv --verbose=4 "$OUT_DIR/$DMG_NAME" 2>&1 || true)"
case "$DMG_SIGN_INFO" in
  *"Authority=Developer ID Application"*) ;;
  *) fail "DMG is not signed with a Developer ID Application certificate" ;;
esac

step "Notarizing DMG"
xcrun notarytool submit "$OUT_DIR/$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 30m \
  || fail "DMG notarization failed"
xcrun stapler staple "$OUT_DIR/$DMG_NAME" || fail "Stapling the DMG failed"
xcrun stapler validate "$OUT_DIR/$DMG_NAME" >/dev/null || fail "Stapled ticket did not validate"
DMG_SPCTL="$(spctl -a -t install -vv "$OUT_DIR/$DMG_NAME" 2>&1 || true)"
case "$DMG_SPCTL" in
  *"source=Notarized Developer ID"*) ;;
  *) fail "Gatekeeper does not accept the DMG as Notarized Developer ID: $DMG_SPCTL" ;;
esac
echo "DMG notarized and stapled."

step "Verifying app inside the DMG"
MOUNT="$(hdiutil attach "$OUT_DIR/$DMG_NAME" -nobrowse -readonly | tail -1 | sed 's|.*\(/Volumes/.*\)|\1|')"
trap 'hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true' EXIT
codesign --verify --deep --strict "$MOUNT/Gleam.app" || fail "App inside the DMG failed verification"
xcrun stapler validate "$MOUNT/Gleam.app" >/dev/null || fail "App inside the DMG is not stapled"
hdiutil detach "$MOUNT" -quiet
trap - EXIT
echo "App inside the DMG verifies and is stapled."

step "Generating Sparkle appcast"
CAST_DIR="$OUT_DIR/appcast"
mkdir -p "$CAST_DIR"
cp "$OUT_DIR/$DMG_NAME" "$CAST_DIR/"
"$GENERATE_APPCAST" --download-url-prefix "$DOWNLOAD_PREFIX" "$CAST_DIR" || fail "generate_appcast failed"
cp "$CAST_DIR/appcast.xml" "$OUT_DIR/appcast.xml"
APPCAST_XML="$(cat "$OUT_DIR/appcast.xml")"
case "$APPCAST_XML" in
  *"$DOWNLOAD_PREFIX$DMG_NAME"*) ;;
  *) fail "appcast does not point at $DOWNLOAD_PREFIX$DMG_NAME" ;;
esac
CAST_LEN="$(sed -n 's/.*length="\([0-9]*\)".*/\1/p' "$OUT_DIR/appcast.xml" | head -1)"
DMG_LEN="$(stat -f%z "$OUT_DIR/$DMG_NAME")"
[ "$CAST_LEN" = "$DMG_LEN" ] || fail "appcast length $CAST_LEN != DMG size $DMG_LEN"
PUB_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist" 2>/dev/null || true)"
[ -n "$PUB_KEY" ] || fail "App has no SUPublicEDKey; Sparkle updates would be unsigned"
case "$APPCAST_XML" in
  *"sparkle:edSignature"*) ;;
  *) fail "appcast has no edSignature" ;;
esac
echo "appcast.xml signed, enclosure length matches."

rm -rf "$CAST_DIR"

step "Ready to publish $TAG to $REPO"
echo "  $OUT_DIR/$DMG_NAME    (website download)"
echo "  $OUT_DIR/appcast.xml (Sparkle feed)"
if [ "$ASSUME_YES" -ne 1 ]; then
  read -r -p "Publish this release now? [y/N] " reply
  case "$reply" in [yY]*) ;; *) echo "Stopped. Artifacts remain in $OUT_DIR"; exit 0 ;; esac
fi

step "Publishing"
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG exists, updating."
  gh release edit "$TAG" --notes "$NOTES"
  gh release upload "$TAG" \
    "$OUT_DIR/$DMG_NAME" "$OUT_DIR/appcast.xml" --clobber
else
  gh release create "$TAG" \
    "$OUT_DIR/$DMG_NAME" "$OUT_DIR/appcast.xml" \
    --title "Gleam $VERSION" --notes "$NOTES"
fi

step "Verifying published URLs"
LATEST="https://github.com/$REPO/releases/latest/download"
echo "GitHub's latest/download redirect is edge-cached; polling until it reflects $TAG."
FEED=""
for attempt in $(seq 1 30); do
  FEED="$(curl -sL "$LATEST/appcast.xml" || true)"
  case "$FEED" in *"$DOWNLOAD_PREFIX$DMG_NAME"*) break ;; esac
  sleep 10
done
case "$FEED" in
  *"$DOWNLOAD_PREFIX$DMG_NAME"*) ;;
  *) fail "Published feed still does not point at $DOWNLOAD_PREFIX$DMG_NAME after 5 minutes" ;;
esac

for name in "$DMG_NAME" "appcast.xml"; do
  code="$(curl -sL -o /dev/null -w '%{http_code}' "$LATEST/$name")"
  [ "$code" = "200" ] || fail "$LATEST/$name returned $code"
  echo "  $LATEST/$name -> 200"
done

ENCLOSURE="$(printf '%s' "$FEED" | sed -n 's/.*enclosure url="\([^"]*\)".*/\1/p' | head -1)"
FEED_LEN="$(printf '%s' "$FEED" | sed -n 's/.*length="\([0-9]*\)".*/\1/p' | head -1)"
echo "  feed enclosure -> $ENCLOSURE"
[ "$FEED_LEN" = "$DMG_LEN" ] || fail "published feed length $FEED_LEN != local DMG size $DMG_LEN"

LIVE_SHA="$(curl -sL "$ENCLOSURE" | shasum -a 256 | cut -d' ' -f1)"
LOCAL_SHA="$(shasum -a 256 "$OUT_DIR/$DMG_NAME" | cut -d' ' -f1)"
[ "$LIVE_SHA" = "$LOCAL_SHA" ] || fail "Published DMG hash $LIVE_SHA != local $LOCAL_SHA"
echo "  published DMG matches local build ($LOCAL_SHA)"

STABLE_SHA="$(curl -sL "$LATEST/$DMG_NAME" | shasum -a 256 | cut -d' ' -f1)"
[ "$STABLE_SHA" = "$LOCAL_SHA" ] || fail "$LATEST/$DMG_NAME hash $STABLE_SHA != local $LOCAL_SHA"
echo "  latest/download/$DMG_NAME matches the published build"

echo
echo "Released $TAG"
echo "  Website download: $LATEST/$DMG_NAME"
echo "  Sparkle feed:     $LATEST/appcast.xml"
