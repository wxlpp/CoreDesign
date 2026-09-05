import CoreDesign
import Foundation
import SwiftUI

// 每个函数都显式 `nonisolated`，模拟下游在非 MainActor 上下文中的使用。
// 这些类型都显式声明了 `Sendable`——作者有意让它们跨 actor 边界传递
// （`ToastItem` 的文档注释就写明了 `await MainActor.run { host.show(item) }`
// 这个用法）。若其中任何一个变回 MainActor 隔离，本文件会编译失败。

nonisolated func constructToastItem() -> String {
    let item = ToastItem(message: "hi", level: .info)
    return item.message
}

nonisolated func readBorderWidth() -> CGFloat {
    CoreBorderWidth.thin
}

nonisolated func compareBadgeVariant(_ a: BadgeVariant, _ b: BadgeVariant) -> Bool {
    a == b
}

// `StatusResult` 随 StatusRow 于 Issue #117 删除；改用保留下来的同构类型
// `StatusLevel`（同样 Sendable + Equatable）继续覆盖「在 nonisolated 上下文
// 比较状态枚举」这条路径。下方 `useStatusLevel()` 只构造不比较，覆盖面不重叠。
nonisolated func compareStatusLevel(_ a: StatusLevel, _ b: StatusLevel) -> Bool {
    a == b
}

nonisolated func compareStateLabelStyle(_ a: StateLabelStyle, _ b: StateLabelStyle) -> Bool {
    a == b
}

nonisolated func compareButtonRole(_ a: ButtonRoleStyleRole, _ b: ButtonRoleStyleRole) -> Bool {
    a == b
}

nonisolated func useSurfaceKind(_ kind: SurfaceKind) -> SurfaceKind {
    kind
}

nonisolated func useElevationLevel(_ level: CoreElevation.Level) -> CoreElevation.Level {
    level
}

nonisolated func useSpacingAndRadius() -> CGFloat {
    CoreSpacing.md + CoreRadius.medium
}

nonisolated func useBorderWidthAndMetrics() -> CGFloat {
    CoreBorderWidth.thin + CoreButtonMetrics.pressedScale + CoreControlMetrics.height(for: .regular)
}

// Issue #119 删除了 `*LineSpacing` / `*Tracking` 常量（连同手写字号表与 `Spec` 一起）；
// `CoreTypography.Token` 现在直接映射系统文本样式。这里改为构造并返回 `Token` 本身，
// 继续覆盖"nonisolated 访问 CoreTypography.Token 不触发 MainActor 隔离"这条路径。
nonisolated func useTypographyToken() -> CoreTypography.Token {
    .body
}

// 注意 `CoreElevation.spec(for:)` **不在**本 probe 覆盖范围：它读 asset-backed 的
// shadow 颜色，而那些颜色的初始化表达式含 `Bundle.module`——SwiftPM 把该访问器生成
// 在本 target 内，`defaultIsolation` 下它随之成为 MainActor 隔离，故整条
// CoreElevation 家族无法 nonisolated。详见 updates/92/ci-decision.md。

nonisolated func useToastDefaults() -> TimeInterval {
    ToastDefaults.duration
}

nonisolated func useStatusLevel() -> StatusLevel {
    .info
}

// 第 4 层「状态功能别名」的公开面。若 FunctionalColor 的 extension 漏加 public，
// 这里会编译失败（Issue #93 的 A2d）。
nonisolated func useFunctionalColors() -> [Color] {
    [.success, .info, .warning, .danger]
}

