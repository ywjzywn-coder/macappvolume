import SwiftUI

struct PermissionGuideView: View {
    @Environment(\.dismiss) private var dismiss
    var onOpenSettings: () -> Void = { ScreenCapturePermission.openSystemSettings() }
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("需要屏幕录制权限", systemImage: "rectangle.dashed.badge.record")
                .font(.title3.bold())

            Text("macOS 把「捕获其他 App 音频」归入屏幕录制保护。AppVolume 不会录制屏幕画面，只在你调节音量/静音时用 Process Tap。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("操作步骤")
                    .font(.headline)
                Text("1. 点击下方打开系统设置")
                Text("2. 找到 AppVolume 并打开开关")
                Text("3. 如列表没有，先点「重试」再回到设置")
                Text("4. 返回本 App，再次拖动滑块或静音")
            }
            .font(.callout)

            HStack {
                Button("打开系统设置") {
                    onOpenSettings()
                }
                .keyboardShortcut(.defaultAction)

                Button("重试") {
                    onRetry()
                }

                Spacer()

                Button("稍后") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 400)
    }
}
