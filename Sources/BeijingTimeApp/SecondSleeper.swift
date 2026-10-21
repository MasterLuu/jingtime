import Foundation
import BeijingTimeCore

/// 看得见时才排下一次北京整秒。隐藏、暂隐、屏幕睡着时没有计时器。
final class SecondSleeper {
    private var timer: Timer?

    func arm(now: Date, fire: @escaping () -> Void) {
        timer?.invalidate()
        let delay = max(0.001, MomentText.nextWake(after: now).timeIntervalSince(now))
        let timer = Timer(timeInterval: delay, repeats: false, block: { _ in fire() })
        timer.tolerance = 0.01
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func disarm() {
        timer?.invalidate()
        timer = nil
    }
}
