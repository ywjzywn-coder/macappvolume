import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AudioSessionStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            appList
            Divider()
            DevicePickerView()
            Divider()
            footer
        }
        .frame(width: 360)
        .padding(.vertical, 6)
        .sheet(isPresented: Binding(
            get: { store.showPermissionSheet },
            set: { store.showPermissionSheet = $0 }
        )) {
            PermissionGuideView(
                onOpenSettings: { store.openPermissionGuide() },
                onRetry: { store.requestPermissionAndRetry() }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: store.menuBarSystemImage)
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            Text("AppVolume")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if store.hasActiveControls {
                Button("全部恢复") {
                    store.releaseAllControls()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
            }
            if let date = store.lastRefresh {
                Text(date, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var appList: some View {
        Group {
            if store.apps.isEmpty {
                Text("当前没有检测到音频 App\n播放音乐或视频后再打开")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.apps) { app in
                        AppRowView(app: app)
                        if app.id != store.apps.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.statusNote)
                .font(.system(size: 9))
                .foregroundStyle(store.needsScreenRecordingPermission ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if store.needsScreenRecordingPermission {
                    Button("授权并重试") {
                        store.requestPermissionAndRetry()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
                Spacer()
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("打开设置")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("退出")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func openSettings() {
        AppSettingsOpener.openWindow(id: "settings", openWindow: openWindow)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppSettingsOpener.open()
        }
    }
}
