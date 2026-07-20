# 按钮体系 + Sidebar 收敛 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除四个 ButtonStyle 与 `Sidebar` 四种 row 的结构性重复，并为 #95 的 Dynamic Type 改造把 font 调用点收敛到单一位置。

**Architecture:** 纯重构，**观感零回归**是硬指标（两处例外已在下方列明并需用户确认）。收敛分两条独立主线：按钮侧建立 `resolvedColor` + 共享 chrome modifier + 合并的 background modifier；Sidebar 侧抽出 `SidebarRow` 骨架，四个 public row 退化为薄封装。

**Tech Stack:** SwiftPM / Swift 6 / SwiftUI，验证靠四条 SwiftPM 命令 + `#Preview` 视觉冒烟。

## Global Constraints

- **不做** `CoreControlMetrics.font(for:)` → `fontToken(for:)` 的签名改造（那是 #95）。本任务只把散落的 font 调用**收敛到单一调用点**为 #95 让路。若发现某处非改签名不能编译，**停下记录，不要越界**。
- **四个 ButtonStyle 保持 `ButtonStyle` + `static func *Button(role:)` 形态，不协议化**（PRD FR-4 硬约束）。
- **不得触碰 #97 的自有文件**（005 ∩ 006 = ∅ 必须保持）：`EmptyState.swift`、`View+SizeReader.swift`、`KeyboardHandling.swift`、`BottomInputBar.swift`、`CommentCard.swift`、`RefPill.swift`、`SegmentedControl.swift`、`TimelineItem.swift`、`BookCover.swift`、`CoreGradient.swift`、`BorderModifier.swift`。收尾用 `git diff --name-only` 自查。
- 四条 SwiftPM 命令绿且不新增 warning。**最终 warning 采集前必须 `swift package clean`**——逐 Task 的增量编译会焐热 `.build`，热构建不重放诊断（#94 的教训）。
- 公开 API 表面无回退：改动涉及的类型 / init / 属性该 `public` 的仍 `public`。
- 代码风格：显式 `self.`、中英双语注释、`// MARK: -`、`Modifier/` 下以 `View` 扩展暴露。

## 已实测的前置事实（不要重新推导）

| 事实 | 影响 |
|---|---|
| 基线绿：`swift build` EXIT=0、`swift test` 95 tests / 32 suites passed | 起点干净 |
| `Sidebar.swift` 391 行，四 row 声明在 `:91 :144 :202 :257`，`CoreTypography.` 引用 **16 处** | AC 已修订为「四个 row 的 body 内 11 → ≤8 处」（96.md:35，经用户确认；原写「文件级 16 → 约 6」不可达） |
| 三处三态取色逻辑逐字相同：`SolidButtonStyle.backgroundColor(isPressed:)`、`LightButtonStyle.textColor(isPressed:)`、`CoreBorderlessButtonStyle.textColor` | B3a 可直接抽取 |
| `CoreControlMetrics.height` 序列 = 24/28/32/40/48（mini→extraLarge） | B3e 的 38 不在序列内，`.large` = 40 最接近 |
| `TelegramGlassButtonModifier` 是 `public`、泛型 `<S: InsettableShape>`，硬编码白色描边 + `pressedScale` + 动画 | B8a 的复用不是 drop-in，见下 |
| `CoreButtonMetrics.glassInset = 2` 与 `CoreSpacing.xxs = 2` **等值** | B8a 复用玻璃 modifier 无内缩差异 |
| `SidebarSelectedBackgroundModifier` 在 `isSelected == false` 时返回裸 `content` | 骨架可无条件调用 `sidebarSelectedBackground(_:)`，对三个非选中 row 是真 no-op |
| `.circularGlass` 的 4 个调用点**全都没设 `controlSize`** | B3e 的默认档是 `.regular`(32) 而非 `.large`(40)，见《判断 1》 |

## 两处必须先定的设计判断（96.md 未预见）

### 判断 1：B3e 会让浮按钮从 38 缩到 **32**（不是 40），且牵动 #97 的文件

`CircularGlassButtonStyle.diameter` 默认 38，而 `CoreControlMetrics.height` 序列是 24/28/32/40/48——**38 不在序列内**，这正是 B3e 判定它为缺陷的理由。

**但「接入 controlSize 后取 `.large` = 40」是错的。** 实测四个调用点：

```
Components/Button/AsyncButton.swift:223        .buttonStyle(.circularGlass)
Components/BottomInputBar/BottomInputBar.swift:153,165,177   .buttonStyle(.circularGlass)
App/Sources/Previews.swift:312                 .buttonStyle(.circularGlass)
```

**没有一处设置 `.controlSize`**，所以读到的是 SwiftUI 的环境默认值 `.regular` → `height(for: .regular)` = **32pt**。即天真实施会让 send / stop / shuffle 三个浮按钮从 38 缩到 32（−6pt，约 16%），这是明显的视觉回归，不是「2pt 对齐」。

更麻烦的是：其中三处在 `BottomInputBar.swift`，那是 **#97 的自有文件**，本任务按并行硬约束不得触碰——所以「在调用点补 `.controlSize(.large)`」这条最自然的解法需要先与 #97 协调。

**三个方案，评审后选定方案 C：**

**方案 A（弃用）**——`nil` 时忽略环境的 `.regular` 而按 `.large` 解释。问题：`.controlSize(.regular)` **不只是"未设置时的默认值"，也是一个合法的显式取值**。下游（本库是对外分发的设计系统）刻意写 `.controlSize(.regular)` 期待 32pt 时会静默得到 40pt，且无任何诊断。这不是"临时的反直觉"，是**永久的公开 API 陷阱**——用一个长期的语义地雷去换 epic 内部的排期便利，代价不成比例。

**方案 B（弃用）**——老实读 `controlSize`，同时给四个调用点补 `.controlSize(.large)`。语义干净，但三处在 `BottomInputBar.swift`（#97 自有文件），需破坏 005 ∩ 006 = ∅ 这条经矩阵验算的并行前提。

**方案 C（采纳）——把档位意图存在 style 自身，而非从环境反推：**

```swift
/// 尺寸档位 / Size tier：浮按钮语义上是 large 档控件。
public var size: ControlSize = .large
/// 显式直径覆写 / Explicit diameter override。
public var diameter: CGFloat?

private var resolvedDiameter: CGFloat {
    self.diameter ?? CoreControlMetrics.height(for: self.size)
}
```

默认 40（落在 metrics 序列内，B3e 达成）、四个调用点一行不改、无 `.regular` 特例、无公开 API 意外。唯一代价：B3e 字面写的是「接入 `@Environment(\.controlSize)`」，方案 C 是**存显式档位**而非读环境——满足其**意图**（"不再写死 38、尺寸来自 metrics 序列"）而非字面。这比为了字面达标而植入语义地雷划算得多。

**一处意外佐证**：`CoreMenuButton.swift:121-123` 的 `controlSize` 注释写着「匹配 `ControlSize.large`（40pt），**与输入栏 trailing 圆形按钮保持视觉等高**」并取 40——而那个圆形按钮实际是 38。也就是说 38 与既有意图**本来就是错位的**，改成 40 恰好把这处不一致修好。

若日后确需跟随环境 `controlSize`，那是一次干净的独立改动（连同调用点一起补 `.controlSize(.large)`），届时 `BottomInputBar.swift` 的归属也已释放。**此取舍须写进 `updates/96/progress.md` 供 #95/#101 接手。**

`public var diameter` / `public init` **保留**为显式覆写通道，只是 `diameter` 类型变为 `CGFloat?` 并新增 `size` 参数。既满足 B3e 又不删公开 API。

### 判断 2：B8a 的「复用 `TelegramGlassButtonModifier`」不是 drop-in，两者视觉本就不同

