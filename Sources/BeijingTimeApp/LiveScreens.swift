import AppKit
import CoreGraphics
import BeijingTimeCore

enum LiveScreens {
    static func snapshot() -> [DisplayScreen] {
        let menuBarScreen = NSScreen.screens.first
        return NSScreen.screens.map { screen in
            let display = displayID(of: screen)
            let isMenuBar = screen == menuBarScreen
            let revealed = screen.frame.maxY - screen.visibleFrame.maxY
            return DisplayScreen(
                id: stableID(of: screen, display: display),
                frame: screen.frame,
                isBuiltIn: display.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
                hasMenuBar: isMenuBar,
                expandedMenuBarHeight: MenuBarReserve.height(
                    isMenuBarScreen: isMenuBar,
                    revealedGap: revealed,
                    statusBarThickness: NSStatusBar.system.thickness,
                    safeAreaTop: screen.safeAreaInsets.top
                )
            )
        }
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }

    private static func stableID(of screen: NSScreen, display: CGDirectDisplayID?) -> String {
        if let display, let unmanaged = CGDisplayCreateUUIDFromDisplayID(display) {
            let uuid = unmanaged.takeRetainedValue()
            return CFUUIDCreateString(nil, uuid) as String
        }
        let frame = screen.frame
        return "frame-\(frame.origin.x)-\(frame.origin.y)-\(frame.width)x\(frame.height)"
    }
}
