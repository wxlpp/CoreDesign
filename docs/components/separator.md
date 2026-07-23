# Separator

可控 inset 的分隔线 / Divider with configurable leading inset.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| inset | Separator.Inset | .none | 分隔线的 leading 缩进方式：`.none`（贯穿）/ `.leading(CGFloat)`（缩进指定量） |

`Inset.leading` 传负值会被 clamp 到 0（视作 `.none`，负值向外扩会溢出父容器边界，无实际用途）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
Separator()                                   // 贯穿整行
Separator(inset: .leading(CoreSpacing.xl))    // leading 缩进 24pt，对齐图标后的文本
```

## 视觉 Token

- 颜色：`Color.dividerDefault`（第 3 层语义 token，即系统 `separator` 色），随系统外观 / 对比度设置自动更新
- 高度：hairline，`1.0 / displayScale`（1 物理像素，@2x/@3x 屏都是最细一线，而非固定 1pt）
- 宽度：`maxWidth: .infinity`，减去 `inset.leadingAmount` 的 leading padding