实测对比 `CoreMenuButtonStyleModifier`（`CoreMenuButton.swift:84-118`）与 `TelegramGlassButtonModifier`（`:47-63`）：

| | TelegramGlass | CoreMenuButtonStyleModifier |
|---|---|---|
| 背景内缩 | `.inset(by: CoreButtonMetrics.glassInset)` | `.padding(CoreSpacing.xxs)` |
| 描边 | `.white.opacity(glassBorderOpacity)` | `Color.borderSubtle` |
| 按压反馈 | `scaleEffect` + `.snappy` 动画 | **无** |

直接换成 `TelegramGlassButtonModifier` 会让菜单按钮的描边从语义色变成半透明白、并凭空多出按压缩放——**那是视觉回归，不是重复消除**。

处置：把 `TelegramGlassButtonModifier` **参数化**，新增两个带默认值的参数，保持现有 **3** 个调用点（`SolidButtonStyle` / `LightButtonStyle` / `CircularGlassButtonStyle`）行为逐字不变：

```swift
public init(
    shape: S,
    isPressed: Bool,
    border: Color? = nil,          // nil = 现有的半透明白
    pressFeedback: Bool = true     // false = 不加 scaleEffect / 动画
)
```

`CoreMenuButtonStyleModifier` 则改为消除**自身两分支**的重复（`labeled` 用 `Capsule`、`circular` 用 `Circle`，其余结构相同——泛型化 shape 即可），并复用参数化后的 `TelegramGlassButtonModifier(border: .borderSubtle, pressFeedback: false)`。B8a 的两个要求（消除自身两分支重复 + 不再平行实现）都达成，且观感零变化。

**若实施中发现参数化让 `TelegramGlassButtonModifier` 的既有 3 个调用点行为漂移，立即停下**——那说明默认值取错了，不要将错就错。

---

### Task 1: `ButtonRoleStyleRole.resolvedColor` 收敛三态取色（B3a）

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift`
- Modify: `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`
- Modify: `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`
- Modify: `Sources/CoreDesign/Components/Button/styles/CoreBorderlessButtonStyle.swift`

**Interfaces:**
- Produces: `public func resolvedColor(isEnabled: Bool, isPressed: Bool) -> Color`
- 删除：三个 style 内的 `backgroundColor(isPressed:)` / `textColor(isPressed:)` / `textColor`

- [ ] **Step 1: 在 `ButtonRoleStyleRole` 末尾（`disabledColor` 之后）加 `resolvedColor`**

```swift
    /// 按交互状态解析出最终颜色 / Resolve the color for a given interaction state.
    ///
    /// 三态优先级：disabled > pressed > normal。此前 `SolidButtonStyle`、
    /// `LightButtonStyle`、`CoreBorderlessButtonStyle` 各自持有一份逐字相同的
    /// 实现（审计项 B3a），现收敛到本枚举——它本就是三个调色板属性的唯一来源。
    ///
    /// - Parameters:
    ///   - isEnabled: 通常来自 `@Environment(\.isEnabled)`。
    ///   - isPressed: 通常来自 `ButtonStyle.Configuration.isPressed`。
    public func resolvedColor(isEnabled: Bool, isPressed: Bool) -> Color {
        if !isEnabled {
            return self.disabledColor
        }
        return isPressed ? self.activeColor : self.color
    }
```

注意：本方法**不**用 `self.` 访问参数（它们是参数不是成员），但访问 `disabledColor` / `activeColor` / `color` 时用 `self.`，与仓库风格一致。

- [ ] **Step 2: 三个 style 改为调用它**

`SolidButtonStyle.swift`——删除 `private func backgroundColor(isPressed:)` 整个方法，把 `makeBody` 开头的

```swift
        let backgroundColor = self.backgroundColor(isPressed: isPressed)
```
改为
```swift
        let backgroundColor = self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed)
```

`LightButtonStyle.swift`——删除 `private func textColor(isPressed:)`，两处 `self.textColor(isPressed: isPressed)` 改为
```swift
self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed)
```
（`makeBody` 里出现两次，glass / 非 glass 各一。Task 4 会把这两支合并，届时只剩一处。）

`CoreBorderlessButtonStyle.swift`——删除 `private var textColor: Color` 计算属性，`makeBody` 里的 `self.textColor` 改为
```swift
self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: self.isPressed)
```
注意此处 `isPressed` 是 `@GestureState` 成员而非 `configuration.isPressed`，要用 `self.isPressed`。

- [ ] **Step 3: 验证三态取色逻辑确实只剩一份**

```bash
grep -rn 'disabledColor' Sources/CoreDesign/Components/Button/ \
  | grep -v 'ButtonRoleStyleRole.swift' | grep -v '///'
```
Expected: 无输出（三个 style 都不再直接读 `disabledColor`）。

**必须滤掉 `///`**：`CoreBorderlessButtonStyle.swift:33` 的 doc 注释里有「颜色完全由 `role.color` / `role.activeColor` / `role.disabledColor` 决定」——那句描述改造后依然成立，**不要去改它**。不滤会让本关卡假红，执行者最可能的反应就是去动那段正确的文档。

Run: `swift build --build-tests`
Expected: EXIT=0

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Components/Button/
git commit -m "refactor: 三态取色逻辑收敛进 ButtonRoleStyleRole.resolvedColor（B3a）"
```

---

### Task 2: 共享 chrome modifier（B3d）

**Files:**
- Create: `Sources/CoreDesign/Modifier/ButtonChromeModifier.swift`
- Modify: 四个 ButtonStyle

**Interfaces:**
- Produces: `View.buttonChrome<S: Shape>(shape:controlSize:) -> some View`

> **B3d 的前提陈述对 `CoreBorderlessButtonStyle` 不成立。** 96.md:29 写「font / padding / contentShape 四行……共出现 5 次」且逐字相同——但实测该类型的 `makeBody` **只有两行 padding**，既没有 `font` 也没有 `contentShape`（96.md 引的 `:43-46` 坐标还落在 doc 注释里）。本任务按 B3d 的**意图**（统一 chrome）执行，代价是给它引入两处受控行为变化（字号、命中区，见下方警告）。**在此显式声明，避免后续审计对账时把这两处变化误判成实现越界。**

**这是为 #95 让路的关键一步**——收敛后按钮体系内的四处 `CoreControlMetrics.font(for:)`（Solid ×2、Light ×2；`CoreBorderlessButtonStyle` 本来就没有）合并为**一处**，#95 把它换成 `fontToken(for:)` + `.coreFont()` 时只需改一行而非四行。注意 `SearchField.swift:98` 是按钮体系之外的独立调用点，不在本任务范围，#95 需单独处理。

- [ ] **Step 1: 新建 `ButtonChromeModifier.swift`**

```swift
//
//  ButtonChromeModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ButtonChromeModifier

/// 按钮的通用 chrome / Shared button chrome：字号 + 内边距 + 命中区域。
///
/// 这四行原本在 `SolidButtonStyle`（glass / 非 glass 各一）、`LightButtonStyle`
/// （同样各一）、`CoreBorderlessButtonStyle` 中共出现 5 次且逐字相同（审计项 B3d）。
///
/// > 收敛的另一重意义：`CoreControlMetrics.font(for:)` 的调用点从 5 处降到 1 处。
/// > Issue #95 要把它改成 `fontToken(for:)` + `.coreFont()` 以恢复 Dynamic Type，
/// > 届时只需改本文件一行。**不要把 font 调用重新散回各 style。**
private struct ButtonChromeModifier<S: Shape>: ViewModifier {
    let shape: S
    let controlSize: ControlSize

    func body(content: Content) -> some View {
        content
            .font(CoreControlMetrics.font(for: self.controlSize))
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .contentShape(self.shape)
    }
}

// MARK: - View extension

