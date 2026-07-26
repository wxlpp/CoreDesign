# LabelIcon / ChevronRightIcon / DangerIcon

表单图标三件套 / Form icon trio.

## API

### LabelIcon

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| systemName | String | - | 上层 SF Symbol 名称 |
| backgroundColor | Color | - | 底层 tile 颜色 |
| variableValue | Double? | nil | SF Symbol variable value |

底层 `app.fill` glyph（24pt）+ 上层 SF Symbol（16pt, `contentInverse` 反白）。

### ChevronRightIcon

无参数。渲染 `chevron.right`，颜色 / 尺寸由父容器决定。

```swift
ChevronRightIcon()
```

### DangerIcon

无参数。渲染 `exclamationmark.circle.fill`，前景固定为 `Color.statusDangerForeground`。

```swift
DangerIcon()
```

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
LabeledContent {
    ChevronRightIcon()
} label: {
    Label {
        Text("主页")
    } icon: {
        LabelIcon(systemName: "person.circle.fill", backgroundColor: .red)
    }
}

LabeledContent {
    DangerIcon()
    ChevronRightIcon()
} label: {
    Label {
        Text("通知")
    } icon: {
        LabelIcon(systemName: "bell.badge.fill", backgroundColor: .danger)
    }
}
```

## 视觉 Token

- LabelIcon 底层 tile 边长：`CoreControlMetrics.iconSize(for: .extraLarge)`（24pt）
- LabelIcon 上层 glyph 边长：`CoreControlMetrics.iconSize(for: .regular)`（16pt）
- LabelIcon 反白色：`Color.contentInverse`
- DangerIcon 前景：`Color.statusDangerForeground`
