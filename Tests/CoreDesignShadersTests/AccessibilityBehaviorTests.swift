import Foundation
import SwiftUI
import Testing

@testable import CoreDesignShaders

// ⚠️ **本文件补的是 FR-12 / FR-13 的行为契约**（PR #261 第 2 轮终审 I-5）。
//
// 代码与文档反复宣称这三条，而在本文件之前**一条断言都没有**：
// ① Reduce Motion 下 `elapsed` 返回 0（冻结）；
// ② Reduce Transparency 下 `ShaderRamp` 收窄斜坡；
// ③ `.still` 档不推进时间。
//
// ⚠️ 覆盖面本来选错了地方：既有的档位单调性测试测的是**可调的实现细节**，
// 而真正的行为契约反倒没测。
//
// ⚠️ 本文件**能在原生 `swift test` 腿跑**——它不碰 Metal，只测纯值计算。
// 需要 GPU 的渲染证明在 `RenderProofTests`（有意在原生腿判红）。

@Suite("FR-12 / FR-13 的行为契约")
@MainActor
struct ShaderAccessibilityTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    private func elapsed(_ offset: TimeInterval, reduceMotion: Bool, motion: ShaderMotion) -> Float {
        ProceduralBackground.elapsed(
            at: self.t0.addingTimeInterval(offset),
            origin: self.t0, motion: motion, reduceMotion: reduceMotion
        )
    }

    @Test("Reduce Motion 开启 ⇒ elapsed 恒为 0（冻结，不是停渲染）")
    func reduceMotionFreezes() {
        for offset in [0.0, 1, 60, 3600] {
            #expect(self.elapsed(offset, reduceMotion: true, motion: .regular) == 0)
        }
    }

    @Test("Reduce Motion 关闭 ⇒ 时间随日期推进（对照组）")
    func timeAdvancesWithoutReduceMotion() {
        let a = self.elapsed(1, reduceMotion: false, motion: .regular)
        let b = self.elapsed(2, reduceMotion: false, motion: .regular)
        #expect(a > 0)
        #expect(b > a, "时间没有推进：\(a) → \(b)")
    }

    @Test(".still 档不推进时间，与 Reduce Motion 无关")
    func stillMotionIsFrozen() {
        #expect(self.elapsed(120, reduceMotion: false, motion: .still) == 0)
        #expect(self.elapsed(120, reduceMotion: true, motion: .still) == 0)
    }

    /// ⚠️ Float 精度：`timeIntervalSinceReferenceDate` 量级 2.3e8 时只剩约 16 单位
    /// 精度，会吞掉 0–11 的空间项让画面变死板——这是第 1 轮修掉的 bug。
    /// 这里钉住「时间从**原点**算起」这条修复本身。
    @Test("时间从捕获的原点算起，不是绝对参考日期")
    func timeIsRelativeToOrigin() {
        let far = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let v = ProceduralBackground.elapsed(
            at: far.addingTimeInterval(1), origin: far, motion: .regular, reduceMotion: false
        )
        #expect(v > 0 && v < 100, "elapsed = \(v) —— 疑似又用了绝对时间")
    }
}

@Suite("ShaderRamp 的三档推导")
struct ShaderRampTests {

    /// ⚠️ 断言的是**斜坡宽度的方向**，不是具体色值——色值是可调的实现细节，
    /// 「Reduce Transparency 下三档相互靠拢」才是 FR-12 的承诺。
    @Test("Reduce Transparency 开启 ⇒ 三档相互靠拢")
    func reduceTransparencyNarrows() {
        let wide = ShaderRamp(tint: .accent, reduceTransparency: false)
        let narrow = ShaderRamp(tint: .accent, reduceTransparency: true)
        #expect(Self.spread(narrow) < Self.spread(wide),
                "收窄后反而更宽：\(Self.spread(narrow)) vs \(Self.spread(wide))")
    }

    @Test("mid 档恒等于传入的 tint —— 斜坡围绕基色展开，不漂移")
    func midIsTint() {
        for tint in [Color.accent, .statusDangerForeground, .contentPrimary] {
            #expect(ShaderRamp(tint: tint, reduceTransparency: false).mid == tint)
            #expect(ShaderRamp(tint: tint, reduceTransparency: true).mid == tint)
        }
    }

    /// low 与 high 的感知距离。⚠️ 用 `resolve` 取实际分量，不比较 `Color` 的相等性
    ///（后者对派生色不可靠）。
    static func spread(_ ramp: ShaderRamp) -> Double {
        let e = EnvironmentValues()
        let low = ramp.low.resolve(in: e), high = ramp.high.resolve(in: e)
        let dr = Double(low.red - high.red)
        let dg = Double(low.green - high.green)
        let db = Double(low.blue - high.blue)
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}

// MARK: - 入口清单交叉校验

/// ⚠️ **`entryPoints` 是手工清单，漏加不会有任何报错**——`PlasmaTests` 里那句注释
/// 自己承认了这一点（终审 S-1）。本仓有现成的源码扫描范式（`ComponentRegistryGuard`），
/// 十几行就能把它变成机器判据。
@Suite("[[stitchable]] 入口清单 —— 双向差集")
struct ShaderEntryPointGuard {

    static var metalSource: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/CoreDesignShadersTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // 仓库根
            .appendingPathComponent("Sources/CoreDesignShaders/CoreDesignShaders.metal")
    }

    /// 从 `.metal` 里抓出所有 `[[stitchable]]` 入口函数名。
    static func declaredEntryPoints() throws -> Set<String> {
        let text = try String(contentsOf: Self.metalSource, encoding: .utf8)
        var found = Set<String>()
        for line in text.split(separator: "\n") {
            guard line.contains("[[stitchable]]") else { continue }
            // 形如：`[[stitchable]] half4 coreDesignPlasma(float2 position, ...)`
            guard let paren = line.firstIndex(of: "(") else { continue }
            let head = line[line.startIndex..<paren]
            guard let name = head.split(separator: " ").last, name.hasPrefix("coreDesign") else { continue }
            found.insert(String(name))
        }
        return found
    }

    @Test("手工清单与 .metal 里的 [[stitchable]] 入口互为子集")
    func listMatchesSource() throws {
        let declared = try Self.declaredEntryPoints()
        // ⚠️ **非空断言**：正则失配时两个集合都空，双向差集恒等 ⇒ 假绿。
        #expect(declared.count >= 7, "只从 .metal 抓到 \(declared.count) 个入口 —— 判据多半失配了")
        let listed = Set(ShaderLibraryLoadTests.entryPoints)
        #expect(declared.subtracting(listed).isEmpty,
                ".metal 里有、清单里没有（新增 shader 忘了登记）：\(declared.subtracting(listed).sorted())")
        #expect(listed.subtracting(declared).isEmpty,
                "清单里有、.metal 里没有（改名或删除后忘了同步）：\(listed.subtracting(declared).sorted())")
    }
}