extension View {
    /// 套用按钮通用 chrome（字号 / 内边距 / 命中区域）。
    ///
    /// **有意保持 internal**：这是四个 style 的内部收敛产物，四者都在包内。
    /// 一次纯重构不应顺手对外承诺一个未经设计评审的 modifier——尤其它的
    /// `controlSize` 走显式传参，与仓库其它 modifier 从环境读取的习惯不同。
    /// 若日后要公开，走独立的 API 设计评审。
    ///
    /// - Parameters:
    ///   - shape: 命中区域形状（胶囊、圆形等）。
    ///   - controlSize: 尺寸档，通常来自 `@Environment(\.controlSize)`。
    func buttonChrome(shape: some Shape, controlSize: ControlSize) -> some View {
        self.modifier(ButtonChromeModifier(shape: shape, controlSize: controlSize))
    }
}
```

- [ ] **Step 2: 五个调用点改用它**

`SolidButtonStyle` 的两支、`LightButtonStyle` 的两支，各把这四行

```swift
                .font(CoreControlMetrics.font(for: self.controlSize))
                .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
                .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
                .contentShape(Capsule(style: .continuous))
```
替换为（**`foregroundStyle` 会移到 `buttonChrome` 之后**——这四行在源码里并不连续，`font` 与两个 `padding` 之间隔着 `foregroundStyle`，收敛必然要移动它。顺序变化是惰性的：font / foregroundStyle / padding / contentShape 互不消费对方的效果）
```swift
                .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
```

`CoreBorderlessButtonStyle` 的 `makeBody`——它的顺序略有不同（`padding` ×2 → `foregroundStyle` → `clipShape`），且**没有** `contentShape` 而是 `clipShape`。把两行 padding 换成 `buttonChrome`，但 `clipShape(Capsule)` 保留在原位：

```swift
        configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: self.isPressed))
            .clipShape(Capsule(style: .continuous))
            .animation(.easeInOut, value: self.isPressed)
            .simultaneousGesture(self.pressedStateGesture)
            .onTapGesture(count: 1, perform: configuration.trigger)
```

> ⚠️ **`CoreBorderlessButtonStyle` 会有两处行为变化，都要实看：**
>
> 1. **字号**——它原本没有 `.font(...)`，靠继承环境字体。套用 `buttonChrome` 后字号变为随 `controlSize`。这是 B3d 期望的统一（"四行在 4 个 style 里共出现 5 次"的口径就包含它）。
> 2. **命中区域**——它原本也没有 `.contentShape(...)`，`buttonChrome` 会加上 `Capsule`。而它是 `PrimitiveButtonStyle`，`.simultaneousGesture` / `.onTapGesture` 挂在更外层，所以命中区从「带 padding 的矩形」变成「胶囊」。**这是交互变化，不只是排版变化**，边角处的点击可能不再命中。
>
> 另：该类型的 doc 注释（`CoreBorderlessButtonStyle.swift:28-29`）明写「padding 仍按 `CoreControlMetrics` 走 token」——言下之意 padding 走 token 而字号有意不走。本改动与已发布文档相悖，**须在本 Step 一并更新那段注释**。
>
> **实施时用 `#Preview` 实看字号与点击区域**；若与周围文字明显脱节、或边角点击失灵，停下记录，不要闷头改。

- [ ] **Step 3: 验证 font 调用点收敛**

```bash
grep -rn 'CoreControlMetrics.font(for:' Sources/CoreDesign/Components/Button/
```
Expected: **恰好 0 行**——四个 style 内已无直接调用，唯一调用点移到了 `Modifier/ButtonChromeModifier.swift`。

**必须限定在 `Components/Button/` 下**。全库扫会得到 3 行而非 1 行，其中两行不属本任务范围：

```
Components/SearchField/SearchField.swift:98   ← 非按钮体系，本任务不碰
Tokens/CoreControlMetrics.swift:25            ← doc 注释里的用法示例
```

若照全库口径写「恰好 1 行」，执行者面对失败断言极可能去改 `SearchField.swift`——那是无人认领的越界改动。

Run: `swift build --build-tests`
Expected: EXIT=0

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Modifier/ButtonChromeModifier.swift Sources/CoreDesign/Components/Button/
git commit -m "refactor: 按钮 font/padding/contentShape 收敛为共享 buttonChrome modifier（B3d）"
```

---

### Task 3: 合并两个 background modifier（B3c）

**Files:**
- Create: `Sources/CoreDesign/Modifier/ButtonBackgroundModifier.swift`
- Modify: `SolidButtonStyle.swift`（删除 `SolidButtonBackgroundModifier`）、`LightButtonStyle.swift`（删除 `LightButtonBackgroundModifier`）

**逐字段差异（实测）：**

| | Solid | Light |
|---|---|---|
| `fill` | `backgroundColor`（role 三态） | `Color.surfaceInteractive` |
| `strokeBorder` | `Color.borderMuted` | `Color.borderSubtle` |
| `scaleEffect` | `pressedScale` | `pressedScale` |
| `opacity` | **`0.92`（在 modifier 内）** | 无（Light 在 modifier **外**统一 `.opacity(0.9)`） |
| `animation` | `.snappy(0.16)` | `.snappy(0.16)` |

**`opacity` 的位置差异是陷阱**：Solid 的 0.92 在 modifier 内、只作用于非 glass 分支；Light 的 0.9 在 modifier 外、glass / 非 glass 两支都有。合并时若把 opacity 一律收进 modifier，Light 的 glass 分支会**丢掉**按压变暗。

- [ ] **Step 1: 新建 `ButtonBackgroundModifier.swift`**

```swift
//
//  ButtonBackgroundModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ButtonBackgroundModifier

/// 非 glass 按钮的背景层 / Non-glass button background：填充 + 描边 + 按压反馈。
///
/// 合并自原先的 `SolidButtonBackgroundModifier` 与 `LightButtonBackgroundModifier`
/// （审计项 B3c）——两者结构完全相同，仅填充色、描边 token 与按压不透明度不同。
///
/// > `pressedOpacity` 默认 `nil`（不施加）：`LightButtonStyle` 的按压变暗写在
/// > 本 modifier **之外**，因为它的 glass 分支同样需要；`SolidButtonStyle` 则只在
/// > 非 glass 分支变暗，故由本参数承担。合并时保持这一位置差异，否则 Light 的
/// > glass 分支会丢掉按压反馈。
private struct ButtonBackgroundModifier: ViewModifier {
    let fill: Color
    let border: Color
    let isPressed: Bool
    var pressedOpacity: Double? = nil

    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(self.fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(self.border, lineWidth: CoreBorderWidth.hairline)
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .opacity(self.isPressed ? (self.pressedOpacity ?? 1) : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}

// MARK: - View extension

extension View {
    /// 套用非 glass 按钮的背景层（填充 / 描边 / 按压反馈）。
    ///
    /// - Parameter pressedOpacity: 按压时的不透明度；`nil` 表示不施加
    ///   （`LightButtonStyle` 的按压变暗写在本 modifier 之外，因为它的 glass
    ///   分支同样需要）。
    func buttonBackground(
        fill: Color,
        border: Color,
        isPressed: Bool,
        pressedOpacity: Double? = nil
    ) -> some View {
        self.modifier(ButtonBackgroundModifier(
            fill: fill,
            border: border,
            isPressed: isPressed,
            pressedOpacity: pressedOpacity
        ))
    }
}
```

以 `View` 扩展暴露而非让调用方写 `.modifier(...)`——这是 CLAUDE.md 的 `Modifier/` 约定，Task 2 的 `buttonChrome` 已遵循，此处保持一致。

- [ ] **Step 2: 两个 style 改用它，删除各自的私有 modifier**

`SolidButtonStyle` 非 glass 分支：
```swift
                .buttonBackground(
                    fill: backgroundColor,
                    border: Color.borderMuted,
                    isPressed: isPressed,
                    pressedOpacity: 0.92
                )
```

`LightButtonStyle` 非 glass 分支（**不传 `pressedOpacity`**，它的 `.opacity(isPressed ? 0.9 : 1)` 留在 modifier 之外）：
```swift
                .buttonBackground(
                    fill: Color.surfaceInteractive,
                    border: Color.borderSubtle,
                    isPressed: isPressed
                )
```

删除两个文件末尾的 `private struct SolidButtonBackgroundModifier` / `private struct LightButtonBackgroundModifier` 及其 `// MARK: -` 标题。

- [ ] **Step 3: 验证**

```bash
grep -rn 'SolidButtonBackgroundModifier\|LightButtonBackgroundModifier' Sources/ ; echo "rc=$?"
```
Expected: `rc=1`，无匹配。

Run: `swift build --build-tests`
Expected: EXIT=0

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Modifier/ButtonBackgroundModifier.swift Sources/CoreDesign/Components/Button/styles/
git commit -m "refactor: 合并 Solid/Light 的 background modifier 为单一类型（B3c）"
```

---

### Task 4: 收敛 glass / 非 glass 分支（B3b）

**Files:**
- Modify: `SolidButtonStyle.swift`、`LightButtonStyle.swift`

经过 Task 1–3，两个 style 的 `makeBody` 两支只剩「共同前缀 + 尾部 modifier 不同」。用 `@ViewBuilder` 把差异部分收窄到尾部。

- [ ] **Step 1: `SolidButtonStyle.makeBody` 重写**

前景色差异（glass 用 `Color.white`，非 glass 用 `Color.contentOnAccent`）先抽成计算属性：

```swift
    private var foregroundColor: Color {
        guard self.isEnabled else { return .contentDisabled }
        return self.glass ? .white : .contentOnAccent
    }
```

`makeBody` 改为「共同结构写一次 + 两支各剩尾部差异」：

```swift
    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let backgroundColor = self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed)

