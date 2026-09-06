import CoreGraphics
import SwiftUI

// MARK: - CoreRadius

/// 圆角 token，对齐 Apple HIG 的圆角标度。
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

/// 圆角 shape 的统一出口，内部固定 `style: .continuous`；组件不要再直接构造 `RoundedRectangle`。
public nonisolated enum CoreShape {
    /// 统一圆角矩形出口，固定 `.continuous` 角样式。
    ///
    /// - Parameter radius: 圆角半径，通常传 `CoreRadius.*`。
    public static func rounded(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
