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
