@MainActor
protocol UpdateService: AnyObject {
    func isAutomaticCheckEnabled() -> Bool
    func setAutomaticCheckEnabled(_ enabled: Bool)
    func start()
}
