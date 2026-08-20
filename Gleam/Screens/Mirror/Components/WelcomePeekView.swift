import SwiftUI

struct WelcomePeekView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.wave.fill")
                .foregroundStyle(Color.yellow)
                .symbolEffect(.wiggle, options: .repeat(.continuous))
                .accessibilityHidden(true)
            Text("I'm here!")
        }
        .font(.title3)
    }
}

#if DEBUG
#Preview("Welcome peek") {
    WelcomePeekView()
        .frame(width: 200, height: 56)
        .background(Color.black)
}
#endif
