import Testing
@testable import BeijingTimeCore

struct PresenceTests {
    @Test func aFreshClockIsOnScreenAndWakesEachSecond() {
        let presence = Presence()
        #expect(presence.showsWindow)
        #expect(presence.wakesEachSecond)
        #expect(presence.canQuit)
    }

    @Test func hideLastsUntilTheSameShortcutBringsItBack() {
        let hidden = Presence().togglingHide()
        #expect(hidden.userHidden)
        #expect(!hidden.showsWindow)
        #expect(!hidden.wakesEachSecond)
        #expect(!hidden.canQuit)

        let shown = hidden.togglingHide()
        #expect(!shown.userHidden)
        #expect(shown.showsWindow)
        #expect(shown.wakesEachSecond)
    }

    @Test func lockAndScreenSaverSuspendWithoutChangingHide() {
        let locked = Presence(locked: true)
        #expect(!locked.userHidden)
        #expect(!locked.showsWindow)
        #expect(!locked.wakesEachSecond)
        #expect(!locked.canQuit)
        #expect(locked.togglingHide() == locked)

        let saver = Presence(savingScreen: true)
        #expect(!saver.userHidden)
        #expect(!saver.showsWindow)
        #expect(saver.togglingHide() == saver)

        let hiddenThenLocked = Presence(userHidden: true, locked: true)
        #expect(hiddenThenLocked.userHidden)
        #expect(!hiddenThenLocked.showsWindow)

        let unlocked = Presence(userHidden: true, locked: false)
        #expect(unlocked.userHidden)
        #expect(!unlocked.showsWindow)
    }

    @Test func displaySleepStopsTheWakeButKeepsTheWindow() {
        let asleep = Presence(asleep: true)
        #expect(asleep.showsWindow)
        #expect(!asleep.wakesEachSecond)
        #expect(asleep.canQuit)
    }
}
