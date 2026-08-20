import CoreGraphics
import Testing
@testable import Gleam

struct MirrorLayoutTests {
    private let layout = MirrorLayout(
        screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 900),
        notchSize: CGSize(width: 180, height: 32)
    )

    @Test func collapsedPanelMatchesThePhysicalNotch() {
        #expect(layout.collapsedFrame == CGRect(x: 410, y: 868, width: 180, height: 32))
    }

    @Test func expandedSilhouetteHangsTheBodyBelowTheNotch() {
        #expect(layout.expandedFrame == CGRect(x: 320, y: 508, width: 360, height: 392))
    }

    @Test func panelAddsBounceSlackAroundTheExpandedSilhouette() {
        #expect(layout.panelFrame == CGRect(x: 276, y: 464, width: 448, height: 436))
        #expect(layout.panelFrame.maxY == layout.expandedFrame.maxY)
    }

    @Test func openFrameIsExactlyTheNotchPlusATopEdgeEpsilon() {
        // CGRect's maxY edge is exclusive, so a cursor pinned there reads as outside.
        #expect(layout.openFrame == CGRect(x: 410, y: 868, width: 180, height: 33))
        #expect(layout.hoverFrame(for: .collapsed) == layout.openFrame)
    }

    @Test func expandedHoverFrameAddsTwentyFourPointsOnEverySide() {
        #expect(layout.expandedHoverFrame == CGRect(x: 296, y: 484, width: 408, height: 440))
    }
}
