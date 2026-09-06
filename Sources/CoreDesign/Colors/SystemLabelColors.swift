import SwiftUI

public extension Color {
    /// 标签
    static var label: Color {
        #if canImport(UIKit)
            Color(uiColor: .label)
        #else
            Color(nsColor: .labelColor)
        #endif
    }

    /// 二级标签
    static var secondaryLabel: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondaryLabel)
        #else
            Color(nsColor: .secondaryLabelColor)
        #endif
    }

    /// 三级标签
    static var tertiaryLabel: Color {
        #if canImport(UIKit)
            Color(uiColor: .tertiaryLabel)
        #else
            Color(nsColor: .tertiaryLabelColor)
        #endif
    }

    /// 四级标签
    static var quaternaryLabel: Color {
        #if canImport(UIKit)
            Color(uiColor: .quaternaryLabel)
        #else
            Color(nsColor: .quaternaryLabelColor)
        #endif
    }

    /// 非自适应系统颜色，用于浅色背景上的文本。
    static var darkText: Color {
        #if canImport(UIKit)
            Color(uiColor: .darkText)
        #else
            Color(nsColor: .textColor)
        #endif
    }

    /// 暗色背景上文本的非可适应系统颜色。
    static var lightText: Color {
        #if canImport(UIKit)
            Color(uiColor: .lightText)
        #else
            Color(nsColor: .textColor)
        #endif
    }

    /// 占位符文本
    static var placeholderText: Color {
        #if canImport(UIKit)
            Color(uiColor: .placeholderText)
        #else
            Color(nsColor: .placeholderTextColor)
        #endif
    }

    /// 分隔符
    static var separator: Color {
        #if canImport(UIKit)
            Color(uiColor: .separator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }

    /// 不透明分隔符
    static var opaqueSeparator: Color {
        #if canImport(UIKit)
            Color(uiColor: .opaqueSeparator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }

    /// 链接
    static var link: Color {
        #if canImport(UIKit)
            Color(uiColor: .link)
        #else
            Color(nsColor: .linkColor)
        #endif
    }
}
