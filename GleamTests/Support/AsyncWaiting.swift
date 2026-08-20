import Testing

func waitUntil(
    _ condition: () async -> Bool,
    attempts: Int = 500,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    for _ in 0..<attempts {
        if await condition() { return }
        await Task.yield()
    }
    Issue.record("Condition never held after \(attempts) yields", sourceLocation: sourceLocation)
}

func yieldRepeatedly(times: Int = 50) async {
    for _ in 0..<times {
        await Task.yield()
    }
}
