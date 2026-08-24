# Steps

横向 / 纵向排列的步骤条 / Horizontal or vertical step indicator.

支持点状（`.dot`）与数字（`.numbered`）两种指示器样式。进行态（未完成 pending /
当前 current / 完成 done）由 `currentIndex: Int` 在组件内部派生，**不暴露公开的进行态
语义枚举**——调用方只能通过 `currentIndex` 驱动。每一步可选标题（必填）+ 描述文案，
支持标记为错误态。

## API

### `StepItem`

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| title | String | - | 步骤标题，必填 |
| description | String? | nil | 步骤描述，可选 |
| isError | Bool | false | 错误态——`true` 时该节点颜色固定走 danger 映射，忽略进行态 |
| id | UUID | 新建 | 稳定标识，可自定义以在列表更新时保持 diff 稳定 |

### `Steps`

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| items | [StepItem] | - | 步骤列表 |
| currentIndex | Int | - | 当前所在步骤索引（0-based），驱动进行态派生 |
| axis | StepsAxis | .horizontal | 排列方向：`.horizontal` / `.vertical` |
| indicatorStyle | StepsIndicatorStyle | .dot | 指示器样式：`.dot` / `.numbered`。⚠️ **只对 `.steps` 呈现有意义** |
| presentation | StepsPresentation | .steps | 整体呈现形态，见下表。默认 `.steps` = 现状形态 ⇒ 现有调用方零影响 |

### `StepsPresentation`（`#60` 形态 D2「配置枚举」）

决定「这组步骤数据画成什么**结构**」，与 `StepsIndicatorStyle`（「离散指示器长什么样」）
**正交**。

| case | 说明 | 业界来源 |
|---|---|---|
| `.steps` | 默认：离散指示器 + 连线（现状形态） | —— |
| `.segmentedBar` | 分段式进度条：N 个离散位置塌成一条连续条，已完成的段填充 | Ant Design Steps 的 percent 形态 / Google 表单分段进度条 |
| `.navigation` | 导航式步骤条：去掉公共轴线与连线，每一步是彼此直接拼接的块 | Ant Design Steps `type="navigation"` / Shopify Polaris 结账步骤导航 |
| `.text` | 纯文本：N 个指示器槽与标题槽连同连线塌成一个文本槽（如「2 of 4」） | Typeform 的「1 of 5」进度文案 |

⚠️ `.segmentedBar` 依赖调用方给出**确定的宽度提议**：各段是弹性 `Capsule`，放进横向
`ScrollView` 一类不约束宽度的容器时会退化为 SwiftUI Shape 的缺省尺寸。需要在这类容器里
使用时，请显式给一个 `.frame(width:)`。

⚠️ **正交性的代价**（有意的静默，传了不生效**不报错**）：

| 参数 | `.steps` | `.segmentedBar` | `.navigation` | `.text` |
|---|---|---|---|---|
| `axis` | ✅ | ❌ | ✅ | ❌ |
| `indicatorStyle` | ✅ | ❌ | ❌ | ❌ |
| `items` 逐条内容 | ✅ | 仅 `isError` | ✅ | ❌ 只用 `count` |

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
let items = [
    StepItem(title: "Cart", description: "Review items"),
    StepItem(title: "Shipping", description: "Add address"),
    StepItem(title: "Payment", description: "Enter card details"),
    StepItem(title: "Confirm", description: "Review & place order")
]

// 横向，点状指示器，第 2 步（index 1）为当前步
Steps(items: items, currentIndex: 1)

// 纵向，数字指示器
Steps(items: items, currentIndex: 2, axis: .vertical, indicatorStyle: .numbered)

// 错误态——该节点固定走 danger 配色，忽略 currentIndex 派生的进行态
let itemsWithError = [
    StepItem(title: "Cart"),
    StepItem(title: "Shipping"),
    StepItem(title: "Payment", description: "Card declined", isError: true),
    StepItem(title: "Confirm")
]
Steps(items: itemsWithError, currentIndex: 2, indicatorStyle: .numbered)

// 全部完成：currentIndex 传出界值（items.count）
Steps(items: items, currentIndex: items.count)

// 覆盖强调色——完成 / 当前节点走 .tint，不写死 Color.accent
Steps(items: items, currentIndex: 2)
    .tint(.orange)

// 分段式进度条：不画离散指示器，每段对应一步
Steps(items: items, currentIndex: 2, presentation: .segmentedBar)

// 导航式：无轴线无连线，每步一个拼接块；axis 在此形态下仍生效
Steps(items: items, currentIndex: 1, axis: .vertical, presentation: .navigation)

// 纯文本：只消费 items.count 与 currentIndex，逐条标题不渲染
Steps(items: items, currentIndex: 1, presentation: .text)   // 「2 of 4」

