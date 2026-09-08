import Foundation
import SwiftUI

/// 第 4 层「状态功能别名」。
public extension Color {
    // ⚠️ `success` / `info` 改指系统色；`warning` / `danger` 两族**有意保持 ColorGrade 色阶**
    // ——它们被 `ButtonRoleStyleRole` 消费，基色换系统色而派生态留色阶会让同一按钮
    // rest 态与 pressed 态分属两个色相族。
    //
    // ⇒ 本层因此**自身是混的**：`success` / `info` 走系统色、`warning` / `danger` 留品牌色阶。
    // 切分线是「**有无渲染面**」而不是色相族——零/近零消费的改，有真实渲染面的冻结。
    //
    // ⚠️ 整族改成系统色**技术上可行且成本不高**：复用 `InteractionColors` 里
    // `Color.accentHover(from:)` 那套派生（对彩色 role 要用 `mix(with: .inkPrimary)`
    // ——远离背景，而不是 accent 用的 `mix(with: .surfaceBase)`）。
    // 不做的理由是**范围**：会让同一文件并存两条方向相反的派生，且要为后者补一套
    // 反向不变式判据（`AccentDerivationTests` 那 4 条是按「朝向背景」写的）。

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
