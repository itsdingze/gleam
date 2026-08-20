import SwiftUI

struct OnboardingPageView<Icon: View, Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            icon()
                .accessibilityHidden(true)

            Text(title)
                .font(.title)
                .multilineTextAlignment(.center)

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            actions()
        }
        .padding(16)
        .compositingGroup()
        .transition(.blurReplace)
    }
}

#if DEBUG
#Preview {
    OnboardingPageView(
        title: "Meet Gleam",
        message: "Your mirror lives in the notch, one click away."
    ) {
        Image(systemName: "sparkles")
            .font(.largeTitle)
    } actions: {
        Button("Continue") {}
            .buttonStyle(.borderedProminent)
    }
    .frame(width: 300, height: 300)
}
#endif
