import Foundation

@Observable
final class PreferencesStore {
    private let defaults: UserDefaults
    private let appStatesKey = "appStates"
    private let launchAtLoginKey = "launchAtLogin"
    private let showAllRunningAppsKey = "showAllRunningApps"
    private let showInactiveAudioClientsKey = "showInactiveAudioClients"
    private let hideNoisySystemClientsKey = "hideNoisySystemClients"
    private let verboseLoggingKey = "verboseLogging"

    var appStates: [String: AppVolumeState] {
        didSet { persistAppStates() }
    }

    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: launchAtLoginKey)
            _ = LoginItemService.setEnabled(launchAtLogin)
        }
    }

    /// Show all regular running apps even when not playing audio.
    var showAllRunningApps: Bool {
        didSet { defaults.set(showAllRunningApps, forKey: showAllRunningAppsKey) }
    }

    /// Show silent Core Audio clients that are not regular apps.
    var showInactiveAudioClients: Bool {
        didSet { defaults.set(showInactiveAudioClients, forKey: showInactiveAudioClientsKey) }
    }

    var hideNoisySystemClients: Bool {
        didSet { defaults.set(hideNoisySystemClients, forKey: hideNoisySystemClientsKey) }
    }

    var verboseLogging: Bool {
        didSet {
            defaults.set(verboseLogging, forKey: verboseLoggingKey)
            AVLog.isVerbose = verboseLogging
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appStates = Self.loadAppStates(from: defaults, key: appStatesKey)
        let savedLaunch = defaults.object(forKey: launchAtLoginKey) as? Bool
        self.launchAtLogin = LoginItemService.isEnabled || (savedLaunch ?? false)

        // Default OFF: only show apps that can produce audio.
        if defaults.object(forKey: showAllRunningAppsKey) == nil {
            self.showAllRunningApps = false
        } else {
            self.showAllRunningApps = defaults.bool(forKey: showAllRunningAppsKey)
        }

        // Default OFF: only show apps actively producing sound.
        if defaults.object(forKey: showInactiveAudioClientsKey) == nil {
            self.showInactiveAudioClients = false
        } else {
            self.showInactiveAudioClients = defaults.bool(forKey: showInactiveAudioClientsKey)
        }

        if defaults.object(forKey: hideNoisySystemClientsKey) == nil {
            self.hideNoisySystemClients = true
        } else {
            self.hideNoisySystemClients = defaults.bool(forKey: hideNoisySystemClientsKey)
        }
        self.verboseLogging = defaults.bool(forKey: verboseLoggingKey)
        AVLog.isVerbose = verboseLogging
    }

    func state(for bundleID: String) -> AppVolumeState {
        appStates[bundleID] ?? .default
    }

    func setVolume(_ volume: Float, for bundleID: String) {
        var state = state(for: bundleID)
        state.volume = min(max(volume, 0), 1)
        appStates[bundleID] = state
    }

    func setMuted(_ muted: Bool, for bundleID: String) {
        var state = state(for: bundleID)
        state.isMuted = muted
        appStates[bundleID] = state
    }

    func resetState(for bundleID: String) {
        var next = appStates
        next.removeValue(forKey: bundleID)
        appStates = next
    }

    func resetAllAppStates() {
        appStates = [:]
    }

    func syncLaunchAtLoginFromSystem() {
        let enabled = LoginItemService.isEnabled
        if launchAtLogin != enabled {
            defaults.set(enabled, forKey: launchAtLoginKey)
            launchAtLogin = enabled
        }
    }

    private func persistAppStates() {
        guard let data = try? JSONEncoder().encode(appStates) else { return }
        defaults.set(data, forKey: appStatesKey)
    }

    private static func loadAppStates(from defaults: UserDefaults, key: String) -> [String: AppVolumeState] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: AppVolumeState].self, from: data)
        else { return [:] }
        return decoded
    }
}
