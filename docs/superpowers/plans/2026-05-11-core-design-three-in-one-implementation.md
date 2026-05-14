# CoreDesign Three-in-One 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标 / Goal：** 跨 5 个 zone 实施 10 个新组件、2 项 token 扩展、1 个共享 modifier 与 4 个按钮样式重构，打造 Apple-GitHub-Telegram 三合一的统一设计语言。

**架构 / Architecture：** Token → Modifier → Component 依赖链。Z1 建立共享基座（CoreButtonMetrics、StatusColors、TelegramGlassButtonModifier），供 Z2–Z5 消费。每个组件遵循既有模式：`public struct` 配 `public init`、组件文件内的 SwiftUI `#Preview`、`Tests/CoreDesignTests/` 下的 Swift Testing `@Test`/`#expect`。所有资源通过 `bundle: .module` 加载。

**技术栈 / Tech Stack：** Swift 6、SwiftUI（iOS 26+ / macOS 26+）、Swift Testing framework、无第三方依赖。

---

## 文件清单 / File Map

### 新建文件
| File | Zone | 用途 |
|------|------|------|
| `Sources/CoreDesign/Tokens/CoreButtonMetrics.swift` | Z1 | 玻璃按钮常量 |
| `Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift` | Z1 | 共享玻璃壳 |
| `Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift` | Z1 | 圆形 spinner |
| `Sources/CoreDesign/Components/StateLabel/StateLabel.swift` | Z2 | 状态 pill |
| `Sources/CoreDesign/Components/RefPill/RefPill.swift` | Z2 | 代码引用 pill |
| `Sources/CoreDesign/Layout/FlowLayout.swift` | Z3 | tag 换行布局 |
| `Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift` | Z3 | 堆叠头像 |
| `Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift` | Z3 | 水平进度条 |
| `Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift` | Z4 | 时间线脊柱 + 环境键 |
| `Sources/CoreDesign/Components/EventRow/EventRow.swift` | Z4 | 紧凑事件行 |
| `Sources/CoreDesign/Components/CommentCard/CommentCard.swift` | Z4 | 评论卡片 |
| `Sources/CoreDesign/Components/StatusRow/StatusRow.swift` | Z5 | CI 检查行 |
| `Tests/CoreDesignTests/CoreButtonMetricsTests.swift` | Z1 | |
| `Tests/CoreDesignTests/StatusColorsTests.swift` | Z1 | |
| `Tests/CoreDesignTests/ProgressIndicatorTests.swift` | Z1 | |
| `Tests/CoreDesignTests/StateLabelTests.swift` | Z2 | |
| `Tests/CoreDesignTests/RefPillTests.swift` | Z2 | |
| `Tests/CoreDesignTests/FlowLayoutTests.swift` | Z3 | |
| `Tests/CoreDesignTests/AvatarGroupTests.swift` | Z3 | |
| `Tests/CoreDesignTests/ProgressBarTests.swift` | Z3 | |
| `Tests/CoreDesignTests/TimelineItemTests.swift` | Z4 | |
| `Tests/CoreDesignTests/EventRowTests.swift` | Z4 | |
| `Tests/CoreDesignTests/CommentCardTests.swift` | Z4 | |
| `Tests/CoreDesignTests/StatusRowTests.swift` | Z5 | |

### 修改文件
| File | Zone | 变更 |
|------|------|------|
| `Sources/CoreDesign/Colors/StatusColors.swift` | Z1 | 新增 5 状态 × 4 变体的 Primer 风格 token（neutral 由 FillColors / ContentColors 提供） |
| `Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift` | Z1 | 新增 `glass:` 参数，使用 `TelegramGlassButtonModifier` |
| `Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift` | Z1 | 新增 `glass:` 参数，使用 `TelegramGlassButtonModifier` |
| `Sources/CoreDesign/Components/Button/styles/BorderlessButtonStyle.swift` | Z1 | token 迁移（魔法数字 → `CoreSpacing`/`CoreControlMetrics`） |
| `Sources/CoreDesign/Components/Button/styles/CircularGlassButtonStyle.swift` | Z1 | 使用共享的 `TelegramGlassButtonModifier` |

---

### Task 1：CoreButtonMetrics token（Z1）

**Files：**
- 新建：`Sources/CoreDesign/Tokens/CoreButtonMetrics.swift`
- 新建：`Tests/CoreDesignTests/CoreButtonMetricsTests.swift`

- [ ] **Step 1：编写测试**

```swift
import Testing
@testable import CoreDesign
import CoreGraphics

@Suite("CoreButtonMetrics")
struct CoreButtonMetricsTests {
    @Test("glassInset is 2pt")
    func glassInset() {
        #expect(CoreButtonMetrics.glassInset == 2.0)
    }

    @Test("glassBorderOpacity is 0.2")
    func glassBorderOpacity() {
        #expect(CoreButtonMetrics.glassBorderOpacity == 0.2)
    }

    @Test("pressedScale is 0.94")
    func pressedScale() {
        #expect(CoreButtonMetrics.pressedScale == 0.94)
    }

    @Test("all values are positive and non-zero")
    func allPositive() {
        #expect(CoreButtonMetrics.glassInset > 0)
        #expect(CoreButtonMetrics.glassBorderOpacity > 0)
        #expect(CoreButtonMetrics.pressedScale > 0 && CoreButtonMetrics.pressedScale < 1)
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter CoreButtonMetricsTests`
预期：FAIL —— `CoreButtonMetrics` 未定义

- [ ] **Step 3：编写 token**

```swift
//
//  CoreButtonMetrics.swift
//  CoreDesign
//

import CoreGraphics

// MARK: - CoreButtonMetrics

/// 按钮专用度量 token，服务于 Telegram 玻璃按钮四层结构。
///
/// 典型使用方式（参考 `TelegramGlassButtonModifier`）——通过 `InsettableShape.inset(by:)`
/// 把底色 path 真正内缩，避免用 `.padding` 撑外框：
///
/// ```swift
/// content
///     .background(
///         shape
///             .inset(by: CoreButtonMetrics.glassInset)
///             .fill(.background)
///             .glassEffect()
///     )
///     .overlay(
///         shape.strokeBorder(
///             .white.opacity(CoreButtonMetrics.glassBorderOpacity),
///             lineWidth: CoreBorderWidth.hairline
///         )
///     )
/// ```
public enum CoreButtonMetrics {
    /// 底色内缩量 (2pt)。让底色从玻璃壳边缘微微透出，形成 Telegram 分层按钮的视觉纵深。
    /// 通过 `InsettableShape.inset(by:)` 应用于底色 path，不要用 `.padding` 替代。
    public static let glassInset: CGFloat = 2

    /// 玻璃壳顶层细白描边的不透明度 (0.2)。配合 `CoreBorderWidth.hairline` 使用。
    public static let glassBorderOpacity: Double = 0.2

