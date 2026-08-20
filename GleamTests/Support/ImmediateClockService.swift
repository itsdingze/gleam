import Foundation
@testable import Gleam

struct ImmediateClockService: ClockService {
    func sleep(for duration: Duration) async throws {}
}
