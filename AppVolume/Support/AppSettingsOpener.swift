import AppKit
import SwiftUI

enum AppSettingsOpener {
    /// Reliable settings open for menu-bar / accessory apps.
    /// Does NOT change activation policy - that was hiding the menu bar icon.
    @MainActor
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            raiseSettingsWindows()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    static func openWindow(id: String, openWindow: OpenWindowAction) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            raiseSettingsWindows()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    private static func raiseSettingsWindows() {
        for window in NSApp.windows {
            let title = window.title.lowercased()
            if title.contains("设置")
                || title.contains("settings")
                || title.contains("preferences")
                || title.contains("appvolume")
                || window.frameAutosaveName.contains("Settings")
                || window.identifier?.rawValue.contains("settings") == true
            {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