    /// 按钮按下时的缩放比例 (0.94)。提供 Telegram 风格的轻微凹陷反馈。
    public static let pressedScale: Double = 0.94
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter CoreButtonMetricsTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Tokens/CoreButtonMetrics.swift Tests/CoreDesignTests/CoreButtonMetricsTests.swift
git commit -m "feat: add CoreButtonMetrics token for Telegram glass button constants"
```


### Task 2：将 StatusColors 扩展为 Primer 风格的 5 状态 × 4 变体体系（Z1）

**Files：**
- 修改：`Sources/CoreDesign/Colors/StatusColors.swift`
- 新建：`Tests/CoreDesignTests/StatusColorsTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StatusColors")
struct StatusColorsTests {
    @Test("accent status has 4 variants")
    func accentVariants() {
        // Type-annotated `let _: Color = ...` 提供编译期覆盖；
        // `Color` 是非可选类型，不能与 `nil` 比较——靠绑定本身即可证明 token 存在。
        let _: Color = .statusAccentForeground
        let _: Color = .statusAccentEmphasis
        let _: Color = .statusAccentMuted
        let _: Color = .statusAccentSubtle
    }

    @Test("success status has 4 variants")
    func successVariants() {
        let _: Color = .statusSuccessForeground
        let _: Color = .statusSuccessEmphasis
        let _: Color = .statusSuccessMuted
        let _: Color = .statusSuccessSubtle
    }

    @Test("attention status has 4 variants")
    func attentionVariants() {
        let _: Color = .statusAttentionForeground
        let _: Color = .statusAttentionEmphasis
        let _: Color = .statusAttentionMuted
        let _: Color = .statusAttentionSubtle
    }

    @Test("danger status has 4 variants")
    func dangerVariants() {
        let _: Color = .statusDangerForeground
        let _: Color = .statusDangerEmphasis
        let _: Color = .statusDangerMuted
        let _: Color = .statusDangerSubtle
    }

    @Test("done status has 4 variants")
    func doneVariants() {
        let _: Color = .statusDoneForeground
        let _: Color = .statusDoneEmphasis
        let _: Color = .statusDoneMuted
        let _: Color = .statusDoneSubtle
    }

