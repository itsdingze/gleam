import SwiftUI

nonisolated enum LoadingDotPulse {
    static let amplitude: Double = 0.18
    static let speed: Double = 1
    static let waves: Double = 1

    static func scale(index: Int, of count: Int, time: Double, converge: Double) -> Double {
        let phase = Double(index) / Double(count) * 2 * .pi * waves
        let fade = 1 - min(1, max(0, converge))
        return 1 + amplitude * fade * sin(time * speed - phase)
    }
}

private enum LoadingChoreography {
    static let ringRadius: CGFloat = 24
    static let dotDiameter: CGFloat = 16
    static let orbiterDiameter: CGFloat = 12
    static let slowSpin: Double = 1
    static let fastSpin: Double = 3
    static let gooeyBlur: CGFloat = 4
    static let convergeDuration: Double = 0.3
    static let revealDuration: Double = 0.5
    static let mergedDiameter: CGFloat = 32
    static let minimumPlayDuration: Double = 1.5
    static let innerGlowRadius: CGFloat = 12
    static let innerGlowOpacity: Double = 0.5
    static let innerGlowColor: Color = Color.white.mix(with: .blue, by: 0.4)
    static let outerGlowRadius: CGFloat = 28
    static let outerGlowOpacity: Double = 0.35
    static let outerGlowColor: Color = Color.white.mix(with: .red, by: 0.4)
    static let introDuration: Double = 0.6
    static let introBlur: CGFloat = 8
    static let aberrationStrength: CGFloat = 0.4
    static let rimWidth: CGFloat = 2
    static let revealFlashOpacity: Double = 0.9
    static let revealSettleBlur: CGFloat = 6
    static let escapeGrace: Double = 0.1
    static let dotsCanvasSide: CGFloat = 120
}

struct MirrorLoadingView<Content: View>: View {
    var isReady: Bool
    @ViewBuilder var content: () -> Content

    @State private var readyAt: Date?
    @State private var appearedAt: Date?
    @State private var showsContentImmediately: Bool

    init(isReady: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isReady = isReady
        self.content = content
        _showsContentImmediately = State(initialValue: isReady)
    }

    var body: some View {
        if showsContentImmediately {
            content()
        } else {
            choreography
        }
    }

    private var choreography: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let readyElapsed = readyAt.map { timeline.date.timeIntervalSince($0) } ?? 0
            let converge = smoothstep(readyElapsed / LoadingChoreography.convergeDuration)
            let reveal = easeOut((readyElapsed - LoadingChoreography.convergeDuration) / LoadingChoreography.revealDuration)
            let intro = smoothstep(
                (appearedAt.map { timeline.date.timeIntervalSince($0) } ?? 0) / LoadingChoreography.introDuration
            )