        let base = configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.foregroundColor)

        if self.glass {
            base
                .backgroundStyle(backgroundColor)
                .modifier(TelegramGlassButtonModifier(
                    shape: Capsule(style: .continuous),
                    isPressed: isPressed
                ))
        } else {
            base
                .buttonBackground(
                    fill: backgroundColor,
                    border: Color.borderMuted,
                    isPressed: isPressed,
                    pressedOpacity: 0.92
                )
        }
    }
```

`.backgroundStyle(backgroundColor)` **留在 glass 分支内**（原实现就只有 glass 分支有它），不要提到 `base` 里——那会给非 glass 路径多设一次 backgroundStyle。

B3b 的验收口径是「共同结构只写一次」——`base` 就是共同结构，两支各剩 1–2 行。保留 `if/else` 而非强行消除它：两支返回的是不同 `ViewModifier` 类型，硬合并要么引入 `AnyViewModifier` 类型擦除、要么破坏 SwiftUI 惯用法，得不偿失。原实现本就在同一位置分支，`_ConditionalContent` 的结构性 identity 不变。

- [ ] **Step 2: `LightButtonStyle.makeBody` 同型重写**

```swift
    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        let base = configuration.label
            .buttonChrome(shape: Capsule(style: .continuous), controlSize: self.controlSize)
            .foregroundStyle(self.role.resolvedColor(isEnabled: self.isEnabled, isPressed: isPressed))

        Group {
            if self.glass {
                base
                    .backgroundStyle(Color.surfaceInteractive)
                    .modifier(TelegramGlassButtonModifier(shape: Capsule(style: .continuous), isPressed: isPressed))
            } else {
                base
                    .buttonBackground(fill: .surfaceInteractive, border: .borderSubtle, isPressed: isPressed)
            }
        }
        .opacity(isPressed ? 0.9 : 1)
    }
```

`Group { }.opacity(...)` 让 Light 的按压变暗只写一次而非两次——这正是 Task 3 特意把 `pressedOpacity` 留空的原因。

- [ ] **Step 3: 视觉冒烟 + 编译 + 测试**

```bash
swift build --build-tests > /tmp/t4b.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t4t.log 2>&1; echo "test  EXIT=$?"
swift build --traits Blossom > /tmp/t4bb.log 2>&1; echo "blossom EXIT=$?"
```
Expected: 三条 EXIT=0，测试 95 tests passed。

**中途就跑 `swift test` 与 Blossom 构建**，不要攒到 Task 8——那是七个 commit 之后，届时若红了很难定位是哪一步引入的。

在 Xcode 里打开 `SolidButtonStyle.swift` / `LightButtonStyle.swift` 的 `#Preview`，light + dark 各看一遍，重点核对：glass 与非 glass 两种形态、按压态、disabled 态。**观感应零变化**（B3e 的 2pt 除外，那在 Task 5）。

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/
git commit -m "refactor: Solid/Light 的 glass 与非 glass 分支只保留差异行（B3b）"
```

---

### Task 5: `CircularGlassButtonStyle` 接入 controlSize（B3e）

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/styles/CircularGlassButtonStyle.swift`

**按前言《判断 1》采用方案 C**：档位存在 style 自身，默认 `.large` = 40（38 → 40，+2pt），不读环境 `controlSize`，不触碰 #97 的 `BottomInputBar.swift`。

- [ ] **Step 1: 改造**

```swift
public struct CircularGlassButtonStyle: ButtonStyle {
    /// 尺寸档位 / Size tier。
    ///
    /// 浮按钮（send / stop / shuffle 一类）语义上是 **large 档**控件，故默认
    /// `.large`（40pt，落在 `CoreControlMetrics.height` 的 24/28/32/40/48 序列内）。
    ///
    /// > 为何不读 `@Environment(\.controlSize)`：该环境值未被显式设置时是
    /// > `.regular`，而现有四个调用点都没设——直接采信会把浮按钮从 38pt 缩到
    /// > 32pt（实测）。若改为"忽略 `.regular` 按 `.large` 解释"，则下游**刻意**
    /// > 写 `.controlSize(.regular)` 时会静默得到 40pt，是永久的公开 API 陷阱。
    /// > 把档位存在 style 上既避免了这两者，也让意图显式可读。
    public var size: ControlSize = .large

    /// 显式直径覆写 / Explicit diameter override：绕过 `size` 直接指定。
    public var diameter: CGFloat?

    public init(size: ControlSize = .large, diameter: CGFloat? = nil) {
        self.size = size
        self.diameter = diameter
    }

    private var resolvedDiameter: CGFloat {
        self.diameter ?? CoreControlMetrics.height(for: self.size)
    }

    public func makeBody(configuration: Configuration) -> some View {
        let diameter = self.resolvedDiameter

        configuration.label
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .backgroundStyle(Color.surfaceInteractive)
            .modifier(TelegramGlassButtonModifier(
                shape: Circle(),
                isPressed: configuration.isPressed
            ))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}
```

同时更新访问器的 doc 注释——`CircularGlassButtonStyle.swift:38` 现写「默认直径（38pt）的圆形玻璃按钮样式」，改名后为假：

```swift
    /// 默认档位（`.large`，40pt）的圆形玻璃按钮样式。
```

- [ ] **Step 2: 确认调用点无需改动**

已实测的 4 个调用点全部走 `.circularGlass` 访问器、不传 `diameter`、不设 `controlSize`：

```
Components/Button/AsyncButton.swift:223
Components/BottomInputBar/BottomInputBar.swift:153,165,177   ← #97 的文件，本任务不碰
App/Sources/Previews.swift:312
```

方案 C 下这些调用点**一行都不用改**（这正是选它的理由）。确认没有遗漏的显式构造：

