import SwiftUI
import Foundation
@testable import CoreDesign

// MARK: - 共享测试辅助 / Shared test helpers

/// 从 `String(describing: Color)` 提取 asset 名（格式 `NamedColor(name: "…", bundle: …)`）。
///
/// swift test 下 asset 颜色无法解析（SPM 不调 `actool`，`Color.resolve()` 返回 (0,0,0,0)），
/// asset 名是唯一可稳定断言的标识。多个测试套件共用本函数，避免脆弱的 SwiftUI 描述正则
/// 在各文件里各写一份、日后分叉。**依赖 SwiftUI 内部描述格式**——SDK 若改格式需同步调整
/// （与既有 asset guard 同性质的已知脆弱点）。
func assetName(of color: Color) -> String? {
    let desc = String(describing: color)
    guard let r = desc.range(of: #"name: "([^"]+)""#, options: .regularExpression) else { return nil }
    return String(desc[r]).replacingOccurrences(of: #"name: ""#, with: "").dropLast().description
}
