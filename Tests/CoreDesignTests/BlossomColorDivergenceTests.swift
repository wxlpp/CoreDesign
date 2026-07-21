import SwiftUI
import Testing
import Foundation
@testable import CoreDesign

// Blossom trait 分流的**真颜色值**断言（C4a）。
//
// swift test 下 asset 颜色无法解析（SPM 不调 actool，Color.accent.resolve()
// 返回 (0,0,0,0)）。故走：String(describing: Color) 取 asset 名 → 解析对应
// colorset/Contents.json 的 light sRGB 分量 → 按 #if Blossom 断言期望值。
@Suite("Blossom 颜色分流")
struct BlossomColorDivergenceTests {

    /// 从 `String(describing: Color)` 提取 asset 名（spike 实证格式：
    /// `NamedColor(name: "brand-5", bundle: ...)`）。
    private func assetName(of color: Color) -> String? {
        let desc = String(describing: color)
        guard let r = desc.range(of: #"name: "([^"]+)""#, options: .regularExpression) else { return nil }
        return String(desc[r]).replacingOccurrences(of: #"name: ""#, with: "").dropLast().description
    }

    /// 读 `<group>/<name>.colorset/Contents.json` 的 **light**（无 appearances 的第一个 color）
    /// sRGB 分量，返回 `#RRGGBB` 大写。
    private func lightHex(group: String, name: String) -> String? {
        guard let base = Bundle.module.resourceURL?.appendingPathComponent("Resources.xcassets"),
              let data = try? Data(contentsOf: base.appendingPathComponent("\(group)/\(name).colorset/Contents.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colors = json["colors"] as? [[String: Any]] else { return nil }
        // 第一个没有 appearances 的 color = universal/light
        guard let light = colors.first(where: { $0["appearances"] == nil }),
              let c = light["color"] as? [String: Any],
              let comp = c["components"] as? [String: String],
              let r = comp["red"], let g = comp["green"], let b = comp["blue"] else { return nil }
        func hex(_ s: String) -> String {
            // 值形如 "0xFA"；也兼容 "1.000" 之类的十进制（此处 colorset 用 0xNN）
            if s.hasPrefix("0x") { return String(s.dropFirst(2)).uppercased().leftPad(2) }
            let v = Int((Double(s) ?? 0) * 255)
            return String(format: "%02X", v)
        }
        return "#\(hex(r))\(hex(g))\(hex(b))"
    }

    @Test("accent 的实际颜色值随 trait 分流")
    func accentDivergesByTrait() {
        let name = self.assetName(of: Color.accent)
        #expect(name != nil, "无法从 Color.accent 取 asset 名")

        #if Blossom
        #expect(name == "blossom-brand-5", "Blossom 下 accent 应指向 blossom-brand-5，实为 \(name ?? "nil")")
        #expect(self.lightHex(group: "blossom-brand", name: "blossom-brand-5") == "#FF6F8E")
        #else
        #expect(name == "brand-5", "默认下 accent 应指向 brand-5，实为 \(name ?? "nil")")
        #expect(self.lightHex(group: "brand", name: "brand-5") == "#0077FA")
        #endif
    }
}

private extension String {
    func leftPad(_ n: Int) -> String { count >= n ? self : String(repeating: "0", count: n - count) + self }
}
