# Avatar

圆形彩色占位头像 / Circular color placeholder avatar.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| name | String | - | 用户名，用于取首字符与背景色哈希 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
Avatar(name: "Alice")
    .frame(width: 100, height: 100)
    .clipShape(Circle())
```

## 视觉 Token

- 位图边长：`CoreSpacing.xxxxl`（48pt）
- 首字符字号：`CoreTypography.titleLargeFont.weight(.bold)`（32pt）
- 前景色：`Color.white`
- 背景色：由 `Color(text: name)` 从姓名哈希稳定派生
- 圆角：由调用方 `.clipShape(Circle())` 保证
