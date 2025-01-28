//
//  Colors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//
import SwiftUI

#if canImport(UIKit)
import UIKit

typealias SLColor = UIColor

extension Color {
    /// 界面主背景的颜色。
    ///
    /// 使用此颜色用于标准表格视图和在设计中有白色主背景的浅色环境。
    public static var systemBackground: Color {
        Color(uiColor: .systemBackground)
    }

    /// 主要背景上层内容的颜色。
    ///
    /// 在浅色环境中，将此颜色用于标准表视图和具有白色主背景的设计。
    public static var secondarySystemBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    /// 次要背景上层内容的颜色。
    ///
    /// 在浅色环境中，将此颜色用于标准表视图和具有白色主背景的设计。
    public static var tertiarySystemBackground: Color {
        Color(uiColor: .tertiarySystemBackground)
    }

    /// 分组界面的主要背景颜色。
    ///
    /// 将此颜色用于分组内容，包括表视图和基于托盘的设计。
    public static var systemGroupedBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    /// 分组界面主要背景上层内容的颜色。
    ///
    /// 将此颜色用于分组内容，包括表视图和基于托盘的设计。
    public static var secondarySystemGroupedBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    /// 内容层叠在分组界面次要背景之上的颜色。
    ///
    /// 使用此颜色用于分组内容，包括表格视图和基于盘子的设计。
    public static var tertiarySystemGroupedBackground: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }

    /// 标签
    ///
    ///  包含一级内容的文本标签。
    public static var label: Color {
        Color(uiColor: .label)
    }

    /// 二级标签
    ///
    /// 包含二级内容的文本标签。
    public static var secondaryLabel: Color {
        Color(uiColor: .secondaryLabel)
    }

    /// 三级标签
    ///
    /// 包含三级内容的文本标签。
    public static var tertiaryLabel: Color {
        Color(uiColor: .tertiaryLabel)
    }

    /// 四级标签
    ///
    /// 包含四级内容的文本标签。
    public static var quaternaryLabel: Color {
        Color(uiColor: .quaternaryLabel)
    }

    /// 非自适应系统颜色，用于浅色背景上的文本。
    ///
    /// 这种颜色不适应底层特性环境的变化。
    public static var darkText: Color {
        Color(uiColor: .darkText)
    }

    /// 暗色背景上文本的非可适应系统颜色。
    ///
    /// 这种颜色不适应底层特性环境的变化。
    public static var lightText: Color {
        Color(uiColor: .lightText)
    }

    /// 占位符文本
    ///
    /// 控制或文本视图中的占位符文本。
    public static var placeholderText: Color {
        Color(uiColor: .placeholderText)
    }

    /// 分隔符
    ///
    /// 允许某些底层内容可见的分隔符。
    public static var separator: Color {
        Color(uiColor: .separator)
    }

    /// 不透明分隔符
    ///
    /// 不允许任何底层内容可见的分隔符。
    public static var opaqueSeparator: Color {
        Color(uiColor: .opaqueSeparator)
    }

    /// 链接
    ///
    /// 用作链接的文本。
    public static var link: Color {
        Color(uiColor: .link)
    }
}
#endif

#if canImport(AppKit)
import AppKit

typealias SLColor = NSColor

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
    /// 用户在“系统设置”中选择的强调色。
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

    /// 标签颜色
    ///
    /// 包含一级内容的标签的文本。
    public static var labelColor: Color {
        Color(nsColor: .labelColor)
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
    public static var unemphasizedSelectedContentBackgroundColor: Color {
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

extension Color {
    /// 为细小形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充细小形状，例如滑动条的轨迹。
    public static var fill: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemFill)
        #endif
        #if canImport(AppKit)
        return Color(nsColor: .systemFill)
        #endif
    }

    /// 中等大小形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充中等大小的形状，例如开关的背景。
    public static var secondaryFill: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemFill)
        #endif
        #if canImport(AppKit)
        return Color(nsColor: .secondarySystemFill)
        #endif
    }

    /// 大型形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充大型形状，例如输入字段、搜索栏或按钮。
    public static var tertiaryFill: Color {
        #if canImport(UIKit)
        return Color(uiColor: .tertiarySystemFill)
        #endif
        #if canImport(AppKit)
        return Color(nsColor: .tertiarySystemFill)
        #endif
    }

    /// 大区域复杂内容的覆盖填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充包含复杂内容的大区域，例如展开的表格单元格。
    public static var quaternaryFill: Color {
        #if canImport(UIKit)
        return Color(uiColor: .quaternarySystemFill)
        #endif
        #if canImport(AppKit)
        return Color(nsColor: .quaternarySystemFill)
        #endif
    }
}

