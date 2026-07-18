# AppVolume — Agent 交接文档

> 供后续 AI / 人类开发者接手。读完本文即可定位代码、理解架构、继续开发。

## 1. 项目一句话

macOS **菜单栏**每 App 音量/静音工具。仅用**公开 Core Audio API**（Process Tap），**无虚拟驱动**，最低 **macOS 14.2**。

内部代号：`AppVolume` · Bundle ID：`local.appvolume` · **非 Mac App Store**（Sandbox 关闭）。

---

## 2. 路径与运行

| 用途 | 路径 |
|------|------|
| 工程根目录 | `/Volumes/512G外置硬盘/workspace/mac sound control/AppVolume` |
| Xcode 工程 | `AppVolume.xcodeproj` |
| 源码 | `AppVolume/` |
| 一键构建运行 | `scripts/run.sh` |
| 再生 pbxproj | `scripts/generate_xcodeproj.py`（新增/删除 Swift 后要跑） |
| 用户易找的 App | `~/Applications/AppVolume.app` |
| 构建副本 | `dist/AppVolume.app` |

```bash
# 打开工程
open "/Volumes/512G外置硬盘/workspace/mac sound control/AppVolume/AppVolume.xcodeproj"

# 构建 + 安装到 ~/Applications + 启动
"/Volumes/512G外置硬盘/workspace/mac sound control/AppVolume/scripts/run.sh"

# 仅构建
cd "/Volumes/512G外置硬盘/workspace/mac sound control/AppVolume"
xcodebuild -project AppVolume.xcodeproj -scheme AppVolume -configuration Debug -destination 'platform=macOS' build
```

菜单栏找扬声器图标（`LSUIElement`，无 Dock）。设置用底部 **「设置」** 按钮（不要依赖 SettingsLink）。

---

## 3. 产品范围

### 已实现（MVP）

- 菜单栏常驻面板
- **全部已打开 App 列表**（即使未播放；可关）
- 每 App 音量滑块 + 静音（真实生效）
- **输出 + 输入**默认设备切换（菜单栏 + 设置页）
- 按 bundleID 记忆音量/静音
- 登录启动（`SMAppService`）
- 屏幕录制权限引导
- 设备/进程/App 启动退出监听
- 退出清理 Process Tap（防永久静音）
- 全部恢复 / 单 App 重置

### 明确不做（除非产品改范围）

- EQ、插件、系统录音、音量增强
- 每 App 路由到不同输出设备
- 私有 API / 内核扩展 / HAL 驱动
- Mac App Store 沙盒版（Process Tap 路径基本不可行）

---

## 4. 核心架构（必读）

```
UI (SwiftUI MenuBarExtra / Settings Window)
        │
        ▼
AudioSessionStore          ← 唯一业务状态中枢 (@Observable, @MainActor)
        │
        ├── ProcessEnumerator     列 App（NSWorkspace + HAL Process）
        ├── AudioDeviceManager    输入/输出设备
        ├── PreferencesStore      UserDefaults 持久化
        ├── VolumeSession / bundleID
        │       ├── ProcessTapController   静音-only Tap
        │       └── GainPlaybackEngine     Tap + Aggregate + IOProc × gain
        └── AudioTeardown         全局清理注册表
```

### 音量控制三条路径

| 用户状态 | 实现 | 文件 |
|----------|------|------|
| volume≈1 且未静音 | **不拦截**，系统直通 | `VolumeSession` 销毁会话 |
| 静音 或 volume≈0 | `AudioHardwareCreateProcessTap` + `CATapMuted` | `ProcessTapController` |
| 0 < volume < 1 | Tap 静音原路径 + 私有 Aggregate + `AudioDeviceIOProc` 读入×gain写出 | `GainPlaybackEngine` |

**关键事实：** macOS **没有** `setVolume(forApp:)` 公开 API。必须走 Process Tap 截取/改道。

### 权限

- 列表 / 切设备：**无** TCC
- 真正调音量/静音：需要 **屏幕录制**（`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`）
- **不要**申请麦克风（本 App 不做输入采集）

---

## 5. 源码地图（按目录）

