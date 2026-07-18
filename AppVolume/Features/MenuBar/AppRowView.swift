import SwiftUI

struct AppRowView: View {
    @Environment(AudioSessionStore.self) private var store
    let app: AudioApp

    var body: some View {
        HStack(spacing: 6) {
            appIcon

            VStack(alignment: .leading, spacing: 0) {
                Text(app.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(statusLine)
                    .font(.system(size: 9))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            .frame(width: 88, alignment: .leading)

            Slider(
                value: Binding(
                    get: { Double(store.volume(for: app)) },
                    set: { store.setVolume(Float($0), for: app) }
                ),
                in: 0...1
            )
            .controlSize(.mini)
            .disabled(app.processObjectIDs.isEmpty && !store.isMuted(for: app) && store.volume(for: app) >= 0.999)

            Text("\(Int((store.volume(for: app) * 100).rounded()))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            Button {
                store.setMuted(!store.isMuted(for: app), for: app)
            } label: {
                Image(systemName: store.isMuted(for: app) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)

            if store.volume(for: app) < 0.999 || store.isMuted(for: app) {
                Button {
                    store.resetApp(app)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .opacity(store.isMuted(for: app) ? 0.6 : 1)
        .contextMenu {
            Button(store.isMuted(for: app) ? "取消静音" : "静音") {
                store.setMuted(!store.isMuted(for: app), for: app)
            }
            Button("恢复默认音量") {
                store.resetApp(app)
            }
            Divider()
            Button("复制 Bundle ID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.bundleID, forType: .string)
            }
        }
    }

    private var statusLine: String {
        if let error = store.controlError(for: app) { return error }
        if store.isMuted(for: app) {
            return store.isMuteActive(for: app) ? "已静音" : "静音待生效"
        }
        if store.isGainActive(for: app) {
            return "音量控制中"
        }
        if store.volume(for: app) < 0.999 { return "待生效" }
        if app.isProducingSound { return "正在发声" }
        if app.isAudioClient { return "已连接" }
        if app.isRunningApp { return "已打开" }
        return "空闲"
    }

    private var statusColor: Color {
        store.controlError(for: app) != nil ? .orange : .secondary
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .cornerRadius(4)
        } else {
            Image(systemName: "app.fill")
                .frame(width: 18, height: 18)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

import AppKit
