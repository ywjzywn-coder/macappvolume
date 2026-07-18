# AppVolume 0.1.1

首个公开测试版本。

## 功能

- 菜单栏按 App 调节音量和静音
- 自动识别浏览器、音乐、聊天和视频应用
- 切换系统默认输入与输出设备
- 记忆每个 App 的音量设置
- 登录时启动
- 跨安装副本单实例运行
- 仅使用公开 Core Audio Process Tap API，无虚拟音频驱动

## 系统要求

- macOS 14.2 或更高版本
- 调节其他 App 音量时需要授予屏幕录制权限

## 安装

1. 下载并解压 `AppVolume-v0.1.1.zip`。
2. 将 `AppVolume.app` 移到“应用程序”文件夹。
3. 首次打开如果被 Gatekeeper 阻止，请在 Finder 中右键 App，选择“打开”。
4. 从菜单栏的推子图标进入 AppVolume。

此测试版使用 ad-hoc 签名，尚未经过 Apple 公证。
