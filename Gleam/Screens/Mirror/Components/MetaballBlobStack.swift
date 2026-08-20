import SwiftUI

struct MetaballBlobStack: View {
    let notchSize: CGSize
    let notchCornerRadius: CGFloat
    let bodySize: CGSize
    let bodyTopOffset: CGFloat
    let bodyCornerRadius: CGFloat
    let blurRadius: CGFloat

    private static let topBleed: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let notchPath = notchPath(midX: size.width / 2)
                let bodyPath = bodyPath(midX: size.width / 2)

                var melted = context
                melted.addFilter(.alphaThreshold(min: 0.5, color: .black))
                melted.addFilter(.blur(radius: blurRadius))
                melted.drawLayer { layer in
                    layer.fill(notchPath, with: .color(.white))
                    layer.fill(bodyPath, with: .color(.white))
                }

                context.fill(notchPath, with: .color(.black))
                context.fill(bodyPath, with: .color(.black))
            }
            .frame(width: proxy.size.width, height: proxy.size.height + Self.topBleed)
            .offset(y: -Self.topBleed)
        }
    }

    private func notchPath(midX: CGFloat) -> Path {
        Path(
            roundedRect: CGRect(
                x: midX - notchSize.width / 2,
                y: 0,
                width: notchSize.width,
                height: notchSize.height + Self.topBleed
            ),
            cornerRadii: RectangleCornerRadii(
                bottomLeading: notchCornerRadius,
                bottomTrailing: notchCornerRadius
            )
        )
    }

    private func bodyPath(midX: CGFloat) -> Path {
        Path(
            roundedRect: CGRect(
                x: midX - bodySize.width / 2,
                y: Self.topBleed + bodyTopOffset,
                width: bodySize.width,
                height: bodySize.height
            ),
            cornerRadius: bodyCornerRadius
        )
    }
}

#if DEBUG
#Preview("Morph check — circle from rect") {
    @Previewable @State var drop: CGFloat = 0

    VStack(spacing: 24) {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.5, color: .black))
            context.addFilter(.blur(radius: 12))
            context.drawLayer { layer in
                layer.fill(
                    Path(
                        roundedRect: CGRect(x: size.width / 2 - 110, y: 0, width: 220, height: 80),
                        cornerRadius: 20
                    ),
                    with: .color(.white)
                )
                layer.fill(
                    Path(ellipseIn: CGRect(x: size.width / 2 - 32, y: drop, width: 64, height: 64)),
                    with: .color(.white)
                )
            }
        }
        .frame(width: 320, height: 380)

        Slider(value: $drop, in: 0...280)
    }
    .padding(32)
    .background(.gray)
}
#endif
