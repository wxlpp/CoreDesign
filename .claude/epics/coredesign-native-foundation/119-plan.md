# Plan: Issue #119 重铸字体 / 圆角 / 尺寸 / 阴影 token

## 范围

只改 `Tokens/` 定义 + 两个连带必须重写的文件 + 测试。不动组件调用点（那是 #121/#122）。

### 1. `Tokens/CoreTypography.swift`（整体重写）

- `Token` 枚举改为 12 个新 case：`largeTitle, title, title2, title3, headline, body, callout,
  subheadline, footnote, caption, captionMono, caption2`，直接映射 `Font.TextStyle`（`caption` /
  `captionMono` 都映射 `.caption`，`captionMono` 额外 `design: .monospaced`）。
- 删除 `Spec` 结构体、`@ScaledMetric` 机制、`fixedFont`、全部 `*LineSpacing` / `*Tracking` 常量。
- 9 个改名旧名以 `@available(*, deprecated, renamed:)` static var 形式挂在 `Token` 上：
  `displayLarge→largeTitle / titleLarge→title / titleMedium→title2 / subtitle→title3 /
  titleSmall→headline / bodyLarge→body / bodyMedium→callout / bodySmall→footnote /
  captionSmall→caption2`。`caption`/`captionMono` 名字不变，无别名。
- 10 个旧 `*Font` static var（`displayLargeFont`…`captionSmallFont`）标 `@available(*, deprecated)`，
  内部改为 `Token.<新名>.font`（新实现会随 Dynamic Type 缩放）——**静默行为变化**，在每个别名注释里
  注明：旧实现固定字号不缩放，本别名现在会缩放；`captionSmallFont` 尤其需要强调（它曾专门为不缩放设计）。
- 头部文档去掉 `Source of truth: docs/PRIMER_VERSION.md`，改写为 Apple 文本样式语义说明。

### 2. `Modifier/CoreFontModifier.swift`（整体重写）

- 删除 `@ScaledMetric` 双字段与 `spec` 消费逻辑。
- `.coreFont(_:)` 调用形态保留，内部直接 `content.font(token.font)`。

### 3. `Tokens/CoreRadius.swift`

- `none 0 / small 6 / medium 10 / large 16` → 新增 `xLarge 22`。
- `smallPlus`(4) / `mediumPlus`(8) 标 `@available(*, deprecated)`，不删除、不改值
  （`Sidebar.swift:157,411` 在用）。
- 新增 `CoreShape` enum：`CoreShape.rounded(_:)` 固定 `style: .continuous`；文档给出
  `ConcentricRectangle()`（iOS 26+）+ `.containerShape(_:)` 的使用约定（本任务只提供出口，不迁移
  组件调用点）。
- 头部去掉 Primer 出处注释。

### 4. `Tokens/CoreControlMetrics.swift`

- `height(for:)`：`mini 28 / small 32 / regular 44 / large 50 / extraLarge 56`。
- `horizontalPadding(for:)` / `verticalPadding(for:)`：按新高度就近调整到 `CoreSpacing.*`
  档位（交付说明列出具体换值，供 #122 复核）。
- `fontToken(for:)` 内部switch 改用新 Token 名（`footnote/callout/body/title2`），避免库内部
  自产生弃用 warning。
- `primerVerticalPadding(for:)` 标 `@available(*, deprecated)`，数值不变（零调用点）。
- 头部去掉 Primer 出处注释。

### 5. `Tokens/CoreElevation.swift`

- 数值维持现状（已是 Craft workbench 调轻后的近平坦值），文档注释里的 Primer 考据替换为
  Apple HIG（material + separator 分层、避免强投影）依据。

### 6. `scripts/downstream-probe`

- `NonisolatedUsage.swift` 的 `useTypographyToken()` 引用了将被删除的
  `CoreTypography.bodyLargeLineSpacing`，改为返回 `CoreTypography.Token`（如
  `useTypographyToken() -> CoreTypography.Token { .body }`），保留"nonisolated 访问
  CoreTypography.Token 不触发 MainActor 隔离"这条覆盖意图。

### 7. 测试

- **前置**：`Tests/CoreDesignTests/` 下新增资源守卫测试（Issue #118 删除
  `BlossomAssetTests` 后仓库无同类机制），用 `FileManager` 扫描 `Resources.xcassets`
  下现存色相 / shadow colorset 目录是否存在，先于本任务的其余改动落地。