```bash
echo "本文件内: $(grep -c 'CircularGlassButtonStyle(' Sources/CoreDesign/Components/Button/styles/CircularGlassButtonStyle.swift)  (预期 2)"
grep -rn 'CircularGlassButtonStyle(' Sources App \
  --exclude=CircularGlassButtonStyle.swift 2>/dev/null; echo "文件外 rc=$?  (预期 1，即无外部直接构造)"
```
Expected: 本文件内恰好 2（访问器扩展的 `:40` 与 `:48`），文件外 `rc=1`。

断言钉到文件而非全局计数——那两行就在 Task 5 正在编辑的文件里，若顺手加了便利构造，全局计数会静默漂移而看不出是内部还是外部新增。逐个 Read 确认新增的 `size:` 参数有默认值、这两处无需传参。

- [ ] **Step 3: 验证**

Run: `swift build --build-tests`
Expected: EXIT=0

`#Preview` 视觉冒烟：圆形按钮应从 38 变为 40（+2pt），`BottomInputBar` 的 send / stop / shuffle 三处同步变化。**重点确认没有缩到 32**——那说明 `size` 默认值不是 `.large`，或误接了环境 `controlSize`。

- [ ] **Step 4: 让 probe 看得见这次破坏性类型变更**

`public var diameter: CGFloat` → `CGFloat?` 是**源码级破坏性变更**（下游 `let d: CGFloat = style.diameter` 会断），但现有 probe 完全没覆盖 `CircularGlassButtonStyle`——`PublicVisibility.swift` 只有 `CoreBorderlessButtonStyle` 与 `ButtonRoleStyleRole`，probe 会照常 EXIT=0，无人守门。

`scripts/` 不在 #97 的自有文件清单内，可以改。在 `PublicVisibility.swift` 末尾追加：

```swift
@MainActor
func constructCircularGlass() -> CGFloat? {
    let style = CircularGlassButtonStyle(size: .large, diameter: 44)
    return style.diameter
}

// 访问器路径单独覆盖：`circularGlass(diameter:)` 是本任务未改动但公开的 API。
//
// > 必须经 `.buttonStyle(.circularGlass(...))` 的前导点推断来触达，**不能**写
// > `ButtonStyle.circularGlass(diameter:)`——该静态成员定义在
// > `extension ButtonStyle where Self == CircularGlassButtonStyle` 上，经协议
// > 元类型访问会报 `static member 'circularGlass' cannot be used on protocol
// > metatype '(any ButtonStyle).Type'`。同文件的 `consumeBorderlessAccessor()`
// > 用的也是这个形态。
@MainActor
func consumeCircularGlassAccessor() -> some View {
    Button("circular") {}
        .buttonStyle(.circularGlass(diameter: 44))
}
```

返回类型写 `CGFloat?` 而非 `CGFloat`——它把「`diameter` 是 optional」这一事实固定进 probe，日后再改回非 optional 会在此处编译失败。

```bash
(cd scripts/downstream-probe && swift build > /tmp/p96b.log 2>&1); echo "probe EXIT=$?"
```
Expected: EXIT=0。

- [ ] **Step 5: 提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/CircularGlassButtonStyle.swift
git add scripts/downstream-probe/Sources/DownstreamProbe/PublicVisibility.swift
git commit -m "refactor!: CircularGlassButtonStyle 改用显式 size 档位，直径 38→40 对齐 metrics 序列（B3e）"
```

---

### Task 6: `Sidebar` 四 row 收敛为共享骨架（B5 + B2b）

**Files:**
- Modify: `Sources/CoreDesign/Components/Sidebar/Sidebar.swift`

**Interfaces:**
- Produces: `private struct SidebarRow<Leading: View, Trailing: View>: View`
- 四个 public row 类型（`SidebarNavigationRow` / `SidebarUtilityRow` / `SidebarDocumentRow` / `SidebarTagRow`）**公开签名逐字不变**，body 退化为薄封装。

**四 row 的实测差异**（骨架必须能表达全部，不能抹平）：

| | leading | title 修饰 | trailing | 选中态 |
|---|---|---|---|---|
| Navigation | `Image(systemImage)` · `bodyLargeFont` | — | 无 | ✅ 背景 + `.isSelected` trait |
| Utility | `Image(systemImage)` · `bodyLargeFont` | — | 可选 `Image` · `bodyLargeFont` · tertiary · **a11y hidden** | 无 |
| Document | `Image(systemImage)` · **`titleMediumFont`** | `.lineLimit(1)` | `Text(detail)` · `bodyMediumFont` · tertiary · `.lineLimit(1)` · **a11y 可读** | 无 |
| Tag | `Text("#")` · **`titleMediumFont`** | — | `Image("chevron.right")` · **`bodySmallFont`** · tertiary · **a11y hidden** | 无 |

> ⚠️ **trailing 的 a11y 语义不一致是有意的**：`Document` 的 `detail` 承载信息（计数 / 日期）必须被 VoiceOver 读到，而 `Utility` / `Tag` 的 trailing 是纯装饰。骨架**不得**统一给 trailing 加 `.accessibilityHidden(true)`——那会让 `Document` 丢失信息。让调用方在传入的 trailing 视图上自行决定。原代码的注释已写明这一区别，收敛时保留。

- [ ] **Step 1: 加入共享骨架（放在四个 row 之前）**

```swift
// MARK: - SidebarRow (shared skeleton)

/// 四种 sidebar row 的共享骨架 / Shared skeleton for the four sidebar rows.
///
/// 收敛自原先四份逐字重复的实现（审计项 B5）。差异全部由调用方经
/// `leading` / `trailing` 两个 `@ViewBuilder` 与 `isSelected` 表达：
///
/// - `leading`：图标或 `#` 字形，字号各 row 不同（`bodyLarge` / `titleMedium`）
/// - `trailing`：可选尾部内容；**a11y 语义由调用方决定**——`SidebarDocumentRow`
///   的 detail 承载信息须可读，`SidebarUtilityRow` / `SidebarTagRow` 的是纯装饰
///   须 `.accessibilityHidden(true)`。骨架不代为决定。
/// - `isSelected`：仅 `SidebarNavigationRow` 使用，驱动 floating-glass 背景与
///   `.isSelected` 辅助技术 trait。
private struct SidebarRow<Leading: View, Trailing: View>: View {
    let title: String
    let titleLineLimit: Int?
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: CoreSpacing.sm) {
                self.leading
                    .foregroundStyle(SidebarTextStyle.secondary)
                    .frame(width: CoreControlMetrics.iconSize(for: .large))
                    // 装饰性 leading 字形：button 的可访问名由 title 驱动，隐藏它
                    // 避免 VoiceOver 朗读 SF Symbol 名 / Decorative leading glyph.
                    .accessibilityHidden(true)

                Text(self.title)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.primary)
                    .modifier(OptionalLineLimit(limit: self.titleLineLimit))

                Spacer()

                self.trailing
            }
            // minHeight 而非固定 height：大字号下不裁切（审计项 B2b），
            // 与 ListRow / SearchField 的既有写法一致。
            .frame(minHeight: CoreControlMetrics.height(for: .large))
            .padding(.horizontal, CoreSpacing.sm)
            .sidebarSelectedBackground(self.isSelected)
            .contentShape(RoundedRectangle(cornerRadius: CoreRadius.mediumPlus))
        }
        .buttonStyle(.plain)
        // 向辅助技术暴露选中态，让 VoiceOver 用户感知当前导航目标
        // （对齐 SegmentedControl）/ Expose selected state to a11y.
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}
```

> **`.lineLimit(nil)` 不等于「不施加 lineLimit」**——它会显式重置从祖先继承来的值。本库的 row 会被调用方包裹，祖先可能设过 `lineLimit`，所以必须条件应用才严格等价于原实现（三个 row 根本没写 lineLimit）。
>
> **用下面这个 modifier，不要用 `if let` 包 `Text` 的写法。** 实测过两条路：`if let` 分支会把 `Text` 那段复制两份，导致 **SC-8 = 105 > 100**、**`CoreTypography` = 9 > 8**，两个硬关卡同时红。而 modifier 定义在任何 `var body` 块**之外**，对两个关卡的计数贡献都是 **0**。
>
> 在 `SidebarRow` 之前加上（`Sidebar.swift` 内，不必新建文件）：
>
> ```swift
> /// 条件性 lineLimit / Conditional line limit。
> ///
> /// `.lineLimit(nil)` 会**显式重置**祖先设过的值，与「不写 lineLimit」不等价。
> /// 本 modifier 在 `limit == nil` 时原样返回 content，保证三个不限行的 row
> /// 与收敛前逐字等价。
> private struct OptionalLineLimit: ViewModifier {
>     let limit: Int?
>
>     func body(content: Content) -> some View {
>         if let limit = self.limit {
>             content.lineLimit(limit)
>         } else {
>             content
>         }
>     }
> }
> ```
>
> `sidebarSelectedBackground(false)` 与 `.accessibilityAddTraits([])` 对非 Navigation 的三个 row 是 no-op——先确认 `sidebarSelectedBackground` 的实现在 `false` 时确实不加任何背景（Read 该 modifier）。**若它在 `false` 时仍改变布局（如加透明背景影响尺寸），则骨架要改为条件应用。**

- [ ] **Step 2: 四个 row 改为薄封装**

四个类型的 `public init` 与 `private let` 成员**逐字不动**，只替换 `body`：

```swift
    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: self.isSelected,
            action: self.action
        ) {
            Image(systemName: self.systemImage)
                .font(CoreTypography.bodyLargeFont)
        } trailing: {
            EmptyView()
        }
    }
