# AvatarGroup

堆叠头像组 / Stacked avatar group.

前 N 个 avatar 交叠显示，超出 `max` 的部分汇总为 "+N" 计数 pill。子视图通过 `Group(subviews:)` 遍历，调用方传入任意 `View` 作 avatar。`max` 在初始化时 clamp 到 `>= 0`。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| max | Int | 3 | 最多直接显示的 avatar 数量；超出走 "+N" pill，负值会被 clamp 到 0。⚠️ `.countOnly` 下不生效 |
| layout | AvatarGroupLayout | .overlapped | 排布形态，见下表。默认 `.overlapped` = 现状形态 ⇒ 现有调用方零影响 |
| avatars | () -> some View | - | `@ViewBuilder`，每个子 View 作为一个 avatar。⚠️ 这是**内容槽**不是外观槽 |

### `AvatarGroupLayout`（`#60` 形态 D2「配置枚举」）

决定「这组头像怎么**排**」，与 `avatars:` 槽（「排什么」）**正交**。

| case | 说明 | 业界来源 |
|---|---|---|
| `.overlapped` | 默认：头像按 `controlSize` 递增的负 offset 交叠（现状形态） | —— |
| `.spaced` | 并排不重叠 + 溢出计数 | Google Docs 协作者栏 / Microsoft Teams 成员条 |
| `.grid` | 网格平铺（列数取 `max` 与内容数的较小值，不出空列） | Slack Huddle 参与者网格 / Google Meet 头像平铺 |
| `.countOnly` | 纯计数徽标：N 个头像塌成 1 个**总数**徽标，不渲染任何头像 | GitHub Contributors 计数 / Linear assignee 计数 |

⚠️ **正交性的代价**（有意的静默，传了不生效**不报错**）：`.countOnly` 不渲染任何头像 ⇒
`max`（「最多显示几个」）无处安放、不生效。存储层原样保留，切回其余形态时不丢配置。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
AvatarGroup {
    Avatar(name: "Evan")
    Avatar(name: "Renovate")
    Avatar(name: "Copilot")
    Avatar(name: "Ada")
    Avatar(name: "Linus")  // 第 5 个：进入 "+2" pill
}

// 自定义 max + 自定义 avatar shape
AvatarGroup(max: 2) {
    Circle().fill(.blue).frame(width: 24, height: 24)
    Circle().fill(.green).frame(width: 24, height: 24)
    Circle().fill(.red).frame(width: 24, height: 24)
}

// 并排不重叠
AvatarGroup(max: 3, layout: .spaced) { avatars }

// 网格平铺（3 列）
AvatarGroup(max: 3, layout: .grid) { avatars }

// 纯计数：读作「一共 N 个」，不渲染头像；max 在此形态下不生效
AvatarGroup(layout: .countOnly) { avatars }
```

## 视觉 Token

- 形状：`Circle`，描边 `Color.systemBackground` / `CoreBorderWidth.thin` 用作 stacking 间隔
- 重叠偏移：`-6` (mini/small) / `-8` (regular) / `-10` (large+)
- 头像尺寸：mini 20 / small 24 / regular 32 / large 40 / extraLarge 48
- "+N" pill：`Color.surfaceCanvasInset` 填充 + `Color.borderMuted` 描边，文字 `.caption2`
- 可访问性：每个 avatar 保留自身可访问性；"+N" 读 `"<N> more avatars"`
  （`AvatarGroupAccessibility.overflowLabel(for:)`）
- `.countOnly` 徽标读 `"<N> avatars"` / `count == 1` 时读 `"1 avatar"`
  （`AvatarGroupAccessibility.totalLabel(for:)`）。⚠️ 与 `+N` 的 `"more avatars"` **语义不同**：
  前者「一共 N 个」、后者「还有 N 个没显示」，误复用会让 VoiceOver 用户以为还有更多被折叠。
  ⚠️ 单数走独立分支而非复数规则表——本仓的本地化资源只有 `.strings`、无 `.stringsdict`，
  真正的复数化随 `wxlpp/oh-my-story#49` 的 A 类文案迁移一并做
