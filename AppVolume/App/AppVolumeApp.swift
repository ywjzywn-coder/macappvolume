import SwiftUI

@main
struct AppVolumeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var sessionStore = AudioSessionStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(sessionStore)
        } label: {
            Image(systemName: "slider.vertical.3")
        }
        .menuBarExtraStyle(.window)

        Window("AppVolume 设置", id: "settings") {
            SettingsView()
                .environment(sessionStore)
        }
        .defaultSize(width: 500, height: 640)

        Settings {
            SettingsView()
                .environment(sessionStore)
        }
    }
}
