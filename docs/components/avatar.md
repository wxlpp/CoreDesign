# Avatar

圆形彩色占位头像 / Circular color placeholder avatar.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| name | String | - | 用户名，用于取首字符与背景色哈希 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

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
