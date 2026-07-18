import CoreAudio
import Foundation

/// Listens for default-output and process-list changes via public Core Audio notifications.
final class HardwareChangeObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var onChange: (() -> Void)?
    private var started = false

    func start(onChange: @escaping () -> Void) {
        lock.lock()
        self.onChange = onChange
        guard !started else {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()

        addListener(selector: kAudioHardwarePropertyDefaultOutputDevice)
        addListener(selector: kAudioHardwarePropertyDefaultInputDevice)
        addListener(selector: kAudioHardwarePropertyDevices)
        addListener(selector: kAudioHardwarePropertyProcessObjectList)
        addListener(selector: kAudioHardwarePropertyServiceRestarted)
    }

    func stop() {
        lock.lock()
        onChange = nil
        started = false
        lock.unlock()
        // Listeners are process-lifetime; acceptable for menu bar agent.
    }

    private func addListener(selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.lock.lock()
            let handler = self?.onChange
            self?.lock.unlock()
            handler?()
        }
        if status != noErr {
            AVLog.error("Failed to add hardware listener \(selector): \(status)")
        }
    }
}
