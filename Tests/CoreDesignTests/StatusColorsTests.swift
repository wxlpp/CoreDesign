import SwiftUI
import Testing
import Foundation
@testable import CoreDesign

// Status 色的**真行为断言**（C2）：断言 5×4 语义 token 各指向正确的 colorset asset。
//
// 旧版是 `let _: Color = .statusAccentForeground` ——只验证符号编译通过（恒真、
// 0 `#expect`）。改写后断言每个 token 的 asset 名，能捕获「status 色被误指向别的
// colorset」这类真实回退（与 C4a 同法：swift test 下 asset 颜色无法解析，故断 asset 名）。
@Suite("StatusColors")
struct StatusColorsTests {

    /// 从 `String(describing: Color)` 提取 asset 名（格式 `NamedColor(name: "…", bundle: …)`）。
    private func assetName(of color: Color) -> String? {
        let desc = String(describing: color)
        guard let r = desc.range(of: #"name: "([^"]+)""#, options: .regularExpression) else { return nil }
        return String(desc[r]).replacingOccurrences(of: #"name: ""#, with: "").dropLast().description
    }

    @Test("5×4 status token 各指向正确的 colorset asset")
    func statusColorsMapToCorrectAssets() {
        // accent
        #expect(self.assetName(of: .statusAccentForeground) == "status-accent-fg")
        #expect(self.assetName(of: .statusAccentEmphasis) == "status-accent-emphasis")
        #expect(self.assetName(of: .statusAccentMuted) == "status-accent-muted")
        #expect(self.assetName(of: .statusAccentSubtle) == "status-accent-subtle")
        // success
        #expect(self.assetName(of: .statusSuccessForeground) == "status-success-fg")
        #expect(self.assetName(of: .statusSuccessEmphasis) == "status-success-emphasis")
        #expect(self.assetName(of: .statusSuccessMuted) == "status-success-muted")
        #expect(self.assetName(of: .statusSuccessSubtle) == "status-success-subtle")
        // attention
        #expect(self.assetName(of: .statusAttentionForeground) == "status-attention-fg")
        #expect(self.assetName(of: .statusAttentionEmphasis) == "status-attention-emphasis")
        #expect(self.assetName(of: .statusAttentionMuted) == "status-attention-muted")
        #expect(self.assetName(of: .statusAttentionSubtle) == "status-attention-subtle")
        // danger
        #expect(self.assetName(of: .statusDangerForeground) == "status-danger-fg")
        #expect(self.assetName(of: .statusDangerEmphasis) == "status-danger-emphasis")
        #expect(self.assetName(of: .statusDangerMuted) == "status-danger-muted")
        #expect(self.assetName(of: .statusDangerSubtle) == "status-danger-subtle")
        // done
        #expect(self.assetName(of: .statusDoneForeground) == "status-done-fg")
        #expect(self.assetName(of: .statusDoneEmphasis) == "status-done-emphasis")
        #expect(self.assetName(of: .statusDoneMuted) == "status-done-muted")
        #expect(self.assetName(of: .statusDoneSubtle) == "status-done-subtle")
    }
}
