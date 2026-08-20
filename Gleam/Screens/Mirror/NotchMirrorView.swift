import SwiftUI

struct NotchMirrorView: View {
    let notchSize: CGSize

    @Environment(AppState.self) private var appState
    @Environment(MirrorViewModel.self) private var viewModel

    var body: some View {
        ZStack(alignment: .top) {
            MetaballNotchSilhouette(geometry: geometry, progress: morphProgress)
                .animation(morphAnimation, value: viewModel.presentation)

            FeedRevealWindow(
                geometry: geometry,
                progress: morphProgress,
                target: viewModel.presentation
            ) { feed in
                mirrorContent(feed: feed)
            }
            .animation(morphAnimation, value: viewModel.presentation)
        }
        .frame(
            width: .mirrorExpandedSide + 2 * .mirrorBounceMargin,
            height: notchSize.height + .mirrorExpandedSide + .mirrorBounceMargin,
            alignment: .top
        )
        .contentShape(NotchMirrorHitShape(geometry: geometry))
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.2), value: appState.onboardingStep)
    }

    private static let peekProgress: CGFloat = 0.1

    private var morphProgress: CGFloat {
        switch viewModel.presentation {
        case .collapsed: 0
        case .peek: Self.peekProgress
        case .expanded: 1
        }
    }

    private var morphAnimation: Animation {
        viewModel.presentation == .collapsed ? .mirrorCollapse : .mirrorExpand
    }

    private var geometry: NotchMirrorGeometry {
        NotchMirrorGeometry(isExpanded: viewModel.isExpanded, notchSize: notchSize)
    }

    @ViewBuilder
    private func mirrorContent(feed: NotchMirrorGeometry.FeedPlacement) -> some View {
        if appState.onboardingStep != nil {
            OnboardingView()
                .frame(width: geometry.expandedMirrorSize.width, height: geometry.expandedMirrorSize.height)
                .blur(radius: viewModel.isExpanded ? 0 : 8)
                .opacity(viewModel.isExpanded ? 1 : 0)
                .animation(
                    viewModel.isExpanded ? .easeOut(duration: 0.6) : .mirrorCollapse,
                    value: viewModel.presentation
                )
        } else if viewModel.isWelcomePeekContentActive {
            WelcomePeekView()
                .blur(radius: feed.blurRadius)
                .opacity(feed.opacity)
        } else if case .failed = viewModel.captureState {
            CameraUnavailableView()
                .frame(width: geometry.expandedMirrorSize.width, height: geometry.expandedMirrorSize.height)
        } else {
            MirrorLoadingView(isReady: viewModel.captureState == .running) {
                Group {
                    if let previewLayer = viewModel.previewLayer {
                        CameraPreviewView(previewLayer: previewLayer)
                            .accessibilityLabel("Live mirrored camera preview")
                    } else {
                        Color.clear
                    }
                }
                .frame(width: geometry.feedSize.width, height: geometry.feedSize.height)
                .offset(y: feed.offset)
                .blur(radius: feed.blurRadius)
                .opacity(feed.opacity)
            }
            .id(viewModel.presentation)
        }
    }
}
