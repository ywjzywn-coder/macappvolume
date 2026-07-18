import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var instanceLock: Int32 = -1

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        let lockPath = "/tmp/local.appvolume.\(getuid()).lock"
        instanceLock = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)

        guard instanceLock >= 0, flock(instanceLock, LOCK_EX | LOCK_NB) == 0 else {
            if instanceLock >= 0 {
                close(instanceLock)
                instanceLock = -1
            }
            NSApp.terminate(nil)
            return
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSSetUncaughtExceptionHandler { _ in
            AudioTeardown.shared.tearDownAll()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AudioTeardown.shared.tearDownAll()
        if instanceLock >= 0 {
            flock(instanceLock, LOCK_UN)
            close(instanceLock)
            instanceLock = -1
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