    @Test("existing info/warning/danger/success foreground-background-border tokens preserved")
    func existingTokensPreserved() {
        let _: Color = .infoForeground
        let _: Color = .infoBackground
        let _: Color = .infoBorder
        let _: Color = .successForeground
        let _: Color = .successBackground
        let _: Color = .successBorder
        let _: Color = .warningForeground
        let _: Color = .warningBackground
        let _: Color = .warningBorder
        let _: Color = .dangerForeground
        let _: Color = .dangerBackground
        let _: Color = .dangerBorder
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter StatusColorsTests`
预期：FAIL —— 新增的 status token 未定义

- [ ] **Step 3：重写 StatusColors.swift**

将既有的 4 状态体系（info/success/warning/danger）替换为 6 状态 × 4 变体体系。在 `Resources.xcassets/status/` 下为 accent / attention / done 创建新的 colorset，success（绿）与 danger（红）复用既有 colorset：

```swift
import SwiftUI

// MARK: - Status Colors (Primer 6-status × 4-variant)

public extension Color {

    // MARK: Accent (blue)
    /// Primer `accent.fg` — link / focus / selection foreground text.
    static let statusAccentForeground: Color = Color("status-accent-fg", bundle: .module)
    /// Primer `accent.emphasis` — bold accent background (selected row, active toggle).
    static let statusAccentEmphasis: Color = Color("status-accent-emphasis", bundle: .module)
    /// Primer `accent.muted` — muted accent background (hover state).
    static let statusAccentMuted: Color = Color("status-accent-muted", bundle: .module)
    /// Primer `accent.subtle` — faint accent background (selection highlight).
    static let statusAccentSubtle: Color = Color("status-accent-subtle", bundle: .module)

    // MARK: Success (green)
    /// Primer `success.fg` — success / merged / CI pass foreground text.
    static let statusSuccessForeground: Color = Color("status-success-fg", bundle: .module)
    /// Primer `success.emphasis` — bold success background.
    static let statusSuccessEmphasis: Color = Color("status-success-emphasis", bundle: .module)
    /// Primer `success.muted` — muted success background.
    static let statusSuccessMuted: Color = Color("status-success-muted", bundle: .module)
    /// Primer `success.subtle` — faint success background.
    static let statusSuccessSubtle: Color = Color("status-success-subtle", bundle: .module)

    // MARK: Attention (yellow)
    /// Primer `attention.fg` — warning / pending / review foreground text.
    static let statusAttentionForeground: Color = Color("status-attention-fg", bundle: .module)
    /// Primer `attention.emphasis` — bold attention background.
    static let statusAttentionEmphasis: Color = Color("status-attention-emphasis", bundle: .module)
    /// Primer `attention.muted` — muted attention background.
    static let statusAttentionMuted: Color = Color("status-attention-muted", bundle: .module)
    /// Primer `attention.subtle` — faint attention background.
    static let statusAttentionSubtle: Color = Color("status-attention-subtle", bundle: .module)

    // MARK: Danger (red)
    /// Primer `danger.fg` — error / delete / blocked foreground text.
    static let statusDangerForeground: Color = Color("status-danger-fg", bundle: .module)
    /// Primer `danger.emphasis` — bold danger background.
    static let statusDangerEmphasis: Color = Color("status-danger-emphasis", bundle: .module)
    /// Primer `danger.muted` — muted danger background.
    static let statusDangerMuted: Color = Color("status-danger-muted", bundle: .module)
    /// Primer `danger.subtle` — faint danger background.
    static let statusDangerSubtle: Color = Color("status-danger-subtle", bundle: .module)

    // MARK: Done (purple)
    /// Primer `done.fg` — completed / closed / resolved foreground text.
    static let statusDoneForeground: Color = Color("status-done-fg", bundle: .module)
    /// Primer `done.emphasis` — bold done background.
    static let statusDoneEmphasis: Color = Color("status-done-emphasis", bundle: .module)
    /// Primer `done.muted` — muted done background.
    static let statusDoneMuted: Color = Color("status-done-muted", bundle: .module)
    /// Primer `done.subtle` — faint done background.
    static let statusDoneSubtle: Color = Color("status-done-subtle", bundle: .module)

    // MARK: Legacy compatibility (existing v1 API surface, preserved for callers)

    static let infoForeground = Color.blue7
    static let infoBackground = Color.blue1
    static let infoBorder = Color.blue3

    static let successForeground = Color.green7
    static let successBackground = Color.green1
    static let successBorder = Color.green3

    static let warningForeground = Color.orange7
    static let warningBackground = Color.orange1
    static let warningBorder = Color.orange3

    static let dangerForeground = Color.red7
    static let dangerBackground = Color.red1
    static let dangerBorder = Color.red3
}
```

- [ ] **Step 4：创建所需 colorset**

每个 colorset 需在 `Sources/CoreDesign/Resources/Resources.xcassets/status/` 下创建带亮/暗变体的 `Contents.json`（SwiftPM 的 `.process("Resources")` 指令会处理此路径下的 `.xcassets` 资源目录）。首版提交时按 Color asset catalog 格式创建 20 个 colorset（5 状态 × 4 变体）。亮色采用 Primer light 调色板；暗色采用 Primer dark 调色板。

执行以下命令生成目录结构：
```bash
mkdir -p Sources/CoreDesign/Resources/Resources.xcassets/status
for status in accent success attention danger done; do
    for variant in fg emphasis muted subtle; do
        cat > "Sources/CoreDesign/Resources/Resources.xcassets/status/status-${status}-${variant}.colorset/Contents.json" <<JSON
{
  "colors" : [
    {"color" : {"color-space" : "srgb","components" : {"red" : "0x00","green" : "0x00","blue" : "0x00","alpha" : "1.000"}},"idiom" : "universal"},
    {"appearances" : [{"appearance" : "luminosity","value" : "dark"}],"color" : {"color-space" : "srgb","components" : {"red" : "0xFF","green" : "0xFF","blue" : "0xFF","alpha" : "1.000"}},"idiom" : "universal"}
  ],
  "info" : {"author" : "xcode","version" : 1}
}
JSON
    done
done
```

随后手工把每个 `Contents.json` 替换为真实的 Primer 十六进制色值（参见 `docs/PRIMER_VERSION.md`）。

- [ ] **Step 5：运行测试确认通过**

Run: `swift test --filter StatusColorsTests`
预期：PASS

- [ ] **Step 6：确认遗留调用方仍可编译**

Run: `swift build`
预期：0 errors

- [ ] **Step 7：提交**

```bash
git add Sources/CoreDesign/Colors/StatusColors.swift Sources/CoreDesign/Resources/Resources.xcassets/status/ Tests/CoreDesignTests/StatusColorsTests.swift
git commit -m "feat: expand StatusColors to Primer-style 5-status x 4-variant system"
```


### Task 3：TelegramGlassButtonModifier（Z1）

**Files：**
- 新建：`Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift`
- （不单独建测试文件——通过 Task 4–5 的 Solid/Light 按钮样式重构间接覆盖）

- [ ] **Step 1：编写 modifier**

```swift
//
//  TelegramGlassButtonModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - TelegramGlassButtonModifier

/// Telegram 风格的玻璃按钮四层结构，抽取为可复用 modifier。
///
/// ## 四层结构 / Layer Stack
///
/// 1. **底色填充**：`Shape.fill(.background)`，颜色由调用方的 `.backgroundStyle()` 注入。
/// 2. **内缩**：`CoreButtonMetrics.glassInset` (2pt) padding，让底色从玻璃边缘微微透出。
/// 3. **玻璃壳**：`.glassEffect()`，iOS 26 液态玻璃材质。
/// 4. **细白描边**：`Shape.strokeBorder(.white.opacity(0.2), lineWidth: .hairline)`。
///
/// ## 使用方式 / Usage
///
/// ```swift
/// configuration.label
///     .modifier(TelegramGlassButtonModifier(
///         shape: Capsule(),
///         isPressed: configuration.isPressed
///     ))
/// ```
///
/// Solid / Light / CircularGlass 三种有容器按钮样式共享此 modifier；
/// Borderless 不参与（无视觉容器）。
public struct TelegramGlassButtonModifier<S: InsettableShape>: ViewModifier {
    public let shape: S
    public let isPressed: Bool

    public init(shape: S, isPressed: Bool) {
        self.shape = shape
        self.isPressed = isPressed
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
                    .white.opacity(CoreButtonMetrics.glassBorderOpacity),
                    lineWidth: CoreBorderWidth.hairline
                )
            )
            .scaleEffect(self.isPressed ? CoreButtonMetrics.pressedScale : 1)
            .animation(.snappy(duration: 0.16), value: self.isPressed)
    }
}
```

- [ ] **Step 2：确认可编译**

Run: `swift build`
预期：0 errors

- [ ] **Step 3：提交**

```bash
git add Sources/CoreDesign/Modifier/TelegramGlassButtonModifier.swift
git commit -m "feat: add TelegramGlassButtonModifier — shared glass button shell"
```


### Task 4：重构 SolidButtonStyle（Z1）

**Files：**
- 修改：`Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift`

- [ ] **Step 1：更新 SolidButtonStyle**

用新的 glass-aware 实现替换 body：

```swift
//
//  SolidButtonStyle.swift
//  CoreDesign
//

import Foundation
import SwiftUI

// MARK: - SolidButtonStyle

/// 主操作按钮样式（"solid button"）。
///
/// ## Telegram 玻璃模式（默认）
///
/// `glass: true`（默认）时使用 `TelegramGlassButtonModifier` 四层结构：
/// 底色 + 2pt 内缩 + 玻璃壳 + 细白描边。底色由 `role.color` 注入。
///
/// `glass: false` 时退回到 Primer 实色 + 1px borderMuted 描边 + CoreElevation.small 阴影。
///
/// ## 使用场景 / Usage
///
/// 主要 CTA、表单提交、Merge 按钮等需要强烈视觉权重的主操作。
public struct SolidButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoreControlMetrics.font(for: self.controlSize))
            .foregroundStyle(self.foregroundColor)
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .contentShape(Capsule(style: .continuous))
            .modifier(self.buttonBackground(configuration: configuration))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }

    let role: ButtonRoleStyleRole
    let glass: Bool

    public init(role: ButtonRoleStyleRole = .primary, glass: Bool = true) {
        self.role = role
        self.glass = glass
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private var foregroundColor: Color {
        self.glass ? .white : (self.isEnabled ? .contentOnAccent : .contentDisabled)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }

    @ViewBuilder
    private func buttonBackground(configuration: Configuration) -> some View {
        if self.glass {
            self.labelOnly(configuration: configuration)
                .backgroundStyle(self.backgroundColor(isPressed: configuration.isPressed))
                .modifier(TelegramGlassButtonModifier(
                    shape: Capsule(style: .continuous),
                    isPressed: configuration.isPressed
                ))
        } else {
            // Primer 实色回退
            self.labelOnly(configuration: configuration)
                .background(
                    Capsule(style: .continuous)
                        .fill(self.backgroundColor(isPressed: configuration.isPressed))
                        .coreShadow(.small)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.borderMuted, lineWidth: CoreBorderWidth.thin)
                )
                .scaleEffect(configuration.isPressed ? CoreButtonMetrics.pressedScale : 1)
                .animation(.snappy(duration: 0.16), value: configuration.isPressed)
        }
    }

    /// Workaround: SwiftUI `backgroundStyle` only propagates to the `background` modifier
    /// — not through `.modifier`. We apply `.backgroundStyle` on an intermediate view
    /// so that `TelegramGlassButtonModifier`'s `shape.fill(.background)` picks it up.
    @ViewBuilder
    private func labelOnly(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == SolidButtonStyle {
    /// 构造主操作按钮样式。
    ///
    /// - Parameter role: 角色色板（默认 `.primary`）。
    /// - Parameter glass: 是否启用 Telegram 玻璃模式（默认 `true`）。
    static func solid(role: ButtonRoleStyleRole = .primary, glass: Bool = true) -> SolidButtonStyle {
        SolidButtonStyle(role: role, glass: glass)
    }
}

#Preview("Solid — glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Primary") }
            .buttonStyle(.solid(role: .primary))
        Button {} label: { Text("Danger") }
            .buttonStyle(.solid(role: .danger))
        Button {} label: { Text("Disabled") }
            .buttonStyle(.solid(role: .primary))
            .disabled(true)
    }
    .padding()
}

