# ScanningOverlay

一道横向光束在内容上上下往复扫描，表示「正在识别 / 正在处理」/ A scanning beam sweeping over content.

`ScanningOverlay { }`（`CoreDesignEffects/ScanningOverlay.swift`，Issue #252）。**容器视图形态**（大写、尾随闭包），不是 modifier。

```swift
import CoreDesignEffects
```

## API

```swift
public struct ScanningOverlay<Content: View>: View {
    public init(@ViewBuilder content: () -> Content)
}
```

无配置参数。外观由环境驱动：颜色取 `.tint`，运动与否取 `\.accessibilityReduceMotion`，
画不画、画多满取两个能耗键（见下）。

## 取色（FR-8）

光束色**取调用方的 `.tint`**，组件不自带颜色：

```swift
ScanningOverlay { documentImage }.tint(.green)
```

## Reduce Motion

不往复，光束**静止停在内容中央**（相位钉在 `ProcessingSweep.restingPhase`）。
这是共享降级**形态 2**：保留"长什么样"、去掉运动，**不叠透明度脉冲**——
本效果是常驻状态呈现、没有 trigger，而脉冲是 trigger 驱动的一次性反馈，形态上对不上。

## 后台与低电量（NFR-7）

| 键 | 类型 | 默认 | 行为 |
|---|---|---|---|
| `\.effectsScenePhase` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ **整层不建**，驱动它的 `TimelineView` 不存在 |
| `\.effectsPowerMode` | `EffectsPowerMode?` | `nil` ⇒ 读 `ProcessInfo.isLowPowerModeEnabled` | `.lowPower` ⇒ 降到 15 fps，并去掉离屏模糊的光晕 |

⚠️ 停摆是"整层不建"，不是 `TimelineView(paused: true)`——后者仍是一个活着的视图节点。

## a11y 分工（FR-13）

光束层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`。

⚠️ **「正在扫描」这个状态由调用方通告**——组件不知道被包裹的是什么，也不知道这次处理
什么时候结束。调用方应自行给容器或相关元素加 `accessibilityLabel` / 发
`AccessibilityNotification.Announcement`。

## 实现约定

⚠️ 本类型是**薄封装**：`body` 只有一行 `content.overlay { ProcessingSweepDriver(kind: .scanning) }`。
驱动与绘制全在 `ProcessingSweep.swift`，容器**不得**自建第二套动画——否则 Reduce Motion 与
能耗降级只覆盖驱动层、不覆盖容器。这条由 `ProcessingSweepTests.containersDelegateToDriver`
守着（三个容器文件里必须出现 `ProcessingSweepDriver(`、且不得出现任何自建动画/绘制调用）。

## 使用示例 / Usage

```swift
ScanningOverlay {
    Image(uiImage: capturedPage)
        .resizable()
        .scaledToFit()
}
.tint(.green)
.accessibilityLabel("正在识别文档")
```

## 相关

- [`glow-sweep.md`](glow-sweep.md) —— 辉光沿边框转，内容不被遮挡
- [`light-sweep.md`](light-sweep.md) —— 光带掠过表面，更轻
- [`confetti.md`](confetti.md) —— 同批落地的一次性庆祝效果，共用同一套 NFR-7 能耗键
