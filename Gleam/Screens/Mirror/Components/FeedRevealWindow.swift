import SwiftUI

@Animatable
struct FeedRevealWindow<Content: View>: View {
    @AnimatableIgnored var geometry: NotchMirrorGeometry
    var progress: CGFloat
    @AnimatableIgnored var target: MirrorPresentation
    @AnimatableIgnored @ViewBuilder var content: (_ feed: NotchMirrorGeometry.FeedPlacement) -> Content

    var body: some View {
        let window = geometry.revealWindow(at: progress)

        content(geometry.feedPlacement(at: progress, target: target))
            .frame(width: window.size.width, height: window.size.height)
            .clipShape(RoundedRectangle(cornerRadius: window.cornerRadius))
            .padding(.top, window.top)
    }
}

#if DEBUG
#Preview("Reveal scrub (red feed)") {
    @Previewable @State var progress: CGFloat = 0
    @Previewable @State var isCollapsing = false

    VStack(spacing: 24) {
        ZStack(alignment: .top) {
            MetaballNotchSilhouette(geometry: .preview, progress: progress)
            FeedRevealWindow(
                geometry: .preview,
                progress: progress,
                target: isCollapsing ? .collapsed : .expanded
            ) { feed in
                Color.red
                    .frame(
                        width: NotchMirrorGeometry.preview.feedSize.width,
                        height: NotchMirrorGeometry.preview.feedSize.height
                    )
                    .offset(y: feed.offset)
                    .blur(radius: feed.blurRadius)
                    .opacity(feed.opacity)
            }
        }
        .frame(width: 380, height: 380, alignment: .top)
        .background(.gray)

        Slider(value: $progress, in: 0...1)
        Toggle("Collapsing", isOn: $isCollapsing)
    }
    .padding(32)
}
#endif
