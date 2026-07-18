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
        .frame(width: 400)
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
        HStack(spacing: 10) {
            Image(systemName: store.menuBarSystemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(store.needsScreenRecordingPermission ? .orange : .blue)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text("AppVolume")
                    .font(.headline)
                Text(store.apps.isEmpty ? "没有可控制的应用" : "\(store.apps.count) 个音频应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.hasActiveControls {
                Button {
                    store.releaseAllControls()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("全部恢复默认")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var appList: some View {
        Group {
            if store.apps.isEmpty {
                ContentUnavailableView {
                    Label("没有音频应用", systemImage: "speaker.slash")
                } description: {
                    Text("打开浏览器、音乐或视频应用后会显示在这里")
                }
                .frame(maxWidth: .infinity, minHeight: 112)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("应用音量")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 7)
                        .padding(.bottom, 3)

                    VStack(spacing: 0) {
                        ForEach(store.apps) { app in
                            AppRowView(app: app)
                            if app.id != store.apps.last?.id {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(store.statusNote)
                .font(.caption)
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
                }
                .buttonStyle(.borderless)
                .help("打开设置")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("退出")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func openSettings() {
        AppSettingsOpener.openWindow(id: "settings", openWindow: openWindow)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppSettingsOpener.open()
        }
    }
}
