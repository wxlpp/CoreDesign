import SwiftUI

public extension Color {
    /// 主要文本颜色，桥接 `UIColor.label` / `NSColor.labelColor`。
    static var label: Color {
        #if canImport(UIKit)
            Color(uiColor: .label)
        #else
            Color(nsColor: .labelColor)
        #endif
    }

    /// 次要文本颜色，桥接 `UIColor.secondaryLabel` / `NSColor.secondaryLabelColor`。
    static var secondaryLabel: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondaryLabel)
        #else
            Color(nsColor: .secondaryLabelColor)
        #endif
    }

    /// 三级文本颜色，桥接 `UIColor.tertiaryLabel` / `NSColor.tertiaryLabelColor`。
    static var tertiaryLabel: Color {
        #if canImport(UIKit)
            Color(uiColor: .tertiaryLabel)
        #else
            Color(nsColor: .tertiaryLabelColor)
        #endif
    }

    /// 四级文本颜色，桥接 `UIColor.quaternaryLabel` / `NSColor.quaternaryLabelColor`。
    static var quaternaryLabel: Color {
        #if canImport(UIKit)
            Color(uiColor: .quaternaryLabel)
        #else
            Color(nsColor: .quaternaryLabelColor)
        #endif
    }

    /// 浅色背景上文本的非自适应颜色，不随外观切换。
    static var darkText: Color {
        #if canImport(UIKit)
            Color(uiColor: .darkText)
        #else
            Color(nsColor: .textColor)
        #endif
    }

    /// 暗色背景上文本的非自适应颜色，不随外观切换。
    static var lightText: Color {
        #if canImport(UIKit)
            Color(uiColor: .lightText)
        #else
            Color(nsColor: .textColor)
        #endif
    }

    /// 输入控件占位文本的颜色。
    static var placeholderText: Color {
        #if canImport(UIKit)
            Color(uiColor: .placeholderText)
        #else
            Color(nsColor: .placeholderTextColor)
        #endif
    }

    /// 分隔线颜色，允许下层内容透出。
    static var separator: Color {
        #if canImport(UIKit)
            Color(uiColor: .separator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }

    /// 不透明的分隔线颜色，完全遮住下层内容。
    static var opaqueSeparator: Color {
        #if canImport(UIKit)
            Color(uiColor: .opaqueSeparator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }

    /// 可点击链接文本的颜色。
    static var link: Color {
        #if canImport(UIKit)
            Color(uiColor: .link)
        #else
            Color(nsColor: .linkColor)
        #endif
    }
}
