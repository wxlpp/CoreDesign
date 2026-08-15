//
//  Card.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CardKind

/// `Card` 的容器观感取值域——**刻意只有两个 case**。
///
/// ⚠️ **为什么不直接暴露 `SurfaceKind`**（#41 裁决 1 / 评审 I5）：`Card` 是
/// 「`.surface(.content)` 的薄封装」（见下方 `Card` 文档与 CoreDesign 的 CLAUDE.md）。
/// 若开放全部 `SurfaceKind`，`Card(kind: .canvas)`（卡片贴画布 ⇒ 隐形，正是 Issue #140
/// 塌缩回归的形态）、`Card(kind: .sidebar)` 这类组合会成为合法 API，把一个薄封装拓宽成
/// 万能容器——与 `bordered: Bool` 想消除的「取值域压扁」是同一类病的镜像（这次是取值域
/// **过宽**）。需要其余 kind 的场景直接用 `View.surface(_:)`。
///
/// ⚠️ **为什么是顶层 `CardKind` 而不是嵌套的 `Card.Kind`**：`Card` 是泛型
/// （`Card<Content: View>`），Swift 的嵌套类型**隐式泛型** ⇒ `Card<A>.Kind` 与
/// `Card<B>.Kind` 是两个不同类型（本机 `swiftc -typecheck` 实测报
/// `cannot convert parent type 'Card<Color>' to expected type 'Card<Text>'`），
/// 而 `BasicContainerTests` 的参数化回归守卫必须在函数签名里写出这个类型。
/// 顶层具名枚举满足同一条取值域约束，且没有这个坑。
public nonisolated enum CardKind: Sendable, Equatable {
    /// 带描边的内容卡片（默认）——完整 `.surface(.content)`：背景 + 描边 + 圆角。
    case content
    /// 分组容器观感——背景 + 圆角、**无描边**，靠填充色对比定界，与
    /// `InsetGroupedSection` 的卡片外观一致。等价于 #41 之前的 `bordered: false`。
    case grouped

    /// 映射到底层的容器表面语义类别。
    var surfaceKind: SurfaceKind {
        switch self {
        case .content: .content
        case .grouped: .grouped
        }
    }
}

// MARK: - Card

/// `.surface(.content)` 的**具名封装** + 默认内边距——iOS 分组卡片/内容容器的最薄外壳。
///
/// Card **不引入平行的容器体系**：它就是 `content` → `.padding(默认值)` →
/// `.surface(kind.surfaceKind)`（背景 + 描边 + 圆角均由 `SurfaceModifier` 提供，
/// 不重新实现）。需要更细控制（其余 `SurfaceKind` / 边距 / 形状）的场景，直接用
/// `View.surface(_:)`。
///
/// `kind: .grouped` 去描边，只留背景 + 圆角，贴近 iOS 系统分组容器（无描边、靠填充色
/// 对比定界），与 `InsetGroupedSection` 的卡片外观一致。
///
/// ⚠️ **#41 破坏性变更**：原 `bordered: Bool` 参数已删除。迁移：
/// `Card(bordered: false)` → `Card(kind: .grouped)`；`Card(bordered: true)` → `Card()`。
///
/// 背景来自 `.surface(.content)` / `.surface(.grouped)`，Issue #140 后指向 `surfaceRaised`
/// （`secondarySystemGroupedBackground`）——**浮于画布之上**，深浅双模式下都与
/// `Color.surfaceCanvas` 拉开、不再塌缩隐形。
///
/// **布局行为**：Card **默认撑满父容器宽度**（`maxWidth: .infinity`，对齐 iOS 分组
/// 卡片贯穿页宽的惯例），内容按 `alignment` 对齐（默认 `.leading`）。需要「卡片 hug
/// 自身内容尺寸」这类非撑满场景时，直接用 `View.surface(.content)` 而非 Card——
/// Card 刻意只服务最常见的撑满分组卡片。
///
/// ```swift
/// Card {
///     VStack(alignment: .leading, spacing: CoreSpacing.sm) {
///         Text("Title").coreFont(.headline)
///         Text("Body").coreFont(.subheadline).foregroundStyle(.secondary)
///     }
/// }
///
/// Card(alignment: .center) { ContentUnavailableView("No Results", systemImage: "magnifyingglass") }  // 居中内容的空态卡片
/// Card(kind: .grouped) { Text("无描边的分组容器观感") }
/// ```
public struct Card<Content: View>: View {
    private let padding: CGFloat
    private let alignment: Alignment
    private let kind: CardKind
    private let content: Content

    /// - Parameters:
    ///   - padding: 内容四周内边距，默认 `CoreSpacing.lg`（16pt，对齐 iOS 分组卡片惯例）。
    ///   - alignment: 撑满宽度内的内容对齐，默认 `.leading`。
    ///   - kind: 容器观感，默认 `.content`（背景 + 描边 + 圆角）。`.grouped` 只保留
    ///     背景 + 圆角、**去掉描边**——贴近 iOS 系统分组容器
    ///     （`secondarySystemGroupedBackground` 靠填充色对比定界、无描边）。
    ///   - content: 卡片内容。
    public init(
        padding: CGFloat = CoreSpacing.lg,
        alignment: Alignment = .leading,
        kind: CardKind = .content,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.alignment = alignment
        self.kind = kind
        self.content = content()
    }

    public var body: some View {
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: self.alignment)
            // 两种观感都走 `SurfaceModifier`（经 `CardKind.surfaceKind` 映射）——不再手抄
            // 背景/圆角，`.content` / `.grouped` 的 token 映射变了 Card 自动跟随，无 drift。
            .surface(self.kind.surfaceKind)
    }
}

#Preview("Card — Light") {
    CardPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Card — Dark") {
    CardPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CardPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            Card {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Card 标题").coreFont(.headline)
                    Text("卡片浮于画布之上，深浅双模式都与背景拉开。")
                        .coreFont(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Card(padding: CoreSpacing.md) {
                Text("紧凑内边距（md）").coreFont(.subheadline)
            }
            Card(kind: .grouped) {
                Text("无描边（kind: .grouped）——贴近系统分组容器").coreFont(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceCanvas)
    }
}
