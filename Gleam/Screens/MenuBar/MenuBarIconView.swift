import SwiftUI

struct MenuBarIconView: View {
    @Environment(MenuBarViewModel.self) private var viewModel

    var body: some View {
        Image(nsImage: MenuBarStatusImage.make(isOn: viewModel.isOn))
            .accessibilityLabel(viewModel.isOn ? "Gleam on" : "Gleam off")
    }
}
