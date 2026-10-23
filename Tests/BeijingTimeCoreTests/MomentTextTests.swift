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
        #expect(MomentText.string(at: utc(2026, 1, 5, 1, 5, 3)) == "2026年01月05日 周一 09:05:03")
        #expect(MomentText.string(at: utc(2026, 1, 5, 15, 5, 3)) == "2026年01月05日 周一 23:05:03")
    }

    /// UTC 还是周三，北京已经是周四。
    @Test func weekdayFollowsTheBeijingDate() {
        #expect(MomentText.string(at: utc(2025, 12, 31, 16, 0, 0)) == "2026年01月01日 周四 00:00:00")
    }

    @Test func sundayIsWrittenAsZhouRi() {
        #expect(MomentText.string(at: utc(2026, 10, 25, 4, 0, 0)) == "2026年10月25日 周日 12:00:00")
    }

    @Test func millisecondsAddOneDigitAfterTheSeconds() {
        let instant = utc(2026, 10, 23, 7, 16, 12).addingTimeInterval(0.22)
        #expect(MomentText.string(at: instant, showsMilliseconds: true) == "2026年10月23日 周五 15:16:12 2")
        #expect(MomentText.string(at: instant, showsMilliseconds: false) == "2026年10月23日 周五 15:16:12")
    }

    /// 只取毫秒的第一位，不四舍五入，所以秒永远不会被进上去。
    @Test func millisecondsAreCutNotRounded() {
        let end = utc(2026, 10, 23, 7, 16, 12).addingTimeInterval(0.999)
        let start = utc(2026, 10, 23, 7, 16, 12).addingTimeInterval(0.099)
        let tenth = utc(2026, 10, 23, 7, 16, 12).addingTimeInterval(0.3)
        #expect(MomentText.string(at: end, showsMilliseconds: true) == "2026年10月23日 周五 15:16:12 9")
        #expect(MomentText.string(at: start, showsMilliseconds: true) == "2026年10月23日 周五 15:16:12 0")
        #expect(MomentText.string(at: tenth, showsMilliseconds: true) == "2026年10月23日 周五 15:16:12 3")
    }

    /// 离下一秒不到半毫秒时，取整毫秒会凑出 1000，末尾仍只写一位 9，宽度不变。
    @Test func theLastHalfMillisecondStillShowsOneDigit() {
        let instant = utc(2026, 10, 23, 7, 16, 12).addingTimeInterval(0.9996)
        #expect(MomentText.string(at: instant, showsMilliseconds: true) == "2026年10月23日 周五 15:16:12 9")
    }

    @Test func nextWakeIsTheFollowingBeijingSecond() {
        let inside = Date(timeIntervalSinceReferenceDate: 1_000_000.2)
        let boundary = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(MomentText.nextWake(after: inside).timeIntervalSinceReferenceDate == 1_000_001)
        #expect(MomentText.nextWake(after: boundary).timeIntervalSinceReferenceDate == 1_000_001)
    }

    /// 显示毫秒时每秒醒 10 次，每一次都落在十分之一秒上，正好换一个数字，换秒那一下是 0。
    @Test func withMillisecondsTheClockWakesTenTimesASecondOnTheTenths() {
        let inside = Date(timeIntervalSinceReferenceDate: 1_000_000.23)
        let boundary = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let lastTenth = Date(timeIntervalSinceReferenceDate: 1_000_000.95)
        #expect(MomentText.nextWake(after: inside, showsMilliseconds: true).timeIntervalSinceReferenceDate == 1_000_000.3)
        #expect(MomentText.nextWake(after: boundary, showsMilliseconds: true).timeIntervalSinceReferenceDate == 1_000_000.1)
        #expect(MomentText.nextWake(after: lastTenth, showsMilliseconds: true).timeIntervalSinceReferenceDate == 1_000_001)
    }
}
