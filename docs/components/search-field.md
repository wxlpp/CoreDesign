# SearchField

搜索输入框 / Search input field.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| text | Binding<String> | - | 搜索文本的双向绑定 |
| placeholder | String | "Search" | 空文本占位提示 |
| onSubmit | ((String) -> Void)? | nil | Return 提交回调 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
@State private var query = ""

SearchField(text: $query, placeholder: "Filter issues") { submitted in
    viewModel.runSearch(submitted)
}
```

## 视觉 Token

⚠️ **本节整段已作废。** 组件内部改用**平台原生**搜索框
（iOS `UISearchTextField` / macOS `NSSearchField`），背景、边框、圆角、放大镜、
清除按钮、占位文案、焦点态、RTL 镜像与 Dynamic Type **全部由平台提供**，
库不再逐项指定这些 token。

⚠️ 上一版本节自身也已失真（写 `surfaceCanvasInset` / `CoreRadius.medium`，
而代码是 `surfaceInteractive` / `CoreRadius.small`）——一并记在这里，
说明「逐 token 抄一遍视觉」这种文档形态本身就容易掉队。

仍由库指定的只有两项：

- **命中区高度**：`CoreControlMetrics.height(for: .regular)` = 44pt，由外层包装层承担。
  ⚠️ 原生控件**不随 frame 撑满**——iOS 实测 `intrinsicContentSize.height = 28`，
  在 28 / 36 / 44 三档 frame 下绘制带恒为同一高度且垂直居中；macOS `NSSearchField(.large)`
  同形。⇒ 视觉是控件自然高、命中区是 44pt，包装层用 `contentShape` + tap 转
  `becomeFirstResponder()` 把上下缘也接上。
- **横向撑满**：`frame(maxWidth: .infinity)`。

⚠️ **`#222` 的 a11y 行为改由系统提供**：清除按钮及其可访问名现在来自平台，
库不再自带 `clearLabel(for:)`，`Localizable.strings` 里的 `"Clear %@"` 已移除。