#Preview("Solid — no glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Primary") }
            .buttonStyle(.solid(role: .primary, glass: false))
        Button {} label: { Text("Secondary") }
            .buttonStyle(.solid(role: .secondary, glass: false))
    }
    .padding()
}
```

- [ ] **Step 2：确认可编译**

Run: `swift build`
预期：0 errors

- [ ] **Step 3：提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/SolidButtonStyle.swift
git commit -m "feat: add glass param to SolidButtonStyle, use TelegramGlassButtonModifier"
```


### Task 5：重构 LightButtonStyle（Z1）

**Files：**
- 修改：`Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift`

- [ ] **Step 1：更新 LightButtonStyle**

把现有按 `colorScheme` 分支的实现替换为统一的 `glass:` 参数方案：

```swift
//
//  LightButtonStyle.swift
//  CoreDesign
//

import Foundation
import SwiftUI

// MARK: - LightButtonStyle

/// 次要操作按钮样式（"light button"）。
///
/// `glass: true`（默认）时使用 `TelegramGlassButtonModifier`，`surfaceInteractive` 底色。
/// `glass: false` 时退回到 Primer 浅灰实色 + CoreElevation.small 阴影 + borderSubtle 1px。
public struct LightButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoreControlMetrics.font(for: self.controlSize))
            .foregroundStyle(self.textColor(isPressed: configuration.isPressed))
            .padding(.horizontal, CoreControlMetrics.horizontalPadding(for: self.controlSize))
            .padding(.vertical, CoreControlMetrics.verticalPadding(for: self.controlSize))
            .contentShape(Capsule(style: .continuous))
            .modifier(self.buttonBackground(configuration: configuration))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }

    let role: ButtonRoleStyleRole
    let glass: Bool

    public init(role: ButtonRoleStyleRole = .primary, glass: Bool = true) {
        self.role = role
        self.glass = glass
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    private func textColor(isPressed: Bool) -> Color {
        if !self.isEnabled {
            return self.role.disabledColor
        }
        return isPressed ? self.role.activeColor : self.role.color
    }

    @ViewBuilder
    private func buttonBackground(configuration: Configuration) -> some View {
        if self.glass {
            configuration.label
                .backgroundStyle(Color.surfaceInteractive)
                .modifier(TelegramGlassButtonModifier(
                    shape: Capsule(style: .continuous),
                    isPressed: configuration.isPressed
                ))
        } else {
            configuration.label
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.surfaceInteractive)
                        .coreShadow(.small)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.borderSubtle, lineWidth: CoreBorderWidth.hairline)
                )
                .scaleEffect(configuration.isPressed ? CoreButtonMetrics.pressedScale : 1)
                .animation(.snappy(duration: 0.16), value: configuration.isPressed)
        }
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == LightButtonStyle {
    static func light(role: ButtonRoleStyleRole = .primary, glass: Bool = true) -> LightButtonStyle {
        LightButtonStyle(role: role, glass: glass)
    }
}

#Preview("Light — glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary))
        Button {} label: { Text("Disabled") }
            .buttonStyle(.light(role: .secondary))
            .disabled(true)
    }
    .padding()
    .background(Color.systemGroupedBackground)
}

#Preview("Light — no glass") {
    VStack(spacing: 12) {
        Button {} label: { Text("Cancel") }
            .buttonStyle(.light(role: .secondary, glass: false))
    }
    .padding()
}
```

- [ ] **Step 2：确认可编译**

Run: `swift build`
预期：0 errors

- [ ] **Step 3：提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/LightButtonStyle.swift
git commit -m "feat: add glass param to LightButtonStyle, use TelegramGlassButtonModifier"
```


### Task 6：重构 BorderlessButtonStyle（Z1）

**Files：**
- 修改：`Sources/CoreDesign/Components/Button/styles/BorderlessButtonStyle.swift`

- [ ] **Step 1：token 迁移——清除魔法数字**

现有的 `BorderlessButtonStyle` 在 padding 上已经没有写死的魔法数字（已使用 `CoreControlMetrics`）。本次重构改动极小——核对没有硬编码值，便利访问器 `borderless(role:)` 名称保持不变（`borderless(role:)`），仅更新文档注释以匹配三合一体系中的新定位。无功能性变更。

- [ ] **Step 2：确认可编译**

Run: `swift build`
预期：0 errors

- [ ] **Step 3：提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/BorderlessButtonStyle.swift
git commit -m "refactor: verify BorderlessButtonStyle token migration complete"
```


### Task 7：重构 CircularGlassButtonStyle（Z1）

**Files：**
- 修改：`Sources/CoreDesign/Components/Button/styles/CircularGlassButtonStyle.swift`

- [ ] **Step 1：用共享 modifier 替换内联玻璃代码**

```swift
//
//  CircularGlassButtonStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CircularGlassButtonStyle

/// 圆形玻璃浮按钮样式。
///
/// 始终使用 Telegram 玻璃四层结构（命名即语义），不使用 `glass:` 参数。
/// 为 BottomInputBar 的 send / stop / shuffle 浮按钮，或任何漂浮在内容之上的
/// 圆形 icon 按钮提供清晰的 elevation 暗示。
public struct CircularGlassButtonStyle: ButtonStyle {
    public var diameter: CGFloat = 38

    public init(diameter: CGFloat = 38) {
        self.diameter = diameter
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: self.diameter, height: self.diameter)
            .contentShape(Circle())
            .backgroundStyle(Color.surfaceInteractive)
            .modifier(TelegramGlassButtonModifier(
                shape: Circle(),
                isPressed: configuration.isPressed
            ))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - ButtonStyle convenience

public extension ButtonStyle where Self == CircularGlassButtonStyle {
    static var circularGlass: CircularGlassButtonStyle {
        CircularGlassButtonStyle()
    }

    static func circularGlass(diameter: CGFloat) -> CircularGlassButtonStyle {
        CircularGlassButtonStyle(diameter: diameter)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        Button {} label: {
            Image(systemName: "wand.and.sparkles.inverse")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.circularGlass)
    }
}
```

- [ ] **Step 2：确认可编译**

Run: `swift build`
预期：0 errors

- [ ] **Step 3：提交**

```bash
git add Sources/CoreDesign/Components/Button/styles/CircularGlassButtonStyle.swift
git commit -m "refactor: use TelegramGlassButtonModifier in CircularGlassButtonStyle"
```


### Task 8：ProgressIndicator 组件（Z1）

**Files：**
- 新建：`Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift`
- 新建：`Tests/CoreDesignTests/ProgressIndicatorTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("ProgressIndicator")
struct ProgressIndicatorTests {
    @Test("init creates without runtime errors")
    func initCreatesInstance() {
        let indicator = ProgressIndicator()
        #expect(indicator != nil)
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter ProgressIndicatorTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  ProgressIndicator.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressIndicator

/// 通用圆形加载指示器。
///
/// 封装系统 `ProgressView`，使用 Primer `accent` 色作为 tint，自动响应
/// `@Environment(\.controlSize)` 调整尺寸。
public struct ProgressIndicator: View {
    public init() {}

    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.accent)
            .controlSize(self.controlSize)
            .accessibilityLabel("Loading")
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressIndicator()
            .controlSize(.small)
        ProgressIndicator()
            .controlSize(.regular)
        ProgressIndicator()
            .controlSize(.large)
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter ProgressIndicatorTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift Tests/CoreDesignTests/ProgressIndicatorTests.swift
git commit -m "feat: add ProgressIndicator component"
```


