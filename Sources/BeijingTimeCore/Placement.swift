import CoreGraphics
import Foundation

public struct DisplayScreen: Equatable, Sendable {
    public var id: String
    public var frame: CGRect
    public var isBuiltIn: Bool
    public var hasMenuBar: Bool
    public var expandedMenuBarHeight: CGFloat

    public init(
        id: String,
        frame: CGRect,
        isBuiltIn: Bool,
        hasMenuBar: Bool,
        expandedMenuBarHeight: CGFloat
    ) {
        self.id = id
        self.frame = frame
        self.isBuiltIn = isBuiltIn
        self.hasMenuBar = hasMenuBar
        self.expandedMenuBarHeight = expandedMenuBarHeight
    }
}

public struct Stay: Equatable, Sendable {
    public var screenID: String
    public var relativeOrigin: CGPoint

    public init(screenID: String, relativeOrigin: CGPoint) {
        self.screenID = screenID
        self.relativeOrigin = relativeOrigin
    }
}

public struct ResolvedPlacement: Equatable, Sendable {
    public var stay: Stay
    public var origin: CGPoint
    public var source: Source

    public enum Source: Equatable, Sendable {
        case firstPlacement
        case restored
        case missingScreen

        /// 屏暂时不在时，只改画面上的位置，不改已经记住的停留位置。
        public var writesStay: Bool {
            switch self {
            case .firstPlacement, .restored:
                return true
            case .missingScreen:
                return false
            }
        }
    }

    public init(stay: Stay, origin: CGPoint, source: Source) {
        self.stay = stay
        self.origin = origin
        self.source = source
    }
}

public enum MenuBarReserve {
    public static func height(
        isMenuBarScreen: Bool,
        revealedGap: CGFloat,
        statusBarThickness: CGFloat,
        safeAreaTop: CGFloat
    ) -> CGFloat {
        guard isMenuBarScreen else { return 0 }
        if revealedGap > 1 { return revealedGap }
        return max(statusBarThickness, safeAreaTop, 24)
    }
}

public enum Placement {
    public static let cornerInset: CGFloat = 8
    public static let grabWidth: CGFloat = 80
    public static let grabHeight: CGFloat = 24

    public static func resolve(
        stay: Stay?,
        among screens: [DisplayScreen],
        windowSize: CGSize
    ) -> ResolvedPlacement? {
        guard !screens.isEmpty else { return nil }
        if let stay, let screen = screens.first(where: { $0.id == stay.screenID }) {
            let absolute = CGPoint(
                x: screen.frame.minX + stay.relativeOrigin.x,
                y: screen.frame.minY + stay.relativeOrigin.y
            )
            let origin = clamp(origin: absolute, windowSize: windowSize, to: [screen])
            let stuck = Stay(
                screenID: screen.id,
                relativeOrigin: CGPoint(
                    x: origin.x - screen.frame.minX,
                    y: origin.y - screen.frame.minY
                )
            )
            return ResolvedPlacement(stay: stuck, origin: origin, source: .restored)
        }

        guard let screen = defaultScreen(among: screens) else { return nil }
        let origin = defaultOrigin(on: screen, windowSize: windowSize)
        let source: ResolvedPlacement.Source = stay == nil ? .firstPlacement : .missingScreen
        return ResolvedPlacement(
            stay: Stay(
                screenID: screen.id,
                relativeOrigin: CGPoint(
                    x: origin.x - screen.frame.minX,
                    y: origin.y - screen.frame.minY
                )
            ),
            origin: origin,
            source: source
        )
    }

    public static func clamp(origin: CGPoint, windowSize: CGSize, to screens: [DisplayScreen]) -> CGPoint {
        guard !screens.isEmpty else { return origin }
        if screens.contains(where: { containsClosed(allowedOriginRect(on: $0, windowSize: windowSize), origin) }) {
            return origin
        }
        let candidates = screens.map { nearest(origin, in: allowedOriginRect(on: $0, windowSize: windowSize)) }
        return candidates.min(by: { distanceSquared($0, origin) < distanceSquared($1, origin) }) ?? origin
    }

    public static func stick(
        windowOrigin: CGPoint,
        windowSize: CGSize,
        among screens: [DisplayScreen]
    ) -> Stay? {
        guard let bestScreen = screenUnderMost(of: CGRect(origin: windowOrigin, size: windowSize), among: screens) else {
            return nil
        }
        return Stay(
            screenID: bestScreen.id,
            relativeOrigin: CGPoint(
                x: windowOrigin.x - bestScreen.frame.minX,
                y: windowOrigin.y - bestScreen.frame.minY
            )
        )
    }

    /// 时刻文本变宽或变窄时，小窗在所在那块屏的右半边就守住右边缘，左半边就守住左边缘。
    public static func resize(
        origin: CGPoint,
        from oldSize: CGSize,
        to newSize: CGSize,
        among screens: [DisplayScreen]
    ) -> CGPoint {
        let window = CGRect(origin: origin, size: oldSize)
        var resized = origin
        if let screen = screenUnderMost(of: window, among: screens), window.midX > screen.frame.midX {
            resized.x = window.maxX - newSize.width
        }
        return clamp(origin: resized, windowSize: newSize, to: screens)
    }

    private static func screenUnderMost(of window: CGRect, among screens: [DisplayScreen]) -> DisplayScreen? {
        var bestScreen: DisplayScreen?
        var bestArea: CGFloat = 0
        for screen in screens {
            let overlap = window.intersection(screen.frame)
            let area: CGFloat
            if overlap.isNull || overlap.isInfinite {
                area = 0
            } else {
                area = max(0, overlap.width) * max(0, overlap.height)
            }
            if area > bestArea {
                bestArea = area
                bestScreen = screen
            }
        }
        return bestScreen
    }

    private static func defaultScreen(among screens: [DisplayScreen]) -> DisplayScreen? {
        if let builtIn = screens.first(where: { $0.isBuiltIn && $0.hasMenuBar }) {
            return builtIn
        }
        if let builtIn = screens.first(where: \.isBuiltIn) {
            return builtIn
        }
        if let menuBar = screens.first(where: \.hasMenuBar) {
            return menuBar
        }
        return screens.first
    }

    private static func defaultOrigin(on screen: DisplayScreen, windowSize: CGSize) -> CGPoint {
        let proposed = CGPoint(
            x: screen.frame.maxX - windowSize.width - cornerInset,
            y: screen.frame.maxY - screen.expandedMenuBarHeight - windowSize.height - cornerInset
        )
        return clamp(origin: proposed, windowSize: windowSize, to: [screen])
    }

    private static func allowedOriginRect(on screen: DisplayScreen, windowSize: CGSize) -> CGRect {
        let grabW = min(grabWidth, windowSize.width)
        let grabH = min(grabHeight, windowSize.height)
        let minX = screen.frame.minX + grabW - windowSize.width
        let maxX = screen.frame.maxX - grabW
        let minY = screen.frame.minY + grabH - windowSize.height
        let maxY = screen.frame.maxY - grabH
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func containsClosed(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }

    private static func nearest(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private static func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}