```
（`SidebarNavigationRow`）

```swift
    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: false,
            action: self.action
        ) {
            Image(systemName: self.systemImage)
                .font(CoreTypography.bodyLargeFont)
        } trailing: {
            if let trailingSystemImage = self.trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(CoreTypography.bodyLargeFont)
                    .foregroundStyle(SidebarTextStyle.tertiary)
                    // 次级装饰性 affordance：随主 button 单一 action 触发，
                    // 不单独暴露给 VoiceOver / Decorative trailing affordance.
                    .accessibilityHidden(true)
            }
        }
    }
```
（`SidebarUtilityRow`）

```swift
    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: 1,
            isSelected: false,
            action: self.action
        ) {
            Image(systemName: self.systemImage)
                .font(CoreTypography.titleMediumFont)
        } trailing: {
            // detail 承载信息（计数 / 日期），**不**隐藏，保持 VoiceOver 可读
            Text(self.detail)
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(SidebarTextStyle.tertiary)
                .lineLimit(1)
        }
    }
```
（`SidebarDocumentRow`）

```swift
    public var body: some View {
        SidebarRow(
            title: self.title,
            titleLineLimit: nil,
            isSelected: false,
            action: self.action
        ) {
            Text("#")
                .font(CoreTypography.titleMediumFont)
        } trailing: {
            Image(systemName: "chevron.right")
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(SidebarTextStyle.tertiary)
                // 装饰性指示箭头：行整体可点击，标题已表达目标
                // Decorative trailing chevron.
                .accessibilityHidden(true)
        }
    }
```
（`SidebarTagRow`）

- [ ] **Step 3: 量 SC-8 行数（硬指标 ≤ 60）**

**测量口径已于 #96 执行期修正**（见 `96.md` 的《SC-8 的测量边界》）：四个 row 类型 + 共享骨架的 **`var body` 块之和**，**不含** init / 成员声明 / 结构声明行 / `#Preview` / 文档注释。

原口径（「含 init 与成员」）与「≤60」这个数字来自不同来源，拼在一起不可达——实测现状 body 合计 **118** 行，恰好对应 PRD 的「约 120 行」，证明数字自始是 body-only 推导的。

```bash
python3 - <<'EOF'
import re, sys
src = open('Sources/CoreDesign/Components/Sidebar/Sidebar.swift').read().split('\n')
names = ['SidebarRow', 'SidebarNavigationRow', 'SidebarUtilityRow', 'SidebarDocumentRow', 'SidebarTagRow']
total = 0
for n in names:
    hits = [i for i, l in enumerate(src) if re.match(rf'^(public |private )?struct {n}[<:]', l)]
    if not hits:
        sys.exit(f'!! 找不到类型 {n}（是否改名？）')
    start = hits[0]
    # 找该类型内的 body 块
    bs = next((i for i in range(start, len(src)) if re.search(r'var body: some View \{', src[i])), None)
    if bs is None:
        sys.exit(f'!! {n} 内找不到 body 块')
    depth = 0
    for i in range(bs, len(src)):
        depth += src[i].count('{') - src[i].count('}')
        if depth == 0 and i > bs:
            be = i; break
    n_lines = be - bs + 1
    print(f'{n}: body {n_lines} 行 ({bs+1}-{be+1})')
    total += n_lines
print(f'TOTAL = {total}   (SC-8 上限 100；改造前基线 118)')
if total > 100:
    sys.exit(f'!! SC-8 超标：{total} > 100')
EOF
```
Expected: **`TOTAL` 恰好 99**（上限 100，只留 1 行余量；脚本超标即 `exit 1`，不靠人眼）。逐类型预期：`SidebarRow` 31 / Navigation 13 / Utility 20 / Document 17 / Tag 18。

**任何偏离都说明实现偏离了本计划的代码**，不要当成"接近就行"——先查清差在哪再继续。**把实测数字与本脚本一并记进 PR 描述**（96.md 要求给出脚本）。

> **上限为何是 100 而不是 60**：60 从未对照真实设计验算过。把本计划提议的骨架 + 四个薄封装落成代码实测得 **99**；删光 body 内注释空行得 85、连骨架也排除得 68、两者都做得 63——全部 > 60。唯一能压进 60 的做法是把多行实参表折成单行，即靠折行凑数。已于 #96 执行期经用户确认改为 ≤100（详见 `96.md` 的《SC-8 的测量边界》）。

> 脚本的花括号配平法对本文件可靠——已核实四个 row 的 body 内无字符串字面量含花括号、无字符串插值。若日后 body 里出现 `"\(...)"`，此法会失准，届时改用真正的 Swift 解析。
>
> 若超 100：真正的收敛应体现在结构上，**不要靠删注释或折行凑数**——本脚本只按行计数，`//` 注释与空行都计入（只有 `///` doc 注释因不在 body 块内而天然排除），所以这两招"能凑数"，正因如此更不该用。

- [ ] **Step 4: 量 `CoreTypography` 引用数（AC 已修订：row body 内 11 → ≤8，见 `96.md:35`）**

口径是**四个 row 的 `var body` 内**，不是文件级——实测 16 处中有 5 处在本任务范围外（`SidebarSection` 的 `:49 :54 :64`、`SidebarStatusFooter` 的 `:330 :334`，B5 不碰这两个类型）。

```bash
python3 - <<'EOF'
import re, sys
src = open('Sources/CoreDesign/Components/Sidebar/Sidebar.swift').read().split('\n')
spans = []
for n in ['SidebarRow','SidebarNavigationRow','SidebarUtilityRow','SidebarDocumentRow','SidebarTagRow']:
    hits = [i for i,l in enumerate(src) if re.match(rf'^(public |private )?struct {n}[<:]', l)]
    if not hits: sys.exit(f'!! 找不到 {n}')
    bs = next(i for i in range(hits[0], len(src)) if re.search(r'var body: some View \{', src[i]))
    d = 0
    for i in range(bs, len(src)):
        d += src[i].count('{') - src[i].count('}')
        if d == 0 and i > bs: spans.append((bs, i)); break
inside = [i+1 for i,l in enumerate(src) if 'CoreTypography.' in l and any(a<=i<=b for a,b in spans)]
outside = [i+1 for i,l in enumerate(src) if 'CoreTypography.' in l and not any(a<=i<=b for a,b in spans)]
print(f'row body 内 = {len(inside)} {inside}   (基线 11，AC 上限 8)')
print(f'范围外     = {len(outside)} {outside}   (SidebarSection / SidebarStatusFooter，本任务不碰)')
if len(inside) > 8: sys.exit('!! 超过 AC 上限 8')
EOF
```
Expected: **`row body 内` 恰好 8**（AC 上限也是 8，**零余量**）、`范围外 = 5`。

