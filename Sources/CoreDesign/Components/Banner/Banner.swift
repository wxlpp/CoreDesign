//
//  Banner.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/2.
//

import SwiftUI

// MARK: - BannerPalette

/// 内部使用的 Banner 颜色三元组：前景（icon + label 文字）/ 背景 / 描边。
/// 由 `StatusLevel` 映射到具体的 status color token（见 `Colors/StatusColors.swift`）。
private struct BannerPalette {
    let foreground: Color
    let background: Color
    let border: Color
}

// MARK: - Banner

/// 内容 / 控件层的信息表面。用状态语义（`info` / `success` / `warning` / `danger`）
/// 配克制的描边或填充——**不用** Liquid Glass。Banner 面向**页内信息**，不是浮层反馈；
/// 需要浮层反馈请经 `.toastHost(edge:)` 用 `ToastHost`。
///
/// **材质层**: 内容 (info-only) or control (with actions).
/// **表面角色**: 内容 / control.
///
/// 通栏式信息提示组件。
///
/// 在主要操作流之外向用户传达系统级状态（成功 / 警告 / 错误 / 信息）。形态固定为
/// 横向 `HStack`：`StatusLevel` 决定的 system icon + 调用方传入的 label。
///
/// 视觉外观由当前环境注入的 `BannerStyle` 决定，默认为 `PlainBannerStyle`（仅背景色）；
/// 可通过 `View.bannerStyle(_:)` 切换为 `BorderedBannerStyle`（背景 + 同色系描边）。
///
/// ```swift
/// Banner(level: .warning) {
///     Text("This document is going to expire in 4 days.")
/// }
/// .bannerStyle(BorderedBannerStyle())
/// ```
///
/// padding / spacing / 字号全部来自设计 token（`CoreSpacing.*` / `CoreTypography.*`），
/// 颜色来自 status color token（`Color.statusAccentSubtle` 等），随 light / dark 自动适配。
/// 不使用 `.glassEffect`：Banner 是基础信息容器，需要清晰的实色背景以保证可读性。
public struct Banner<Label: View>: View {
    /// 创建 Banner。
    ///
    /// - Parameters:
    ///   - level: 语义等级，决定图标与配色（见 `StatusLevel`）。
    ///   - label: banner 主体文本视图，通常为 `Text`。
    public init(level: StatusLevel, @ViewBuilder label: () -> Label) {
        self.configuration = .init(label: .init(label()), level: level)
    }

    public var body: some View {
        AnyView(self.style.makeBody(configuration: self.configuration))
    }

    @Environment(\.bannerStyle) var style

    let configuration: BannerStyleConfiguration
}

// MARK: - BannerStyle

/// `Banner` 视觉外观的扩展点，形态对齐 Apple `ButtonStyle` / `ToggleStyle`。
///
/// 实现该协议以提供新的 banner 外观（如新增 "subtle" / "filled" 等变体），通过
/// `View.bannerStyle(_:)` 注入到子树。`makeBody(configuration:)` 接收 `BannerStyleConfiguration`，
/// 内含 label 视图和 `StatusLevel`，由实现自行决定如何组织 padding / 背景 / 描边。
///
/// 内置实现见 `PlainBannerStyle`（默认）与 `BorderedBannerStyle`。新实现应继续走
/// 设计 token（`CoreSpacing.*` / `CoreBorderWidth.*` / `CoreTypography.*`）和 status
/// color token，避免引入魔法数字。
public protocol BannerStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = BannerStyleConfiguration
}

// MARK: - BannerStyleConfiguration

/// 传给 `BannerStyle.makeBody` 的上下文，提供 banner 的语义等级与 label 视图。
///
/// - `label`：调用方在 `Banner.init` 中通过 `@ViewBuilder` 传入的内容，已类型擦除为
///   `AnyView`，便于在自定义 style 中以任意结构嵌入。
/// - `level`：决定图标与配色映射（见 `StatusLevel`）。自定义 style 可读取该字段以
///   提供分级别的外观差异。
public struct BannerStyleConfiguration {
    public typealias Label = AnyView

    public let label: Label
    public let level: StatusLevel
}

// MARK: - Banner shared helpers

/// 由 `StatusLevel` 映射到对应的 SF Symbol 图标。
///
/// 抽取为 file-private 自由函数以便 `PlainBannerStyle` / `BorderedBannerStyle` 复用，
/// 保证两种 style 在同一 level 下渲染一致的图标语义。新增 style 时直接调用此函数，
/// 不要在各自 style 中再次 switch `StatusLevel`。
private func bannerIcon(for level: StatusLevel) -> Image {
    switch level {
    case .info:
        Image(systemName: "info.circle.fill")
    case .warning:
        Image(systemName: "exclamationmark.triangle.fill")
    case .danger:
        Image(systemName: "exclamationmark.circle.fill")
    case .success:
        Image(systemName: "checkmark.circle.fill")
    }
}

