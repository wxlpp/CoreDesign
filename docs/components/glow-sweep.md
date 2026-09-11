# GlowSweep

一段辉光沿内容边框转圈，表示「正在生成 / 正在思考」/ A glow travelling around the content border.

`GlowSweep { }`（`OhMyDesignEffects/GlowSweep.swift`，Issue #252）。**容器视图形态**。

```swift
import OhMyDesign        // 下面示例里的 `Card` 来自 `OhMyDesign`
import OhMyDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0，`OhMyDesignEffects` 不会把
`OhMyDesign` 的符号带出来。只写一个，下面的示例照抄进项目**编译不过**
（#252 PR #269 第 2 轮终审 S-b）。

## API

```swift
public nonisolated enum GlowSweepActivity: Sendable { case active, inactive }

public struct GlowSweep<Content: View>: View {
    public init(activity: GlowSweepActivity = .active, @ViewBuilder content: () -> Content)
    public init<S: InsettableShape>(in shape: S, activity: GlowSweepActivity = .active, @ViewBuilder content: () -> Content)
    public init<S: InsettableShape, Stroke: ShapeStyle>(in shape: S, stroke: Stroke, activity: GlowSweepActivity = .active, @ViewBuilder content: () -> Content)
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

省略 `stroke:` 时，辉光色**取调用方的 `.tint`**；显式传入时使用指定颜色或渐变。省略 `in:` 时边框圆角跟随 `CoreRadius.large`，
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

## ⚠️ 登记（`#270`）

`public struct GlowSweep` 由 `PublicTypeCollector` 采到，已按公约判定法登记进
`docs/component-registry.json` 的 `components`：
`kind: prescriptive` / `decidedBy: tiebreaker` / `needsExtensionPoint: false`。
落 tiebreaker 的理由：作用域条款排除了 `ScanningOverlay` / `LightSweep` 各自承担的候选形态，
其余（弧多宽 / 多亮 / 几段）是同一条弧换画法 ⇒ 装饰 ⇒ 不计入 ≥2。
逐字理由见该条目的 `notes`；扫描根由单根扩成 `GuardScanRoots.allRoots` 的经过见 issue #270。

## 自定义形状与启停

```swift
GlowSweep(in: Capsule(), stroke: LinearGradient(colors: [.cyan, .indigo, .pink], startPoint: .leading, endPoint: .trailing),
    activity: isVisible && isRunning ? .active : .inactive) {
    actionBar.glassEffect(.regular, in: .capsule)
}
.tint(Color.contentPrimary)
```

`in:` 接收 `InsettableShape`，使用内描边沿实际路径绘制；不裁剪内容，内容背景与流光应使用相同形状。省略形状保持原来的自适应圆角矩形。`GlowSweep<Content>` 类型参数不变，已有显式类型引用继续有效。

`activity == .inactive` 完全隐藏装饰层，不建立 `ProcessingSweepDriver` / `TimelineView`；内容仍保持同一结构身份。它优先于减少动态效果：停用不保留静态弧。启用后沿用系统后台/低电量/减少动态效果策略。宿主应在页面被覆盖或离屏时传入 .inactive，组件不会自动判断遮挡。

`stroke:` 接受任意 ShapeStyle，包括颜色和渐变；省略时沿用 `.tint`。生命周期使用 `GlowSweepActivity` 语义参数，避免为局部动效新增布尔配置豁免。

## 长条形状的速度

自定义形状入口按真实路径的归一化弧长推进，每周 3 秒；光尾占周长的 18%，首尾拆分衔接。长胶囊不再使用匀角速度遮罩，避免长边上加速、圆角处减速。无形状参数的旧入口保持原角向行为和周期。


### 遮罩与动效登记

路径光尾使用 `Color.maskLuminance(_:)` 生成不透明灰度，经过 `luminanceToAlpha()` 转换为遮罩。灰度属于遮罩数据而非界面色彩，不随主题改变；保持不透明绘制可避免相邻分段叠加形成亮点。

`PerimeterGlowTrail` 只绘制传入的相位，本身不启动时间线。计时、离屏、低电量和减少动态效果策略由 `ProcessingSweep` 统一管理，因此在动效守卫中登记为无自主运动的绘制组件。
