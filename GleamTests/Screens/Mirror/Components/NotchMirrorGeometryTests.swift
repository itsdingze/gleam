import CoreGraphics
import SwiftUI
import Testing
@testable import Gleam

struct NotchMirrorGeometryTests {
    private func geometry(expanded: Bool) -> NotchMirrorGeometry {
        NotchMirrorGeometry(
            isExpanded: expanded,
            notchSize: CGSize(width: 200, height: 38),
            expandedSide: 300,
            mirrorInset: 10,
            notchCornerRadius: 10,
            bodyCornerRadius: 42,
            feedBleed: 24,
            feedParallax: 0.6,
            feedCollapseBlur: 12
        )
    }

    private let rect = CGRect(x: 0, y: 0, width: 300, height: 338)

    @Test func collapsedBodyIsTheNotchFootprintWithNoHeight() {
        #expect(geometry(expanded: false).bodySize == CGSize(width: 200, height: 0))
    }

    @Test func expandedBodyIsTheFullSquare() {
        #expect(geometry(expanded: true).bodySize == CGSize(width: 300, height: 300))
    }

    @Test func expandedMirrorSizeIsConstantRegardlessOfExpansion() {
        #expect(geometry(expanded: false).expandedMirrorSize == CGSize(width: 280, height: 280))
        #expect(geometry(expanded: true).expandedMirrorSize == CGSize(width: 280, height: 280))
    }

    @Test func feedSizeOverflowsTheBodySquareAndNeverChanges() {
        #expect(geometry(expanded: false).feedSize == CGSize(width: 348, height: 348))
        #expect(geometry(expanded: true).feedSize == CGSize(width: 348, height: 348))
    }

    @Test func morphEndpointsPinTheBodyToTheNotchAndTheFullSquare() {
        let collapsed = geometry(expanded: false).morph(at: 0)
        #expect(collapsed.bodySize == CGSize(width: 200, height: 38))
        #expect(collapsed.bodyTopOffset == 0)
        #expect(collapsed.bodyCornerRadius == 10)

        let expanded = geometry(expanded: true).morph(at: 1)
        #expect(expanded.bodySize == CGSize(width: 300, height: 300))
        #expect(expanded.bodyTopOffset == 38)
        #expect(expanded.bodyCornerRadius == 42)
    }

    @Test func bodyEmergesFromTheNotchBeforeItBlooms() {
        let mid = geometry(expanded: true).morph(at: 0.5)
        let widthProgress = (mid.bodySize.width - 200) / (300 - 200)
        let heightProgress = (mid.bodySize.height - 38) / (300 - 38)
        #expect(widthProgress > 0)
        #expect(widthProgress < heightProgress)
    }

    @Test func morphOnlyGrowsAsProgressGrows() {
        let g = geometry(expanded: true)
        var previous = g.morph(at: 0)
        for step in 1...10 {
            let next = g.morph(at: CGFloat(step) / 10)
            #expect(next.bodySize.width >= previous.bodySize.width)
            #expect(next.bodySize.height >= previous.bodySize.height)
            #expect(next.bodyTopOffset >= previous.bodyTopOffset)
            previous = next
        }
    }

    @Test func revealWindowTopEdgeNeverEntersTheNotch() {
        let g = geometry(expanded: false)
        for step in 0...10 {
            let window = g.revealWindow(at: CGFloat(step) / 10)
            #expect(window.top >= 38)
        }
    }

    @Test func revealWindowMatchesTheInsetMorphWhileClearOfTheNotch() {
        let g = geometry(expanded: true)
        let window = g.revealWindow(at: 1)
        #expect(window.top == 48)
        #expect(window.size == CGSize(width: 280, height: 280))
        #expect(window.cornerRadius == 32)
    }

    @Test func revealWindowCollapsesToNothingUnderThePinnedCeiling() {
        let g = geometry(expanded: false)
        let window = g.revealWindow(at: 0)
        #expect(window.size.height == 0)
    }

    @Test func fullyOpenFeedPlacementIsInertForBothDirections() {
        let g = geometry(expanded: true)
        for target in [MirrorPresentation.expanded, .collapsed] {
            let placement = g.feedPlacement(at: 1, target: target)
            #expect(placement.offset == 0)
            #expect(placement.blurRadius == 0)
            #expect(placement.opacity == 1)
        }
    }

    @Test func collapsingFeedIsDraggedBlurredAndFadedWhileExpandingStaysPinned() {
        let g = geometry(expanded: false)
        let pinned = g.feedPlacement(at: 0.5, target: .expanded)
        let collapsing = g.feedPlacement(at: 0.5, target: .collapsed)

        #expect(pinned.offset == g.pinnedFeedOffset(at: 0.5))
        #expect(pinned.blurRadius == 0)
        #expect(pinned.opacity == 1)

        #expect(collapsing.offset > 0)
        #expect(collapsing.offset < pinned.offset)
        #expect(collapsing.blurRadius > 0)
        #expect(collapsing.opacity > 0)
        #expect(collapsing.opacity < 1)

        let closed = g.feedPlacement(at: 0, target: .collapsed)
        #expect(closed.opacity == 0)
    }

    @Test func expandedHitPathCoversNotchAndBodyButNotTheArmpits() {
        let path = geometry(expanded: true).hitPath(in: rect)
        #expect(path.contains(CGPoint(x: 150, y: 6)))
        #expect(path.contains(CGPoint(x: 150, y: 200)))
        #expect(path.contains(CGPoint(x: 20, y: 6)) == false)
        #expect(path.contains(CGPoint(x: 280, y: 6)) == false)
        #expect(path.contains(CGPoint(x: 2, y: 336)) == false)
        #expect(path.contains(CGPoint(x: 298, y: 336)) == false)
    }

    @Test func collapsedHitPathIsJustTheNotch() {
        let path = geometry(expanded: false).hitPath(in: rect)
        #expect(path.contains(CGPoint(x: 150, y: 10)))
        #expect(path.contains(CGPoint(x: 150, y: 60)) == false)
        #expect(path.contains(CGPoint(x: 30, y: 20)) == false)
    }
}
