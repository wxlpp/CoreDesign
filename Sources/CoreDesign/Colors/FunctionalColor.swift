//
//  FunctionalColor.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI


/// 第 4 层「状态功能别名」。
///
/// 本层只承载**状态语义**（success / info / warning / danger）。交互色不在此层——
/// `accent` / `secondaryAccent` / `neutralAccent` 等走第 3 层 `InteractionColors`。
///
/// > 该层曾定义 `Color.primary/secondary/tertiary` 三组，因与 SwiftUI 内建成员同名
/// > 而遮蔽它们（删除时编译器不报错，只静默改变解析目标）——已移除该组别名。
public extension Color {
    static let success: Color = .green5
    static let info: Color = .blue5

    static let warning: Color = .orange5
    static let warningActive: Color = .orange7
    static let warningDisable: Color = .orange2
    static let warningHover: Color = .orange6

    static let danger: Color = .red5
    static let dangerActive: Color = .red7
    static let dangerDisable: Color = .red2
    static let dangerHover: Color = .red6
}
