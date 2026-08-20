import CoreGraphics

struct MirrorLayout: Equatable, Sendable {
    private static let hoverMargin: CGFloat = 24

    let screenFrame: CGRect
    let notchSize: CGSize

    var collapsedFrame: CGRect {
        topCenteredFrame(size: notchSize)
    }

    var expandedFrame: CGRect {
        topCenteredFrame(
            size: CGSize(width: .mirrorExpandedSide, height: notchSize.height + .mirrorExpandedSide)
        )
    }

    var panelFrame: CGRect {
        CGRect(
            x: expandedFrame.minX - .mirrorBounceMargin,
            y: expandedFrame.minY - .mirrorBounceMargin,
            width: expandedFrame.width + 2 * .mirrorBounceMargin,
            height: expandedFrame.height + .mirrorBounceMargin
        )
    }

    // `CGRect`'s top edge is exclusive: a cursor pinned at `maxY` reads as outside without the extra 1pt.
    var openFrame: CGRect {
        var frame = collapsedFrame
        frame.size.height += 1
        return frame
    }

    var expandedHoverFrame: CGRect {
        hoverFrame(around: expandedFrame)
    }

    func hoverFrame(for presentation: MirrorPresentation) -> CGRect {
        switch presentation {
        case .collapsed, .peek:
            openFrame
        case .expanded:
            expandedHoverFrame
        }
    }

    private func topCenteredFrame(size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func hoverFrame(around frame: CGRect) -> CGRect {
        frame.insetBy(dx: -Self.hoverMargin, dy: -Self.hoverMargin)
    }
}
