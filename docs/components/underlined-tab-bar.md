# UnderlinedTabBar

下划线分栏组件 / Underlined tab bar.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| items | [Item] | - | tab 数据源，Item 需 Hashable |
| selection | Binding<Item> | - | 受控选中态 |
| title | (Item) -> String | - | 从 Item 抽取展示文字 |
| trailing | () -> Trailing | — | 右侧固定视图（仅 `UnderlinedTabBar(items:selection:title:trailing:)` 需此参数） |

另提供无 trailing 便利 init：`UnderlinedTabBar(items:selection:title:)`（此时 trailing 默认为 `EmptyView`）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `OhMyDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
@State private var selection = "全部"

UnderlinedTabBar(
    items: ["全部", "人物", "地点", "物品"],
    selection: $selection,
    title: { $0 },
    trailing: {
        Button {} label: {
            Image(systemName: "slider.horizontal.3")
        }
        .buttonStyle(.plain)
    }
)
```

## 视觉 Token

- 选中文字：`Color.contentPrimary` + `.semibold`
- 非选中文字：`Color.contentSecondary` + `.regular`
- 字号：`CoreTypography.bodyMediumFont`
- 下划线：`Color.accent`，厚度 `CoreBorderWidth.thick`（2pt），通过 `matchedGeometryEffect` 动画过渡
- 横向间距：`CoreSpacing.xs`（item 间），`CoreSpacing.md`（左右 padding）
- 垂直间距：`CoreSpacing.sm`（文字顶部），`CoreSpacing.xs`（underline 左右）
- 分隔线（trailing 存在时）：`Color.dividerDefault`，宽度 `CoreBorderWidth.hairline`
- 滚动：横向 `ScrollView`，选中项自动 `scrollTo(.center)`

## a11y 的一处已登记盲区

tab 的选中态走 `.accessibilityAddTraits(self.isSelected ? .isSelected : [])`。
⚠️ `#234` 的 a11y 冒烟**证实不了它落进了 AX 树**——用的那个工具（`axe describe-ui`）
的 JSON 没有 traits 字段，实测点了 Tab 2 再 dump，树里除约 1 pt 的宽度变化（Tab 1 63→61.67、Tab 2 64→65.33）外无任何差异。
**两个方向都判不了**：源码只证明声明存在。同形态另有六处，逐条见
`docs/issues/234-a11y-smoke.md`。
