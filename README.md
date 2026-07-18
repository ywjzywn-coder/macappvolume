# AppVolume

macOS 菜单栏每 App 音量控制（MVP）。公开 API · Process Tap · 无虚拟驱动。

[下载最新版本](https://github.com/ywjzywn-coder/macappvolume/releases/latest)

> **接手开发请先读 [`AGENTS.md`](./AGENTS.md)**（架构、文件地图、约定、验收清单）。

## 要求

- macOS 14.2+
- Xcode 15+
- 调节音量/静音需要「屏幕录制」权限

## 功能（MVP）

- 菜单栏常驻（无 Dock 图标）
- 全部已打开 App 列表（即使未播放）
- 每 App 音量滑块 + 静音
- 输入 / 输出设备选择
- 记忆每个 App 的音量/静音
- 登录时启动
- 防止从多个安装副本重复启动
- 设置页（独立窗口打开）
- 设备/进程变化监听 + 退出清理

**不做：** EQ、每 App 不同输出设备、插件、系统录音、音量增强。

## 运行

```bash
# 一键构建并启动
"/Volumes/512G外置硬盘/workspace/mac sound control/AppVolume/scripts/run.sh"

# 或打开工程
open "/Volumes/512G外置硬盘/workspace/mac sound control/AppVolume/AppVolume.xcodeproj"
```

App 位置：

1. `~/Applications/AppVolume.app`（推荐）
2. `AppVolume/dist/AppVolume.app`
3. DerivedData 构建产物

菜单栏找扬声器图标；设置点面板底部 **「设置」**。

## 安装发布版

1. 从 [Releases](https://github.com/ywjzywn-coder/macappvolume/releases) 下载 ZIP 并解压
2. 将 `AppVolume.app` 移到“应用程序”文件夹
3. 首次打开如果被 Gatekeeper 阻止，在 Finder 中右键 App 并选择“打开”

当前公开测试版使用 ad-hoc 签名，尚未经过 Apple 公证。

## 技术摘要

| 状态 | 路径 |
|------|------|
| 100% 未静音 | 系统直通 |
| 静音 / 0% | Process Tap `CATapMuted` |
| 1%–99% | Tap + Aggregate + IOProc × gain |

- Bundle ID: `local.appvolume`
- 非 Mac App Store，未启用 App Sandbox

## 新增源码后

```bash
python3 scripts/generate_xcodeproj.py
```

## 生成发布包

```bash
scripts/release.sh 0.1.0
```

发布 ZIP 输出到 `dist/AppVolume-0.1.0.zip`。
