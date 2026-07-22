//
//  FillColors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//

import SwiftUI

// Issue #120 完整映射表（第 3 层 FillColors 全部 token）——全部保持现值：
//
// | token          | 值                   | 判定 |
// |----------------|-----------------------|------|
// | fill           | systemFill            | 保持现值——已是系统色，UIKit/AppKit 双端均正确桥接 |
// | secondaryFill  | secondarySystemFill   | 保持现值——同上 |
// | tertiaryFill   | tertiarySystemFill    | 保持现值——同上；本任务新增消费者 `surfaceCanvasInset`（见 SurfaceColors.swift） |
// | quaternaryFill | quaternarySystemFill  | 保持现值——同上 |
public extension Color {
    /// 为细小形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充细小形状，例如滑动条的轨迹。
    static var fill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .systemFill)
        #else
            return Color(nsColor: .systemFill)
        #endif
    }

    /// 中等大小形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充中等大小的形状，例如开关的背景。
    static var secondaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .secondarySystemFill)
        #else
            return Color(nsColor: .secondarySystemFill)
        #endif
    }

    /// 大型形状的叠加填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充大型形状，例如输入字段、搜索栏或按钮。
    static var tertiaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .tertiarySystemFill)
        #else
            return Color(nsColor: .tertiarySystemFill)
        #endif
    }

    /// 大区域复杂内容的覆盖填充颜色。
    ///
    /// 使用系统填充颜色为位于现有背景颜色之上的项目。系统填充颜色包含透明度，以便背景颜色能够透过来。
    ///
    /// 使用此颜色填充包含复杂内容的大区域，例如展开的表格单元格。
    static var quaternaryFill: Color {
        #if canImport(UIKit)
            return Color(uiColor: .quaternarySystemFill)
        #else
            return Color(nsColor: .quaternarySystemFill)
        #endif
    }
}
