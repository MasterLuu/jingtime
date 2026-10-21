import Foundation

public struct FaceColor: Equatable, Sendable {
    public var white: Double
    public var alpha: Double

    public init(white: Double, alpha: Double) {
        self.white = white
        self.alpha = alpha
    }
}

public enum FixedFace {
    public static let text = FaceColor(white: 0.96, alpha: 1)

    public static func background(reduceTransparency: Bool) -> FaceColor {
        FaceColor(white: 0.08, alpha: reduceTransparency ? 1 : 0.72)
    }
}
