# TagInput

标签输入框 / Tag input field with inline chip entry.

`Binding<[String]>` 驱动：已有标签以 chip 形式展示，末尾内联一个文本输入框，
回车或逗号提交新标签，点击 chip 上的删除按钮移除标签。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| tags | Binding<[String]> | - | 已提交标签的双向绑定，按添加顺序排列 |
| placeholder | String | "Add tag" | 输入框空态占位文案 |
| tagColor | Color | `.contentSecondary` | chip 调色板，透传给 `Tag(color:)` |
| allowDuplicates | Bool | false | 是否允许提交与已有标签完全相同（大小写敏感）的候选 |
| onCommit | ((String) -> Void)? | nil | 每次成功提交一个新标签后调用，参数为归一化后的文本 |

## 与 FlowLayout / Tag 的复用关系

- **折行**：复用 `FlowLayout(spacing: CoreSpacing.xs)`——输入框作为其最后一个
  子视图，随已有标签数量自然换行到新行，不改动 `FlowLayout` 本身。
- **chip**：复用 `Tag(_:color:removable:onRemove:)`——拿到现成的 44pt 命中区
  删除按钮与已登记的 `"Remove tag"` 本地化键，不重造删除交互。`tagColor`
  默认 `Color.contentSecondary`（中性文本色），而非 `Tag` 常见的分类色板，
  因为标签输入场景通常不需要 GitHub-label 式的按色相分类。
- **chip 迭代**：`ForEach(Array(tags.enumerated()), id: \.offset)`——按下标
  而非标签值取 id，避免 `allowDuplicates: true` 时同名标签产生 `ForEach` id
  碰撞；删除同样按下标定位，精确命中目标 chip 而非误删同名的第一个。

## 提交规则

- trim 首尾空白/换行后为空字符串的候选不提交（`normalizedTag(_:)`）。
- `allowDuplicates == false`（默认）时，与已有标签完全相等（大小写敏感，不做
  归一化）的候选不重复添加。
- 提交后清空输入框，无论走哪条提交路径。
- **Return 提交**：`TextField.onSubmit`，整段输入框内容作为单个候选提交。
- **逗号快速录入**（增强路径，非替代）：输入框内容包含 `,` 时即时拆分——除
  最后一段外的每一段各自按上述规则提交，最后一段留在输入框继续编辑。例如
  `"bug, enhancement,"` 会连续提交 `"bug"` 与 `"enhancement"`；`"bug,enh"`
  只提交 `"bug"`，`"enh"` 留在输入框内。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
@State private var tags: [String] = ["bug", "enhancement"]

TagInput(tags: $tags, placeholder: "Add tag") { committed in
    print("committed: \(committed)")
}
```

## 视觉 Token

- 折行容器：`FlowLayout(spacing: CoreSpacing.xs)`
- chip：`Tag(color: tagColor, removable: true, onRemove:)`
- 输入框字号：`CoreControlMetrics.fontToken(for: .regular)`
- 输入框文字色：`Color.contentPrimary`
- 输入框最小宽度：80pt（避免 `FlowLayout` 压缩到不可用宽度）
- 输入框最小高度：`CoreControlMetrics.height(for: .regular)`

## 无障碍

- 输入框 `.accessibilityLabel(Text(placeholder))`——`placeholder` 为调用方
  任意字符串，走 verbatim 渲染，与 `SearchField.placeholder` 处理方式一致。
- chip 删除按钮的无障碍标签完全来自 `Tag` 内建的 `"Remove tag"`（Phase 0 已
  登记），本组件不重复声明。