/// 由 `StatusLevel` 映射到完整的 status color 三元组（前景 / 背景 / 描边）。
///
/// 抽取为 file-private 自由函数以便所有内置 style 共用同一份 token 映射；新增 level
/// 或调整 token 名称时只需改一处。
private func bannerPalette(for level: StatusLevel) -> BannerPalette {
    switch level {
    case .info:
        BannerPalette(foreground: .statusAccentForeground, background: .statusAccentSubtle, border: .statusAccentBorder)
    case .warning:
        BannerPalette(foreground: .statusAttentionForeground, background: .statusAttentionSubtle, border: .statusAttentionBorder)
    case .danger:
        BannerPalette(foreground: .statusDangerForeground, background: .statusDangerSubtle, border: .statusDangerBorder)
    case .success:
        BannerPalette(foreground: .statusSuccessForeground, background: .statusSuccessSubtle, border: .statusSuccessBorder)
    }
}

/// 两个内置 `BannerStyle` 的公共布局主体。
///
/// `PlainBannerStyle` 与 `BorderedBannerStyle` 的 body 只差最后的背景是否叠描边，
/// 抽此一处避免两份 11 行 HStack 逐字重复。`bordered` 为 `true` 时在背景 `Rectangle`
/// 上追加 `.bordered(style: palette.border)`（`CoreBorderWidth.thin`）。
@ViewBuilder
private func bannerBody(configuration: BannerStyleConfiguration, bordered: Bool) -> some View {
    let palette = bannerPalette(for: configuration.level)
    HStack(spacing: CoreSpacing.sm) {
        bannerIcon(for: configuration.level)
            .foregroundStyle(palette.foreground)
            .accessibilityHidden(true)
        configuration.label
    }
    .accessibilityElement(children: .combine)
    .coreFont(.callout)
    .foregroundStyle(palette.foreground)
    .padding(CoreSpacing.md)
    .background {
        if bordered {
            Rectangle().fill(palette.background).bordered(style: palette.border)
        } else {
            Rectangle().fill(palette.background)
        }
    }
}

// MARK: - PlainBannerStyle

/// 默认的 Banner 外观：纯色背景 + 同色系前景，无描边。
///
/// 默认样式。背景 / 前景按 `StatusLevel` 走 status color token
/// （`Color.statusAccentSubtle` / `.statusAccentForeground` 等），随 light / dark 自动适配；padding
/// 走 `CoreSpacing.md`（12pt），`HStack` spacing 显式固定为 `CoreSpacing.sm`（8pt，与
/// SwiftUI system default 接近但显式化以避免依赖系统默认值，保证 icon 与 label 之间
/// 的视觉间距在所有平台上稳定一致）。
///
/// 适合页面顶部、表单上方等需要"嵌入式"提示的场景；若希望与背景拉开层次，使用
/// `BorderedBannerStyle`。
public struct PlainBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: false)
    }
}

// MARK: - BorderedBannerStyle

/// 带同色系描边的 Banner 外观：背景 + `CoreBorderWidth.thin` 描边。
///
/// 带描边的样式。在内容区背景颜色不确定 / 与 banner 背景
/// 接近时使用，描边帮助 banner 与周围内容拉开层次；颜色按 `StatusLevel` 走 status
/// color token（`Color.statusAccentBorder` 等）。
///
/// padding / spacing / icon 渲染与 `PlainBannerStyle` 保持一致（`CoreSpacing.md` 内边距，
/// `CoreSpacing.sm` icon-to-label 间距，由 `StatusLevel` 决定的 SF Symbol 图标），
/// 描边宽度由 `View.bordered(...)` 默认值 `CoreBorderWidth.thin`（1pt）提供。light / dark
/// 自动适配，无需额外配置。
public struct BorderedBannerStyle: BannerStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        bannerBody(configuration: configuration, bordered: true)
    }
}

extension EnvironmentValues {
    /// 当前生效的 `BannerStyle`，默认 `PlainBannerStyle`。
    ///
    /// 通过 `View.bannerStyle(_:)` 注入到子树；`Banner` 在 `body` 中读取该值并调用
    /// `style.makeBody(configuration:)` 渲染。自定义 style 可在父视图统一切换整个
    /// 区域内 banner 的外观，调用方无需改动每个 `Banner` 实例。
    @Entry var bannerStyle: any BannerStyle = PlainBannerStyle()
}

public extension View {
    /// 为子树中的所有 `Banner` 设置外观。
    ///
    /// 对应 Apple `View.buttonStyle(_:)` 的注入模式：在父视图调用一次即可影响下游
    /// 所有 `Banner` 实例，无需逐个指定。常见用法是在 `NavigationStack` 或某个
    /// section 内统一切换为带描边的样式：
    ///
    /// ```swift
    /// VStack {
    ///     Banner(level: .info) { Text("...") }
    ///     Banner(level: .warning) { Text("...") }
    /// }
    /// .bannerStyle(BorderedBannerStyle())
    /// ```
    ///
    /// - Parameter style: 任意符合 `BannerStyle` 协议的实现，通常为内置的
    ///   `PlainBannerStyle` / `BorderedBannerStyle`。
    func bannerStyle(_ style: some BannerStyle) -> some View {
        self.environment(\.bannerStyle, style)
    }
}

#Preview {
    VStack(spacing: 10) {
        Banner(level: .info) {
            Text("A pre-released version is available.")
        }.bannerStyle(BorderedBannerStyle())
        Banner(level: .warning) {
            Text("This version of the document is going to expire after 4 days.")
        }
        Banner(level: .danger) {
            Text("This document was deprecated since Jan 1, 2019.")
        }
        Banner(level: .success) {
            Text("You are viewing the latest version of this document.")
        }
    }
}
