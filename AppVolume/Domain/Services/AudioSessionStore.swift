import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AudioSessionStore {
    private(set) var apps: [AudioApp] = []
    private(set) var outputDevices: [AudioDevice] = []
    private(set) var inputDevices: [AudioDevice] = []
    private(set) var lastRefresh: Date?
    private(set) var controlErrors: [String: String] = [:]
    private(set) var needsScreenRecordingPermission = false
    var showPermissionSheet = false

    let preferences = PreferencesStore()
    private var refreshTask: Task<Void, Never>?
    private var sessions: [String: VolumeSession] = [:]
    private var lastDefaultOutputUID: String?
    private let hardwareObserver = HardwareChangeObserver()
    private var refreshDebounceTask: Task<Void, Never>?

    /// Compatibility for older UI bindings.
    var devices: [AudioDevice] { outputDevices }

    var statusNote: String {
        if needsScreenRecordingPermission {
            return "需要屏幕录制权限才能控制其他 App 音量。"
        }
        if let first = controlErrors.values.first {
            return first
        }
        let controlled = sessions.count
        if controlled > 0 {
            return "正在控制 \(controlled) 个 App（100% 未静音时自动直通）。"
        }
        return "列表显示已打开的 App；发声后可调音量。可在下方切换输入/输出设备。"
    }

    /// 菜单栏图标：三档推子 = 多 App 混音器，刻意区别于系统扬声器图标。
    var menuBarSystemImage: String {
        if needsScreenRecordingPermission { return "exclamationmark.triangle.fill" }
        if sessions.values.contains(where: \.isMuteTapActive) { return "slider.vertical.3.fill" }
        if sessions.values.contains(where: \.isGainActive) { return "slider.vertical.3.fill" }
        return "slider.vertical.3"
    }

    var hasActiveControls: Bool {
        !sessions.isEmpty
    }

    init() {
        preferences.syncLaunchAtLoginFromSystem()
        hardwareObserver.start { [weak self] in
            Task { @MainActor in
                self?.scheduleRefresh(forceRestartOnOutputChange: true)
            }
        }
        // Running-app launch/terminate also updates the list.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleRefresh(forceRestartOnOutputChange: false) }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleRefresh(forceRestartOnOutputChange: false) }
        }

        refresh()
        startPolling()
    }

    func refresh() {
        let hideNoisy = preferences.hideNoisySystemClients
        var listed = ProcessEnumerator.listApps(
            showAllRunningApps: preferences.showAllRunningApps,
            includeSilentAudioClients: preferences.showInactiveAudioClients
        )
        .filter {
            ProcessFilter.shouldInclude(
                bundleID: $0.bundleID,
                hideNoisySystemClients: hideNoisy,
                isRunningApp: $0.isRunningApp,
                isAudioClient: $0.isAudioClient,
                isProducingSound: $0.isProducingSound
            )
        }

        // Keep controlled apps visible even if temporarily gone from lists.
        let listedIDs = Set(listed.map(\.bundleID))
        for (bundleID, state) in preferences.appStates where state.needsTapControl && !listedIDs.contains(bundleID) {
            if !ProcessFilter.shouldInclude(
                bundleID: bundleID,
                hideNoisySystemClients: hideNoisy,
                isRunningApp: false,
                isAudioClient: false,
                isProducingSound: false
            ) {
                continue
            }
            listed.append(
                AudioApp(
                    bundleID: bundleID,
                    displayName: displayNameFallback(bundleID: bundleID),
                    processObjectIDs: [],
                    pids: [],
                    isProducingSound: false,
                    isAudioClient: false,
                    isRunningApp: false
                )
            )
        }

        apps = listed.sorted {
            let l = preferences.state(for: $0.bundleID).needsTapControl
            let r = preferences.state(for: $1.bundleID).needsTapControl
            if l != r { return l && !r }
            if $0.isProducingSound != $1.isProducingSound {
                return $0.isProducingSound && !$1.isProducingSound
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        outputDevices = AudioDeviceManager.listOutputDevices()
        inputDevices = AudioDeviceManager.listInputDevices()
        lastRefresh = Date()

        let outputUID = outputDevices.first(where: \.isDefault)?.uid
        let outputChanged = outputUID != lastDefaultOutputUID
        lastDefaultOutputUID = outputUID

        reapplyPersistedControls(forceRestart: outputChanged)
        needsScreenRecordingPermission = !ScreenCapturePermission.isGranted && hasActiveControls
    }

    func setDefaultOutputDevice(_ device: AudioDevice) {
        if AudioDeviceManager.setDefaultOutputDevice(id: device.id) {
            outputDevices = AudioDeviceManager.listOutputDevices()
            lastDefaultOutputUID = outputDevices.first(where: \.isDefault)?.uid
            reapplyPersistedControls(forceRestart: true)
        }
    }

    func setDefaultInputDevice(_ device: AudioDevice) {
        if AudioDeviceManager.setDefaultInputDevice(id: device.id) {
            inputDevices = AudioDeviceManager.listInputDevices()
        }
    }

    /// Compatibility alias.
    func setDefaultDevice(_ device: AudioDevice) {
        setDefaultOutputDevice(device)
    }

    func volume(for app: AudioApp) -> Float {
        preferences.state(for: app.bundleID).volume
    }

    func isMuted(for app: AudioApp) -> Bool {
        preferences.state(for: app.bundleID).isMuted
    }

    func controlError(for app: AudioApp) -> String? {
        controlErrors[app.bundleID]
    }

    func isMuteActive(for app: AudioApp) -> Bool {
        sessions[app.bundleID]?.isMuteTapActive == true
    }

    func isGainActive(for app: AudioApp) -> Bool {
        sessions[app.bundleID]?.isGainActive == true
    }

    func setVolume(_ value: Float, for app: AudioApp) {
        let clamped = min(max(value, 0), 1)
        preferences.setVolume(clamped, for: app.bundleID)

        let state = preferences.state(for: app.bundleID)
        if let session = sessions[app.bundleID],
           session.isGainActive,
           !state.isMuted,
           state.volume >= 0.001,
           state.volume < 0.999
        {
            session.updateGainOnly(state)
            return
        }

        applySession(for: app, forceRestart: false)
    }

    func setMuted(_ muted: Bool, for app: AudioApp) {
        preferences.setMuted(muted, for: app.bundleID)
        if !muted, preferences.state(for: app.bundleID).volume < 0.001 {
            preferences.setVolume(1, for: app.bundleID)
        }
        applySession(for: app, forceRestart: false)
    }

    func resetApp(_ app: AudioApp) {
        preferences.resetState(for: app.bundleID)
        if let session = sessions.removeValue(forKey: app.bundleID) {
            session.stop()
        }
        controlErrors.removeValue(forKey: app.bundleID)
        refresh()
    }

    func releaseAllControls() {
        for session in sessions.values {
            session.stop()
        }
        sessions.removeAll()
        controlErrors.removeAll()
        preferences.resetAllAppStates()
        needsScreenRecordingPermission = false
        refresh()
    }

    func openPermissionGuide() {
        ScreenCapturePermission.openSystemSettings()
    }

    func requestPermissionAndRetry() {
        _ = ScreenCapturePermission.requestIfNeeded()
        if !ScreenCapturePermission.isGranted {
            showPermissionSheet = true
            openPermissionGuide()
        } else {
            needsScreenRecordingPermission = false
            reapplyPersistedControls(forceRestart: true)
        }
    }

    private func displayNameFallback(bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    private func currentOutputUID() -> String? {
        outputDevices.first(where: \.isDefault)?.uid
            ?? AudioDeviceManager.listOutputDevices().first(where: \.isDefault)?.uid
    }

    private func applySession(for app: AudioApp, forceRestart: Bool) {
        let state = preferences.state(for: app.bundleID)

        if !state.needsTapControl {
            if let session = sessions.removeValue(forKey: app.bundleID) {
                session.stop()
            }
            controlErrors.removeValue(forKey: app.bundleID)
            return
        }

        if app.processObjectIDs.isEmpty {
            controlErrors[app.bundleID] = "当前无音频客户端，开始播放后自动生效"
            return
        }

        let session = sessions[app.bundleID] ?? VolumeSession(bundleID: app.bundleID)
        sessions[app.bundleID] = session

        if forceRestart {
            session.stop()
        }

        let ok = session.apply(
            state: state,
            processObjectIDs: app.processObjectIDs,
            outputDeviceUID: currentOutputUID()
        )

        if ok {
            controlErrors.removeValue(forKey: app.bundleID)
            if controlErrors.isEmpty {
                needsScreenRecordingPermission = false
            }
        } else {
            controlErrors[app.bundleID] = session.lastError ?? "音量控制失败"
            if !ScreenCapturePermission.isGranted {
                needsScreenRecordingPermission = true
                showPermissionSheet = true
            }
        }
    }

    private func reapplyPersistedControls(forceRestart: Bool) {
        let controlledIDs = Set(
            preferences.appStates.compactMap { bundleID, state in
                state.needsTapControl ? bundleID : nil
            }
        )

        for app in apps where controlledIDs.contains(app.bundleID) {
            applySession(for: app, forceRestart: forceRestart)
        }

        for bundleID in sessions.keys where !controlledIDs.contains(bundleID) {
            sessions.removeValue(forKey: bundleID)?.stop()
            controlErrors.removeValue(forKey: bundleID)
        }
    }

    private func scheduleRefresh(forceRestartOnOutputChange: Bool) {
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            if forceRestartOnOutputChange {
                lastDefaultOutputUID = nil
            }
            refresh()
        }
    }

    private func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    self?.refresh()
                }
            }
        }
    }

    private static func appendDebugLog(_ line: String) {
        // Reserved for future diagnostics; no-op in production.
    }
}
