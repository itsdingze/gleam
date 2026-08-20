import SwiftUI

@main
struct GleamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .withDependencyContainer(appDelegate.container)
        } label: {
            MenuBarIconView()
                .withDependencyContainer(appDelegate.container)
        }
        .menuBarExtraStyle(.window)
    }
}
