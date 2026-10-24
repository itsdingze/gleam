import Foundation
import os

extension Logger {
    nonisolated init(category: String) {
        self.init(subsystem: Bundle.main.bundleIdentifier ?? "Gleam", category: category)
    }
}
