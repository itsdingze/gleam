import AppKit
import Testing
@testable import Gleam

struct MirrorPanelTests {
    private let panel = MirrorPanel(
        contentRect: CGRect(x: 0, y: 0, width: 388, height: 360)
    )

    @Test func panelIsBorderlessAndClickThroughChrome() {
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == .clear)
        #expect(panel.hasShadow == false)
        #expect(panel.isMovable == false)
        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }

    @Test func panelKeepsTheSizeItWasGiven() {
        #expect(panel.frame.width == 388)
        #expect(panel.frame.height == 360)
    }

    @Test func panelRefusesKeyStatusUnlessOnboardingAsksForIt() {
        #expect(panel.canBecomeKey == false)

        panel.acceptsKey = true
        #expect(panel.canBecomeKey)

        panel.acceptsKey = false
        #expect(panel.canBecomeKey == false)
    }
}