// 遮罩基色 token（`Colors/MaskColors.swift`，`#276`；**不在四层色彩之内**）。
// 一句话同时覆盖两半：漏 `public` ⇒ 本包解析不到符号；标成 MainActor 隔离
// ⇒ 这个 `nonisolated` 函数当场判红。
//
// ⚠️ **为什么明知已有覆盖还要加这三行**（#276 终审 F6）：终审实测本 token 今天已有
// **三个跨模块消费点**（`ProcessingSweep.swift` ×2、`AnimatedMeshGradient.swift` ×1），
// 且两个宿主都是 `nonisolated enum` ⇒ 去掉 `public` 或标 `@MainActor` 都会让
// `swift build` 硬红（29 处 / 1 处）。但那份覆盖是**偶然的**——它取决于那 3 个用点
// 继续存在，而本 PR 自己刚把第 4 个用点（`BeforeAfterSlider`）改成了 `clipShape`。
// ⇒ 这里把覆盖钉成**结构性**的，不再依赖生产代码的用点数量。
//
// ⚠️ **上一版只写到这里为止，等于"结构性保险"是句没有实证的自述**（#276 终审 C 节）。
// 照本仓「变异实证」惯例补上：先把上面那 3 个 Effects 用点**临时**换成 `Color.white`
//（抹掉偶然覆盖），再对 `maskOpaque` 各施加一次变异，`swift build` 原文如下 ——
// 两次都**只有这一行判红**，全包 error 计数各为 1、别处零 error
//（⚠️ `107` 是**复跑当时** `.maskOpaque` 那一行的位置，逐字照录的编译器原文；
// 在本文件里插删行会让它漂 ⇒ **别把它当行号引用**，承重的是"只有这一行"这件事）：
//
//     # 变异 a：`public extension Color` → `extension Color`
//     NonisolatedUsage.swift:107:6: error: 'maskOpaque' is inaccessible due to
//                                  'internal' protection level
//
//     # 变异 b：给 `maskOpaque` 标 `@MainActor`
//     NonisolatedUsage.swift:107:6: error: main actor-isolated static property
//                                  'maskOpaque' can not be referenced from a
//                                  nonisolated context
//
// ⇒ 这 3 行**独立承重**，且注释开头那句"一句话同时覆盖两半"的**两半都承**。
nonisolated func useMaskOpaque() -> Color {
    .maskOpaque
}

// `CoreShape` 是 #119 引入的圆角唯一出口，而它的主要消费点是 `Shape.path(in:)` 这类
// nonisolated 同步上下文。本包走 `defaultIsolation(MainActor)`，漏 `nonisolated` 关键字
// 时这里会编译失败——#122 迁移调用点前先在这里挡住。
nonisolated func useCoreShape() -> some Shape {
    CoreShape.rounded(CoreRadius.medium)
}

// `SettingsRowMetrics` 是**布局常量命名空间**（图标列宽、分隔线 inset），
// 它的存在理由逐字写在类型文档里：「让调用方把自定义行/内容对齐到 `SettingsRow`
// 的网格，而不必抄魔数」——那正是调用方在**自己**的布局计算里读它，而布局计算
// 不必然发生在主 actor 上。
//
// ⚠️ 它此前是 `public enum`（本包 `.defaultIsolation(MainActor.self)` ⇒ MainActor
// 隔离），从本文件这样的 `nonisolated` 上下文读它是**硬 error**、不是 warning：
//
//     error: main actor-isolated static property 'iconSquareSize'
//            can not be referenced from a nonisolated context
//
// 与 `#290` 那 5 条同一形态、同一根因（默认值 / 布局常量被 `defaultIsolation`
// 卷进 MainActor），只是严重度不同——那 5 条长在 `View` / `Transition` 上，
// 隔离由 SwiftUI 协议遵从推断而来，编译器降级成 warning；这一组的隔离直接
// 来自 `defaultIsolation`，是 error。⇒ 修法相同：`public nonisolated enum`。
//
// ⚠️ **本函数现在是 probe 侧对 `SettingsRowMetrics` 的唯一覆盖**（PR #304 第 2 轮
// 终审 I-4）：`PublicVisibility.swift` 里那个 `@MainActor consumeSettingsRowMetrics()`
// 读的是**逐字相同、顺序相同**的同 6 个成员、同在 `DownstreamProbe` 这**一个**外部
// target 里 ⇒ 可见性覆盖 100% 重叠，而隔离那一侧它比本函数**弱**（`nonisolated` 被
// 拿掉时它不会红）。严格被本函数支配 ⇒ 已删除。本函数因此同时承担两件事：
// **pin 住 `public` 可见性**，与**pin 住 `nonisolated` 可达性**。
//
// ⚠️ 前一件不是冗余的：`SettingsRowMetrics` 从 internal 改 public（`0.6.0` item 2）
// 的**全部交付物**就是「下游能读这 6 个成员」，而若它被改回 internal，库内
// `@testable` 测试、`App/` 预览宿主、其余既有 probe 文件**没有一个**会红
// （无一从外部包引用它）——只有本函数会。
//
// ⚠️ 连同删掉的还有它头上那段 F-5 更正记录，照录于此以免有人重新推导出旧结论：
// **上一版那里写「必须 @MainActor：`.defaultIsolation(MainActor.self)` 下两个计算属性
// （`iconAlignedDividerInset` / `textAlignedDividerInset`）是 MainActor 隔离的，四个
// `static let` 跨模块也非 nonisolated 可达（SE-0434 只放开模块内）」——`#290` 把
// `SettingsRowMetrics` 改成 `public nonisolated enum` 之后，这段话的每一个分句都已为
// 假**（PR #304 第 1 轮终审 F-5）。反证就是本函数：6 个成员（含那两个计算属性）跨模块
// `nonisolated` 逐条读、干净编译。SE-0434 那半句本身也是误引，射程见下方
// `SidebarTextStyle` 那条更正。
nonisolated func useSettingsRowMetrics() -> [CGFloat] {
    [
        SettingsRowMetrics.iconSquareSize,
        SettingsRowMetrics.iconTitleGap,
        SettingsRowMetrics.horizontalPadding,
        SettingsRowMetrics.iconCornerRadius,
        SettingsRowMetrics.iconAlignedDividerInset,
        SettingsRowMetrics.textAlignedDividerInset,
    ]
}