这 8 处的构成：骨架 title ×1 + Navigation ×1 + Utility ×2 + Document ×2 + Tag ×2。**多出一处就红**——不要把 9 当成"接近 8"，那意味着实现比计划多了一个字号调用点。实测数字记进 PR。

- [ ] **Step 5: 验证 + 视觉冒烟**

```bash
swift build --build-tests > /tmp/t6b.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t6t.log 2>&1; echo "test  EXIT=$?"
```
Expected: 两条 EXIT=0，95 tests passed。`Tests/CoreDesignTests/SidebarComponentsTests.swift` 只断言四个 public init 的签名，本任务保持签名不变，应仍绿——**若它红了，说明薄封装误改了公开 init**。

`#Preview` 光暗两态各看一遍：四种 row 的图标字号、trailing 对齐、选中态背景、行高（`minHeight` 后应与之前一致——默认字号下 `minHeight` 与 `height` 表现相同）。

- [ ] **Step 6: 提交**

```bash
git add Sources/CoreDesign/Components/Sidebar/Sidebar.swift
git commit -m "refactor: Sidebar 四 row 收敛为共享骨架，固定高度改 minHeight（B5、B2b）"
```

---

### Task 7: `CoreMenuButtonStyleModifier` 复用参数化的 glass modifier（B8a）

**Files:**
- Modify: `Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift`
- Modify: `Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift`

> `CoreMenuButton.swift` **不在** #97 的自有文件清单里（清单含 `BottomInputBar.swift` 但不含 `CoreMenuButton.swift`），可以改。实施前再核对一次 Global Constraints 的清单。

按前言《判断 2》：参数化 `TelegramGlassButtonModifier`，保持既有 3 个调用点（`SolidButtonStyle` / `LightButtonStyle` / `CircularGlassButtonStyle`）行为逐字不变。

- [ ] **Step 1: 参数化 `TelegramGlassButtonModifier`**

```swift
    public let shape: S
    public let isPressed: Bool
    /// 描边色 / Border color：`nil` = 玻璃默认的半透明白。
    public let border: Color?
    /// 是否施加按压缩放与动画 / Whether to apply press scale + animation。
    public let pressFeedback: Bool

    public init(
        shape: S,
        isPressed: Bool,
        border: Color? = nil,
        pressFeedback: Bool = true
    ) {
        self.shape = shape
        self.isPressed = isPressed
        self.border = border
        self.pressFeedback = pressFeedback
    }

    public func body(content: Content) -> some View {
        content
            .background(
                self.shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background)
                    .glassEffect()
            )
            .overlay(
                self.shape.strokeBorder(
                    self.border ?? .white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
            .scaleEffect(self.pressFeedback && self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(self.pressFeedback ? .snappy(duration: 0.16) : nil, value: self.isPressed)
    }
```

> **同步更新该类型的 doc 注释**（`TelegramGlassButtonModifier.swift:10-36`）。它把「四层结构」写死：第 3 层明写 `strokeBorder(.white.opacity(0.2), ...)`、第 4 层明写 `scaleEffect(pressedScale)`，Usage 示例只给两参数形态。参数化后这两条不再无条件成立，须改为「默认如此，可经 `border` / `pressFeedback` 覆写」，并写明**默认值 = 原行为**。这是三处需同步 doc 的地方里唯一 public 且被最多样式共享的类型。
>
> `self.border ?? .white.opacity(...)` 的类型推断：`border` 是 `Color?`，`.white.opacity(...)` 是 `Color`，`??` 结果是 `Color`，而 `strokeBorder` 收 `some ShapeStyle`——应能推断。**若编译器报歧义，显式写 `Color.white.opacity(...)`。** 同理 `.animation(self.pressFeedback ? .snappy(duration: 0.16) : nil, value:)` 里的隐式成员处在上下文类型为 `Animation?` 的三元表达式中，推断更脆——报错就显式写 `Animation.snappy(duration: 0.16)`。

- [ ] **Step 2: `CoreMenuButtonStyleModifier` 泛型化并复用**

原两分支只差 shape（`Capsule` vs `Circle`）与 frame 方式（`minHeight` vs `width×height`）。改为：

```swift
private struct CoreMenuButtonStyleModifier: ViewModifier {
    let style: CoreMenuButtonStyle

    func body(content: Content) -> some View {
        switch self.style {
        case .labeled:
            content
                .padding(.horizontal, CoreSpacing.sm)
                .frame(minHeight: self.controlSize)
                .contentShape(Capsule())
                .modifier(TelegramGlassButtonModifier(
                    shape: Capsule(),
                    isPressed: false,
                    border: .borderSubtle,
                    pressFeedback: false
                ))
        case .circular:
            content
                .frame(width: self.controlSize, height: self.controlSize)
                .contentShape(Circle())
                .modifier(TelegramGlassButtonModifier(
                    shape: Circle(),
                    isPressed: false,
                    border: .borderSubtle,
                    pressFeedback: false
                ))
        }
    }
```

> **内缩方式已实测等值，可直接复用**：`CoreButtonMetrics.glassInset = 2`、`CoreSpacing.xxs = 2`。原实现的 `.padding(CoreSpacing.xxs)` 与 `TelegramGlassButtonModifier` 的 `.inset(by: glassInset)` 数值相同，复用无视觉变化。（`.padding` 与 `.inset(by:)` 的几何语义略有不同——前者缩内容、后者缩形状——但此处作用于 `background` 里的 shape，效果一致。**实施后仍以 `#Preview` 实看为准。**）
>
> 另：`.inset(by:)` 要求 `InsettableShape`，`Capsule` / `Circle` 都满足。

> ⚠️ 上面只给出 `body` 的改写。**`private let controlSize: CGFloat = CoreControlMetrics.height(for: .large)`（`CoreMenuButton.swift:123`）及其 doc 注释原样保留**，结构体的收尾 `}` 也别漏——照抄上面的代码块会删掉该属性并破坏编译。

两分支仍需 `switch`（shape 类型不同，泛型无法在同一函数内统一），但**重复的四层玻璃结构已消除**——这正是 B8a 的要求。

- [ ] **Step 3: 验证既有调用点未漂移**

```bash
grep -rn 'TelegramGlassButtonModifier(' Sources/ | cat
```
其中 1 行是 `TelegramGlassButtonModifier.swift` doc 注释里的 Usage 示例（本 Step 已要求同步更新它）。其余逐个确认：`SolidButtonStyle`、`LightButtonStyle`、`CircularGlassButtonStyle` 三处**不传** `border` / `pressFeedback`（走默认值 = 原行为）；`CoreMenuButtonStyleModifier` 两处显式传。

Run: `swift build --build-tests`
Expected: EXIT=0

`#Preview` 冒烟：`CoreMenuButton` 的 labeled / circular 两态，描边应仍是 `borderSubtle` 语义色、**无**按压缩放。

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
git commit -m "refactor: CoreMenuButtonStyleModifier 复用参数化的玻璃 modifier（B8a）"
```

---

### Task 8: 全量验证 + 审计清单 + 交接记录

**Files:**
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`
- Create: `.claude/epics/coredesign-audit-remediation/updates/96/progress.md`

- [ ] **Step 1: 确认未触碰 #97 的自有文件（005 ∩ 006 = ∅）**

