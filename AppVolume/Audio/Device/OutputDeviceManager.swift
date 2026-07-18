import CoreAudio
import Foundation

enum AudioDeviceManager {
    // MARK: - Lists

    static func listOutputDevices() -> [AudioDevice] {
        listDevices(requireOutput: true, requireInput: false, defaultID: defaultOutputDeviceID())
    }

    static func listInputDevices() -> [AudioDevice] {
        listDevices(requireOutput: false, requireInput: true, defaultID: defaultInputDeviceID())
    }

    // MARK: - Defaults

    static func defaultOutputDeviceID() -> AudioObjectID? {
        systemDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    static func defaultInputDeviceID() -> AudioObjectID? {
        systemDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    @discardableResult
    static func setDefaultOutputDevice(id: AudioObjectID) -> Bool {
        setSystemDeviceID(id, selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    @discardableResult
    static func setDefaultInputDevice(id: AudioObjectID) -> Bool {
        setSystemDeviceID(id, selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    // MARK: - Private

    private static func listDevices(
        requireOutput: Bool,
        requireInput: Bool,
        defaultID: AudioObjectID?
    ) -> [AudioDevice] {
        deviceIDs().compactMap { id -> AudioDevice? in
            let hasOut = hasStreams(id, scope: kAudioObjectPropertyScopeOutput)
            let hasIn = hasStreams(id, scope: kAudioObjectPropertyScopeInput)
            if requireOutput && !hasOut { return nil }
            if requireInput && !hasIn { return nil }
            guard let uid = stringProperty(objectID: id, selector: kAudioDevicePropertyDeviceUID),
                  let name = stringProperty(objectID: id, selector: kAudioObjectPropertyName)
            else { return nil }
            return AudioDevice(
                id: id,
                uid: uid,
                name: name,
                isDefault: id == defaultID,
                hasInput: hasIn,
                hasOutput: hasOut
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func systemDeviceID(selector: AudioObjectPropertySelector) -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func setSystemDeviceID(_ id: AudioObjectID, selector: AudioObjectPropertySelector) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &deviceID
        )
        if status != noErr {
            AVLog.error("Failed to set device (\(selector)): \(status)")
            return false
        }
        return true
    }

    private static func deviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &ids
        ) == noErr else { return [] }
        return ids
    }

    private static func hasStreams(_ deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }

    private static func stringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else { return nil }

        var cfValue: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &cfValue) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr, let cfValue else { return nil }
        return cfValue.takeRetainedValue() as String
    }
}

/// Compatibility wrapper for previous name.
enum OutputDeviceManager {
    static func listOutputDevices() -> [AudioDevice] { AudioDeviceManager.listOutputDevices() }
    static func defaultOutputDeviceID() -> AudioObjectID? { AudioDeviceManager.defaultOutputDeviceID() }
    static func setDefaultOutputDevice(id: AudioObjectID) -> Bool {
        AudioDeviceManager.setDefaultOutputDevice(id: id)
    }
}
