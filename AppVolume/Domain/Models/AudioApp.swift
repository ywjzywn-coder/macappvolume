import AppKit
import CoreAudio

struct AudioApp: Identifiable, Hashable, Sendable {
    var id: String { bundleID }
    let bundleID: String
    let displayName: String
    let processObjectIDs: [AudioObjectID]
    let pids: [pid_t]
    let isProducingSound: Bool
    /// Connected to Core Audio HAL (may be silent).
    let isAudioClient: Bool
    /// Visible regular app from NSWorkspace (Finder-open style).
    let isRunningApp: Bool

    @MainActor
    var icon: NSImage? {
        for pid in pids {
            if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon {
                return icon
            }
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
}
