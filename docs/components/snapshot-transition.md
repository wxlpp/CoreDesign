# SnapshotTransition

快门 / 显影转场 / A shutter-and-develop (instant photo) transition.

`.transition(.snapshot)`（`CoreDesignEffects/SnapshotTransition.swift`，Issue #266）。
⚠️ **`Transition` 形态**——不是容器视图，也不是 `View` 上的 modifier。

```swift
import CoreDesign
import CoreDesignEffects
```

## API

```swift
public struct SnapshotTransition: Transition {
    public let intensity: Double
    public nonisolated static let defaultIntensity: Double   // 0.7
    public nonisolated static let properties: TransitionProperties       // hasMotion: false
    public init(intensity: Double = SnapshotTransition.defaultIntensity)
    public func body(content: Content, phase: TransitionPhase) -> some View
}

public extension Transition where Self == SnapshotTransition {
    static var snapshot: SnapshotTransition { get }
    static func snapshot(intensity: Double = SnapshotTransition.defaultIntensity)
        -> SnapshotTransition
}
```

两个静态成员按 `Host.member` 去重，**算同一种转场**。

## ⚠️ Reduce Motion / 减弱闪烁灯光：**只读「减弱闪烁灯光」**（与 `filmExposure` 同族）

| 维度 | 判断 | 处置 |
|---|---|---|
| 前庭（光流） | **无风险**——无位移 / 旋转 / 缩放 | **有意不读** `\.accessibilityReduceMotion` |
| 光敏（亮度） | **有（强）**——快门白场是全簇**最陡**的一次亮度上冲 | 读 `\.accessibilityDimFlashingLights` |

白场被刻意做成一个**窄窗**（半宽 0.25 的升余弦），窄意味着**陡**。窗形是 **0 → 峰 → 0**
⇒ 按 WCAG 2.3.1 的定义（"a pair of opposing changes" 逐字即 "an increase followed by a
decrease, or a decrease followed by an increase"）**它就是一次 general flash**。
**单次**使用不构成 2.3.1 违规，理由是**频率**：一次转场只放 1 次 flash，而阈值的第一条
通过条件是「任意一秒内 general flash 不超过 3 次」。
⚠️ **有边界，不是无条件豁免**：一秒内插入/移除 4 个以上带本转场的视图（列表批量插入、
照片墙逐格出现）就越过 3 次/秒线，届时 `full` 档 **0.7** 的峰值幅度也远高于「10% 相对
亮度」那条合取项。**批量场景请自行核对触发频率。**
⚠️ 前两版这里先把 0.1 写成一条独立的幅度阈值、再写「单向 ⇒ 不满足『一对反向变化』」，
**两句都是误述**（终审 I-1 与第 2 轮 I-1）；逐字论证见
`docs/components/film-exposure-transition.md` 同一节。
⇒ 压制它的理由与 `filmExposure` 逐字相同：**用户显式打开了「减弱闪烁灯光」**，
而这是全簇最陡的一下亮冲。走同一道闸、同一个上限
（`FilterTransitionSafety.exposure(dimFlashingLights:)` ⇒ 峰值 ≤ **0.08**）。
⚠️ 0.08 是一条**产品策略线**，不是达标线；`.brightness(_:)` 与 WCAG 的相对亮度不是同一个量，
逐格实测（`.brightness(0.08)` 在 gray 0.85 上的 ΔrelLum 是 0.1286）见
`docs/components/film-exposure-transition.md` 与
`FilterTransitionSafety.calmedBrightnessCeiling` 的文档。

⚠️ **不是 no-op**：显影（饱和度 / 对比度从洗白回到常态）与淡入淡出全部保留，
去掉的只有那一下白场。

### ⚠️⚠️ `properties.hasMotion` 必须是 `false`，否则「有意不读 Reduce Motion」是假的

`Transition` 协议有 `static var properties: TransitionProperties`，**默认 `hasMotion == true`**。
SDK 原文：

> Whether the transition includes motion. When this behavior is included in a transition,
> that transition will be replaced by opacity when Reduce Motion is enabled. Defaults to `true`.

⇒ 不显式声明的话，只开启「减弱动态效果」的用户**照样**丢掉这条成像效果
——只是丢在框架那一层，本文件一个字都看不见，而上表却写着"有意不读"。
本类型因此写了 `public nonisolated static let properties = TransitionProperties(hasMotion: false)`，
判据 `everyTransitionOptsOutOfTheFrameworkMotionSubstitution` 直接断言那个**性质**
（PR #289 终审 C-4）。

## 相位契约与曲线

| 相位 | 进度 | 亮度增量 | 饱和度 | 对比度 | 不透明度 |
|---|---|---|---|---|---|
| `.willAppear` | 1 | **0** | 0 | 0.55 | **0** |
| `.identity` | **0** | **0** | **1** | **1** | **1** |
| `.didDisappear` | 1 | **0** | 0 | 0.55 | **0** |
| （白场中心 0.75） | 0.75 | **`intensity`** | 0.0625 | 0.6625 | 0.75 |

- 亮度：升余弦窗，中心 `shutterCenter = 0.75`、半宽 `shutterWidth = 0.25`
  ⇒ 只在 `(0.5, 1)` 内非零，中心 1、两端 0（一阶连续，不留硬边）。
  ⚠️ 中心取 0.75 而不是 0.5：插入时进度从 1 走到 0，白场因此落在**动作的前段**
  ——先按快门、再显影，与真实即显相机的次序一致。
- 饱和度：`max(0, 1 − 1.25p)`；对比度：`1 − 0.45p`；
  不透明度：`min(1, max(0, (1 − p) · 3))`
  ——前 2/3 段保持完全不透明，只在最后一小段收掉，否则白场发生时内容已经半透明。

## ⚠️⚠️ 曲线非单调 ⇒ 绘制层**必须** `Animatable`

白场只在窗内有值，而**可达相位只有 0 与 1**（两端都恰为 0）。
绘制层不 `Animatable` 的话，SwiftUI 把 `.brightness` 的输出从 0 插到 0
⇒ **快门一次都不会发生且全套测试照绿**（#253 `ParticleTransition` 的原形态）。

⇒ `SnapshotFilm` 是 `ViewModifier & Animatable`。判据两条互锁：
`snapshotOnlyFlashesInsideTheShutterWindow`（窗内非零、窗外与两个可达相位恒 0）
+ `snapshotDrawsTheShutterMidFlight`（插值到窗口中心的那一帧，位图必须与两端都不同，
且等于直接用 `shutterCenter` 构造的那一帧）。

## 退化输入

`intensity` 为负 / `NaN` / `∞` / `> 1` 一律夹进 `0...1`，**不抛断言**（AD-F）。

## a11y 分工（FR-13）

无装饰层。**"这块内容出现 / 消失了"的通告由调用方提供。**

## 登记

`Transition.snapshot` 已登记进 `docs/component-registry.json` 的 `entryPoints`。

## 预览

`#Preview("SnapshotTransition")` 在同文件内。
