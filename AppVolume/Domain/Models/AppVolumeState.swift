import Foundation

struct AppVolumeState: Codable, Hashable, Sendable {
    var volume: Float
    var isMuted: Bool

    static let `default` = AppVolumeState(volume: 1.0, isMuted: false)

    /// Any state that requires Process Tap interception.
    var needsTapControl: Bool {
        isMuted || volume < 0.999
    }

    var effectiveGain: Float {
        if isMuted { return 0 }
        return min(max(volume, 0), 1)
    }
}
