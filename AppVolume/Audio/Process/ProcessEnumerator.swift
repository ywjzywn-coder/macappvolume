import AppKit
import CoreAudio
import Foundation

enum ProcessEnumerator {
    /// Audio HAL clients (optionally only those currently outputting).
    static func listAudioApps(includeSilent: Bool = false) -> [AudioApp] {
        Array(audioBuckets(includeSilent: includeSilent).values)
            .map(makeAudioApp)
            .sorted(by: sortApps)
    }

    /// Merge currently open regular apps with audio clients.
    /// - showAllRunningApps: include Finder-visible running apps even if silent
    /// - includeSilentAudioClients: include HAL clients that are not outputting
    static func listApps(
        showAllRunningApps: Bool,
        includeSilentAudioClients: Bool
    ) -> [AudioApp] {
        var buckets = audioBuckets(includeSilent: includeSilentAudioClients || showAllRunningApps)

        if showAllRunningApps {
            let selfPID = getpid()
            for app in NSWorkspace.shared.runningApplications {
                guard app.activationPolicy == .regular else { continue }
                guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { continue }
                guard app.processIdentifier != selfPID else { continue }

                let pid = app.processIdentifier
                var bucket = buckets[bundleID] ?? Bucket(
                    bundleID: bundleID,
                    displayName: app.localizedName ?? bundleID,
                    processObjectIDs: [],
                    pids: [],
                    isProducingSound: false,
                    isAudioClient: false,
                    isRunningApp: true
                )
                if !bucket.pids.contains(pid) {
                    bucket.pids.append(pid)
                }
                bucket.isRunningApp = true
                if let name = app.localizedName, !name.isEmpty {
                    bucket.displayName = name
                }
                buckets[bundleID] = bucket
            }
        }

        return buckets.values
            .map(makeAudioApp)
            .sorted(by: sortApps)
    }

    private struct Bucket {
        let bundleID: String
        var displayName: String
        var processObjectIDs: [AudioObjectID]
        var pids: [pid_t]
        var isProducingSound: Bool
        var isAudioClient: Bool
        var isRunningApp: Bool
    }

    private static func audioBuckets(includeSilent: Bool) -> [String: Bucket] {
        var buckets: [String: Bucket] = [:]
        let selfPID = getpid()

        for objectID in processObjectIDs() {
            guard let pid = pid(for: objectID) else { continue }
            if pid == selfPID { continue }

            let isRunningOutput = boolProperty(
                objectID: objectID,
                selector: kAudioProcessPropertyIsRunningOutput
            )
            if !includeSilent && !isRunningOutput { continue }

            let bundleID = bundleID(for: objectID)
                ?? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
                ?? "pid.\(pid)"

            let displayName = displayName(bundleID: bundleID, pid: pid)
            let running = NSRunningApplication(processIdentifier: pid)
            let isRegular = running?.activationPolicy == .regular

            var bucket = buckets[bundleID] ?? Bucket(
                bundleID: bundleID,
                displayName: displayName,
                processObjectIDs: [],
                pids: [],
                isProducingSound: false,
                isAudioClient: true,
                isRunningApp: isRegular
            )
            bucket.processObjectIDs.append(objectID)
            if !bucket.pids.contains(pid) {
                bucket.pids.append(pid)
            }
            bucket.isProducingSound = bucket.isProducingSound || isRunningOutput
            bucket.isAudioClient = true
            bucket.isRunningApp = bucket.isRunningApp || isRegular
            if bucket.displayName.hasPrefix("pid.") || bucket.displayName == bundleID {
                bucket.displayName = displayName
            }
            buckets[bundleID] = bucket
        }
        return buckets
    }

    private static func makeAudioApp(_ bucket: Bucket) -> AudioApp {
        AudioApp(
            bundleID: bucket.bundleID,
            displayName: bucket.displayName,
            processObjectIDs: bucket.processObjectIDs,
            pids: bucket.pids,
            isProducingSound: bucket.isProducingSound,
            isAudioClient: bucket.isAudioClient,
            isRunningApp: bucket.isRunningApp
        )
    }

    private static func sortApps(_ a: AudioApp, _ b: AudioApp) -> Bool {
        if a.isProducingSound != b.isProducingSound {
            return a.isProducingSound && !b.isProducingSound
        }
        if a.isAudioClient != b.isAudioClient {
            return a.isAudioClient && !b.isAudioClient
        }
        return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
    }

    private static func processObjectIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        let getStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &ids
        )
        guard getStatus == noErr else { return [] }
        return ids
    }

    private static func pid(for objectID: AudioObjectID) -> pid_t? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func bundleID(for objectID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
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

    private static func boolProperty(objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        return status == noErr && value != 0
    }

    private static func displayName(bundleID: String, pid: pid_t) -> String {
        if let app = NSRunningApplication(processIdentifier: pid),
           let name = app.localizedName,
           !name.isEmpty
        {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }
}