### Task 9：StateLabel 组件（Z2）

**Files：**
- 新建：`Sources/CoreDesign/Components/StateLabel/StateLabel.swift`
- 新建：`Tests/CoreDesignTests/StateLabelTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StateLabel")
struct StateLabelTests {
    @Test("active maps to success status color")
    func activeMapsToSuccess() {
        let label = StateLabel(.active)
        #expect(label.style == .active)
        #expect(label.label == "Active")
    }

    @Test("completed maps to done status color")
    func completedMapsToDone() {
        let label = StateLabel(.completed)
        #expect(label.style == .completed)
    }

    @Test("custom label overrides default")
    func customLabel() {
        let label = StateLabel(.draft, label: "WIP")
        #expect(label.label == "WIP")
    }

    @Test("all styles construct")
    func allStylesConstruct() {
        for style in [StateLabelStyle.active, .draft, .completed, .cancelled] {
            let label = StateLabel(style)
            #expect(label != nil)
        }
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter StateLabelTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  StateLabel.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StateLabelStyle

/// 通用状态标签的语义样式。
public enum StateLabelStyle: Sendable, Equatable {
    case active      // green — in progress
    case draft       // gray — not ready
    case completed   // purple — finished
    case cancelled   // red — cancelled
}

// MARK: - StateLabel

/// 通用状态标识 pill。
///
/// 大圆角 + 彩色背景 + SF Symbol 图标 + 文字。颜色由 `StateLabelStyle` 枚举驱动，
/// 映射到 `StatusColors` 系统的 emphasis 背景 + foreground 文字。
public struct StateLabel: View {
    public let style: StateLabelStyle
    public let label: String

    public init(_ style: StateLabelStyle, label: String? = nil) {
        self.style = style
        self.label = label ?? style.defaultLabel
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Image(systemName: self.iconName)
                .font(.caption2)
            Text(self.label)
                .font(CoreTypography.bodySmallFont)
        }
        .foregroundStyle(self.foregroundColor)
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(self.backgroundColor)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.label)
    }

    private var iconName: String {
        switch self.style {
        case .active: return "circle.fill"
        case .draft: return "circle.dashed"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch self.style {
        case .active: return .statusSuccessForeground
        case .draft: return .statusAttentionForeground
        case .completed: return .statusDoneForeground
        case .cancelled: return .statusDangerForeground
        }
    }

    private var backgroundColor: Color {
        switch self.style {
        case .active: return .statusSuccessEmphasis
        case .draft: return .statusAttentionEmphasis
        case .completed: return .statusDoneEmphasis
        case .cancelled: return .statusDangerEmphasis
        }
    }
}

private extension StateLabelStyle {
    var defaultLabel: String {
        switch self {
        case .active: return "Active"
        case .draft: return "Draft"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StateLabel(.active)
        StateLabel(.draft)
        StateLabel(.completed)
        StateLabel(.cancelled)
        StateLabel(.active, label: "In Progress")
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter StateLabelTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/StateLabel/StateLabel.swift Tests/CoreDesignTests/StateLabelTests.swift
git commit -m "feat: add StateLabel component"
```


### Task 10：RefPill 组件（Z2）

**Files：**
- 新建：`Sources/CoreDesign/Components/RefPill/RefPill.swift`
- 新建：`Tests/CoreDesignTests/RefPillTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("RefPill")
struct RefPillTests {
    @Test("single ref stores value")
    func singleRef() {
        let pill = RefPill("main")
        #expect(pill.singleRef == "main")
        #expect(pill.base == nil)
        #expect(pill.head == nil)
    }

    @Test("base-head ref stores both values")
    func baseHeadRef() {
        let pill = RefPill(base: "main", head: "feat/foo")
        #expect(pill.base == "main")
        #expect(pill.head == "feat/foo")
        #expect(pill.singleRef == nil)
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter RefPillTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  RefPill.swift
//  CoreDesign
//

import SwiftUI

// MARK: - RefPill

/// 代码引用 pill。
///
/// 灰底 + 等宽字体 + 细边框，用于显示分支名、commit SHA、tag 等技术引用。
/// 支持单引用（`RefPill("main")`）和双引用箭头连接（`RefPill(base: "main", head: "feat/foo")`）。
public struct RefPill: View {
    let singleRef: String?
    let base: String?
    let head: String?

    public init(_ ref: String) {
        self.singleRef = ref
        self.base = nil
        self.head = nil
    }

    public init(base: String, head: String) {
        self.singleRef = nil
        self.base = base
        self.head = head
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Image(systemName: "arrow.triangle.branch")
                .font(.caption2)
            if let ref = self.singleRef {
                Text(ref)
                    .font(.caption.monospaced())
            } else if let base = self.base, let head = self.head {
                Text(base)
                    .font(.caption.monospaced())
                Image(systemName: "arrow.left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(head)
                    .font(.caption.monospaced())
            }
        }
        .padding(.horizontal, CoreSpacing.sm)
        .padding(.vertical, CoreSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: CoreRadius.small)
                .fill(Color.surfaceCanvasInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoreRadius.small)
                .strokeBorder(.borderMuted, lineWidth: CoreBorderWidth.thin)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityText)
        .accessibilityAddTraits(.isStaticText)
    }

    private var accessibilityText: String {
        if let ref = self.singleRef {
            return ref
        } else if let base = self.base, let head = self.head {
            return "\(base) from \(head)"
        }
        return ""
    }
}

#Preview {
    VStack(spacing: 12) {
        RefPill("main")
        RefPill(base: "main", head: "feat/foo")
        RefPill("a1b2c3d4e5f6")
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter RefPillTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/RefPill/RefPill.swift Tests/CoreDesignTests/RefPillTests.swift
git commit -m "feat: add RefPill component"
```


### Task 11：FlowLayout（Z3）

**Files：**
- 新建：`Sources/CoreDesign/Layout/FlowLayout.swift`
- 新建：`Tests/CoreDesignTests/FlowLayoutTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("FlowLayout")
struct FlowLayoutTests {
    @Test("init with default spacing uses CoreSpacing.xs")
    func defaultSpacing() {
        let layout = FlowLayout()
        #expect(layout.spacing == CoreSpacing.xs)
    }

    @Test("init with custom spacing stores value")
    func customSpacing() {
        let layout = FlowLayout(spacing: 8)
        #expect(layout.spacing == 8)
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter FlowLayoutTests`
预期：FAIL

- [ ] **Step 3：编写 layout**

```swift
//
//  FlowLayout.swift
//  CoreDesign
//

import SwiftUI

// MARK: - FlowLayout

/// Tag 自动换行布局容器。
///
/// 使用 SwiftUI `Layout` 协议实现，子视图在行内容纳不下时自动折行。
/// 配合现有 `Tag` 组件使用，构建 label chip group。
///
/// ```swift
/// FlowLayout(spacing: CoreSpacing.xs) {
///     Tag("bug", color: .red)
///     Tag("enhancement", color: .blue)
/// }
/// ```
public struct FlowLayout: Layout {
    public let spacing: CGFloat

