//
//  SystemLabelColors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//

import SwiftUI

extension Color {
    /// 标签
    ///
    ///  包含一级内容的文本标签。
    public static var label: Color {
        #if canImport(UIKit)
        Color(uiColor: .label)
        #else
        Color(nsColor: .labelColor)
        #endif
    }

    /// 二级标签
    ///
    /// 包含二级内容的文本标签。
    public static var secondaryLabel: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondaryLabel)
        #else
        Color(nsColor: .secondaryLabelColor)
        #endif
    }

    /// 三级标签
    ///
    /// 包含三级内容的文本标签。
    public static var tertiaryLabel: Color {
        #if canImport(UIKit)
        Color(uiColor: .tertiaryLabel)
        #else
        Color(nsColor: .tertiaryLabelColor)
        #endif
    }

    /// 四级标签
    ///
    /// 包含四级内容的文本标签。
    public static var quaternaryLabel: Color {
        #if canImport(UIKit)
        Color(uiColor: .quaternaryLabel)
        #else
        Color(nsColor: .quaternaryLabelColor)
        #endif
    }

    /// 非自适应系统颜色，用于浅色背景上的文本。
    ///
    /// 这种颜色不适应底层特性环境的变化。
    public static var darkText: Color {
        #if canImport(UIKit)
        Color(uiColor: .darkText)
        #else
        Color(nsColor: .textColor) // 假设
        #endif
    }

    /// 暗色背景上文本的非可适应系统颜色。
    ///
    /// 这种颜色不适应底层特性环境的变化。
    public static var lightText: Color {
        #if canImport(UIKit)
        Color(uiColor: .lightText)
        #else
        Color(nsColor: .textColor) // 假设
        #endif
    }

    /// 占位符文本
    ///
    /// 控制或文本视图中的占位符文本。
    public static var placeholderText: Color {
        #if canImport(UIKit)
        Color(uiColor: .placeholderText)
        #else
        Color(nsColor: .placeholderTextColor)
        #endif
    }

    /// 分隔符
    ///
    /// 允许某些底层内容可见的分隔符。
    public static var separator: Color {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    /// 不透明分隔符
    ///
    /// 不允许任何底层内容可见的分隔符。
    public static var opaqueSeparator: Color {
        #if canImport(UIKit)
        Color(uiColor: .opaqueSeparator)
        #else
        Color(nsColor: .separatorColor) // 假设
        #endif
    }

    /// 链接
    ///
    /// 用作链接的文本。
    public static var link: Color {
        #if canImport(UIKit)
        Color(uiColor: .link)
        #else
        Color(nsColor: .linkColor)
        #endif
    }
}
