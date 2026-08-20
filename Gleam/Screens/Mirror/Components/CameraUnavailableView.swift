import SwiftUI

struct CameraUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "Camera Unavailable",
            systemImage: "video.slash.fill",
            description: Text("Gleam could not start the camera.")
        )
    }
}

#if DEBUG
#Preview {
    CameraUnavailableView()
        .frame(width: 360, height: 360)
        .background(Color.black)
}
#endif
