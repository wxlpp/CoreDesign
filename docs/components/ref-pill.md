# RefPill

代码引用 pill / Code reference pill.

灰底 + 等宽字体 + 细边框，用于显示分支名、commit SHA、tag 等技术引用。支持单引用和 base/head 双引用箭头连接。

## API

| 初始化器 | 用途 |
|---|---|
| `RefPill(_ ref: String)` | 单引用：分支名、SHA、tag |
| `RefPill(base: String, head: String)` | 双引用：base ← head，用于 PR 标题 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
RefPill("main")
RefPill("a1b2c3d4e5f6")
RefPill(base: "main", head: "feat/foo")
```

## 视觉 Token

- 圆角：`CoreRadius.small`
- 字号：`.caption.monospaced()` for ref text，`.caption2` for icons
- 背景：`Color.surfaceCanvasInset`
- 边框：`Color.borderMuted`，宽度 `CoreBorderWidth.thin`
- 图标：`arrow.triangle.branch`（首），`arrow.left`（base/head 连接）
- Padding：横向 `CoreSpacing.sm`，纵向 `CoreSpacing.xxs`
- 可访问性：单引用读 ref 字符串；双引用读 `"<base> from <head>"`
