# Sidebar

可组合的侧栏导航组件组 / Composable sidebar navigation component family.

## API

| 类型 | 签名 | 说明 |
|---|---|---|
| `SidebarSection` | `(title:showsChevron:content:)` | 带标题的分组容器，header 含可选 disclosure chevron + 装饰性 overflow glyph |
| `SidebarNavigationRow` | `(systemImage:title:isSelected:action:)` | 主导航行，`isSelected` 时带 floating-glass 选中态背景 |
| `SidebarUtilityRow` | `(systemImage:title:trailingSystemImage:presentation:action:)` | 次级工具行，可选装饰性 trailing 图标；整行单一 `action`。`presentation` 见下节 |
| `SidebarDocumentRow` | `(systemImage:title:detail:action:)` | 文档行，尾部带 `detail`（计数 / 日期等） |
| `SidebarTagRow` | `(title:action:)` | 标签行，`#` 前缀 + 标题 |
| `SidebarStatusFooter` | `(title:detail:statusColor:)` | 非交互页脚，状态点 + 两行文案；`statusColor` 默认 `.statusSuccessForeground` |

所有 row 类型都要求显式传入 `action`。

### 辅助 API

- `View.sidebarSelectedBackground(_ isSelected: Bool)` —— 选中态的 floating-glass
  背景 + selected 色描边 + 阴影 modifier；`SidebarNavigationRow` 内部使用，也
  可在自定义 row 上复用。
- `SidebarTextStyle` —— 语义化文本配色别名（`primary` / `secondary` /
  `tertiary`），映射到 `Color.contentPrimary` / `.contentMuted` /
  `.contentSubtle`，用于自定义 sidebar 内容时与内置 row 保持一致。

### 可访问性

装饰性元素（leading SF Symbol、chevron、ellipsis、tag `#`、status dot）均标记
`.accessibilityHidden(true)`，row 的可访问名由 `title`（及 `detail`）驱动；
`SidebarNavigationRow` 选中态通过 `.accessibilityAddTraits(.isSelected)` 暴露给
辅助技术；`SidebarStatusFooter` 通过 `.accessibilityElement(children: .combine)`
合并为单个可访问元素。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
VStack(alignment: .leading, spacing: CoreSpacing.md) {
    SidebarSection(title: "Core", showsChevron: false) {
        SidebarNavigationRow(systemImage: "calendar", title: "Today", isSelected: true) {}
        SidebarNavigationRow(systemImage: "tray.full", title: "Inbox", isSelected: false) {}
    }

    SidebarSection(title: "Library") {
        SidebarDocumentRow(systemImage: "doc.text", title: "Exam Sprint", detail: "47 days") {}
        SidebarTagRow(title: "Math") {}
    }

    SidebarSection(title: "Tools", showsChevron: false) {
        SidebarUtilityRow(systemImage: "gearshape", title: "Settings") {}
        SidebarUtilityRow(systemImage: "trash", title: "Trash", trailingSystemImage: "arrow.up.right") {}
    }

    SidebarStatusFooter(title: "Synced", detail: "Updated just now")
}
.background(Color.surfaceSidebar)
```

## `SidebarUtilityRowPresentation`（`#64`，公约 §2 形态 D2）

| case | 说明 | 业界来源 |
|---|---|---|
| `.iconLeading` | 默认：leading 字形 + 标题（现状形态） | —— |
| `.textOnly` | 纯文字行，**不渲染 leading 字形、也不占位** | Ant Design Menu 默认无 icon 项 / macOS Finder 下拉菜单项 |

### 候选 2「字形移到行尾」= `.textOnly` + `trailingSystemImage`

没有第三个 case —— 「字形移到 trailing、文字左对齐起首」由**两个既有参数的组合**承载：

```swift
SidebarUtilityRow(
    systemImage: "",                        // ⚠️ .textOnly 下不渲染，见下方「死参数」
    title: "Settings",
    trailingSystemImage: "chevron.forward",
    presentation: .textOnly
) {}
// ⇒ 文字左对齐起首 + 行尾字形
```

