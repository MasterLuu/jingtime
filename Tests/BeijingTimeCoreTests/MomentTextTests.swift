import Testing
import Foundation
@testable import BeijingTimeCore

/// 输入用 UTC 日历拼出来，期望是手算的北京墙钟，不经过「亚洲/上海」那条实现。
private func utc(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int,
    _ second: Int
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second
    ))!
}

struct MomentTextTests {
    @Test func shanghaiWallClockIsZeroPaddedAndTwentyFourHour() {
        #expect(MomentText.string(at: utc(2026, 1, 5, 1, 5, 3)) == "2026年01月05日 09:05:03")
        #expect(MomentText.string(at: utc(2026, 1, 5, 15, 5, 3)) == "2026年01月05日 23:05:03")
        #expect(MomentText.string(at: utc(2025, 12, 31, 16, 0, 0)) == "2026年01月01日 00:00:00")
    }

    @Test func nextWakeIsTheFollowingBeijingSecond() {
        let inside = Date(timeIntervalSinceReferenceDate: 1_000_000.2)
        let boundary = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(MomentText.nextWake(after: inside).timeIntervalSinceReferenceDate == 1_000_001)
        #expect(MomentText.nextWake(after: boundary).timeIntervalSinceReferenceDate == 1_000_001)
    }
}
