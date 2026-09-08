import Foundation
import SwiftUI

/// 第 4 层「状态功能别名」。
public extension Color {
    // ⚠️ `success` / `info` 改指系统色；`warning` / `danger` 两族**有意保持 ColorGrade 色阶**
    // ——它们被 `ButtonRoleStyleRole` 消费，基色换系统色而派生态留色阶会让同一按钮
    // rest 态与 pressed 态分属两个色相族。

    /// 成功语义色，指向系统绿。
    static var success: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemGreen)
        #else
            Color(nsColor: .systemGreen)
        #endif
    }

    /// 信息语义色。单色体系下指向 `label`。
    static var info: Color { .label }

    static let warning: Color = .orange5
    static let warningActive: Color = .orange7
    static let warningDisable: Color = .orange2
    static let warningHover: Color = .orange6

    static let danger: Color = .red5
    static let dangerActive: Color = .red7
    static let dangerDisable: Color = .red2
    static let dangerHover: Color = .red6
}
