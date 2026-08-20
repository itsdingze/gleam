import Foundation
import Testing
@testable import Gleam

struct LoadingDotPulseTests {
    @Test func eachDotBreathesOverTime() throws {
        let period = 2 * .pi / LoadingDotPulse.speed
        let samples = stride(from: 0.0, through: period, by: period / 40).map {
            LoadingDotPulse.scale(index: 0, of: 6, time: $0, converge: 0)
        }
        #expect(try #require(samples.max()) > 1)
        #expect(try #require(samples.min()) < 1)
    }

    @Test func dotsPulseOutOfPhaseSoTheRingWaves() {
        let scales = (0..<6).map {
            LoadingDotPulse.scale(index: $0, of: 6, time: 0.4, converge: 0)
        }
        #expect(Set(scales.map { ($0 * 10_000).rounded() }).count > 1)
    }

    @Test func convergeSilencesThePulse() {
        for time in stride(from: 0.0, through: 2.0, by: 0.25) {
            #expect(LoadingDotPulse.scale(index: 2, of: 6, time: time, converge: 1) == 1)
        }
    }

    @Test func pulseStaysWithinItsAmplitudeSoDotsNeverVanishInTheThreshold() {
        for index in 0..<6 {
            for time in stride(from: 0.0, through: 3.0, by: 0.05) {
                let scale = LoadingDotPulse.scale(index: index, of: 6, time: time, converge: 0)
                #expect(scale >= 1 - LoadingDotPulse.amplitude)
                #expect(scale <= 1 + LoadingDotPulse.amplitude)
            }
        }
    }
}
