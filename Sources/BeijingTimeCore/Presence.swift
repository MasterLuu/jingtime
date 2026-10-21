import Foundation

public struct Presence: Equatable, Sendable {
    public var userHidden: Bool
    public var locked: Bool
    public var savingScreen: Bool
    public var asleep: Bool

    public init(
        userHidden: Bool = false,
        locked: Bool = false,
        savingScreen: Bool = false,
        asleep: Bool = false
    ) {
        self.userHidden = userHidden
        self.locked = locked
        self.savingScreen = savingScreen
        self.asleep = asleep
    }

    /// 隐藏、锁屏、屏保都不在画面上。屏幕睡着时窗口还在，只是没人看得见。
    public var showsWindow: Bool {
        !userHidden && !locked && !savingScreen
    }

    public var wakesEachSecond: Bool {
        showsWindow && !asleep
    }

    /// 人还在锁屏或屏保里时，快捷键不改变隐藏。
    public func togglingHide() -> Presence {
        guard !locked, !savingScreen else { return self }
        var copy = self
        copy.userHidden.toggle()
        return copy
    }

    public var canQuit: Bool { showsWindow }
}
