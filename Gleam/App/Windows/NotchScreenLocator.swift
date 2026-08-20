import AppKit

struct NotchScreenLocator: NotchScreenLocating {
    nonisolated init() {}

    func currentLayout() -> MirrorLayout? {
        guard let screen = physicalNotchedScreen() else { return nil }
        return layout(for: screen)
    }

    private func physicalNotchedScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.safeAreaInsets.top > 0
                && screen.auxiliaryTopLeftArea != nil
                && screen.auxiliaryTopRightArea != nil
        }
    }

    private func layout(for screen: NSScreen) -> MirrorLayout? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              screen.safeAreaInsets.top > 0 else {
            return nil
        }

        let notchSize = CGSize(
            width: screen.frame.width - left.width - right.width,
            height: screen.safeAreaInsets.top
        )
        return MirrorLayout(screenFrame: screen.frame, notchSize: notchSize)
    }
}