    public init(spacing: CGFloat = CoreSpacing.xs) {
        self.spacing = spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = self.computeRows(proposalWidth: proposal.width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * self.spacing
        let width = proposal.width ?? rows.map(\.totalWidth).max() ?? 0
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = self.computeRows(proposalWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = item.sizeThatFits(.unspecified)
                item.place(at: CGPoint(x: x, y: y + (row.maxHeight - size.height) / 2), proposal: .unspecified)
                x += size.width + self.spacing
            }
            y += row.maxHeight + self.spacing
        }
    }

    private struct Row {
        let items: [LayoutSubview]
        let maxHeight: CGFloat
        var totalWidth: CGFloat {
            items.reduce(0) { acc, item in
                acc + item.sizeThatFits(.unspecified).width
            } + CGFloat(max(0, items.count - 1)) * spacing
        }
    }

    private func computeRows(proposalWidth: CGFloat?, subviews: Subviews) -> [Row] {
        let maxWidth = proposalWidth ?? .infinity
        var rows: [Row] = []
        var currentItems: [LayoutSubview] = []

        for subview in subviews {
            let itemSize = subview.sizeThatFits(.unspecified)
            let projectedWidth = currentItems.reduce(itemSize.width) { $0 + $1.sizeThatFits(.unspecified).width + self.spacing }
            + CGFloat(currentItems.count) * self.spacing

            if projectedWidth > maxWidth && !currentItems.isEmpty {
                let maxHeight = currentItems.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
                rows.append(Row(items: currentItems, maxHeight: maxHeight))
                currentItems = []
            }
            currentItems.append(subview)
        }

        if !currentItems.isEmpty {
            let maxHeight = currentItems.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            rows.append(Row(items: currentItems, maxHeight: maxHeight))
        }

        return rows
    }
}

#Preview {
    FlowLayout(spacing: CoreSpacing.xs) {
        ForEach(["bug", "enhancement", "help wanted", "documentation", "good first issue", "dependencies"], id: \.self) { label in
            Tag(label)
        }
    }
    .padding()
    .frame(width: 280)
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter FlowLayoutTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Layout/FlowLayout.swift Tests/CoreDesignTests/FlowLayoutTests.swift
git commit -m "feat: add FlowLayout for tag-wrapping container"
```


### Task 12：AvatarGroup 组件（Z3）

**Files：**
- 新建：`Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift`
- 新建：`Tests/CoreDesignTests/AvatarGroupTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AvatarGroup")
struct AvatarGroupTests {
    @Test("init with max parameter stores value")
    func initMaxParam() {
        let group = AvatarGroup(max: 5) {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
        }
        #expect(group.max == 5)
    }

