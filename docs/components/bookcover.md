# BookCover

书籍封面容器 / Book cover container.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| data | Data? | - | 封面图原始字节（PNG/JPEG），nil 或解码失败时降级为占位图 |
| title | String | - | 书名，同时作为占位图的文字内容与背景色种子 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
// 有效图片
BookCover(data: imageData, title: "万历十五年")
    .frame(width: 120)

// 无图自动降级占位
BookCover(data: nil, title: "三体：黑暗森林")
    .frame(width: 120)
```

## 视觉 Token

- 宽高比：`BookCover.aspectRatio = 2.0 / 3.0`（行业标准书籍比例）
- 圆角：`CoreRadius.medium`
- 边框：`Color.borderMuted`，宽度 `CoreBorderWidth.hairline`
- 阴影：`.coreShadow(.medium)`
- 占位图背景：由 `Color(text: title)` 哈希生成的线性渐变
- 占位图文字：`Color.contentOnEmphasis`（白色），字号与容器宽度成比例（13%）
