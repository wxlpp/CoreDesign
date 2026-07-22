//
//  CoreRadius.swift
//  CoreDesign
//

import CoreGraphics
import SwiftUI

// MARK: - CoreRadius

/// 圆角 token，对齐 Apple HIG 的圆角标度。
///
/// 调用方式：
///
/// ```swift
/// CoreShape.rounded(CoreRadius.medium)
///     .clipShape(Capsule())   // pill 形态用 Capsule，不要用大 cornerRadius
/// ```
///
/// > Note: HIG 没有单独的 `.none` 档（直角通常通过省略圆角实现）。本仓库引入
/// > `.none = 0`，方便在统一类型签名下表达"无圆角"——譬如 `BorderModifier` 默认
/// > 不带圆角时仍走 token 路径，而不是字面量 0。
// `nonisolated`：理由同 `CoreSpacing`——纯数值常量，需要在 nonisolated 上下文
// （如 `BottomInputBarGlassEffectShape.path(in:)`）中被引用。
public nonisolated enum CoreRadius {
    /// 直角 (0pt)。**CoreDesign 扩展**，HIG 无对应。
    public static let none: CGFloat = 0

    /// 小圆角 (6pt)。Badge、Tag、紧凑控件的圆角。
    public static let small: CGFloat = 6

    /// 中圆角 (10pt)。按钮、输入框、Card、容器的默认圆角。
    public static let medium: CGFloat = 10

    /// 大圆角 (16pt)。Dialog、Modal、希望视觉柔和的容器。
    public static let large: CGFloat = 16

    /// 特大圆角 (22pt)。**CoreDesign 扩展**。全屏 sheet、大尺寸浮层容器等需要更明显
    /// 柔化观感的场景。
    public static let xLarge: CGFloat = 22
}

// MARK: - CoreShape

/// 圆角 shape 的统一出口。内部固定 `style: .continuous`（squircle 观感）——组件不应
/// 再直接构造 `RoundedRectangle`，那样每个构造点都要记得手动指定 `.continuous`，
/// 漏一处就是一处观感不一致的元素。
///
/// ## 使用约定
///
/// - **独立元素**（不嵌套在已知容器内、或容器形状与自身圆角无关）：用
///   `CoreShape.rounded(_:)`，配合 `CoreRadius.*` 传入固定半径。
/// - **嵌套于已知容器的元素**（容器内边距固定、子元素紧贴容器内壁，譬如卡片内的
///   缩略图、按钮内的 icon 底板）：改用 iOS 26+ 的 `ConcentricRectangle()`——它会
///   向上寻找最近的 `.containerShape(_:)` 声明并按其圆角推算出自身应有的圆角，
///   父子边框天然同心，不需要手动对齐两处半径字面量。容器侧按需搭配
///   `.containerShape(CoreShape.rounded(radius))` 声明形状。
///
/// > Note: 本任务只提供这个出口；组件调用点从裸 `RoundedRectangle` 迁移到
/// > `CoreShape` / `ConcentricRectangle` 是 Task #122 的范围
/// > （验收判据是 `grep` 裸 `RoundedRectangle` 为 0）。
// `nonisolated`：理由同 `CoreRadius`——本包全 target 走 `.defaultIsolation(MainActor.self)`，
// 而 shape 的主要消费点恰是 `Shape.path(in:)` / `InsettableShape` 这类 nonisolated 同步上下文
// （如 `BottomInputBarGlassEffectShape.path(in:)`）。漏掉这个关键字，#122 迁移调用点时
// 会在这些位置拿到 Swift 6 隔离错误，而本任务因零调用点不会暴露。
public nonisolated enum CoreShape {
    /// 统一圆角矩形出口，固定 `.continuous` 角样式。
    ///
    /// - Parameter radius: 圆角半径，通常传 `CoreRadius.*`。
    public static func rounded(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
