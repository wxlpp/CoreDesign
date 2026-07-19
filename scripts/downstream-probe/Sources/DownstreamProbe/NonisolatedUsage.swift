import CoreDesign
import Foundation

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

nonisolated func compareStatusResult(_ a: StatusResult, _ b: StatusResult) -> Bool {
    a == b
}

nonisolated func compareStateLabelStyle(_ a: StateLabelStyle, _ b: StateLabelStyle) -> Bool {
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

nonisolated func useTypographyToken() -> CGFloat {
    CoreTypography.bodyLargeLineSpacing
}

// 注意 `CoreElevation.spec(for:)` **不在**本 probe 覆盖范围：它读 asset-backed 的
// shadow 颜色，而那些颜色的初始化表达式含 `Bundle.module`——SwiftPM 把该访问器生成
// 在本 target 内，`defaultIsolation` 下它随之成为 MainActor 隔离，故整条
// CoreElevation 家族无法 nonisolated。详见 updates/92/ci-decision.md。

nonisolated func useToastDefaults() -> TimeInterval {
    ToastDefaults.duration
}

nonisolated func useToastLevel() -> ToastLevel {
    .info
}
