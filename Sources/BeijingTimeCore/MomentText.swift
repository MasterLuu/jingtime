import Foundation

public enum MomentText {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    public static func string(at instant: Date) -> String {
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: instant
        )
        return String(
            format: "%04d年%02d月%02d日 %02d:%02d:%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0,
            parts.hour ?? 0,
            parts.minute ?? 0,
            parts.second ?? 0
        )
    }

    /// 亚洲/上海无夏令时，整秒和参考时间的整秒对齐。恰好卡在整秒上时，下一次是下一秒。
    public static func nextWake(after instant: Date) -> Date {
        let next = floor(instant.timeIntervalSinceReferenceDate) + 1
        return Date(timeIntervalSinceReferenceDate: next)
    }
}
