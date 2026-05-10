# UnderlinedTabBar

下划线分栏组件 / Underlined tab bar.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| items | [Item] | - | tab 数据源，Item 需 Hashable |
| selection | Binding\<Item\> | - | 受控选中态 |
| title | (Item) -> String | - | 从 Item 抽取展示文字 |
| trailing | () -> Trailing | — | 右侧固定视图（仅 `UnderlinedTabBar(items:selection:title:trailing:)` 需此参数） |

另提供无 trailing 便利 init：`UnderlinedTabBar(items:selection:title:)`（此时 trailing 默认为 `EmptyView`）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

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
