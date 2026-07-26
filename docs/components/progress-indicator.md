# ProgressIndicator

通用圆形加载指示器 / Generic circular loading indicator.

封装系统 `ProgressView`，使用 `accent` 色（跟随宿主 App 的 `AccentColor`）作为 tint，自动响应 `@Environment(\.controlSize)`。可选传入文案，渲染于 spinner 下方（Issue #172）。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| (none) | - | - | `init()`，不带文案；通过 `.controlSize(_:)` 调整尺寸 |
| text | `LocalizedStringKey` | - | `init(text:)`，静态文案，在 `Bundle.main` 本地化 |
| text | `some StringProtocol` | - | `init(text:)`，运行期字符串文案，verbatim 显示（`@_disfavoredOverload`，字面量优先落到 `LocalizedStringKey` 重载） |

三个 init 均保留既有 `accessibilityLabel("Loading")` 语义——带文案时，可视文案对 VoiceOver `.accessibilityHidden(true)`，避免与 label 双重播报。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
ProgressIndicator()
    .controlSize(.large)

// 带静态文案
ProgressIndicator(text: "Loading…")

// 带运行期字符串文案
ProgressIndicator(text: statusMessage)

// 与其他 SwiftUI 控件一起被外层 controlSize 影响
HStack {
    ProgressIndicator()
    Text("Loading…")
}
.controlSize(.small)
```

为任意内容整体叠加加载遮罩（而非只放一个 spinner），见 [`spinning` modifier](spinning.md)。

## 视觉 Token

- Tint：`Color.accent`（**FR-3a 例外**：本文件是 epic 内唯一直接包装系统 `ProgressView` 的组件，显式写 `.tint(Color.accent)` 而非走 `.tint` 环境取色——SC-5 的静态核对「无字面 `Color.accent`」对本文件豁免，详见 `.claude/epics/semi-mobile-components/172.md` Technical Details）
- 尺寸：跟随 `\.controlSize`（mini / small / regular / large / extraLarge）
- 文案：`.coreFont(.footnote)` + `Color.contentSecondary`，spinner 与文案间距 `CoreSpacing.sm`
- 可访问性：`accessibilityLabel("Loading")`
