# spinning

为任意内容整体叠加一层加载遮罩 / Overlay any content with a loading mask.

`View.spinning(_:text:presentation:)`（`Modifier/SpinningModifier.swift`）吸收 Semi Design `Spin` 能力（Issue #172）。

⚠️ **交互与无障碍契约按 `presentation` 分岔**——不是整个 modifier 的统一语义：

- `.overlay`（默认）：`isActive == true` 时底层内容**禁止交互与 VoiceOver 访问**，上覆半透明遮罩 + 居中的 [`ProgressIndicator`](progress-indicator.md)；`isActive == false` 时内容原样渲染，无遮罩、无常驻空视图。表达「此刻不可操作」。
- `.topBar` / `.inline`：**非阻塞**。底层内容始终可交互、对 VoiceOver 始终可达，只在顶边加一条细进度条 / 在行内追加一个指示器。表达「后台正在加载、内容仍可用」。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| isActive | `Bool` | - | 是否显示加载指示 |
| text | `LocalizedStringKey?` | `nil` | 指示器的可选文案。⚠️ `.topBar` 下不生效（顶条没有文案位） |
| presentation | `SpinningPresentation` | `.overlay` | 呈现形态，见下表。默认 `.overlay` = 现状形态 ⇒ 现有调用方零影响 |

### `SpinningPresentation`（`#60` 形态 D2「配置枚举」）

⚠️ **D1（外观槽）事实上不可用**：本类型是 `ViewModifier` 而非 `View`，没有可挂
`@ViewBuilder` 外观槽的 `init` 参数位（`body(content:)` 的 `content` 是被修饰的内容，
属**内容槽**，公约明文排除）⇒ D 的两个子形态里只剩 D2。

| case | 说明 | 阻塞底层？ | 业界来源 |
|---|---|---|---|
| `.overlay` | 默认：材质遮罩铺满内容 + 居中指示器（现状形态） | ✅ 是 | —— |
| `.topBar` | 容器顶边的细进度条，不铺遮罩 | ❌ 否 | NProgress / YouTube 顶条 / GitHub Turbo |
| `.inline` | 原位行内指示器，不铺遮罩 | ❌ 否 | Ant Design Spin 非包裹用法 / MUI CircularProgress |

⚠️ **正交性的代价**：`text` 在 `.topBar` 下**不生效**（有意的静默，传了不报错）；
存储层原样保留，切回其余形态时不丢配置。

⚠️ **`.inline` 的 `HStack` 常驻**，`isActive == false` 时也包着内容——这是有意的：
改成 `if/else` 两分支会让 `isActive` 每次翻转都换掉内容的**视图身份**，SwiftUI 随之销毁
重建被修饰的整棵子树（`@State` 清零、输入焦点丢失、动画被打断），代价远大于「多包一层
单子视图 `HStack`」的对齐差异。

## 使用示例 / Usage

```swift
ContentView()
    .spinning(viewModel.isLoading)

ContentView()
    .spinning(viewModel.isLoading, text: "Refreshing…")

// 非阻塞：顶边细进度条，内容仍可点、仍对 VoiceOver 可达
ContentView()
    .spinning(viewModel.isLoading, presentation: .topBar)

// 非阻塞：行内指示器，跟在内容后面
Text("保存中")
    .spinning(viewModel.isSaving, presentation: .inline)

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
