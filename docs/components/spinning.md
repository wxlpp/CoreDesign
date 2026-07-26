# spinning

为任意内容整体叠加一层加载遮罩 / Overlay any content with a loading mask.

`View.spinning(_:text:)`（`Modifier/SpinningModifier.swift`）吸收 Semi Design `Spin` 能力（Issue #172）——`isActive == true` 时底层内容禁止交互与 VoiceOver 访问，上覆半透明遮罩 + 居中的 [`ProgressIndicator`](progress-indicator.md)；`isActive == false` 时内容原样渲染，无遮罩、无常驻空视图。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| isActive | `Bool` | - | 是否显示遮罩 |
| text | `LocalizedStringKey?` | `nil` | 遮罩内 `ProgressIndicator` 的可选文案 |

## 使用示例 / Usage

```swift
ContentView()
    .spinning(viewModel.isLoading)

ContentView()
    .spinning(viewModel.isLoading, text: "Refreshing…")

// 常见用法：包裹一个已有的卡片列表 / 表单
ScrollView {
    VStack(spacing: CoreSpacing.lg) {
        ForEach(items) { item in
            Card { ItemRow(item: item) }
        }
    }
    .padding()
}
.spinning(isRefreshing)
```

## 无障碍

- 遮罩激活时，底层内容 `.allowsHitTesting(false)` + `.accessibilityHidden(true)`——VoiceOver 焦点落在遮罩内的 `ProgressIndicator`（复用其既有 `"Loading"` accessibilityLabel 语义）。
- 遮罩关闭时内容行为不受影响。

## 视觉 Token

- 遮罩背景：`.regularMaterial`（系统材质，随外观自动适配，不新增 colorset）
- Loading 视觉：直接复用 `ProgressIndicator(text:)`——**不**重新包装系统 `ProgressView`
- 出现 / 消失过渡：`.transition(.opacity)` + `.animation(.default, value: isActive)`

## FR-3a 例外范围说明

`ProgressIndicator.swift` 因直接包装系统 `ProgressView`，显式写 `.tint(Color.accent)`，是 epic FR-3「强调色走 `.tint`」的唯一例外（SC-5 静态核对对该文件豁免）。`SpinningModifier` **不**落入这条豁免范围——它不直接包装 `ProgressView`，而是组合调用已经处理好 tint 的 `ProgressIndicator` 组件；本文件若出现任何强调色需求，须正常走 `.tint`（当前实现无此需求）。详见 `.claude/epics/semi-mobile-components/172.md` Technical Details。
