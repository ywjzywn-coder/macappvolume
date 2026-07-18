import AppKit
import CoreGraphics
import Foundation

enum ScreenCapturePermission {
    /// Process Tap of other apps is gated by Screen Recording TCC.
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Shows the system prompt when possible. Returns current grant state after the call.
    @discardableResult
    static func requestIfNeeded() -> Bool {
        if isGranted { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        ]
        for string in urls {
            if let url = URL(string: string) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}
