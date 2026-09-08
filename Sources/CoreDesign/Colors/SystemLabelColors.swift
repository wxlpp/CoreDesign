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

    /// **不透明**的主要墨色：浅色下黑、深色下白，两种外观 α 恒为 1.0。
    ///
    /// ⚠️ 两端桥的是**不同**系统色，这是刻意的：iOS 用 `UIColor.label`（实测 α = 1.0），
    /// macOS 用 `NSColor.textColor` 而**不是** `labelColor`——后者实测 α = 0.8471，
    /// 会让所有以本色为基的比例落不准（`.opacity(0.22)` 实得 0.186）并让实心填充透底。
    /// 两者 RGB 相同，只差 α。
    static var inkPrimary: Color {
        #if canImport(UIKit)
            Color(uiColor: .label)
        #else
            Color(nsColor: .textColor)
        #endif
    }

    /// 浅色背景上文本的固定深色（`UIColor.darkText`）。
    /// ⚠️ macOS 无对应 API，退化为**随外观切换**的 `NSColor.textColor`，且与 `lightText` 同值。
    static var darkText: Color {
        #if canImport(UIKit)
            Color(uiColor: .darkText)
        #else
            Color(nsColor: .textColor)
        #endif
    }

    /// 暗色背景上文本的固定浅色（`UIColor.lightText`）。
    /// ⚠️ macOS 无对应 API，退化为**随外观切换**的 `NSColor.textColor`，且与 `darkText` 同值。
    static var lightText: Color {
        #if canImport(UIKit)
            Color(uiColor: .lightText)
        #else
            Color(nsColor: .textColor)
        #endif
    }

    /// 输入控件占位文本的颜色，桥接 `UIColor.placeholderText` / `NSColor.placeholderTextColor`。
    static var placeholderText: Color {
        #if canImport(UIKit)
            Color(uiColor: .placeholderText)
        #else
            Color(nsColor: .placeholderTextColor)
        #endif
    }

    /// 分隔线颜色，允许下层内容透出，桥接 `UIColor.separator` / `NSColor.separatorColor`。
    static var separator: Color {
        #if canImport(UIKit)
            Color(uiColor: .separator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }

    /// 不透明的分隔线颜色，完全遮住下层内容（`UIColor.opaqueSeparator`）。
    /// ⚠️ macOS 无对应 API，退化为 `NSColor.separatorColor`——它**并不透明**
    /// （实测 α ≈ 0.098），且与 `separator` 同值。需要真正遮挡时不要依赖本 token。
    static var opaqueSeparator: Color {
        #if canImport(UIKit)
            Color(uiColor: .opaqueSeparator)
        #else
            Color(nsColor: .separatorColor)
        #endif
    }

    /// 可点击链接文本的颜色，桥接 `UIColor.link` / `NSColor.linkColor`。
    static var link: Color {
        #if canImport(UIKit)
            Color(uiColor: .link)
        #else
            Color(nsColor: .linkColor)
        #endif
    }
}