            ZStack {
                if reveal >= 1 {
                    content()
                } else {
                    if reveal > 0 {
                        content()
                            .blur(radius: LoadingChoreography.revealSettleBlur * (1 - reveal))
                            .overlay(
                                Color.white
                                    .opacity(LoadingChoreography.revealFlashOpacity * (1 - reveal))
                                    .blendMode(.screen)
                            )
                            .clipShape(revealCircle(progress: reveal))
                        revealRim(progress: reveal)
                    }
                    if converge < 1 {
                        dots(time: time, converge: converge)
                            .opacity(intro)
                            .blur(radius: LoadingChoreography.introBlur * (1 - intro))
                    }
                }
            }
        }
        .onAppear {
            appearedAt = Date.now
        }
        .onChange(of: isReady) { _, ready in
            guard ready else {
                readyAt = nil
                return
            }
            let earliestEnd = (appearedAt ?? Date.now).addingTimeInterval(LoadingChoreography.minimumPlayDuration)
            readyAt = max(Date.now, earliestEnd)
        }
        // TimelineView(.animation) keeps ticking every display frame forever unless it is left.
        .task(id: readyAt) {
            guard let readyAt else { return }
            let end = readyAt.addingTimeInterval(
                LoadingChoreography.convergeDuration + LoadingChoreography.revealDuration + LoadingChoreography.escapeGrace
            )
            try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))
            guard Task.isCancelled == false else { return }
            showsContentImmediately = true
        }
    }

    // The shader pipeline rasterizes small moving blobs with visibly aliased contours; the Canvas filter chain does not.
    private func dots(time: Double, converge: Double) -> some View {
        let radius = LoadingChoreography.ringRadius * (1 - converge)
        let dotDiameter = LoadingChoreography.dotDiameter + (LoadingChoreography.mergedDiameter - LoadingChoreography.dotDiameter) * converge
        let orbiterDiameter = LoadingChoreography.orbiterDiameter + (LoadingChoreography.mergedDiameter - LoadingChoreography.orbiterDiameter) * converge
        let gooeyBlur = LoadingChoreography.gooeyBlur * (1 - converge * 0.5)

        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.addFilter(.alphaThreshold(min: 0.5, color: .white))
            context.addFilter(.blur(radius: gooeyBlur))
            context.drawLayer { layer in
                for index in 0..<6 {
                    let angle = Double(index) / 6 * 2 * .pi + time * LoadingChoreography.slowSpin
                    let pulse = LoadingDotPulse.scale(index: index, of: 6, time: time, converge: converge)
                    layer.fill(
                        dotPath(center: center, diameter: dotDiameter * pulse, angle: angle, radius: radius),
                        with: .color(.white)
                    )
                }
                layer.fill(
                    dotPath(center: center, diameter: orbiterDiameter, angle: time * LoadingChoreography.fastSpin, radius: radius),
                    with: .color(.white)
                )
            }
        }
        .frame(width: LoadingChoreography.dotsCanvasSide, height: LoadingChoreography.dotsCanvasSide)
        .layerEffect(
            ShaderLibrary.chromaticAberration(
                .float2(LoadingChoreography.dotsCanvasSide / 2, LoadingChoreography.dotsCanvasSide / 2),
                .float(LoadingChoreography.aberrationStrength)
            ),
            maxSampleOffset: CGSize(width: LoadingChoreography.aberrationStrength, height: LoadingChoreography.aberrationStrength)
        )
        // Inside the Canvas filter chain the glow would be clamped away by the alpha threshold.
        .shadow(color: LoadingChoreography.innerGlowColor.opacity(LoadingChoreography.innerGlowOpacity), radius: LoadingChoreography.innerGlowRadius)
        .shadow(color: LoadingChoreography.outerGlowColor.opacity(LoadingChoreography.outerGlowOpacity), radius: LoadingChoreography.outerGlowRadius)
        .blur(radius: 0.5)
    }

    private func dotPath(center: CGPoint, diameter: CGFloat, angle: Double, radius: CGFloat) -> Path {
        Path(
            ellipseIn: CGRect(
                x: center.x + radius * cos(angle) - diameter / 2,
                y: center.y + radius * sin(angle) - diameter / 2,
                width: diameter,
                height: diameter
            )
        )
    }

    private func revealCircle(progress: CGFloat) -> some Shape {
        RevealCircle(diameter: revealDiameter(progress: progress))
    }

    private func revealRim(progress: Double) -> some View {
        RevealCircle(diameter: revealDiameter(progress: progress))
            .strokeBorder(LoadingChoreography.innerGlowColor, lineWidth: LoadingChoreography.rimWidth)
            .shadow(color: LoadingChoreography.innerGlowColor.opacity(LoadingChoreography.innerGlowOpacity), radius: LoadingChoreography.innerGlowRadius)
            .shadow(color: LoadingChoreography.outerGlowColor.opacity(LoadingChoreography.outerGlowOpacity), radius: LoadingChoreography.outerGlowRadius)
            .opacity(1 - progress)
    }

    private func revealDiameter(progress: CGFloat) -> CGFloat {
        LoadingChoreography.mergedDiameter + (2 * .mirrorFeedBleed + .mirrorExpandedSide) * 1.42 * progress
    }

    private func smoothstep(_ x: Double) -> Double {
        let clamped = min(1, max(0, x))
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func easeOut(_ x: Double) -> Double {
        let clamped = min(1, max(0, x))
        return 1 - pow(1 - clamped, 3)
    }
}

private struct RevealCircle: InsettableShape {
    var diameter: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> RevealCircle {
        var circle = self
        circle.insetAmount += amount
        return circle
    }

    func path(in rect: CGRect) -> Path {
        let inset = diameter - insetAmount * 2
        return Path(
            ellipseIn: CGRect(
                x: rect.midX - inset / 2,
                y: rect.midY - inset / 2,
                width: inset,
                height: inset
            )
        )
    }
}

#if DEBUG
#Preview("Loading choreography") {
    @Previewable @State var isReady = false

    VStack(spacing: 24) {
        MirrorLoadingView(isReady: isReady) {
            Color.red
        }
        .frame(width: 340, height: 340)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 40))

        Button(isReady ? "Reset" : "Camera ready") { isReady.toggle() }
    }
    .padding(32)
    .background(.gray)
}
#endif
