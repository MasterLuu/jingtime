import Testing
import Foundation
@testable import BeijingTimeCore

private let window = CGSize(width: 260, height: 36)

private func screen(
    _ id: String,
    _ x: CGFloat,
    _ y: CGFloat,
    _ width: CGFloat,
    _ height: CGFloat,
    builtIn: Bool = false,
    menuBar: Bool = false,
    menuBarHeight: CGFloat = 0
) -> DisplayScreen {
    DisplayScreen(
        id: id,
        frame: CGRect(x: x, y: y, width: width, height: height),
        isBuiltIn: builtIn,
        hasMenuBar: menuBar,
        expandedMenuBarHeight: menuBarHeight
    )
}

struct PlacementTests {
    private let builtin = screen("builtin", 0, 0, 1440, 900, builtIn: true, menuBar: true, menuBarHeight: 24)
    private let dell = screen("dell", 1440, 0, 1920, 1080)

    @Test func defaultCornerSitsOnTheBuiltInScreenBelowTheMenuBar() {
        let resolved = Placement.resolve(stay: nil, among: [dell, builtin], windowSize: window)
        #expect(resolved?.source == .firstPlacement)
        #expect(resolved?.origin == CGPoint(x: 1172, y: 832))
        #expect(resolved?.stay == Stay(screenID: "builtin", relativeOrigin: CGPoint(x: 1172, y: 832)))
        #expect(resolved?.source.writesStay == true)
    }

    @Test func aNotchSizedMenuBarPushesTheCornerDown() {
        let tallBar = screen("builtin", 0, 0, 1440, 900, builtIn: true, menuBar: true, menuBarHeight: 37)
        let resolved = Placement.resolve(stay: nil, among: [tallBar], windowSize: window)
        #expect(resolved?.origin == CGPoint(x: 1172, y: 819))
    }

    @Test func withoutTheBuiltInScreenTheMenuBarScreenGetsTheCorner() {
        let onlyDell = screen("dell", 0, 0, 1920, 1080, menuBar: true, menuBarHeight: 24)
        let resolved = Placement.resolve(stay: nil, among: [onlyDell], windowSize: window)
        #expect(resolved?.origin == CGPoint(x: 1652, y: 1012))
        #expect(resolved?.stay.screenID == "dell")
    }

    @Test func builtInScreenWinsEvenWhenTheMenuBarIsOnTheOtherDisplay() {
        let lid = screen("builtin", 0, 0, 1440, 900, builtIn: true)
        let external = screen("dell", 1440, 0, 1920, 1080, menuBar: true, menuBarHeight: 24)
        let resolved = Placement.resolve(stay: nil, among: [external, lid], windowSize: window)
        #expect(resolved?.stay.screenID == "builtin")
        #expect(resolved?.origin == CGPoint(x: 1172, y: 856))
    }

    @Test func movingADisplayKeepsTheSamePlaceOnThatDisplay() {
        let stay = Stay(screenID: "dell", relativeOrigin: CGPoint(x: 10, y: 20))
        let moved = screen("dell", -1920, 50, 1920, 1080)
        let resolved = Placement.resolve(stay: stay, among: [builtin, moved], windowSize: window)
        #expect(resolved?.source == .restored)
        #expect(resolved?.origin == CGPoint(x: -1910, y: 70))
        #expect(resolved?.stay == stay)
        #expect(resolved?.source.writesStay == true)
    }

    @Test func aMissingDisplayFallsBackWithoutReplacingTheSavedStay() {
        let stay = Stay(screenID: "gone", relativeOrigin: CGPoint(x: 1, y: 1))
        let resolved = Placement.resolve(stay: stay, among: [dell, builtin], windowSize: window)
        #expect(resolved?.source == .missingScreen)
        #expect(resolved?.origin == CGPoint(x: 1172, y: 832))
        #expect(resolved?.source.writesStay == false)
    }

    @Test func noScreensLeavesTheClockUnplaced() {
        #expect(Placement.resolve(stay: nil, among: [], windowSize: window) == nil)
    }

    @Test func shrinkingADisplayPullsTheClockBackOntoIt() {
        let stay = Stay(screenID: "dell", relativeOrigin: CGPoint(x: 100, y: 1070))
        let shrunk = screen("dell", 0, 0, 1920, 1080)
        let resolved = Placement.resolve(stay: stay, among: [shrunk], windowSize: window)
        #expect(resolved?.origin == CGPoint(x: 100, y: 1056))
        #expect(resolved?.stay.relativeOrigin == CGPoint(x: 100, y: 1056))
    }

