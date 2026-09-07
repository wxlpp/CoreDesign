# ProgressBar

水平进度条 / Horizontal progress bar.

> **⚠️ 已弃用（`0.6.0` 起）**：改用系统 `ProgressView(value:).progressViewStyle(.core)`（见 [core-control-styles.md](core-control-styles.md)）。二者视觉几乎一致，但 `.core` **响应环境 `.tint`**、走系统控件，无障碍与 Dynamic Type 更完整；`ProgressBar` 有意拒绝环境 tint、只认自己的 `tint:` 参数。`ProgressBar` 保留至下游迁移完成后移除。

灰色底轨 + 可配置彩色填充 + 可选左侧 label 文本。`value` 自动 clamp 到 `0...1`。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| value | Double | - | 进度，自动 clamp 到 `0...1` |
| tint | Color? | nil | 填充色，nil 时使用 `Color.accent` |
| label | String? | nil | 左侧 label，nil 时省略 |

## 预览 / Preview

已弃用，不再生成快照预览图。替代品的预览见 [core-control-styles.md](core-control-styles.md)（`.core ProgressView`）。

## 使用示例 / Usage

```swift
ProgressBar(value: 0.5, label: "50%")
ProgressBar(value: 1.0, tint: .statusSuccessEmphasis, label: "Done")
```

## 视觉 Token

- 高度：`CoreSpacing.xs`
- 圆角：`CoreRadius.small`
- 底轨色：`Color.surfaceCanvasInset`
- 填充色：`tint ?? Color.accent`
- Label 字号：`.coreFont(.footnote)`
- 可访问性：`accessibilityValue` = 百分比 + catalog 的 `"%@ complete"`。
  百分比走 `value.formatted(.percent…)`（`#235`）⇒ **百分号相对数字的位置由 locale 决定**，
  不写死在 Swift 侧：`en_US` `50%` · `tr_TR` `%50` · `fr_FR` / `fr_CA` / `de_DE` `50\u{00A0}%`
  · `eu_ES` `%\u{00A0}50` · `ar_EG` `٥٠٪` + U+061C。
  ⚠️ 这是**区域**事实不是语言事实：`de_CH` 实测就是 `50%`（无空格）。
  **只有百分比部分**取自 SwiftUI 的 `\.locale` 环境值（不是进程 locale），与同一个 a11y
  元素上的 `accessibilityLabel` 同源。
  取整方向是 `.towardZero`（`0.999` ⇒ `99%`），不取默认的四舍五入——`0.999` 读成「100% complete」而进度并未完成是更坏的失败形态。
  ⚠️ **文案部分仍是英文**：`Bundle.module` 只有 `en.lproj`，`"%@ complete"` 对任何 locale
  都回退到 en ⇒ 土耳其语下读出来是 `%50 complete` 这种**数字随 locale、文案随 en** 的
  混合形态。这是 Foundation 对未翻译 bundle 的标准行为，不是缺陷。
  （旧实现对 tr 是通篇英文的 `50% complete`，混合形态是 `#235` 才出现的。）
  ⚠️ **补 `<lang>.lproj` 之后也不会与 `\.locale` 同源**：`String(localized:locale:)` 的
  `locale:` 参数**不参与 `.lproj` 选择**（实测：带 `en.lproj` + `fr.lproj` 的 fixture bundle
  下，传 `fr_FR` 与不传输出一字不差），文案永远按 `Bundle.module.preferredLocalizations`
  即**进程** locale 取 ⇒ `.environment(\.locale, fr)` + 进程 en 会读出「label 与百分比跟环境、
  文案跟进程」的分叉。

  ⚠️ 与旧实现的 `Int(value * 100)` **方向相同但不逐值相等**：旧实现在**二进制**浮点上截断，`0.29` / `0.57` / `0.58` 旧给 `28` / `56` / `57`，新的十进制截断给 `29` / `57` / `58`（101 个整点里 3 处，新值正确，属顺带修正）。
