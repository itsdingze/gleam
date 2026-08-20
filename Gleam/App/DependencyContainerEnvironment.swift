import SwiftUI

extension View {
    func withDependencyContainer(_ container: DependencyContainer) -> some View {
        self
            .environment(container.appState)
            .environment(container.mirrorViewModel)
            .environment(container.onboardingViewModel)
            .environment(container.menuBarViewModel)
    }
}
