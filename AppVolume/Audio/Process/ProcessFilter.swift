import Foundation

enum ProcessFilter {
    /// Bundle IDs that never make sense in a volume mixer.
    static let excludedBundleIDs: Set<String> = [
        "local.appvolume",
        "com.apple.audio.Core-Audio-Driver-Service",
        "com.apple.controlcenter",
        "com.apple.loginwindow",
        "com.apple.WindowServer",
        "com.apple.systempreferences",
        "com.apple.dock",
        "com.apple.finder",
        "com.apple.Preview",
        "com.apple.Terminal",
        "com.apple.systemuiserver",
        "com.apple.TextEdit",
        "com.apple.ActivityMonitor",
        "com.apple.utilities.AirPortUtility",
        "com.apple.AppStore",
        "com.apple.dt.Xcode",
        "com.apple.Console",
        "com.apple.Dictionary",
        "com.apple.fontbook",
        "com.apple.ImageCapture",
        "com.apple.MigrationAssistant",
        "com.apple.ScreenshotCaptureApp",
        "com.apple.ScreenSaverEngine",
        "com.apple.Stickies",
        "com.appleCalculator",
        "com.apple.AddressBook",
        "com.apple.Notes",
        "com.apple.iCal",
        "com.apple.Reminders",
        "com.apple.Map",
        "com.apple.Weather",
        "com.apple.Stocks",
        "com.apple.Photos",
        "com.apple.Notes",
        "com.crystalidea.macsfancontrol",
        "com.tencent.Lemon",
        "systemsoundserverd"
    ]

    /// App bundle IDs / prefixes that are known to be able to play audio.
    static let audioCapablePrefixes: Set<String> = [
        "com.apple.Music", "com.apple.Safari", "com.apple.TV",
        "com.apple.QuickTimePlayerX", "com.apple.FaceTime",
        "com.apple.MobileSMS", "com.apple.Podcasts",
        "com.apple.garageband10", "com.apple.FinalCut",
        "com.apple.iMovieApp", "com.apple.logic10",
        "com.apple.QuickLookPlayer",
        "com.apple.WebKit",
        "com.tencent.xinWeChat", "com.tencent.qq",
        "com.google.Chrome", "org.mozilla.firefox",
        "com.microsoft.VSCode", "com.microsoft.edgemac",
        "com.brave.Browser", "com.operasoftware.Opera",
        "com.electron.lark", "com.spotify.client",
        "com.colliderli.iina", "com.collider.iina",
        "com.videolan.vlc", "org.videolan.vlc",
        "tv.plex.player", "com.netflix.Netflix",
        "com.disney.disneyplus", "com.amazon.aiv.AmazonVideo",
        "com.hbo.HBO NOW", "com.youtube.desktop",
        "com.valvesoftware.steam", "com.epicgames.launcher",
        "com.tencent.meeting", "us.zoom.xos",
        "com.microsoft.teams2", "com.microsoft.skypeforbusiness",
        "com.tinyspeck.slackmacgap", "com.figma.Desktop",
        "notion.id", "md.obsidian", "com.linear.frontend",
        "com.openai", "ai.opencode",
        "com.bytedance",
        "com.dingtalk",
        "com.alibaba.DingTalk",
        "com.netease",
        "org.telegram",
        "comWhatsApp",
        "com.readdle.smartemail",
        "com.flexibits.fantastical",
        "com.culturedcode.ThingsMac"
    ]

    static func isAudioCapable(bundleID: String) -> Bool {
        if bundleID.isEmpty || bundleID == "pid." { return false }
        if excludedBundleIDs.contains(bundleID) { return false }
        for prefix in audioCapablePrefixes {
            if bundleID == prefix || bundleID.hasPrefix(prefix + ".")
                || bundleID.hasPrefix(prefix) {
                return true
            }
        }
        return false
    }

    /// Decide whether to show an app in the list.
    static func shouldInclude(
        bundleID: String,
        hideNoisySystemClients: Bool,
        isRunningApp: Bool = false,
        isAudioClient: Bool = false,
        isProducingSound: Bool = false
    ) -> Bool {
        if bundleID.isEmpty || bundleID == "pid." { return false }
        if excludedBundleIDs.contains(bundleID) { return false }
        if bundleID.hasPrefix("pid.") { return isProducingSound }

        // Anything actively producing sound always shows.
        if isProducingSound { return true }

        // Background audio daemons: only show when producing sound.
        if isAudioClient && !isRunningApp {
            return false
        }

        // Helper processes: only when producing sound.
        if bundleID.hasSuffix(".helper") || bundleID.hasSuffix(".Helper") {
            return false
        }

        // Regular apps: show only if they can play audio (browser, music, chat, video...).
        if isRunningApp {
            if !hideNoisySystemClients { return true }
            return isAudioCapable(bundleID: bundleID) || isAudioClient
        }

        // Other audio clients: only when producing sound.
        return isProducingSound
    }
}
