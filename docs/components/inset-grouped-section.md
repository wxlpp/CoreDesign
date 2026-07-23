# InsetGroupedSection

iOS `.insetGrouped` 分组容器的视觉复刻 / Visual replica of iOS's `.insetGrouped` list section.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| header | LocalizedStringKey? | nil | 可选分组页眉（复用 `SectionHeader` 样式） |
| footer | LocalizedStringKey? | nil | 可选分组页脚（复用 `SectionFooter` 样式） |
| dividerInset | SettingsDividerInset | .iconAligned | 相邻行分隔线的 leading 对齐：`.iconAligned`（对齐标题 leading，58pt）/ `.textAligned`（对齐内容 leading）/ `.custom(CGFloat)` |
| content | () -> Content | - | 分组内的行（通常是若干 `SettingsRow`） |

只复刻**观感**，不复刻 `List` 的数据 / 滚动 / 编辑能力（ADR-2）——因此能直接嵌进已有的 `ScrollView` / `VStack`，「在自定义页面里放一两个设置分组」这一最常见用法，`List` 反而做不到。相邻行之间的分隔线由 `Group(subviews:)` 遍历真实渲染的子视图自动插入，数量恒等于「行数 − 1」，无需调用方摆放。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
InsetGroupedSection(header: "General", footer: "Applies to all accounts.") {
    SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: Text("Wi-Fi")) {
        SettingsRowChevron()
    }
    SettingsRow(icon: .init(systemName: "bell.fill", background: .red), title: Text("Notifications")) {
        Toggle("Notifications", isOn: $on).labelsHidden()
    }
}

// 无图标分组：分隔线对齐内容 leading
InsetGroupedSection(header: "About", dividerInset: .textAligned) {
    SettingsRow(title: Text("Version")) {
        Text("0.4.0").foregroundStyle(.secondary)
    }
}
```

## 视觉 Token

- 背景：`Color.surfaceCard`
- 圆角：`CoreShape.rounded(CoreRadius.medium)`（分隔线裁在圆角内，不溢出圆角缺口）
- 分组间距：`CoreSpacing.sm`（header/card/footer 之间）
- 分隔线：`Separator(inset: .leading(dividerInset.value))`，inset 值从 `SettingsRowMetrics` 推导，不由调用方计算
- header / footer 横向内边距：`SettingsRowMetrics.horizontalPadding`
