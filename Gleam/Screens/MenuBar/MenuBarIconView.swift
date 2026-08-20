import SwiftUI

struct MenuBarIconView: View {
    @Environment(MenuBarViewModel.self) private var viewModel

    var body: some View {
        Image(systemName: "camera.fill")
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(viewModel.isOn ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                    .overlay {
                        Circle()
                            .stroke(.black, lineWidth: 1.5)
                    }
                    .offset(x: 2, y: 2)
            }
            .accessibilityLabel(viewModel.isOn ? "Gleam on" : "Gleam off")
    }
}
