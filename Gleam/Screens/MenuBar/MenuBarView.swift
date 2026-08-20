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

                HStack {
                    Text("Launch at startup")
                    Spacer()
                    Toggle("Launch at startup", isOn: $viewModel.launchAtStartup)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                HStack {
                    Text("Auto update")
                    Spacer()
                    Toggle("Auto update", isOn: $viewModel.autoUpdateEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            Divider()

            HStack {
                Text(viewModel.versionLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit", role: .destructive) {
                    viewModel.quit()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color.red)
            }
        }
        .padding(16)
        .frame(width: 240)
    }

    private var pauseToggleButton: some View {
        Button {
            viewModel.togglePause()
        } label: {
            Text(viewModel.actionTitle)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.extraLarge)
    }
}
