# GlowSweep

一段辉光沿内容边框转圈，表示「正在生成 / 正在思考」/ A glow travelling around the content border.

`GlowSweep { }`（`CoreDesignEffects/GlowSweep.swift`，Issue #252）。**容器视图形态**。

```swift
import CoreDesignEffects
```

## API

```swift
public struct GlowSweep<Content: View>: View {
    public init(@ViewBuilder content: () -> Content)
}
```

## 与另外两个"处理中"效果的分工

三者都是常驻呈现，落点不同：

| 组件 | 形态 | 表达 |
|---|---|---|
| [`ScanningOverlay`](scanning-overlay.md) | 光束**穿过**内容 | 「正在读这块内容」（识别、解析） |
| `GlowSweep` | 辉光**沿边框转** | 「这块内容正在被生成」，内容本身不被遮挡 |
| [`LightSweep`](light-sweep.md) | 光带**掠过表面** | 「正在等待 / 传输」，比前两者更轻 |

## 取色（FR-8）

辉光色**取调用方的 `.tint`**，组件不自带颜色。边框圆角跟随 `CoreRadius.large`，
并自动收敛到短边的一半（小尺寸内容上不会画歪）。

## Reduce Motion

不转圈，辉光弧**静止停在一个固定角度**（共享降级形态 2：保留呈现、去掉运动、不叠脉冲）。

## 后台与低电量（NFR-7）

| 键 | 类型 | 默认 | 行为 |
|---|---|---|---|
| `\.scenePhaseOverride` | `ScenePhase?` | `nil` ⇒ 读系统 `\.scenePhase` | `.inactive` / `.background` ⇒ **整层不建** |
| `\.lowPowerModeOverride` | `Bool?` | `nil` ⇒ 读 `ProcessInfo.isLowPowerModeEnabled` | `true` ⇒ 降到 15 fps，并去掉离屏模糊的光晕 |

## a11y 分工（FR-13）

辉光层是**纯装饰**，已 `accessibilityHidden(true)`、`allowsHitTesting(false)`。
⚠️ **「正在生成」这个状态由调用方通告。**

## 实现约定

⚠️ 薄封装，运动全部委托给 `ProcessingSweepDriver`（理由与判据同
[`scanning-overlay.md`](scanning-overlay.md)）。

## 使用示例 / Usage

```swift
GlowSweep {
    Card {
        Text(answer)
    }
}
.tint(.accent)
.accessibilityLabel("正在生成回答")
```
