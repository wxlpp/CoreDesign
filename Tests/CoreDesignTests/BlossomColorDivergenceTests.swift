import SwiftUI
import Testing
import Foundation
@testable import CoreDesign

// Blossom trait 分流的**真颜色值**断言（C4a）。
//
// 两层断言，平台自适应：
//   1. **asset 名**分流（两种分发都跑、都强）：`String(describing: Color)` 取 asset 名，
//      按 `#if Blossom` 断言 accent 指向不同 colorset——不同 asset 即不同颜色，这已区分分流。
//   2. **真 sRGB 值**（仅 SwiftPM）：解析 `colorset/Contents.json` 的 light 分量做加强断言。
//      xcodebuild 把 `.xcassets` 编译成 Assets.car，原始 `Contents.json` 不存在（正是
//      `BlossomAssetTests` 在 CI iOS job 被 `-skip-testing` 的同一原因）；此时按目录是否存在
//      检测环境并**跳过真值断言**——不改 CI skip 列表（本任务硬边界），改让测试自适应。
@Suite("Blossom 颜色分流")
struct BlossomColorDivergenceTests {

    // asset 名提取用共享的 `assetName(of:)`（见 TestSupport.swift）。

    /// `.xcassets` 是否以**原始目录**分发（SwiftPM 为真；xcodebuild 编译成 Assets.car 为假）。
    /// 为真时 `lightHex` 必须能读到值——故 SwiftPM 下的解析回退仍会让断言变红（reverse-proof
    /// 不被降级掩盖）；为假时跳过真值断言。
    private var xcassetsIsRawDirectory: Bool {
        guard let base = Bundle.module.resourceURL?.appendingPathComponent("Resources.xcassets") else { return false }
        return FileManager.default.fileExists(atPath: base.path)
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
        let name = assetName(of: Color.accent)
        #expect(name != nil, "无法从 Color.accent 取 asset 名")

        #if Blossom
        #expect(name == "blossom-brand-5", "Blossom 下 accent 应指向 blossom-brand-5，实为 \(name ?? "nil")")
        if self.xcassetsIsRawDirectory {
            #expect(self.lightHex(group: "blossom-brand", name: "blossom-brand-5") == "#FF6F8E")
        }
        #else
        #expect(name == "brand-5", "默认下 accent 应指向 brand-5，实为 \(name ?? "nil")")
        if self.xcassetsIsRawDirectory {
            #expect(self.lightHex(group: "brand", name: "brand-5") == "#0077FA")
        }
        #endif
    }
}

private extension String {
    func leftPad(_ n: Int) -> String { count >= n ? self : String(repeating: "0", count: n - count) + self }
}