- 整体重写 `CoreTypographyTokenTests.swift`：断言 12 档 `textStyle` 映射、`isMonospaced`
  仅 `captionMono` 为真、`allCases.count == 12`、9 个弃用别名解析到映射固定的新档位。
- `DynamicTypeLayoutTests.captionSmallDoesNotScale`（iOS-only suite）**翻转**断言方向并
  更名，注明这是 119 AC 明确要求的故意行为变化。
- 核查后确认 `CoreButtonMetricsTests` / `ButtonStyleDefaultTests` 未被本任务改动面波及
  （两者测试 `CoreButtonMetrics` / 按钮样式默认值，与本任务改的 4 个 token 文件无交集），
  不改写。

## 不在范围内

- 组件调用点迁移（#121）、同名换值复核（#122）、别名删除（#121 之后）。
- `Sidebar.swift` / `Avatar.swift` / App 宿主 17 处：继续使用旧名，靠别名编译通过，不修改。

## 验证

- `swift build`
- `swift test`（基线 75 tests / 21 suites 全绿，前置资源守卫测试另加分）
- `cd scripts/downstream-probe && swift build`
- `grep -n "Font.system(size:" Sources/CoreDesign/Tokens/CoreTypography.swift` → 0 行
- 遇到 `missing inputs` 之类报错先 `rm -rf .build` 再重建

## 换值清单（不产生 warning，交 #122 复核）

- `CoreRadius.medium`：6 → 10（与旧 `small` 的旧值 6 撞车，纯语义层面无关联）。
- `CoreControlMetrics.height(for:)` 全部 5 档：24/28/32/40/48 → 28/32/44/50/56。
- `CoreControlMetrics.horizontalPadding(for:)` / `verticalPadding(for:)`：具体新旧对照见实现后的
  代码注释。


> ⚠️ **基线时效性**：本文档记录的 `.coreFont` 调用点计数（42 处等）是在 **#117 删除 6 个
> GitHub 专用组件之前**测的。那些组件自己消费这些 token，删除后实测为 33 处
> （`caption` 8 / `captionMono` 1）。计数类基线会随并行任务漂移，**迁移完成的判据应是
> deprecation warning 清零，而不是数字对上**。

## 换值清单（交付物，供 Task #122 逐点重审）

以下改动**不产生 deprecation warning、也不产生编译错误**，调用点静默继承新值——
与改名类不同，deprecation 机制发现不了它们。这是 #122 存在的全部理由。

### CoreRadius（三档全部换值，不止 medium）

| token | 旧值 | 新值 | 备注 |
|---|---|---|---|
| `small` | 3 | 6 | **新 `small`(6) 恰等于旧 `medium`(6)**——所有按旧语义选 `small=3` 的调用点圆角直接翻倍 |
| `medium` | 6 | 10 | 按钮 / 输入框默认档 |
| `large` | 12 | 16 | 卡片 / 分组容器 |

> 早先版本的计划文档把这条写成「新 medium 与旧 small 的旧值 6 撞车」——错的，旧 `small` 是 3。
> 撞车的是**新 `small`(6) == 旧 `medium`(6)**，这才是 #122 最需要逐点核的一条。

### CoreControlMetrics.height(for:)

| controlSize | 旧 | 新 |
|---|---|---|
| mini / small / regular / large / extraLarge | 24 / 28 / 32 / 40 / 48 | 28 / 32 / **44** / 50 / 56 |

`.regular` 32 → 44 是 HIG 触控下限的兑现，对所有交互组件的布局有连锁影响。

### CoreControlMetrics padding（旧值在代码里已无处可查，故记于此）

| | mini | small | regular | large | extraLarge |
|---|---|---|---|---|---|
| horizontal 旧 → 新 | 8 → 8 | 12 → 12 | 12 → **16** | 12 → **16** | 12 → **24** |
| vertical 旧 → 新 | 2 → **4** | 4 → 4 | 8 → **12** | 12 → **16** | 16 → 16 |

> 注意 `primerVerticalPadding` 保留的 2/4/6/10/14 是 **Primer 原始值**，不是旧 helper 的
> 实际返回值——不要拿它当旧值对照。

### 地板生效情况（#122 视觉复核时须核对）

`mini` / `small` 由 `frame(minHeight:)` 地板决定实际高度；`regular` 及以上由 padding 决定，
`height(for:)` 退化为不生效的下限。详见 `CoreControlMetrics.verticalPadding` 的文档注释。
