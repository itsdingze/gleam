import Combine
import SwiftUI

struct MenuBarView: View {
    @Environment(MenuBarViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 16) {
            if case .onboarding = viewModel.phase {
                Text("Finish the setup to turn Gleam on.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if case .unavailable = viewModel.phase {
                Text("Camera permission is required to use Gleam.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open System Settings", systemImage: "gear", action: viewModel.openSystemSettings)
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
            }

            if viewModel.canTogglePause {
                if viewModel.actionIsResume {
                    pauseToggleButton.buttonStyle(.borderedProminent)
                } else {
                    pauseToggleButton.buttonStyle(.bordered)
                }

                Divider()

                settingToggle("Launch at startup", isOn: $viewModel.launchAtStartup)
                settingToggle("Auto update", isOn: $viewModel.autoUpdateEnabled)
            }

            Divider()

            HStack {
                Text(viewModel.versionLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit", action: viewModel.quit)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 240)
        .onAppear(perform: viewModel.menuDidOpen)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            viewModel.menuDidOpen()
        }
    }

    private func settingToggle(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var pauseToggleButton: some View {
        Button {
            viewModel.togglePause()
        } label: {
            Text(viewModel.actionTitle)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.extraLarge)
        .accessibilityActions {
            if viewModel.canShowMirror {
                Button(viewModel.mirrorActionTitle, action: viewModel.toggleMirror)
            }
        }
    }
}
