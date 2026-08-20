import SwiftUI

@Animatable
struct MetaballNotchSilhouette: View {
    @AnimatableIgnored var geometry: NotchMirrorGeometry
    var progress: CGFloat

    private static let gooeyBlur: CGFloat = 10
    private static let blurRampEnd: CGFloat = 0.25

    var body: some View {
        let morph = geometry.morph(at: progress)
        MetaballBlobStack(
            notchSize: geometry.notchSize,
            notchCornerRadius: geometry.notchCornerRadius,
            bodySize: morph.bodySize,
            bodyTopOffset: morph.bodyTopOffset,
            bodyCornerRadius: morph.bodyCornerRadius,
            blurRadius: Self.gooeyBlur * min(1, max(0, progress) / Self.blurRampEnd)
        )
    }
}

#if DEBUG
#Preview("Expand scrub") {
    @Previewable @State var progress: CGFloat = 0

    VStack(spacing: 24) {
        MetaballNotchSilhouette(geometry: .preview, progress: progress)
            .frame(width: 380, height: 380, alignment: .top)
            .background(.gray)
        Slider(value: $progress, in: 0...1)
    }
    .padding(32)
}

#Preview("Expand animated") {
    @Previewable @State var isExpanded = false

    VStack(spacing: 24) {
        MetaballNotchSilhouette(geometry: .preview, progress: isExpanded ? 1 : 0)
            .animation(isExpanded ? .mirrorExpand : .mirrorCollapse, value: isExpanded)
            .frame(width: 380, height: 380, alignment: .top)
            .background(.gray)
        Button(isExpanded ? "Collapse" : "Expand") { isExpanded.toggle() }
    }
    .padding(32)
}

extension NotchMirrorGeometry {
    static let preview = NotchMirrorGeometry(
        isExpanded: false,
        notchSize: CGSize(width: 200, height: 38),
        expandedSide: 300,
        bodyCornerRadius: 42
    )
}
#endif
