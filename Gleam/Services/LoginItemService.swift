@MainActor
protocol LoginItemService: AnyObject {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}