// 导航式同样响应 .tint —— 当前块底色走 .tint，不写死 Color.accentColor
Steps(items: items, currentIndex: 1, presentation: .navigation)
    .tint(.orange)
```

## 进行态派生

进行态由 `currentIndex` 在组件内部按下述规则派生（`index` 为该步骤 0-based 索引）：

- `index < currentIndex` → **done**（完成）
- `index == currentIndex` → **current**（当前）
- `index > currentIndex` → **pending**（未完成）

`currentIndex` 可以传出界值（如 `items.count`）表示「全部完成」；**存储层不做 clamp**。该派生逻辑
是组件内部实现细节，**不对外暴露成公开枚举**——下游只能通过 `currentIndex: Int` 驱动，
无法读取内部进行态类型本身。

### `.segmentedBar` 的段与文案表达两件事

段填充判据是 `index < currentIndex`（**已完成**几步），caption 与无障碍文案是
`currentIndex + 1`（**当前在**第几步）。`currentIndex == 2, count == 4` ⇒ 2 段填充 + 读
「3 of 4」：已完成 2 步、正在第 3 步，二者同时为真。文案不跟着填充数走，是为了与
`.steps` / `.navigation` 逐步播报的「2 of 4」逐字一致 —— 同一组数据换 `presentation`，
VoiceOver 读法不该变。

### `.text` 的已知信息损失

因为显示序号被夹进 `1...count`，`.text` 下「停在最后一步」（`currentIndex == count - 1`）
与「全部完成」（`currentIndex == count`）产出**同一段文案**，不可区分。这是「N 个槽塌成
1 个文本槽」的固有代价。需要区分这两个状态请改用 `.segmentedBar`（末段填充与否可见）或
`.steps`。

⚠️ `.segmentedBar` / `.text` 的**显示序号**是唯一例外：它经
`Steps.progressSummary(currentIndex:total:)` 夹进 `1...items.count` 再显示——否则负索引
会读成「-3 of 3」，而 `Int.max` 上的 `currentIndex + 1` 会直接 trap。夹的只是**显示值**，
`progress(for:)` 的派生口径不变。空 `items` 退化为「0 of 0」。

## 视觉 Token

- 完成态 / 当前态指示器强调色：`.tint`（`TintShapeStyle`，响应环境 `.tint(_:)`，
  未显式设置时解析为宿主 App 的 `Color.accentColor`）
- 错误态（`StepItem.isError == true`）：**忽略**进行态，固定走
  `StatusColors`（`Color.statusDangerEmphasis` 填充 / `Color.contentOnDanger` 前景 /
  `Color.statusDangerForeground` 标题文字），对应 `StatusLevel.danger` 映射
- 未完成态：`Color.dividerDefault` 描边（空心圆）、`Color.contentTertiary` 文字
- 连线（横向 / 纵向）：`Color.dividerDefault`（`BorderColors`，系统 `separator`）；
  已完成的连线段走 `.tint`
- 指示器直径：点状 12pt，数字 28pt
- 标题字号：`.subheadline`；描述字号：`.footnote` / `Color.contentSecondary`

## Accessibility

- 指示器行本身对 VoiceOver 隐藏（`.accessibilityHidden(true)`）——图形化的圆点 /
  数字 / checkmark 属视觉冗余，进行态已经由文字行的 `accessibilityValue` 表达
- 每一步的文字行是一个独立 accessibility element：
  - `accessibilityLabel`：`title`，若有非空 `description` 则拼接为
    `"<title>: <description>"`（`Steps.accessibilityLabelText(title:description:)`）
  - `accessibilityValue`：当前步骤（`index == currentIndex`）用 Phase 0 预登记的位置键
    `"%@ of %@"`，经
    `String(localized: "\(current.formatted()) of \(total.formatted())", bundle:
    .module)` 组装（`Steps.positionText(current:total:)`），1-based 播报，如「2 of 4」；
    错误态额外播报已登记键 `"Error"`；当前步骤同时是错误态时以 `", "` 拼接两者；
    均不成立时不挂载 `accessibilityValue`
- **`.segmentedBar` / `.text` 塌成单个 element**（`.accessibilityElement(children: .ignore)`）：
  `accessibilityLabel` 为进度文案（同上位置键 `"%@ of %@"`，与逐步 `accessibilityValue`
  **逐字一致**）；`items` 中存在任一 `isError` 步骤时，容器级 `accessibilityValue` 播报
  同一个已登记键 `"Error"`（`Steps.collapsedValueText(hasError:)`）——塌陷不该让错误态
  对读屏用户消失，而红色段 / 纯文本摘要在视觉上仍看得出出错
- `.navigation` 与 `.steps` 共用逐步的 `applyStepAccessibility(_:index:)`，读法完全一致
