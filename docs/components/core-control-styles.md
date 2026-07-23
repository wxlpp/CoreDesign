# CoreProgressViewStyle / CoreLabelStyle / CoreDisclosureGroupStyle

系统控件的 CoreDesign 换皮 / CoreDesign skins for system controls.

## API

三者都不重新实现控件本身——只重绘 / 重排各协议 `makeBody(configuration:)` 交出的内容，展开态、进度值等状态仍由系统控件自身持有。均无参数 `init()`，经各自协议的 `static var core` 使用。

### CoreProgressViewStyle

`.progressViewStyle(.core)`。确定态（`fractionCompleted != nil`）渲染水平轨道 + 填充条；不确定态退回系统环形 spinner（显式 `.progressViewStyle(.circular)`，避免递归回本 style）。

### CoreLabelStyle

`.labelStyle(.core)`。重排 `icon` + `title`：icon 走 `.tint` 取色，title 保持系统默认前景色，icon 显式 `.accessibilityHidden(true)`（VoiceOver 只播报 title）。

### CoreDisclosureGroupStyle

`.disclosureGroupStyle(.core)`。`label` + 随展开态旋转 90° 的 chevron 放进 `.plain` 样式的 `Button` 里；换皮后系统不再自动为这个自绘 `Button` 播报展开态，已显式补 `.accessibilityValue`（"Expanded" / "Collapsed"，走 `bundle: .module`）。

### 诚实略过：Toggle / TextField

FR-12 原始范围列了 5 个 style，实际交付 3 个 + 2 个诚实略过：

- **`.toggleStyle(.core)` 略过**：自定义 `ToggleStyle.makeBody` 会整体替换原生 `UISwitch`，拖动手势与 haptic 必丢；补回等于重造控件（任务明令禁止）。
- **`.textFieldStyle(.core)` 略过**：`TextFieldStyle` 唯一 requirement 是下划线私有的 `_body`，无公开的第三方自定义入口；能做的只有 `.coreTextField()` 这类 View modifier 组合，满足不了 `.textFieldStyle(.core)` 的字面 API。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
    .progressViewStyle(.core)
    .tint(.red) // 填充条随之变红，不恒取 Color.accent

Label("Sync", systemImage: "arrow.triangle.2.circlepath")
    .labelStyle(.core)
    .tint(.red) // icon 随之变红

DisclosureGroup("Details", isExpanded: $isExpanded) {
    Text("Additional information goes here.")
}
.disclosureGroupStyle(.core)
.tint(.red) // chevron 随之变红
```

## 视觉 Token

- 强调色全部经 `.tint`（`ShapeStyle.tint`）取值，不写死 `Color.accent`（FR-12 / ADR-3 硬约束）——外层 `.tint(_:)` 能真的改变填充条 / icon / chevron 的颜色
- `CoreProgressViewStyle` 轨道底色：`Color.surfaceCanvasInset`；圆角：`CoreShape.rounded(CoreRadius.small)`；间距：`CoreSpacing.xs`
- `CoreLabelStyle` 图标 ↔ 标题间距：`CoreSpacing.sm`
- `CoreDisclosureGroupStyle` 展开内容缩进：`CoreSpacing.md`；标题行 ↔ 展开内容纵向间距：`CoreSpacing.sm`（标题与 chevron 间是弹性 `Spacer()`，非定距）；展开内容不套 `.surface(.content)`（贴近系统观感，不消费 surface 层）