// ⚠️ **`SidebarTextStyle` 与 `BottomInputBarDefaults` 有意不在本文件**，理由与
// `CoreElevation.spec(for:)` 那条逐字同源，只是上游不同（#290 实测）：
// · `SidebarTextStyle.primary/secondary/tertiary` 的初始化表达式是
//   `Color.contentPrimary` / `.contentMuted` / `.contentSubtle`，而**这些表达式在
//   模块内求值**——`CoreDesign` 自己开了 `.defaultIsolation(MainActor.self)`，于是
//   模块内的色彩层整体是 MainActor 隔离的 ⇒ 一个 `nonisolated` 的静态存储属性
//   用不了它。给这个 enum 标 `nonisolated` ⇒ `error: main actor-isolated default
//   value in a nonisolated context`。要解开得先让整个色彩层 `nonisolated`，
//   那是另一件事。
//
//   ⚠️ **上一版这里写「第 3 层语义色是**计算** `static var` 所以隔离，`static let`
//   才会按 SE-0434 隐式 `nonisolated`」——实测为假，照录更正**（PR #304 终审 F-2）：
//   · **判别式不是 `static let` vs 计算 `static var`**。`Color.success` 是
//     `public static let`（`Sources/CoreDesign/Colors/FunctionalColor.swift`），
//     往 `Sources/CoreDesign/` 塞一个 `nonisolated func { Color.success }` 同样
//     当场 `error: main actor-isolated static property 'success' can not be
//     referenced from a nonisolated context`——与计算属性 `Color.contentPrimary`
//     在同一次构建里给出**一模一样**的诊断。两者一视同仁。
//   · **SE-0434 被误引**。提案原文讲的是「global-actor-isolated **value type** 里
//     `Sendable` 类型的**实例存储属性**，在**定义它的模块内**被当作 `nonisolated`」
//     ——与 `static` 成员无关，射程也只到模块内。
//   · **而从下游看这句话是反的**：本文件 `useFunctionalColors()` 与
//     `PublicVisibility.swift` 的对照面就是活证据——本包（独立消费包）干净重建
//     零 warning 零 error，其中 `nonisolated func useFunctionalColors()` 直接读
//     `.success` / `.info` / `.warning` / `.danger`。⇒ 第 3/4 层色彩 token
//     **跨模块反而是 nonisolated 可达的**，MainActor 只在**模块内**成立。
//     本条「不可修」成立的理由因此只有一条：`SidebarTextStyle` 的初值表达式
//     求值发生在**模块内**。
// · `BottomInputBarDefaults.placeholder` 走 `String(localized:bundle: .module)`,
//   而 `Bundle.module` 的访问器由 SwiftPM 生成在本 target 内、随 `defaultIsolation`
//   成为 MainActor 隔离 ⇒ `error: main actor-isolated static property 'module'
//   can not be referenced from a nonisolated context`。同 `CoreElevation` 家族。
