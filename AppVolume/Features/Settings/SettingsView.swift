import AppKit
import CoreAudio
import SwiftUI

struct SettingsView: View {
    @Environment(AudioSessionStore.self) private var store

    var body: some View {
        @Bindable var preferences = store.preferences

        TabView {
            Form {
                Section("启动") {
                    Toggle("登录时启动", isOn: $preferences.launchAtLogin)
                        .onChange(of: preferences.launchAtLogin) { _, enabled in
                            if enabled {
                                LoginItemService.openLoginItemsSettingsIfNeeded()
                            }
                        }
                }

                Section("应用列表") {
                    Toggle("显示全部已打开的 App", isOn: $preferences.showAllRunningApps)
                        .onChange(of: preferences.showAllRunningApps) { _, _ in store.refresh() }
                    Text("关闭后，仅显示正在发声或已有音量设置的 App。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("显示静默的音频客户端", isOn: $preferences.showInactiveAudioClients)
                        .onChange(of: preferences.showInactiveAudioClients) { _, _ in store.refresh() }
                    Toggle("隐藏系统音频客户端", isOn: $preferences.hideNoisySystemClients)
                        .onChange(of: preferences.hideNoisySystemClients) { _, _ in store.refresh() }
                }

                Section("诊断") {
                    Toggle("启用详细日志", isOn: $preferences.verboseLogging)
                    Text("可在 Console 中筛选 local.appvolume 查看日志。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tabItem {
                Label("通用", systemImage: "gearshape")
            }

            Form {
                Section("设备") {
                    Picker("输出设备", selection: outputSelection) {
                        ForEach(store.outputDevices) { device in
                            Text(device.name).tag(device.id as AudioObjectID?)
                        }
                    }
                    Picker("输入设备", selection: inputSelection) {
                        ForEach(store.inputDevices) { device in
                            Text(device.name).tag(device.id as AudioObjectID?)
                        }
                    }
                    Button {
                        store.refresh()
                    } label: {
                        Label("刷新设备列表", systemImage: "arrow.clockwise")
                    }
                }

                Section("屏幕录制权限") {
                    LabeledContent("状态") {
                        Label(
                            ScreenCapturePermission.isGranted ? "已授权" : "未授权",
                            systemImage: ScreenCapturePermission.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(ScreenCapturePermission.isGranted ? .green : .orange)
                    }
                    Text("macOS 将捕获其他 App 的音频归入屏幕录制权限。AppVolume 不会录制屏幕画面。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("打开系统设置") { store.openPermissionGuide() }
                        Button("重新检测") { store.requestPermissionAndRetry() }
                    }
                }

                Section("重置") {
                    Button("恢复所有 App 的默认音量", role: .destructive) {
                        store.releaseAllControls()
                    }
                    Button("清除已保存的 App 状态", role: .destructive) {
                        preferences.resetAllAppStates()
                        store.refresh()
                    }
                }
            }
            .tabItem {
                Label("音频", systemImage: "speaker.wave.2")
            }

            VStack(spacing: 18) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)

                VStack(spacing: 4) {
                    Text("AppVolume")
                        .font(.title2.bold())
                    Text("版本 \(appVersion)")
                        .foregroundStyle(.secondary)
                }

                Text("macOS 菜单栏每 App 音量控制")
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(width: 260)

                VStack(spacing: 5) {
                    Text("macOS 14.2 或更高版本")
                    Text("公开 Core Audio API · Process Tap · 无驱动")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, 34)
            .tabItem {
                Label("关于", systemImage: "info.circle")
            }
        }
        .frame(width: 480, height: 500)
        .padding(12)
        .onAppear {
            preferences.syncLaunchAtLoginFromSystem()
            store.refresh()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var outputSelection: Binding<AudioObjectID?> {
        Binding(
            get: { store.outputDevices.first(where: \.isDefault)?.id },
            set: { newID in
                if let newID, let device = store.outputDevices.first(where: { $0.id == newID }) {
                    store.setDefaultOutputDevice(device)
                }
            }
        )
    }

    private var inputSelection: Binding<AudioObjectID?> {
        Binding(
            get: { store.inputDevices.first(where: \.isDefault)?.id },
            set: { newID in
                if let newID, let device = store.inputDevices.first(where: { $0.id == newID }) {
                    store.setDefaultInputDevice(device)
                }
            }
        )
    }
}