⚠️ 行尾那个字形走 `SidebarTextStyle.tertiary`，语义是**装饰性尾图标**而非主字形。这比「把
主字形搬到行尾」**更贴**该候选的具名来源（Fluent 2 的 trailing affordance / iOS 设置二级
页面行首无图标）—— 那两个来源本身就是「无 leading 图标 + 行尾一个装饰性指示」。

⇒ 本组件**不会**在行尾渲染 `systemImage`；需要「主字形位移」语义的场景不在本设计覆盖范围。

### ⚠️ 正交性代价：`.textOnly` 下的死参数

| 参数 | `.iconLeading` | `.textOnly` |
|---|---|---|
| `systemImage`（**必填**） | ✅ 渲染在前 | ❌ **静默不生效**（存储层原样保留，切回不丢配置） |
| `trailingSystemImage`（可选） | ✅ | ✅（候选 2 正是靠它 + `.textOnly`） |

⚠️ 与 `Steps` / `Timeline` / `AvatarGroup` / `SpinningModifier` 四条兄弟有一处**实质差异**：
它们的失效参数都有默认值、调用方**可以不传**；而本组件的 `systemImage` **必填** ⇒ 每个
`.textOnly` 调用点被迫写一个永不渲染的值。

⇒ **约定统一写空串 `""`**。不规定的话各调用点会长出五花八门的死值，将来若要收回该参数
**难以批量识别**。


## 视觉 Token

- 文本配色：`SidebarTextStyle`（`Color.contentPrimary` / `.contentMuted` / `.contentSubtle`）
- 行高：`CoreControlMetrics.height(for: .large)`（≥40pt，`frame(minHeight:)`——长标题换行时 row 撑高，与 `ListRow` / `SearchField` 一致）
- leading icon / glyph 列宽：`CoreControlMetrics.iconSize(for: .large)`（20pt）
- 行内间距：`CoreSpacing.sm`；section header ↔ 内容 `CoreSpacing.sm`，行间 `CoreSpacing.xxs`
- 圆角：`CoreRadius.mediumPlus`（选中态背景 / contentShape）
- 选中态：`floatingGlass(isInteractive: true)` + `Color.borderSelected` 描边（`CoreBorderWidth.thin`）+ `coreShadow(.medium)`
- status footer 圆点：边长 `CoreSpacing.sm`，默认色 `Color.statusSuccessForeground`

## 选中态：刻意不追随原生（#136 / #226 定案）

**本库的侧栏选中态是「浮层玻璃 + 全周选中色描边 + 阴影」，而 iOS / macOS 原生是
「着色填充、无独立轮廓」**（Files / Reminders / Mail）。这是风格决策，不是疏漏。

该差异被独立提出过**两次**，措辞高度一致：

| 来源 | 原话 |
|---|---|
| **#136**（Phase 1 视觉终审 #125） | 「一圈蓝色轮廓环绕整个 pill，读起来更像**聚焦的输入框**而非侧栏选中态」 |
| **#225 视觉终审**（`ios-visual-reviewer`，2026-09） | 「白卡 + 2pt 蓝描边，**读作键盘 focus ring 而非选中态**（iOS 惯例是 tinted fill）」 |

**#226 裁决：保持现状。** 本库侧栏走浮层玻璃语言（与 `floatingGlass` / `BottomInputBar`
一脉），选中态用同族材质内部一致；换原生着色填充会让侧栏与库内其余浮层形态割裂。

⚠️ **成本如实记账**：两个独立评审都读成「聚焦 / focus ring」，说明它与用户既有的平台
直觉冲突——**不是「他们看错了」，而是本库选了一条需要用户重新学习的表达**。若出现第三次
同类反馈、或本库整体向原生收敛，应当**重议**而不是再次援引本条。
