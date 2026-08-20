@testable import Gleam

@MainActor
final class MockNotchScreenLocator: NotchScreenLocating {
    var layout: MirrorLayout?

    init(layout: MirrorLayout?) {
        self.layout = layout
    }

    func currentLayout() -> MirrorLayout? {
        layout
    }
}
