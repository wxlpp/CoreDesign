//
//  AppKitColors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//

import SwiftUI

#if canImport(AppKit)
extension Color {
    /// 交替选择的控制文本颜色
    ///
    /// 列表或表格中所选表面上的文本。
    public static var alternateSelectedControlTextColor: Color {
        Color(nsColor: .alternateSelectedControlTextColor)
    }

    /// 交替内容背景颜色
    ///
    /// 列表、表格或集合视图中交替行或列的背景。
    public static var alternatingContentBackgroundColors: [Color] {
        NSColor.alternatingContentBackgroundColors.map { Color(nsColor: $0) }
    }

    /// 控制强调色
    ///
    /// 用户在"系统设置"中选择的强调色。
    public static var controlAccentColor: Color {
        Color(nsColor: .controlAccentColor)
    }

    /// 控制背景颜色
    ///
    /// 浏览器或表格等大型界面元素的背景。
    public static var controlBackgroundColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    /// 控制颜色
    ///
    /// 控制的表面。
    public static var controlColor: Color {
        Color(nsColor: .controlColor)
    }

    /// 控制文本颜色
    ///
    /// 可用控制的文本。
    public static var controlTextColor: Color {
        Color(nsColor: .controlTextColor)
    }

    /// 当前控制着色
    ///
    /// 系统定义的控制着色。
    public static var currentControlTint: NSControlTint {
        NSColor.currentControlTint
    }

    /// 不可用的控制文本颜色
    ///
    /// 不可用控制的文本。
    public static var disabledControlTextColor: Color {
        Color(nsColor: .disabledControlTextColor)
    }

    /// 查找高亮标记颜色
    ///
    /// 查找指示符的颜色。
    public static var findHighlightColor: Color {
        Color(nsColor: .findHighlightColor)
    }

    /// 网格颜色
    ///
    /// 表格等界面元素的网格线。
    public static var gridColor: Color {
        Color(nsColor: .gridColor)
    }

    /// 标题文本颜色
    ///
    /// 表格中的标题单元格的文本。
    public static var headerTextColor: Color {
        Color(nsColor: .headerTextColor)
    }

    /// 高亮标记颜色
    ///
    /// 屏幕上的虚拟光源。
    public static var highlightColor: Color {
        Color(nsColor: .highlightColor)
    }

    /// 键盘焦点指示符颜色
    ///
    /// 使用键盘进行界面导览时，在当前获得焦点的控制周围出现的圆环。
    public static var keyboardFocusIndicatorColor: Color {
        Color(nsColor: .keyboardFocusIndicatorColor)
    }

    /// 链接颜色
    ///
    /// 其他内容的链接。
    public static var linkColor: Color {
        Color(nsColor: .linkColor)
    }

    /// 占位符文本颜色
    ///
    /// 控制或文本视图中的占位符字符串。
    public static var placeholderTextColor: Color {
        Color(nsColor: .placeholderTextColor)
    }

    /// 四级标签颜色
    ///
    /// 重要性低于三级标签的标签的文本，如水印文本。
    public static var quaternaryLabelColor: Color {
        Color(nsColor: .quaternaryLabelColor)
    }

    /// 二级标签颜色
    ///
    /// 重要性低于一级标签的标签的文本，如用于表示副标题或附加信息的标签。
    public static var secondaryLabelColor: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    /// 所选内容背景颜色
    ///
    /// 关键窗口或视图中的所选内容的背景。
    public static var selectedContentBackgroundColor: Color {
        Color(nsColor: .selectedContentBackgroundColor)
    }

    /// 所选控制颜色
    ///
    /// 所选控制的表面。
    public static var selectedControlColor: Color {
        Color(nsColor: .selectedControlColor)
    }

    /// 所选控制文本颜色
    ///
    /// 所选控制的文本。
    public static var selectedControlTextColor: Color {
        Color(nsColor: .selectedControlTextColor)
    }

    /// 所选菜单项文本颜色
    ///
    /// 所选菜单的文本。
    public static var selectedMenuItemTextColor: Color {
        Color(nsColor: .selectedMenuItemTextColor)
    }

    /// 所选文本背景颜色
    ///
    /// 所选文本的背景。
    public static var selectedTextBackgroundColor: Color {
        Color(nsColor: .selectedTextBackgroundColor)
    }

    /// 所选文本颜色
    ///
    /// 所选文本的颜色。
    public static var selectedTextColor: Color {
        Color(nsColor: .selectedTextColor)
    }

    /// 分隔符颜色
    ///
    /// 内容不同部分之间的分隔符。
    public static var separatorColor: Color {
        Color(nsColor: .separatorColor)
    }

    /// 阴影颜色
    ///
    /// 屏幕上被提起的对象所投射的虚拟阴影。
    public static var shadowColor: Color {
        Color(nsColor: .shadowColor)
    }

    /// 三级标签颜色
    ///
    /// 重要性低于二级标签的标签的文本。
    public static var tertiaryLabelColor: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    /// 文本背景颜色
    ///
    /// 文本后面的背景颜色。
    public static var textBackgroundColor: Color {
        Color(nsColor: .textBackgroundColor)
    }

    /// 文本颜色
    ///
    /// 文稿中的文本。
    public static var textColor: Color {
        Color(nsColor: .textColor)
    }

    /// 页面下方的背景颜色
    ///
    /// 文稿内容后面的背景。
    public static var underPageBackgroundColor: Color {
        Color(nsColor: .underPageBackgroundColor)
    }

    /// 未强调的所选内容背景颜色
    ///
    /// 非关键窗口或视图中的所选内容。
    public static var unemphasizedSelectedContentBgColor: Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    /// 未强调的所选文本背景颜色
    ///
    /// 非关键窗口或视图中的所选文本的背景。
    public static var unemphasizedSelectedTextBackgroundColor: Color {
        Color(nsColor: .unemphasizedSelectedTextBackgroundColor)
    }

    /// 未强调的所选文本颜色
    ///
    /// 非关键窗口或视图中的所选文本。
    public static var unemphasizedSelectedTextColor: Color {
        Color(nsColor: .unemphasizedSelectedTextColor)
    }

    /// 窗口背景颜色
    ///
    /// 窗口的背景。
    public static var windowBackgroundColor: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    /// 窗口框文本颜色
    ///
    /// 窗口标题栏区中的文本。
    public static var windowFrameTextColor: Color {
        Color(nsColor: .windowFrameTextColor)
    }
}
#endif