```
AppVolume/
├── AGENTS.md                 ← 本文件
├── README.md                 ← 用户向说明
├── scripts/
│   ├── generate_xcodeproj.py ← 无 xcodegen 时用；增删 .swift 后执行
│   └── run.sh                ← build + 拷到 ~/Applications + open
├── AppVolume.xcodeproj/
├── AppVolumeTests/
│   └── PreferencesStoreTests.swift
└── AppVolume/
    ├── App/
    │   ├── AppVolumeApp.swift      @main：MenuBarExtra + Window(settings) + Settings
    │   └── AppDelegate.swift       .accessory、退出清理
    ├── Features/
    │   ├── MenuBar/
    │   │   ├── MenuBarView.swift   主面板；打开设置入口
    │   │   ├── AppRowView.swift    单行滑块/静音/重置
    │   │   └── DevicePickerView.swift  输入+输出 Picker
    │   ├── Settings/
    │   │   └── SettingsView.swift  设备测试、列表开关、权限、自启
    │   └── Onboarding/
    │       └── PermissionGuideView.swift
    ├── Domain/
    │   ├── Models/
    │   │   ├── AudioApp.swift          列表项模型
    │   │   ├── AppVolumeState.swift    volume/muted；needsTapControl
    │   │   └── OutputDevice.swift      AudioDevice（输入输出共用）
    │   └── Services/
    │       ├── AudioSessionStore.swift ★ 状态中枢，优先从这里改
    │       ├── PreferencesStore.swift  偏好与持久化
    │       └── LoginItemService.swift  SMAppService.mainApp
    ├── Audio/
    │   ├── Process/
    │   │   ├── ProcessEnumerator.swift  HAL 进程 + 运行中 App 合并
    │   │   └── ProcessFilter.swift      排除自身/嘈杂系统客户端
    │   ├── Tap/
    │   │   └── ProcessTapController.swift  mute-only Process Tap
    │   ├── Engine/
    │   │   ├── VolumeSession.swift       单 bundleID 生命周期
    │   │   └── GainPlaybackEngine.swift  ★ 增益回放（最复杂）
    │   ├── Device/
    │   │   ├── OutputDeviceManager.swift AudioDeviceManager（输入输出）
    │   │   └── HardwareChangeObserver.swift 默认设备/设备列表/进程列表监听
    │   └── Cleanup/
    │       └── AudioTeardown.swift
    ├── Support/
    │   ├── AppSettingsOpener.swift     菜单栏 App 可靠打开设置窗
    │   ├── Permissions/ScreenCapturePermission.swift
    │   └── Logging/AVLog.swift
    └── Resources/
        ├── Info.plist              LSUIElement=true
        ├── AppVolume.entitlements  sandbox=false
        └── Assets.xcassets
```

### 接手时优先读的 5 个文件

1. `Domain/Services/AudioSessionStore.swift` — 所有 UI 操作汇合点  
2. `Audio/Engine/VolumeSession.swift` — mute vs gain 决策  
3. `Audio/Engine/GainPlaybackEngine.swift` — Tap + Aggregate + IOProc  
4. `Audio/Tap/ProcessTapController.swift` — 纯静音  
5. `Audio/Process/ProcessEnumerator.swift` — 列表从哪来  

---

## 6. 关键实现细节

### Process Tap 创建

- API：`AudioHardwareCreateProcessTap` / `Destroy`（`AudioHardwareTapping.h`，14.2+）
- 描述：`CATapDescription(stereoMixdownOfProcesses:)`
- 静音：`muteBehavior = CATapMuteBehavior(rawValue: 1)!` // CATapMuted  
  （Swift 枚举名不稳定，项目里用 rawValue）

### Aggregate 组成（增益路径）

```
kAudioAggregateDeviceIsPrivateKey = true
kAudioAggregateDeviceTapAutoStartKey = true
subdevices = [ 当前默认输出 UID ]
taps = [ { uid: tapUUID, drift: true } ]
```

IOProc：`AudioDeviceCreateIOProcIDWithBlock` — 输入 buffer × gain → 输出 buffer。  
假定 float32 PCM（Core Audio Tap 常见格式）。

### 列表策略

- `showAllRunningApps`（默认 true）：`NSWorkspace.runningApplications` 中 `.regular`
- 合并 HAL `kAudioHardwarePropertyProcessObjectList`
- 按 `bundleID` 聚合多 PID（Chrome Helper 等）
- 受控但暂时无进程的 App 仍显示（待发声后自动 apply）

### 设置打不开的历史坑

菜单栏 + `activationPolicy(.accessory)` 下 **`SettingsLink` 不可靠**。  
当前：`Window(id: "settings")` + `AppSettingsOpener.openWindow` + 短暂 `setActivationPolicy(.regular)`。

