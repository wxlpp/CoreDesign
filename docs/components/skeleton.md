# Skeleton

骨架屏加载态 / Skeleton loading placeholder.

`Skeleton` 是 `isLoading` 与真实内容之间的切换容器：`true` 时展示占位形状树（`.redacted(reason: .placeholder)` 基座 + `.skeletonShimmer()` 扫光叠加），`false` 时展示调用方通过 `@ViewBuilder content` 传入的真实内容，两者用 `.animation` 平滑过渡。占位形状由 `SkeletonLine` / `SkeletonRect` / `SkeletonCircle` 三种独立 view 组成，可单独使用，也可以任意 `HStack` / `VStack` 拼装出复合骨架布局（如"头像 + 两行文本"）。

## API

### Skeleton

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| isLoading | Bool | - | `true` 展示 `placeholder`，`false` 展示 `content` |
| placeholder | () -> some View | - | `@ViewBuilder`，占位形状树，会被自动叠加 `.redacted(reason: .placeholder)` + `.skeletonShimmer()` |
| content | () -> some View | - | `@ViewBuilder`，`isLoading == false` 时展示的真实内容 |

### SkeletonLine

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| lineCount | Int | 1 | 行数，小于 1 会被 clamp 到 1 |
| lineHeight | CGFloat | 12 | 每行高度（pt） |
| spacing | CGFloat | CoreSpacing.xs | 行间距 |
| lastLineWidthFraction | CGFloat | 0.7 | 最后一行宽度相对整宽的比例，仅 `lineCount > 1` 时生效 |

### SkeletonRect

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| width | CGFloat? | nil | 固定宽度；`nil` 时撑满父容器宽度 |
| height | CGFloat | 120 | 固定高度 |
| cornerRadius | CGFloat | CoreRadius.medium | 圆角半径 |

### SkeletonCircle

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| diameter | CGFloat | 40 | 直径 |

### `.skeletonShimmer()`

`View` 扩展 modifier，叠加持续扫过的高亮渐变带。`Skeleton` 已在占位分支自动叠加，独立使用 `SkeletonLine` / `SkeletonRect` / `SkeletonCircle` 而不经过 `Skeleton` 容器时可直接调用。响应 `accessibilityReduceMotion`：开启时跳过动画，只保留静态占位底色。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
// 独立使用单一形状
SkeletonLine(lineCount: 3)
SkeletonRect(height: 160)
SkeletonCircle(diameter: 48)

// 通过 Skeleton 容器在占位态与真实内容之间切换
Skeleton(isLoading: viewModel.isLoading) {
    HStack(alignment: .top, spacing: CoreSpacing.md) {
        SkeletonCircle(diameter: 40)
        SkeletonLine(lineCount: 2)
    }
} content: {
    HStack(alignment: .top, spacing: CoreSpacing.md) {
        Avatar(name: viewModel.name)
        VStack(alignment: .leading, spacing: CoreSpacing.xs) {
            Text(viewModel.name)
            Text(viewModel.subtitle).foregroundStyle(.secondary)
        }
    }
}
```

## 视觉 Token

- 占位底色：`Color.skeletonBase`（= `Color.fill`，系统 `systemFill`），随系统外观 / 对比度自动更新
- shimmer 高光：`Color.skeletonHighlight`（= `skeletonBase.opacity(0.35)`），由底色派生，**不新增 colorset**（semi-mobile-components Phase 0 定案，见 `Colors/FillColors.swift`）
- 圆角：`SkeletonLine` 用 `lineHeight / 2`（胶囊化行占位）；`SkeletonRect` 默认 `CoreRadius.medium`
- shimmer 周期：1.4s，`TimelineView(.animation)` 驱动，不使用 `repeatForever`
- 可访问性：占位态整体收敛为一个 `accessibilityElement(children: .ignore)` + `"Loading"` 标签（复用 `ProgressIndicator` 已登记的 `Localizable` 键，非新增字符串）
- reduce motion：`accessibilityReduceMotion` 开启时 `.skeletonShimmer()` 不叠加动画，只保留静态底色