**必须按 basename 精确匹配，不能用子串 grep**——`EmptyState`、`BottomInputBar`、`CommentCard`、`RefPill`、`SegmentedControl`、`TimelineItem`、`BookCover` 全都同时是**目录名**。子串匹配会把 Task 7 合法修改的 `Components/BottomInputBar/CoreMenuButton.swift` 判成违规，形成必然假红——而一个永远失败的关卡会被忽略，比没有关卡更糟。

```bash
git diff --name-only epic/coredesign-audit-remediation..HEAD \
  | xargs -n1 basename \
  | grep -Fx -f <(printf '%s\n' \
      EmptyState.swift 'View+SizeReader.swift' KeyboardHandling.swift \
      BottomInputBar.swift CommentCard.swift RefPill.swift \
      SegmentedControl.swift TimelineItem.swift BookCover.swift \
      CoreGradient.swift BorderModifier.swift)
echo "rc=$?"
```
Expected: `rc=1`，无匹配。**有匹配即违反并行硬约束**，必须回退该文件的改动或与 #97 协调。

（`CoreMenuButton.swift` **不在**清单内，Task 7 修改它是允许的——这正是需要 basename 精确匹配的原因。）

- [ ] **Step 2: 四条 SwiftPM 命令（clean 后冷跑）**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-96"; mkdir -p "$LOGDIR"
swift package clean
swift build                  > "$LOGDIR/b.log"  2>&1; echo "build          EXIT=$?"
swift test                   > "$LOGDIR/t.log"  2>&1; echo "test           EXIT=$?"
swift build --traits Blossom > "$LOGDIR/bb.log" 2>&1; echo "build-blossom  EXIT=$?"
swift test  --traits Blossom > "$LOGDIR/tb.log" 2>&1; echo "test-blossom   EXIT=$?"
```
Expected: 四条 EXIT=0，两侧各 `95 tests in 32 suites passed`。

**warning 判据**（注意 EmptyState 的诊断续行不含 "EmptyState" 字样，朴素 `grep -v` 会漏，#94 踩过）：

```bash
python3 - <<EOF
import os
for f in ['b','t','bb','tb']:
    d = open(os.path.join("$LOGDIR", f+".log")).read()
    assert d, f+".log 为空"
    w = [l for l in d.split('\n') if 'warning:' in l]
    non = [l for l in w if 'EmptyState' not in l and 'ContentUnavailableView' not in l]
    print(f"{f}: warning={len(w)} 非EmptyState={len(non)}")
    for l in non[:5]: print("   !!", l.strip()[:160])
EOF
```
Expected: 每份 `非EmptyState=0`。

- [ ] **Step 3: 下游 probe（公开 API 无回退）**

```bash
(cd scripts/downstream-probe && swift build > /tmp/p96.log 2>&1); echo "probe EXIT=$?"
```
Expected: EXIT=0。本任务改了 `ButtonRoleStyleRole`（加 public 方法）与 `CircularGlassButtonStyle`（`diameter` 类型变 optional），probe 是唯一能看见公开面回退的地方。

- [ ] **Step 4: SC-3 前置自查（为 #95 让路的核心交付）**

```bash
grep -rn 'CoreControlMetrics.font(for:' Sources/CoreDesign/Components/Button/
```
Expected: **恰好 0 行**（口径与 Task 2 Step 3 一致）。

**不要用全库口径写「恰好 1 行」**——全库改造后是 **3 行**：`Modifier/ButtonChromeModifier.swift` 的唯一调用点，加上两处不属本任务范围的
```
Components/SearchField/SearchField.swift:98   ← 非按钮体系，#95 单独处理
Tokens/CoreControlMetrics.swift:25            ← doc 注释里的用法示例
```
**这两处一行都不要动。** Task 2 Step 3 已就此写过警告，本 Step 是最终验证、后面没有任务能兜底，更不能在这里重犯。

- [ ] **Step 5: 视觉冒烟（AC 明列，不可省）**

`Sidebar` 与四个按钮样式的 `#Preview`，在默认与 Blossom 两种模式、light + dark 下各看一遍。**已知的三处受控变化**（与 Task 2 Step 2 的警告对齐，别漏第三条）：

1. `CircularGlassButtonStyle` 直径 38→40（`BottomInputBar` 的 send / stop / shuffle 同步）
2. `CoreBorderlessButtonStyle` 字号从随环境变为随 `controlSize`
3. `CoreBorderlessButtonStyle` **命中区从带 padding 的矩形变为胶囊**——`buttonChrome` 给它加了原本没有的 `contentShape(Capsule)`。这是交互变化，**冒烟时要实点边角**，不能只看渲染。

其余应零变化。

- [ ] **Step 6: 更新审计清单**

把 B2b、B3a、B3b、B3c、B3d、B3e、B5、B8a 八项标为 `✅ **已修复**（GitHub #96）——<做法>。原缺陷：<原文保留>`，沿用 #93/#94 的既定写法。B3e 行须注明 38→40 的视觉变化。

同时按 #94 的教训检查**两维 stale**：本任务改了 `Sidebar.swift` / 四个 ButtonStyle / `CoreMenuButton.swift` 的行号，`audit-checklist.md` 与兄弟任务文件里指向这些文件的坐标要重算。至少涉及：

```bash
grep -rn 'Sidebar\.swift:\|SolidButtonStyle\.swift:\|LightButtonStyle\.swift:\|CoreBorderlessButtonStyle\.swift:\|CircularGlassButtonStyle\.swift:\|CoreMenuButton\.swift:' \
  .claude/epics/coredesign-audit-remediation/*.md
```
逐条 Read 目标位置确认坐标是否仍成立，**不要凭推理判断**（#94 连续两轮在这里出错）。

**已知一处待清扫**：`96.md:26`（B3a）引的 `CoreBorderlessButtonStyle.swift:73-78` 已陈旧，`textColor` 的真实位置是 `:91-96`（#94 的改名 + doc 扩写造成）。同文件的 `SolidButtonStyle.swift:71-76` 与 `LightButtonStyle.swift:57-62` 经核对仍准确。

计数校验：
```bash
echo $(( $(grep -c '^| [A-D][0-9]' .claude/epics/coredesign-audit-remediation/audit-checklist.md) - 4 ))
```
Expected: `83`

- [ ] **Step 7: 写 `updates/96/progress.md`**

必须落进去的内容（这些证据合并后只存在于此）：
- 八项各自的做法
- **SC-8 实测行数**与 `CoreTypography` 引用数（16 → ?）
- **三处**受控变化（38→40、Borderless 字号来源、Borderless 命中区变胶囊）及理由——第三条是交互变化不是视觉变化，别归错类
- `TelegramGlassButtonModifier` 参数化的默认值契约——**后续任何人加参数都必须保证既有调用点走默认值时行为不变**
- 给 #95 的交接：`CoreControlMetrics.font(for:)` 现在只有 1 个调用点，在 `ButtonChromeModifier.swift`；`Sidebar` 的 `CoreTypography` 引用已降到 ? 处
- 给 #97 的交接：005 ∩ 006 = ∅ 已用 `git diff --name-only` 自查通过

- [ ] **Step 8: 提交**

```bash
git status --porcelain
git add .claude/epics/coredesign-audit-remediation/
git commit -m "docs(ccpm): 更新 #96 审计清单状态与完成记录"
```

---

## 收尾

`oh-my-superpowers:verification-before-completion` → `finishing-a-development-branch` Option 2 开 PR（**base = `epic/coredesign-audit-remediation`，禁止直合 main**）→ Copilot 不可用，按 auto-fix skill §3.6 降级为 `superpowers-reviewer` 一轮并在 PR 留顶层评论。

PR 描述必须包含：SC-8 实测行数与脚本、`CoreTypography` 引用数变化（row body 内 11 → ?）、**三处**受控变化的说明。
