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
//   `Color.contentPrimary` / `.contentMuted` / `.contentSubtle`——第 3 层语义色是
//   `public extension Color` 上的**计算** `static var`，在 `defaultIsolation` 下
//   是 MainActor 隔离的（`static let` 才会按 SE-0434 隐式 `nonisolated`）。
//   给这个 enum 标 `nonisolated` ⇒ `error: main actor-isolated default value in a
//   nonisolated context`。要解开得先让整个色彩层 `nonisolated`，那是另一件事。
// · `BottomInputBarDefaults.placeholder` 走 `String(localized:bundle: .module)`,
//   而 `Bundle.module` 的访问器由 SwiftPM 生成在本 target 内、随 `defaultIsolation`
//   成为 MainActor 隔离 ⇒ `error: main actor-isolated static property 'module'
//   can not be referenced from a nonisolated context`。同 `CoreElevation` 家族。
