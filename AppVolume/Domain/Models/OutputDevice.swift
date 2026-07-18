import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable, Sendable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let isDefault: Bool
    let hasInput: Bool
    let hasOutput: Bool
}

/// Backward-compatible alias used by existing call sites.
typealias OutputDevice = AudioDevice
