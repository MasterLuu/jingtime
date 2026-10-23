import Foundation

public enum MomentText {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// 日历的 weekday 从周日的 1 数起。
    private static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    public static func string(at instant: Date, showsMilliseconds: Bool = false) -> String {
        let whole = floor(instant.timeIntervalSinceReferenceDate)
        let parts = calendar.dateComponents(
            [.year, .month, .day, .weekday, .hour, .minute, .second],
            from: Date(timeIntervalSinceReferenceDate: whole)
        )
        let text = String(
            format: "%04d年%02d月%02d日 周%@ %02d:%02d:%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0,
            weekdays[((parts.weekday ?? 1) - 1) % 7],
            parts.hour ?? 0,
            parts.minute ?? 0,
            parts.second ?? 0
        )
        guard showsMilliseconds else { return text }
        // 先取到整毫秒，抹掉 Double 的尾差（.3 存成 .2999999…），再只留第一位。
        let milliseconds = min(999, Int(((instant.timeIntervalSinceReferenceDate - whole) * 1000).rounded()))
        return text + " \(milliseconds / 100)"
    }

    /// 亚洲/上海无夏令时，整秒和参考时间的整秒对齐。恰好卡在整秒上时，下一次是下一秒。
    /// 显示毫秒时每秒醒 10 次，落在十分之一秒上。
    public static func nextWake(after instant: Date, showsMilliseconds: Bool = false) -> Date {
        let wakesPerSecond: Double = showsMilliseconds ? 10 : 1
        let next = (floor(instant.timeIntervalSinceReferenceDate * wakesPerSecond) + 1) / wakesPerSecond
        return Date(timeIntervalSinceReferenceDate: next)
    }
}
