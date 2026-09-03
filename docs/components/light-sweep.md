# LightSweep

一道斜向光带在内容表面左右掠过，表示「正在等待 / 正在传输」/ A light band sweeping across the surface.

`LightSweep { }`（`CoreDesignEffects/LightSweep.swift`，Issue #252）。**容器视图形态**。

```swift
import CoreDesignEffects
```

## API

```swift
public struct LightSweep<Content: View>: View {
    public init(@ViewBuilder content: () -> Content)
}
```

## 与另外两个"扫光"的区别

| API | 触发 | 遮罩 | 表达 |
|---|---|---|---|
| `View.shine(trigger:)`（`CoreDesignEffects`） | 一次性，由 `trigger` 驱动 | 遮罩到**内容形状** | 「这件事刚发生」 |
| `LightSweep { }` | 常驻，无 trigger | 裁到内容**外接矩形** | 「这件事正在进行」 |
| `View.skeletonShimmer()`（`CoreDesign`） | 常驻 | 骨架块自身 | 骨架屏占位，扫的不是真内容 |

⚠️ **裁矩形而不是 `.mask(content)` 是有意的**：后者会把被包裹的内容**实例化两次**
（`.shine(trigger:)` 逐字记着这条限度——内容里带副作用的 modifier 会跑两遍：
`onAppear` 打点、`task {}`、`@FocusState` 自动聚焦）。容器形态天生包着别人的视图树，
把那个陷阱继承进来不可接受。
**代价**：光带不贴合内容的圆角与异形轮廓，只贴合它的外接矩形。

## 取色（FR-8）

光带色**取调用方的 `.tint`**，组件不自带颜色。

## Reduce Motion

不掠过，光带**静止停在内容中线**（共享降级形态 2：保留呈现、去掉运动、不叠脉冲）。

## 后台与低电量（NFR-7）

| 键 | 类型 | 默认 | 行为 |
|---|---|---|---|
| `\.effectsScenePhase` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ **整层不建** |
| `\.effectsPowerMode` | `EffectsPowerMode?` | `nil` ⇒ 读 `ProcessInfo.isLowPowerModeEnabled` | `.lowPower` ⇒ 降到 15 fps，并去掉离屏模糊的光晕 |

## a11y 分工（FR-13）

光带层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`。
⚠️ **「正在传输」这个状态由调用方通告。**

## 实现约定

⚠️ 薄封装，运动全部委托给 `ProcessingSweepDriver`（理由与判据同
[`scanning-overlay.md`](scanning-overlay.md)）。

## 使用示例 / Usage

```swift
LightSweep {
    ListRow(title: file.name, subtitle: "同步中…")
}
.accessibilityLabel("正在同步 \(file.name)")
```
