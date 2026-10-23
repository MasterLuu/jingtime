import Foundation

/// 显示毫秒是跨运行记住的；从没设过时不显示。
struct MillisecondsStore {
    private let defaults: UserDefaults
    private let key = "moment.showsMilliseconds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Bool {
        defaults.bool(forKey: key)
    }

    func save(_ showsMilliseconds: Bool) {
        defaults.set(showsMilliseconds, forKey: key)
    }
}
