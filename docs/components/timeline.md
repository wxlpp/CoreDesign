# Timeline

数据驱动的纵向时间线：节点（node）+ 连线（line）+ 节点右侧内容（content）/ Data-driven
vertical timeline: node + connecting line + trailing content.

节点状态色**直接复用 `StatusLevel`**（`info/success/warning/danger`），不新增公开状态语义
枚举；连线颜色复用 `Color.dividerDefault`。承接
`.claude/epics/semi-mobile-components/phase0-decisions.md` §1 的架构决定。

## API

### TimelineItem

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| id | UUID | UUID() | stable identity |
| status | StatusLevel | .info | 节点状态，决定默认圆点颜色（自定义 `node` 时仅作语义标记，不驱动颜色） |
| node | @ViewBuilder（可选） | 默认圆点 | 自定义节点视图（图标 / 头像等），完全替代默认圆点 |
| content | @ViewBuilder | - | 节点右侧内容，任意视图 |

两个 designated init：
- `TimelineItem(id:status:content:)` —— 省略 `node`，使用默认圆点。
- `TimelineItem(id:status:node:content:)` —— 显式传 `node`，自定义节点视图。

### Timeline

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| items | [TimelineItem] | - | 时间线节点数据，按数组顺序纵向排列 |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
// 默认圆点节点
Timeline(items: [
    TimelineItem(status: .info) {
        Text("已创建")
    },
    TimelineItem(status: .success) {
        Text("审核通过")
    },
    TimelineItem(status: .warning) {
        Text("即将过期提醒")
    },
    TimelineItem(status: .danger) {
        Text("处理失败")
    },
])

// 自定义节点（图标替代默认圆点）+ 富内容
Timeline(items: [
    TimelineItem(status: .success) {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.statusSuccessEmphasis)
    } content: {
        VStack(alignment: .leading, spacing: CoreSpacing.xxs) {
            Text("订单已发货")
            Text("2026-07-25 10:00").font(.footnote).foregroundStyle(.secondary)
        }
    },
])
```

> **stable identity 提示**：`TimelineItem.id` 缺省由 `UUID()` 生成。若 `Timeline` 由外部
> 可变状态驱动（增删节点），调用方应显式传入稳定 `id`，否则每次视图刷新重建
> `TimelineItem` 会产生新 identity，引发不必要的插入/删除动画。

## 布局

每行是 `HStack(alignment: .top)`：左侧固定 `24×24pt` 的节点方框（默认圆点或自定义
`node` 均在此方框内居中），右侧 `content`。**自定义 `node` 应 ≤ 24×24pt**——方框不裁剪，
更大的视图（如 32–40pt 头像）会溢出、上沿侵入上一行、下沿被连线穿过；需要更大节点时请自行
缩放到 24pt（`.frame(width:24,height:24)` + `.clipShape(...)`）。连线以 `.background(alignment:)` 挂在整行
`HStack` 之下——`.background` 的内容会被提议整行**已解析出的具体尺寸**，让
`Rectangle().frame(maxHeight: .infinity)` 能正确撑到「本行实际高度」，不受
`VStack`/`ScrollView` 这类按内容 hug 高度的祖先容器影响。最后一条节点不渲染连线（用
`id` 而非位置索引判定，见 `Timeline.isLastItem(_:in:)`）。

## 视觉 Token

- 节点方框：`24×24pt`，默认圆点直径 `10pt`
- 默认圆点颜色：`StatusColors` emphasis 档，按 `StatusLevel` 映射——
  `info → statusAccentEmphasis` / `success → statusSuccessEmphasis` /
  `warning → statusAttentionEmphasis` / `danger → statusDangerEmphasis`
- 连线：`Color.dividerDefault`（= 系统 `separator` 色），`CoreBorderWidth.thin`（1pt）宽度——
  竖向长连线用 1pt 比 separator hairline（0.5pt）观感更实，是对 phase0「连线对齐 separator」
  决策的有意偏离（与 Steps 横向连线同源，指示性连线需强于分隔线；phase0/013 统一记录）
- 行间距：`CoreSpacing.lg`（最后一条不追加）；节点列与 content 横向间距 `CoreSpacing.md`

## Accessibility

- 默认圆点节点携带 `accessibilityLabel`，取 Phase 0 预登记键
  （`.claude/epics/semi-mobile-components/phase0-decisions.md` §2）：
  `StatusLevel.info/success/warning/danger` → `"Info"/"Success"/"Warning"/"Error"`
  （`danger` 播报为 "Error"，比 "Danger" 对 VoiceOver 更清晰），经
  `Timeline.accessibilityLabelKey(for:)` 取键、`Text(LocalizedStringKey(...), bundle:
  .module)` 消费。
- **自定义 `node` 不叠加该 label**——自定义内容可能自带其他语义（例如头像 + 姓名），由
  调用方自行决定 accessibility 表达，本组件不代为覆盖。
- 节点右侧 `content` 的 accessibility 语义完全由调用方内容自身决定（`Timeline` 不对其
  做 `.accessibilityElement(children: .combine)` 合并），保证 content 内若含多个可交互
  元素（如按钮）时 VoiceOver 仍能逐一定位。
