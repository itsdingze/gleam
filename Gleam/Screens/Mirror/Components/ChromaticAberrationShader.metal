#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Radial chromatic aberration: red samples toward the given center, blue
/// away from it, so fringes point outward like a lens edge. Alpha takes the
/// widest of the three samples so the outward fringe isn't clipped by the
/// unshifted channel's silhouette.
[[ stitchable ]] half4 chromaticAberration(
    float2 position,
    SwiftUI::Layer layer,
    float2 center,
    float strength
) {
    float2 delta = position - center;
    float dist = length(delta);
    float2 shift = dist > 0 ? delta / dist * strength : float2(0);

    half4 red = layer.sample(position - shift);
    half4 green = layer.sample(position);
    half4 blue = layer.sample(position + shift);

    half alpha = max(red.a, max(green.a, blue.a));
    return half4(red.r, green.g, blue.b, alpha);
}
