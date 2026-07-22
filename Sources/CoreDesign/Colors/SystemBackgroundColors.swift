//
//  SystemBackgroundColors.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/1/28.
//

import SwiftUI

public extension Color {
    /// 界面主背景的颜色。
    ///
    /// 使用此颜色用于标准表格视图和在设计中有白色主背景的浅色环境。
    static var systemBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// 主要背景上层内容的颜色。
    ///
    /// 在浅色环境中，将此颜色用于标准表视图和具有白色主背景的设计。
    static var secondarySystemBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondarySystemBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 次要背景上层内容的颜色。
    ///
    /// 在浅色环境中，将此颜色用于标准表视图和具有白色主背景的设计。
    static var tertiarySystemBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .tertiarySystemBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 分组界面的主要背景颜色。
    ///
    /// 将此颜色用于分组内容，包括表视图和基于托盘的设计。
    ///
    /// macOS 降级：AppKit 没有 grouped background 系列。取 `.windowBackgroundColor`——
    /// AppKit 里代表窗口最外层画布背景，与 `controlBackgroundColor`（内容/控件区背景，
    /// 见下方 `secondarySystemGroupedBackground`）在浅色与深色下均有可辨差异（验证见
    /// `SystemBackgroundColorsMacOSTests`）。若改落 `controlBackgroundColor`，会与
    /// `secondarySystemGroupedBackground` 完全同值，让 `surfaceCanvas`（本 token 的
    /// 消费者）与 `surfaceRaised` 在 macOS 上卡片和画布同色、raised 层完全隐形。
    static var systemGroupedBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemGroupedBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// 分组界面主要背景上层内容的颜色。
    ///
    /// 将此颜色用于分组内容，包括表视图和基于托盘的设计。
    ///
    /// 与上面 `systemGroupedBackground` 配对：取 `.controlBackgroundColor`
    /// （AppKit 里内容/控件区背景），使其与 `systemGroupedBackground`（画布，
    /// `.windowBackgroundColor`）在 macOS 上确有可辨差异。
    static var secondarySystemGroupedBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondarySystemGroupedBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 内容层叠在分组界面次要背景之上的颜色。
    ///
    /// 使用此颜色用于分组内容，包括表格视图和基于盘子的设计。
    ///
    /// macOS 分支保持 `.controlBackgroundColor`（与上面二级同值）——AC 只要求
    /// canvas/raised 两档在 macOS 上可辨，这一档目前在 `SurfaceColors` 内无实际
    /// 生产消费点（`surfaceGroupedElevated` / `surfaceElevated` 未被任何组件引用），
    /// AppKit 也没有第三档背景概念可用，故不强行找一个不精确的近似值。
    static var tertiarySystemGroupedBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .tertiarySystemGroupedBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
