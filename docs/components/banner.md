# Banner

通栏式信息提示组件 / Full-width notification banner.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| level | MessageLevel | - | 语义等级：info / success / warning / danger |
| label | () -> Label | - | banner 主体内容 |

支持 `View.bannerStyle(_:)` 注入外观，内置 `PlainBannerStyle`（默认）与 `BorderedBannerStyle`。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
Banner(level: .info) {
    Text("A pre-released version is available.")
}
Banner(level: .warning) {
    Text("This document will expire in 4 days.")
}
.bannerStyle(BorderedBannerStyle())
```

## 视觉 Token

- 布局：横向 HStack，`CoreSpacing.sm` icon-to-label 间距，`CoreSpacing.md` 内边距
- 字号：`CoreTypography.bodyMediumFont`
- 颜色：按 `MessageLevel` 走 status color token（`statusAccentForeground` / `statusAccentSubtle` / `statusAccentBorder` 等）
- 图标：`info.circle.fill` / `exclamationmark.triangle.fill` / `exclamationmark.circle.fill` / `checkmark.circle.fill`
- 描边（BorderedBannerStyle）：`CoreBorderWidth.thin`