### 工程维护

无 CocoaPods/SPM。新增 Swift 文件后：

```bash
python3 scripts/generate_xcodeproj.py
# 若测试 target 依赖丢失，参考历史：需 PBXTargetDependency + ENABLE_TESTABILITY
```

或直接用 Xcode 把文件加进 target。

---

## 7. 配置常量

| 项 | 值 |
|----|-----|
| PRODUCT_BUNDLE_IDENTIFIER | `local.appvolume` |
| MACOSX_DEPLOYMENT_TARGET | `14.2` |
| MARKETING_VERSION | `0.1.0` |
| LSUIElement | true（Info.plist） |
| App Sandbox | false |
| 日志 subsystem | `local.appvolume` |

偏好键（UserDefaults）：`appStates`, `launchAtLogin`, `showAllRunningApps`, `showInactiveAudioClients`, `hideNoisySystemClients`, `verboseLogging`。

---

## 8. 测试

```bash
xcodebuild -project AppVolume.xcodeproj -scheme AppVolume -destination 'platform=macOS' test -only-testing:AppVolumeTests
```

当前单测仅覆盖 `PreferencesStore` / `AppVolumeState` 逻辑。  
**真机音频行为必须手动测**（见下）。

### 手动验收清单

1. 菜单栏图标出现；列表在无播放时也显示已打开 App  
2. 播放音乐 → 拖滑块到 ~40% → 音量变小  
3. 静音 / 取消静音  
4. 拉回 100% → 直通（状态「正在发声」）  
5. 切换输出设备后受控 App 仍可听  
6. 切换输入设备（仅切系统默认输入，不改 per-app）  
7. 点「设置」能弹出窗口  
8. 拒绝/授予屏幕录制后的提示与重试  
9. 退出 App 后被静音的 App 恢复有声  
10. 登录启动开关  

---

## 9. 已知限制 / 风险

- 增益路径有 **缓冲延迟**（截取回放固有）  
- hog mode / 部分 DRM / 受保护音频可能控制失败  
- 多 App 同时非 100% → 多条 Aggregate/IO，CPU 上升  
- `CATapMuted` 若进程崩溃未清理 → 可能静音残留（已有 `AudioTeardown` + 退出钩子，仍需稳健性加强）  
- 刷新默认 2s 轮询 + 硬件监听；极端情况列表可能略滞后  
- dist/ 目录可能含带 XCTest 的 Debug 包，**不要当发布包**；发布应 Archive + 公证  

---

## 10. 建议后续工作（优先级）

1. **稳定性**：输出设备热插拔时会话重建更稳；启动时扫描残留 private aggregate/tap  
2. **UX**：真正 App 图标；菜单栏音量条；受控 App 排序固定  
3. **性能**：仅对非 100% App 保持 engine；空闲自动降级  
4. **格式健壮性**：IOProc 不假设 float（读 `kAudioTapPropertyFormat`）  
5. **分发**：Developer ID 签名 + 公证；`scripts/release.sh`  
6. **测试**：ProcessFilter / VolumeSession 决策表单测；可选集成测试文档  

---

## 11. 原则（与产品方约定）

- 只用公开 API  
- 优先系统音频稳定（默认 100% 直通）  
- 不破坏现有文件、无意义重构  
- 公开 API 做不到的能力：**直接说明，不假装实现**  
- 改音频路径的代码必须保证 **退出/失败路径销毁 Tap**  

---

## 12. 快速「我该改哪」

| 需求 | 改哪里 |
|------|--------|
| 列表显示规则 | `ProcessEnumerator` + `ProcessFilter` + `PreferencesStore` 开关 |
| 滑块/静音行为 | `AudioSessionStore` → `VolumeSession` |
| 真实增益算法/延迟 | `GainPlaybackEngine` |
| 静音-only | `ProcessTapController` |
| 输入输出设备 | `OutputDeviceManager.swift`（`AudioDeviceManager`）+ `DevicePickerView` / `SettingsView` |
| 设置打不开 | `AppSettingsOpener` + `MenuBarView.openSettings` |
| 自启 | `LoginItemService` + `PreferencesStore.launchAtLogin` |
| 权限文案 | `ScreenCapturePermission` + `PermissionGuideView` |

---

*最后同步：MVP Phase 0–3 + 列表/设备/设置打磨完成；构建状态 BUILD SUCCEEDED。*
