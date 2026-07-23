# SectionHeader / SectionFooter

iOS 分组列表的页眉页脚 / iOS grouped-list section header and footer.

## API

### SectionHeader

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| titleKey / title | LocalizedStringKey / StringProtocol | - | 标题文本，提供两个 init：字面量走 `Bundle.main` 本地化，运行期字符串 verbatim 显示 |

### SectionFooter

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| textKey / text | LocalizedStringKey / StringProtocol | - | 说明文本，同样提供本地化 / verbatim 两个 init |

两者都只负责**文本样式**，不带分组外边距——外边距由承载它们的 `InsetGroupedSection` 提供。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
SectionHeader("General")   // 渲染为 "GENERAL"，footnote 灰
SectionFooter("Turning this off stops all notifications from this app.")
```

## 视觉 Token

- 字号：`.coreFont(.footnote)`（Dynamic Type text style，非固定 pt）
- 颜色：`Color.contentSecondary`
- `SectionHeader` 额外 `.textCase(.uppercase)`（复刻 iOS `.insetGrouped` 惯例）+ `.accessibilityAddTraits(.isHeader)`（供 VoiceOver heading rotor 跳节）；`SectionFooter` 不大写、不带 heading trait
- 布局：`frame(maxWidth: .infinity, alignment: .leading)`
