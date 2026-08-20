import SwiftUI

nonisolated struct NotchMirrorGeometry: Equatable {
    var isExpanded: Bool
    var notchSize: CGSize
    var expandedSide: CGFloat
    var mirrorInset: CGFloat
    var notchCornerRadius: CGFloat
    var bodyCornerRadius: CGFloat
    var feedBleed: CGFloat
    var feedParallax: CGFloat
    var feedCollapseBlur: CGFloat

    init(
        isExpanded: Bool,
        notchSize: CGSize,
        expandedSide: CGFloat = .mirrorExpandedSide,
        mirrorInset: CGFloat = 10,
        notchCornerRadius: CGFloat = 10,
        bodyCornerRadius: CGFloat = 80,
        feedBleed: CGFloat = .mirrorFeedBleed,
        feedParallax: CGFloat = 0.6,
        feedCollapseBlur: CGFloat = 12
    ) {
        self.isExpanded = isExpanded
        self.notchSize = notchSize
        self.expandedSide = expandedSide
        self.mirrorInset = mirrorInset
        self.notchCornerRadius = notchCornerRadius
        self.bodyCornerRadius = bodyCornerRadius
        self.feedBleed = feedBleed
        self.feedParallax = feedParallax
        self.feedCollapseBlur = feedCollapseBlur
    }

    struct Morph: Equatable {
        var bodySize: CGSize
        var bodyTopOffset: CGFloat
        var bodyCornerRadius: CGFloat
    }

    func morph(at progress: CGFloat) -> Morph {
        let p = max(0, progress)
        let bloom = p * p * p
        return Morph(
            bodySize: CGSize(
                width: notchSize.width + (expandedSide - notchSize.width) * bloom,
                height: notchSize.height + (expandedSide - notchSize.height) * p
            ),
            bodyTopOffset: notchSize.height * p,
            bodyCornerRadius: notchCornerRadius + (bodyCornerRadius - notchCornerRadius) * bloom
        )
    }

    struct RevealWindow: Equatable {
        var top: CGFloat
        var size: CGSize
        var cornerRadius: CGFloat
    }

    func revealWindow(at progress: CGFloat) -> RevealWindow {
        let morph = morph(at: progress)
        let top = max(morph.bodyTopOffset + mirrorInset, notchSize.height)
        let bottom = morph.bodyTopOffset + morph.bodySize.height - mirrorInset
        return RevealWindow(
            top: top,
            size: CGSize(
                width: max(0, morph.bodySize.width - 2 * mirrorInset),
                height: max(0, bottom - top)
            ),
            cornerRadius: max(0, morph.bodyCornerRadius - mirrorInset)
        )
    }

    var bodySize: CGSize {
        isExpanded
            ? CGSize(width: expandedSide, height: expandedSide)
            : CGSize(width: notchSize.width, height: 0)
    }

    struct FeedPlacement: Equatable {
        var offset: CGFloat
        var blurRadius: CGFloat
        var opacity: CGFloat
    }

    func feedPlacement(at progress: CGFloat, target: MirrorPresentation) -> FeedPlacement {
        let pin = pinnedFeedOffset(at: progress)
        switch target {
        case .expanded, .peek:
            return FeedPlacement(offset: pin, blurRadius: 0, opacity: 1)
        case .collapsed:
            let closure = 1 - min(1, max(0, progress))
            return FeedPlacement(
                offset: pin * feedParallax,
                blurRadius: feedCollapseBlur * closure,
                opacity: 1 - closure
            )
        }
    }

    func pinnedFeedOffset(at progress: CGFloat) -> CGFloat {
        let window = revealWindow(at: progress)
        let openWindowCenter = notchSize.height + mirrorInset + (expandedSide - 2 * mirrorInset) / 2
        return openWindowCenter - (window.top + window.size.height / 2)
    }

    var expandedMirrorSize: CGSize {
        CGSize(
            width: max(0, expandedSide - 2 * mirrorInset),
            height: max(0, expandedSide - 2 * mirrorInset)
        )
    }

    var feedSize: CGSize {
        CGSize(width: expandedSide + 2 * feedBleed, height: expandedSide + 2 * feedBleed)
    }

    func hitPath(in rect: CGRect) -> Path {
        let notchRect = CGRect(
            x: rect.midX - notchSize.width / 2,
            y: rect.minY,
            width: notchSize.width,
            height: notchSize.height
        )
        let bodyRect = CGRect(
            x: rect.midX - bodySize.width / 2,
            y: rect.minY + notchSize.height,
            width: bodySize.width,
            height: bodySize.height
        )
        var path = Path()
        path.addRect(notchRect)
        if bodyRect.isEmpty == false {
            path.addPath(RoundedRectangle(cornerRadius: bodyCornerRadius).path(in: bodyRect))
        }
        return path
    }
}

nonisolated struct NotchMirrorHitShape: Shape {
    var geometry: NotchMirrorGeometry

    func path(in rect: CGRect) -> Path {
        geometry.hitPath(in: rect)
    }
}
