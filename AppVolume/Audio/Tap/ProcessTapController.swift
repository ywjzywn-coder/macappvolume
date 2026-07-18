import CoreAudio
import Foundation

enum ProcessTapError: LocalizedError {
    case emptyProcessList
    case permissionDenied
    case createFailed(OSStatus)
    case destroyFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyProcessList:
            return "没有可控制的音频进程"
        case .permissionDenied:
            return "需要屏幕录制权限才能静音其他 App"
        case .createFailed(let status):
            return "创建 Process Tap 失败（\(status)）"
        case .destroyFailed(let status):
            return "销毁 Process Tap 失败（\(status)）"
        }
    }
}

/// Creates mute-only process taps via public Core Audio Process Tap API (macOS 14.2+).
final class ProcessTapController: @unchecked Sendable {
    private struct TapRecord {
        let tapID: AudioObjectID
        let processObjectIDs: [AudioObjectID]
    }

    private let lock = NSLock()
    private var taps: [String: TapRecord] = [:]

    func isActive(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return taps[key] != nil
    }

    func activeKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(taps.keys)
    }

    /// Ensures a private mute tap exists for the given process objects.
    func ensureMuteTap(key: String, processObjectIDs: [AudioObjectID]) throws {
        let ids = Array(Set(processObjectIDs)).sorted()
        guard !ids.isEmpty else { throw ProcessTapError.emptyProcessList }

        lock.lock()
        if let existing = taps[key], existing.processObjectIDs == ids {
            lock.unlock()
            return
        }
        let previous = taps.removeValue(forKey: key)
        lock.unlock()

        if let previous {
            destroyTapID(previous.tapID)
        }

        guard ScreenCapturePermission.requestIfNeeded() else {
            throw ProcessTapError.permissionDenied
        }

        let description = CATapDescription(stereoMixdownOfProcesses: ids)
        description.name = "AppVolume.\(key)"
        description.uuid = UUID()
        // CATapMuted = 1 — silences process output while tap exists.
        description.muteBehavior = CATapMuteBehavior(rawValue: 1)!
        description.isPrivate = true
        if #available(macOS 26.0, *) {
            description.isProcessRestoreEnabled = true
        }

        var tapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr, tapID != kAudioObjectUnknown else {
            AVLog.error("AudioHardwareCreateProcessTap failed: \(status)")
            if !ScreenCapturePermission.isGranted {
                throw ProcessTapError.permissionDenied
            }
            throw ProcessTapError.createFailed(status)
        }

        lock.lock()
        taps[key] = TapRecord(tapID: tapID, processObjectIDs: ids)
        lock.unlock()
        AVLog.info("Mute tap created for \(key) tapID=\(tapID) processes=\(ids.count)")
    }

    func destroy(key: String) {
        lock.lock()
        let record = taps.removeValue(forKey: key)
        lock.unlock()
        if let record {
            destroyTapID(record.tapID)
            AVLog.info("Mute tap destroyed for \(key)")
        }
    }

    func destroyAll() {
        lock.lock()
        let values = Array(taps.values)
        taps.removeAll()
        lock.unlock()
        for record in values {
            destroyTapID(record.tapID)
        }
    }

    private func destroyTapID(_ tapID: AudioObjectID) {
        let status = AudioHardwareDestroyProcessTap(tapID)
        if status != noErr {
            AVLog.error("AudioHardwareDestroyProcessTap failed: \(status)")
        }
    }
}