extension SLColor {
    public var rgbComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        #if canImport(UIKit)
        let slColor = self
        #endif
        #if canImport(AppKit)
        let slColor = self.usingColorSpace(.deviceRGB) ?? self
        #endif
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        slColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}

extension Color {
    public var rgbaString: String? {
        let (red, green, blue, alpha) = SLColor(self).rgbComponents
        guard red >= 0, green >= 0, blue >= 0, alpha >= 0 else {
            return nil
        }

        let redInt = Int(red * 255)
        let greenInt = Int(green * 255)
        let blueInt = Int(blue * 255)
        let alphaInt = Int(alpha * 255)

        return String(format: "#%02X%02X%02X%02X", redInt, greenInt, blueInt, alphaInt)
    }

    public var rgbaStringValue: String {
        self.rgbaString ?? ""
    }
}

extension Color: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue) else {
            self = .black
            return
        }

        do {
            let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: SLColor.self, from: data) ?? .black
            self = Color(color)
        } catch {
            self = .black
        }
    }

    public var rawValue: String {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: SLColor(self), requiringSecureCoding: false) as Data
            return data.base64EncodedString()

        } catch {
            return ""
        }
    }
}

public struct ColorItemView: View {
    let name: String
    let description: String
    let color: Color

    let textColor: Color

    init(name: String, description: String, color: Color, textColor: Color = .label) {
        self.name = name
        self.description = description
        self.color = color
        self.textColor = textColor
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(self.name)
                    .foregroundStyle(self.textColor)
                    .font(.headline)
                Text(String(self.description))
                    .foregroundStyle(self.textColor)
                    .font(.caption)
            }
            Spacer()
            Text(self.color.rgbaStringValue)
                .foregroundColor(self.textColor)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(self.color)
        .listRowInsets(.none)
    }
}

#Preview {
    List {
        Section {
            ColorItemView(name: "systemBackground", description: "第一层级背景色", color: .systemBackground)
            ColorItemView(name: "secondarySystemBackground", description: "第二层级背景色", color: .secondarySystemBackground)
            ColorItemView(name: "tertiarySystemBackground", description: "第三层级背景色", color: .tertiarySystemBackground)
        } header: {
            Text("背景色").foregroundStyle(Color.darkText)
        }
        Section {
            ColorItemView(name: "systemGroupedBackground", description: "第一层级背景色", color: .systemGroupedBackground)
            ColorItemView(name: "secondarySystemGroupedBackground", description: "第二层级背景色", color: .secondarySystemGroupedBackground)
            ColorItemView(name: "tertiarySystemGroupedBackground", description: "第三层级背景色", color: .tertiarySystemGroupedBackground)
        } header: {
            Text("分组界面背景色").foregroundStyle(Color.darkText)
        }
        Section {
            ColorItemView(name: "fill", description: "为细小形状的叠加填充颜色。", color: .fill)
            ColorItemView(name: "secondaryFill", description: "中等大小形状的叠加填充颜色。", color: .secondaryFill)
            ColorItemView(name: "tertiaryFill", description: "大型形状的叠加填充颜色。", color: .tertiaryFill)
            ColorItemView(name: "quaternaryFill", description: "大区域复杂内容的覆盖填充颜色。", color: .quaternaryFill)
        } header: {
            Text("填充色").foregroundStyle(Color.darkText)
        }

        Section {
            ColorItemView(name: "label", description: "标签", color: .label, textColor: .lightText)
            ColorItemView(name: "secondaryLabel", description: "二级标签", color: .secondaryLabel)
            ColorItemView(name: "tertiaryLabel", description: "三级标签", color: .tertiaryLabel)
            ColorItemView(name: "quaternaryLabel", description: "四级标签", color: .quaternaryLabel)
            ColorItemView(name: "placeholderText", description: "占位符文本", color: .placeholderText)
            ColorItemView(name: "separator", description: "分隔符", color: .separator)
            ColorItemView(name: "opaqueSeparator", description: "不透明分隔符", color: .opaqueSeparator)
            ColorItemView(name: "link", description: "链接", color: .link)
            ColorItemView(name: "darkText", description: "", color: .darkText, textColor: .lightText)
            ColorItemView(name: "lightText", description: "", color: .lightText, textColor: .darkText)

        } header: {
            Text("文本颜色").foregroundStyle(Color.darkText)
        }
    }
    .headerProminence(.increased)
    .background(content: {
        Color.systemBackground
    })
    .scrollContentBackground(.hidden)
}
