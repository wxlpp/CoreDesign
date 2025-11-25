//
//  SystemBackgroundColors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//

import SwiftUI

extension Color {
    /// 界面主背景的颜色。
    ///
    /// 使用此颜色用于标准表格视图和在设计中有白色主背景的浅色环境。
    public static var systemBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// 主要背景上层内容的颜色。
    ///
    /// 在浅色环境中，将此颜色用于标准表视图和具有白色主背景的设计。
    public static var secondarySystemBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 次要背景上层内容的颜色。
    ///
    /// 在浅色环境中，将此颜色用于标准表视图和具有白色主背景的设计。
    public static var tertiarySystemBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .tertiarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 分组界面的主要背景颜色。
    ///
    /// 将此颜色用于分组内容，包括表视图和基于托盘的设计。
    public static var systemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 分组界面主要背景上层内容的颜色。
    ///
    /// 将此颜色用于分组内容，包括表视图和基于托盘的设计。
    public static var secondarySystemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 内容层叠在分组界面次要背景之上的颜色。
    ///
    /// 使用此颜色用于分组内容，包括表格视图和基于盘子的设计。
    public static var tertiarySystemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .tertiarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
