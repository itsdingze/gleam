import os

nonisolated struct OSLogLoggerService: LoggerService {
    private let logger: Logger

    init(category: String = "gleam") {
        logger = Logger(subsystem: "com.dingze.Gleam", category: category)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
