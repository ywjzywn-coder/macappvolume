import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSSetUncaughtExceptionHandler { _ in
            AudioTeardown.shared.tearDownAll()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AudioTeardown.shared.tearDownAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
