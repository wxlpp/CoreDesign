# Separator

可控 inset 的分隔线 / Divider with configurable leading inset.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| inset | Separator.Inset | .edgeToEdge | 分隔线的 leading 缩进方式：`.edgeToEdge`（贯穿）/ `.leading(CGFloat)`（缩进指定量） |

`Inset.leading` 传负值会被 clamp 到 0（视作 `.edgeToEdge`，负值向外扩会溢出父容器边界，无实际用途）。

> `0.6.0` 起 `case none` 改名 `.edgeToEdge`——避免与 `Optional.none` 遮蔽（持有 `Inset?` 时写 `.none` 会静默解析成 `Optional.none`）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
Separator()                                   // 贯穿整行
Separator(inset: .leading(CoreSpacing.xl))    // leading 缩进 24pt，对齐图标后的文本
```

## 视觉 Token

- 颜色：`Color.dividerDefault`（第 3 层语义 token，即系统 `separator` 色），随系统外观 / 对比度设置自动更新
- 高度：hairline，`1.0 / displayScale`（1 物理像素，@2x/@3x 屏都是最细一线，而非固定 1pt）
- 宽度：`maxWidth: .infinity`，减去 `inset.leadingAmount` 的 leading padding