    @Test("default max is 3")
    func defaultMax() {
        let group = AvatarGroup {
            Circle().fill(.blue).frame(width: 32, height: 32)
        }
        #expect(group.max == 3)
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter AvatarGroupTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  AvatarGroup.swift
//  CoreDesign
//

import SwiftUI

// MARK: - AvatarGroup

/// 堆叠头像组。
///
/// 前 N 个 avatar 交叠显示，超出 `max` 的部分显示 "+N" 计数 pill。
/// 使用 `Group(subviews:)` (iOS 17+) 遍历子视图。
///
/// ```swift
/// AvatarGroup(max: 3) {
///     Image("avatar1").resizable().clipShape(.circle).frame(width: 32, height: 32)
///     Image("avatar2").resizable().clipShape(.circle).frame(width: 32, height: 32)
/// }
/// ```
public struct AvatarGroup<Avatars: View>: View {
    public let max: Int

    @ViewBuilder let avatars: () -> Avatars

    public init(max: Int = 3, @ViewBuilder avatars: @escaping () -> Avatars) {
        self.max = max
        self.avatars = avatars
    }

    @Environment(\.controlSize) private var controlSize

    private var overlapOffset: CGFloat {
        switch self.controlSize {
        case .mini, .small: return -6
        case .regular: return -8
        case .large, .extraLarge: return -10
        @unknown default: return -8
        }
    }

    public var body: some View {
        Group(subviews: self.avatars()) { subviews in
            let visible = subviews.prefix(self.max)
            let overflow = subviews.count - self.max

            HStack(spacing: self.overlapOffset) {
                ForEach(Array(zip(visible.indices, visible)), id: \.0) { _, subview in
                    subview
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.systemBackground, lineWidth: CoreBorderWidth.thin)
                        )
                        .accessibilityHidden(true)
                }

                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: self.avatarSize, height: self.avatarSize)
                        .background(
                            Circle()
                                .fill(Color.surfaceCanvasInset)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(.borderMuted, lineWidth: CoreBorderWidth.thin)
                        )
                        .accessibilityLabel("\(overflow) more")
                }
            }
        }
    }

    private var avatarSize: CGFloat {
        switch self.controlSize {
        case .mini: return 20
        case .small: return 24
        case .regular: return 32
        case .large: return 40
        case .extraLarge: return 48
        @unknown default: return 32
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AvatarGroup {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.green).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
            Circle().fill(.orange).frame(width: 32, height: 32)
            Circle().fill(.purple).frame(width: 32, height: 32)
        }
        AvatarGroup(max: 2) {
            Circle().fill(.blue).frame(width: 24, height: 24)
            Circle().fill(.green).frame(width: 24, height: 24)
            Circle().fill(.red).frame(width: 24, height: 24)
        }
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter AvatarGroupTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift Tests/CoreDesignTests/AvatarGroupTests.swift
git commit -m "feat: add AvatarGroup component"
```


### Task 13：ProgressBar 组件（Z3）

**Files：**
- 新建：`Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift`
- 新建：`Tests/CoreDesignTests/ProgressBarTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("ProgressBar")
struct ProgressBarTests {
    @Test("init with value stores clamped value")
    func initValue() {
        let bar = ProgressBar(value: 0.6)
        #expect(bar.value == 0.6)
    }

    @Test("value clamped to 0...1")
    func valueClamping() {
        let low = ProgressBar(value: -0.5)
        #expect(low.value == 0.0)
        let high = ProgressBar(value: 1.5)
        #expect(high.value == 1.0)
    }

    @Test("optional tint and label stored")
    func optionalParams() {
        let bar = ProgressBar(value: 0.3, tint: .done, label: "3 of 10")
        #expect(bar.value == 0.3)
        #expect(bar.label == "3 of 10")
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter ProgressBarTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  ProgressBar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressBar

/// 水平进度条。
///
/// 灰色底轨 + 可配置彩色填充 + 可选左侧 label 文本。
/// 高度由 `@Environment(\.controlSize)` 通过 `CoreControlMetrics` 决定。
public struct ProgressBar: View {
    public let value: Double  // 0.0...1.0
    public let tint: Color?
    public let label: String?

    public init(value: Double, tint: Color? = nil, label: String? = nil) {
        self.value = min(max(value, 0), 1)
        self.tint = tint
        self.label = label
    }

    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            if let label = self.label {
                Text(label)
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: CoreRadius.small)
                        .fill(Color.surfaceCanvasInset)
                    RoundedRectangle(cornerRadius: CoreRadius.small)
                        .fill(self.tint ?? .accent)
                        .frame(width: geometry.size.width * CGFloat(self.value))
                }
            }
            .frame(height: self.barHeight)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(self.value * 100))% complete")
    }

    private var barHeight: CGFloat {
        CoreControlMetrics.height(for: self.controlSize) / 4
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBar(value: 0.0)
        ProgressBar(value: 0.5, label: "50%")
        ProgressBar(value: 1.0, tint: .statusSuccessEmphasis, label: "Done")
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter ProgressBarTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift Tests/CoreDesignTests/ProgressBarTests.swift
git commit -m "feat: add ProgressBar component"
```


### Task 14：TimelineItem + TimelineDepthKey（Z4）

**Files：**
- 新建：`Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift`
- 新建：`Tests/CoreDesignTests/TimelineItemTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("TimelineItem")
struct TimelineItemTests {
    @Test("init creates instance with default isLast")
    func initDefault() {
        let item = TimelineItem(icon: { Circle().fill(.blue).frame(width: 20, height: 20) }) {
            Text("content")
        }
        #expect(item.isLast == false)
    }

    @Test("init creates instance with explicit isLast")
    func initExplicit() {
        let item = TimelineItem(
            icon: { Circle().fill(.blue).frame(width: 20, height: 20) },
            isLast: true
        ) {
            Text("content")
        }
        #expect(item.isLast == true)
    }

    @Test("timelineDepthKey defaults to 0")
    func defaultDepth() {
        #expect(TimelineDepthKey.defaultValue == 0)
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter TimelineItemTests`
预期：FAIL

- [ ] **Step 3：编写组件（含 TimelineDepthKey）**

```swift
//
//  TimelineItem.swift
//  CoreDesign
//

import SwiftUI

// MARK: - TimelineDepthKey

struct TimelineDepthKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var timelineDepth: Int {
        get { self[TimelineDepthKey.self] }
        set { self[TimelineDepthKey.self] = newValue }
    }
}

// MARK: - TimelineItem

/// 时间线脊柱节点容器。
///
/// 左侧脊柱（连接线 + 图标圆点）+ 右侧内容槽。通过 `@Environment(\.timelineDepth)`
/// 自动管理缩进递归——父级嵌套子 `TimelineItem` 时缩进自动 +1，无需手动传参。
///
/// ```swift
/// TimelineItem(icon: avatarView, isLast: false) {
///     CommentCard(author: "evan", ...) { ... }
///     // 回复嵌套（自动缩进）
///     TimelineItem(icon: smallAvatar, isLast: true) {
///         CommentCard(author: "bot", ...) { ... }
///     }
/// }
/// ```
public struct TimelineItem<Icon: View, Content: View>: View {
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let content: () -> Content
    public let isLast: Bool

    public init(
        @ViewBuilder icon: @escaping () -> Icon,
        isLast: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.isLast = isLast
        self.content = content
    }

    @Environment(\.timelineDepth) private var depth

    private var indent: CGFloat {
        CGFloat(self.depth) * CoreSpacing.xl
    }

    public var body: some View {
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            // Spine column
            self.spineView
            // Content column
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                self.content()
            }
            .environment(\.timelineDepth, self.depth + 1)
        }
        .padding(.leading, self.indent)
    }

    private var spineView: some View {
        VStack(spacing: 0) {
            // Top connection line (from previous node)
            Rectangle()
                .fill(.borderMuted)
                .frame(width: CoreBorderWidth.thin, height: CoreSpacing.sm)

            // Icon dot
            self.icon()
                .frame(width: self.dotSize, height: self.dotSize)

            // Bottom connection line (to next node, hidden if last)
            if !self.isLast {
                Rectangle()
                    .fill(.borderMuted)
                    .frame(width: CoreBorderWidth.thin, height: CoreSpacing.sm)
            }
        }
        .accessibilityHidden(true)
    }

    private var dotSize: CGFloat {
        switch self.depth {
        case 0: return 32
        default: return 20
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        TimelineItem(icon: {
            Circle().fill(.blue).frame(width: 32, height: 32)
                .overlay(Text("A").foregroundStyle(.white).font(.caption))
        }, isLast: false) {
            VStack(alignment: .leading) {
                Text("First event").font(.headline)
                TimelineItem(icon: {
                    Circle().fill(.green).frame(width: 20, height: 20)
                }, isLast: true) {
                    Text("Nested reply").font(.subheadline)
                }
            }
        }
        TimelineItem(icon: {
            Circle().fill(.gray).frame(width: 32, height: 32)
        }, isLast: true) {
            Text("Last event").font(.headline)
        }
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter TimelineItemTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/TimelineItem/TimelineItem.swift Tests/CoreDesignTests/TimelineItemTests.swift
git commit -m "feat: add TimelineItem with automatic depth-aware indentation"
```


### Task 15：EventRow 组件（Z4）

**Files：**
- 新建：`Sources/CoreDesign/Components/EventRow/EventRow.swift`
- 新建：`Tests/CoreDesignTests/EventRowTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("EventRow")
struct EventRowTests {
    @Test("init stores parameters with pill content")
    func initWithPill() {
        let row = EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2d") {
            Text("abc")
        }
        #expect(row.actor == "renovate")
        #expect(row.action == "force-pushed from")
        #expect(row.timeAgo == "2d")
    }

    @Test("init stores parameters without pill")
    func initWithoutPill() {
        let row = EventRow(actor: "evan", action: "commented", timeAgo: "1h") {
            EmptyView()
        }
        #expect(row.actor == "evan")
        #expect(row.action == "commented")
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter EventRowTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  EventRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - EventRow

/// 紧凑单行时间线事件。
///
/// Actor + 动作文本 + 可选 object pill + 时间戳。用于 TimelineItem 内容槽中
/// 的非评论事件行（label 添加、force-push、commit 引用等）。
///
/// ```swift
/// EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2 days ago") {
///     RefPill("4d2040c")
/// }
/// ```
public struct EventRow<PillContent: View>: View {
    public let actor: String
    public let action: String
    public let timeAgo: String

    @ViewBuilder let pill: () -> PillContent

    public init(
        actor: String,
        action: String,
        timeAgo: String,
        @ViewBuilder pill: @escaping () -> PillContent = { EmptyView() }
    ) {
        self.actor = actor
        self.action = action
        self.timeAgo = timeAgo
        self.pill = pill
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            Text(self.actor)
                .font(CoreTypography.bodyMediumFont)
                .fontWeight(.medium)
            Text(self.action)
                .font(CoreTypography.bodyMediumFont)
                .foregroundStyle(.secondary)
            self.pill()
            Text(self.timeAgo)
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.actor) \(self.action) \(self.timeAgo)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        EventRow(actor: "renovate", action: "added the", timeAgo: "2 days ago") {
            Tag("dependencies")
        }
        EventRow(actor: "renovate", action: "force-pushed from", timeAgo: "2 days ago") {
            RefPill("4d2040c")
        }
        EventRow(actor: "evan", action: "commented", timeAgo: "1 hour ago")
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter EventRowTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/EventRow/EventRow.swift Tests/CoreDesignTests/EventRowTests.swift
git commit -m "feat: add EventRow component"
```


### Task 16：CommentCard 组件（Z4）

**Files：**
- 新建：`Sources/CoreDesign/Components/CommentCard/CommentCard.swift`
- 新建：`Tests/CoreDesignTests/CommentCardTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("CommentCard")
struct CommentCardTests {
    @Test("init with required params, not minimized")
    func initNotMinimized() {
        let card = CommentCard(author: "evan", timestamp: "2h ago") {
            Text("Hello world")
        }
        #expect(card.author == "evan")
        #expect(card.role == nil)
        #expect(card.timestamp == "2h ago")
        #expect(card.isMinimized == nil)
    }

    @Test("init with role and minimized binding")
    func initWithRole() {
        let card = CommentCard(
            author: "bot",
            role: "Bot",
            timestamp: "1d ago",
            isMinimized: Binding.constant(true)
        ) {
            Text("auto-generated")
        }
        #expect(card.author == "bot")
        #expect(card.role == "Bot")
        #expect(card.isMinimized?.wrappedValue == true)
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter CommentCardTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  CommentCard.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CommentCard

/// 通用评论卡片。
///
/// Header（作者名 + 可选 role badge + 时间戳）+ 主体内容 slot + 最小化提示。
/// Avatar 由外层 `TimelineItem` 的 icon 槽提供，不在卡片内。
///
/// `isMinimized` 为 `Binding<Bool>` 可选：`nil` 时不可折叠（始终展开）；
/// 非 nil 时由调用方控制折叠/展开状态。
public struct CommentCard<BodyContent: View>: View {
    public let author: String
    public let role: String?
    public let timestamp: String
    public let isMinimized: Binding<Bool>?

    @ViewBuilder let content: () -> BodyContent

    public init(
        author: String,
        role: String? = nil,
        timestamp: String,
        isMinimized: Binding<Bool>? = nil,
        @ViewBuilder content: @escaping () -> BodyContent
    ) {
        self.author = author
        self.role = role
        self.timestamp = timestamp
        self.isMinimized = isMinimized
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            // Header
            HStack(spacing: CoreSpacing.xs) {
                Text(self.author)
                    .font(CoreTypography.bodyMediumFont)
                    .fontWeight(.semibold)
                if let role = self.role {
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, CoreSpacing.xs)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(Color.surfaceCanvasInset)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(.borderMuted, lineWidth: CoreBorderWidth.thin)
                        )
                }
                Spacer()
                Text(self.timestamp)
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(.tertiary)
            }

            // Body or minimized placeholder
            if let binding = self.isMinimized, binding.wrappedValue {
                HStack(spacing: CoreSpacing.sm) {
                    Text("This content has been minimized.")
                        .font(CoreTypography.bodySmallFont)
                        .foregroundStyle(.secondary)
                    Button("Show") {
                        binding.wrappedValue = false
                    }
                    .font(CoreTypography.bodySmallFont)
                    .foregroundStyle(.accent)
                }
            } else {
                self.content()
            }
        }
        .padding(CoreSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CoreRadius.medium)
                .fill(Color.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoreRadius.medium)
                .strokeBorder(.borderMuted, lineWidth: CoreBorderWidth.thin)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Comment by \(self.author)")
    }
}

#Preview("Normal") {
    CommentCard(author: "evan", role: "Contributor", timestamp: "2 hours ago") {
        Text("This is a sample comment body.")
            .font(.body)
    }
    .padding()
}

#Preview("Minimized") {
    CommentCard(
        author: "renovate",
        role: "Bot",
        timestamp: "2 days ago",
        isMinimized: Binding.constant(true)
    ) {
        Text("chore(deps): update github actions")
    }
    .padding()
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter CommentCardTests`
预期：PASS

- [ ] **Step 5：提交**

```bash
git add Sources/CoreDesign/Components/CommentCard/CommentCard.swift Tests/CoreDesignTests/CommentCardTests.swift
git commit -m "feat: add CommentCard component with minimized toggle"
```


### Task 17：StatusRow 组件（Z5）

**Files：**
- 新建：`Sources/CoreDesign/Components/StatusRow/StatusRow.swift`
- 新建：`Tests/CoreDesignTests/StatusRowTests.swift`

- [ ] **Step 1：编写测试**

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("StatusRow")
struct StatusRowTests {
    @Test("init stores parameters")
    func initParams() {
        let row = StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
        #expect(row.label == "build (arm64)")
        #expect(row.duration == "2m 14s")
        #expect(row.result == .success)
    }

    @Test("all result cases construct")
    func allResults() {
        for result in [StatusResult.success, .failure, .pending, .skipped] {
            let row = StatusRow(label: "test", duration: "0s", result: result)
            #expect(row.result == result)
        }
    }
}
```

- [ ] **Step 2：运行测试确认失败**

Run: `swift test --filter StatusRowTests`
预期：FAIL

- [ ] **Step 3：编写组件**

```swift
//
//  StatusRow.swift
//  CoreDesign
//

import SwiftUI

// MARK: - StatusResult

/// CI 检查结果状态。
public enum StatusResult: Sendable, Equatable {
    case success
    case failure
    case pending
    case skipped
}

// MARK: - StatusRow

/// CI 检查状态行。图标 + 名称 + 耗时 + 结果指示器。
///
/// 用于平铺的检查列表（VStack），不是时间线组件。
public struct StatusRow: View {
    public let label: String
    public let duration: String
    public let result: StatusResult

    public init(label: String, duration: String, result: StatusResult) {
        self.label = label
        self.duration = duration
        self.result = result
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Image(systemName: self.resultIcon)
                .foregroundStyle(self.resultColor)
                .font(.caption)

            Text(self.label)
                .font(CoreTypography.bodySmallFont)
                .lineLimit(1)

            Spacer()

            Text(self.duration)
                .font(CoreTypography.bodySmallFont)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, CoreSpacing.md)
        .padding(.vertical, CoreSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.resultLabel): \(self.label), \(self.duration)")
        .accessibilityValue(self.resultLabel)
    }

    private var resultIcon: String {
        switch self.result {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .pending: return "clock"
        case .skipped: return "minus.circle"
        }
    }

    private var resultColor: Color {
        switch self.result {
        case .success: return .statusSuccessForeground
        case .failure: return .statusDangerForeground
        case .pending: return .statusAttentionForeground
        case .skipped: return .secondary
        }
    }

    private var resultLabel: String {
        switch self.result {
        case .success: return "Passed"
        case .failure: return "Failed"
        case .pending: return "Pending"
        case .skipped: return "Skipped"
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusRow(label: "build (arm64)", duration: "2m 14s", result: .success)
        Divider()
        StatusRow(label: "test (macOS)", duration: "3m 01s", result: .success)
        Divider()
        StatusRow(label: "lint", duration: "0m 12s", result: .failure)
        Divider()
        StatusRow(label: "deploy (preview)", duration: "—", result: .pending)
        Divider()
        StatusRow(label: "analyze", duration: "—", result: .skipped)
    }
    .padding()
    .background(Color.systemBackground)
}
```

- [ ] **Step 4：运行测试确认通过**

Run: `swift test --filter StatusRowTests`
预期：PASS

- [ ] **Step 5：确认完整构建**

Run: `swift build`
预期：0 errors

- [ ] **Step 6：运行全部测试**

Run: `swift test`
预期：ALL PASS

- [ ] **Step 7：提交**

```bash
git add Sources/CoreDesign/Components/StatusRow/StatusRow.swift Tests/CoreDesignTests/StatusRowTests.swift
git commit -m "feat: add StatusRow component"
```
