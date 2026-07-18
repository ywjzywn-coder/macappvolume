import AppKit
import SwiftUI

struct AppRowView: View {
    @Environment(AudioSessionStore.self) private var store
    let app: AudioApp

    var body: some View {
        HStack(spacing: 8) {
            appIcon

            VStack(alignment: .leading, spacing: 0) {
                Text(app.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            .frame(width: 106, alignment: .leading)

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
                .frame(width: 31, alignment: .trailing)

            Button {
                store.setMuted(!store.isMuted(for: app), for: app)
            } label: {
                Image(systemName: store.isMuted(for: app) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .frame(width: 20, height: 20)
            .help(store.isMuted(for: app) ? "取消静音" : "静音")

            Group {
                if store.volume(for: app) < 0.999 || store.isMuted(for: app) {
                    Button {
                        store.resetApp(app)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help("恢复默认")
                } else {
                    Color.clear
                }
            }
            .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
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
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "app.fill")
                .frame(width: 24, height: 24)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }
}
