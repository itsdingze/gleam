import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .welcome:
                welcomePage
            case .instructions:
                instructionsPage
            case .permission:
                permissionPage
            case .none:
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.step)
    }

    private var welcomePage: some View {
        OnboardingPageView(
            title: "Psst, up here",
            message: "There's a little mirror hiding in your notch."
        ) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(height: 128)
        } actions: {
            nextButton
        }
    }

    private var instructionsPage: some View {
        OnboardingPageView(
            title: "Sneak a peek",
            message: "Slide your pointer up to the notch and Gleam appears."
        ) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.largeTitle)
        } actions: {
            nextButton
        }
    }

    private var permissionPage: some View {
        OnboardingPageView(
            title: permissionTitle,
            message: permissionMessage
        ) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
        } actions: {
            permissionActions
        }
    }

    private var nextButton: some View {
        Button("Continue", systemImage: "arrow.right", action: viewModel.next)
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
    }

    @ViewBuilder
    private var permissionActions: some View {
        switch viewModel.cameraPermission {
        case .denied:
            Button("Open System Settings", systemImage: "gear", action: viewModel.openSystemSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .notDetermined, .authorized:
            Button {
                Task { await viewModel.requestCameraPermission() }
            } label: {
                if viewModel.isRequestingPermission {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Continue", systemImage: "arrow.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .disabled(viewModel.isRequestingPermission)
        }
    }

    private var permissionTitle: String {
        if viewModel.cameraPermission == .denied {
            return "Oops, camera says no"
        }
        return "One last thing"
    }

    private var permissionMessage: String {
        if viewModel.cameraPermission == .denied {
            return "Give it the green light in System Settings."
        }
        return "Gleam needs your camera to be your mirror — it's only on while you peek."
    }
}
