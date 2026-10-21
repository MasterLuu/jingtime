import CoreGraphics
import Foundation
import BeijingTimeCore

struct StayStore {
    private let defaults: UserDefaults
    private let idKey = "stay.screenID"
    private let xKey = "stay.x"
    private let yKey = "stay.y"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Stay? {
        guard let id = defaults.string(forKey: idKey) else { return nil }
        guard defaults.object(forKey: xKey) != nil, defaults.object(forKey: yKey) != nil else { return nil }
        return Stay(
            screenID: id,
            relativeOrigin: CGPoint(x: defaults.double(forKey: xKey), y: defaults.double(forKey: yKey))
        )
    }

    func save(_ stay: Stay) {
        defaults.set(stay.screenID, forKey: idKey)
        defaults.set(Double(stay.relativeOrigin.x), forKey: xKey)
        defaults.set(Double(stay.relativeOrigin.y), forKey: yKey)
    }
}
