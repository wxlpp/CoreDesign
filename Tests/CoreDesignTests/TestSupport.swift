import SwiftUI
import Foundation
@testable import CoreDesign

// MARK: - 共享测试辅助 / Shared test helpers

func assetName(of color: Color) -> String? {
    let desc = String(describing: color)
    guard let r = desc.range(of: #"name: "([^"]+)""#, options: .regularExpression) else { return nil }
    return String(desc[r]).replacingOccurrences(of: #"name: ""#, with: "").dropLast().description
}
