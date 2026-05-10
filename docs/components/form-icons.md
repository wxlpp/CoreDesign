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

无参数。渲染 `exclamationmark.circle.fill`，前景固定为 `Color.dangerForeground`。

```swift
DangerIcon()
```

## 预览 / Preview

![Light](../snapshots/CoreDesignPreview_Previews.swift_Form_Icons.png)

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
- DangerIcon 前景：`Color.dangerForeground`
