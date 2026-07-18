import CoreAudio
import SwiftUI

struct SettingsView: View {
    @Environment(AudioSessionStore.self) private var store

    var body: some View {
        @Bindable var preferences = store.preferences

        Form {
            Section("音频设备（可直接切换测试）") {
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
                LabeledContent("当前输出") {
                    Text(store.outputDevices.first(where: \.isDefault)?.name ?? "—")
                }
                LabeledContent("当前输入") {
                    Text(store.inputDevices.first(where: \.isDefault)?.name ?? "—")
                }
                Button("刷新设备列表") {
                    store.refresh()
                }
            }

            Section("通用") {
                Toggle("登录时启动", isOn: $preferences.launchAtLogin)
                    .onChange(of: preferences.launchAtLogin) { _, enabled in
                        if enabled {
                            LoginItemService.openLoginItemsSettingsIfNeeded()
                        }
                    }
                Toggle("显示全部已打开的 App（即使未播放）", isOn: $preferences.showAllRunningApps)
                    .onChange(of: preferences.showAllRunningApps) { _, _ in
                        store.refresh()
                    }
                Toggle("显示静默的音频客户端（Helper 等）", isOn: $preferences.showInactiveAudioClients)
                    .onChange(of: preferences.showInactiveAudioClients) { _, _ in
                        store.refresh()
                    }
                Toggle("隐藏嘈杂的系统音频客户端", isOn: $preferences.hideNoisySystemClients)
                    .onChange(of: preferences.hideNoisySystemClients) { _, _ in
                        store.refresh()
                    }
                Toggle("详细日志（Console 过滤 local.appvolume）", isOn: $preferences.verboseLogging)
            }

            Section("权限") {
                LabeledContent("屏幕录制") {
                    Text(ScreenCapturePermission.isGranted ? "已授权" : "未授权")
                        .foregroundStyle(ScreenCapturePermission.isGranted ? .green : .orange)
                }
                Text("调节其他 App 音量需要此权限。列表与输入/输出设备切换不需要。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("打开屏幕录制设置…") {
                    store.openPermissionGuide()
                }
                Button("重新检测权限") {
                    store.requestPermissionAndRetry()
                }
            }

            Section("控制") {
                Button("全部恢复默认（解除所有音量/静音）", role: .destructive) {
                    store.releaseAllControls()
                }
                Button("清除已保存的 App 音量状态", role: .destructive) {
                    preferences.resetAllAppStates()
                    store.refresh()
                }
            }

            Section("关于") {
                LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                LabeledContent("最低系统", value: "macOS 14.2")
                LabeledContent("架构", value: "公开 API · Process Tap · 无驱动")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
        .padding()
        .onAppear {
            preferences.syncLaunchAtLoginFromSystem()
            store.refresh()
        }
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