    @Test func dragStaysPutWhenAGrabChunkRemains() {
        let screens = [builtin, dell]
        #expect(Placement.clamp(origin: CGPoint(x: 100, y: 100), windowSize: window, to: screens) == CGPoint(x: 100, y: 100))
        #expect(Placement.clamp(origin: CGPoint(x: 1600, y: 100), windowSize: window, to: screens) == CGPoint(x: 1600, y: 100))
    }

    @Test func dragCannotLeaveEveryScreen() {
        let screens = [builtin]
        #expect(Placement.clamp(origin: CGPoint(x: 1430, y: 100), windowSize: window, to: screens) == CGPoint(x: 1360, y: 100))
        #expect(Placement.clamp(origin: CGPoint(x: -200, y: 100), windowSize: window, to: screens) == CGPoint(x: -180, y: 100))
        #expect(Placement.clamp(origin: CGPoint(x: 100, y: 890), windowSize: window, to: screens) == CGPoint(x: 100, y: 876))
        #expect(Placement.clamp(origin: CGPoint(x: 100, y: -30), windowSize: window, to: screens) == CGPoint(x: 100, y: -12))
    }

    @Test func aPointPastEveryDisplaySnapsToTheNearestGrab() {
        let snapped = Placement.clamp(origin: CGPoint(x: 10000, y: 10000), windowSize: window, to: [builtin, dell])
        #expect(snapped == CGPoint(x: 3280, y: 1056))
    }

    @Test func dropSticksToTheDisplayUnderMostOfTheWindow() {
        let onDell = Placement.stick(windowOrigin: CGPoint(x: 1500, y: 100), windowSize: window, among: [builtin, dell])
        #expect(onDell == Stay(screenID: "dell", relativeOrigin: CGPoint(x: 60, y: 100)))

        let mostlyBuiltin = Placement.stick(windowOrigin: CGPoint(x: 1300, y: 100), windowSize: window, among: [builtin, dell])
        #expect(mostlyBuiltin == Stay(screenID: "builtin", relativeOrigin: CGPoint(x: 1300, y: 100)))
    }

    @Test func onTheRightHalfResizingKeepsTheRightEdge() {
        let wide = CGSize(width: 300, height: 36)
        let widened = Placement.resize(origin: CGPoint(x: 1172, y: 832), from: window, to: wide, among: [builtin, dell])
        #expect(widened == CGPoint(x: 1132, y: 832))
        let narrowed = Placement.resize(origin: CGPoint(x: 1132, y: 832), from: wide, to: window, among: [builtin, dell])
        #expect(narrowed == CGPoint(x: 1172, y: 832))
    }

    /// 看的是小窗所在那块屏的左右半边，不是第一块屏的。
    @Test func onTheLeftHalfOfItsDisplayResizingKeepsTheLeftEdge() {
        let wide = CGSize(width: 300, height: 36)
        #expect(Placement.resize(origin: CGPoint(x: 8, y: 400), from: window, to: wide, among: [builtin, dell]) == CGPoint(x: 8, y: 400))
        #expect(Placement.resize(origin: CGPoint(x: 1500, y: 100), from: window, to: wide, among: [builtin, dell]) == CGPoint(x: 1500, y: 100))
        #expect(Placement.resize(origin: CGPoint(x: 3092, y: 100), from: window, to: wide, among: [builtin, dell]) == CGPoint(x: 3052, y: 100))
    }

    @Test func narrowingAtTheEdgeStillLeavesAGrabOnScreen() {
        let wide = CGSize(width: 300, height: 36)
        let narrowed = Placement.resize(origin: CGPoint(x: 1360, y: 400), from: wide, to: window, among: [builtin])
        #expect(narrowed == CGPoint(x: 1360, y: 400))
    }

    @Test func autoHiddenMenuBarStillReservesItsExpandedHeight() {
        #expect(MenuBarReserve.height(isMenuBarScreen: false, revealedGap: 24, statusBarThickness: 24, safeAreaTop: 0) == 0)
        #expect(MenuBarReserve.height(isMenuBarScreen: true, revealedGap: 37, statusBarThickness: 24, safeAreaTop: 0) == 37)
        #expect(MenuBarReserve.height(isMenuBarScreen: true, revealedGap: 0, statusBarThickness: 24, safeAreaTop: 0) == 24)
        #expect(MenuBarReserve.height(isMenuBarScreen: true, revealedGap: 0, statusBarThickness: 0, safeAreaTop: 0) == 24)
        #expect(MenuBarReserve.height(isMenuBarScreen: true, revealedGap: 0, statusBarThickness: 30, safeAreaTop: 40) == 40)
    }
}
