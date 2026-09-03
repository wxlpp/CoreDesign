import Foundation
import SwiftUI
import Testing

@testable import CoreDesignShaders

// ⚠️ **本文件补的是 FR-12 的行为契约**（PR #261 第 2 轮终审 I-5）。
//
// ⚠️ **第 2 轮把 suite 叫「FR-12 / FR-13」，但 FR-13 一条断言都没有**（第 3 轮终审 I-5）
// ——名字比内容大，正是本 PR 反复栽的那个跟头。suite 名已改准；FR-13（装饰层
// `accessibilityHidden`）的可断言部分见文件末尾的 `DecorativeLayerTests`。
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

@Suite("FR-12 的行为契约（冻结 / 收窄 / .still）")
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
    ///
    /// ⚠️ **初版用字符串切分，有三个静默漏检口**（第 3 轮终审 I-3），方向恰好都落在
    /// 它存在的唯一理由「新增 shader 忘了登记」上：
    /// ① `[[ stitchable ]]`（**带空格**）匹配不到——而那正是 **Apple 官方文档**里
    ///    写这个属性的形态；照文档新增一个 shader ⇒ 清单没有、也抓不到 ⇒ **假绿**；
    /// ② `[[stitchable]]` 单独一行的跨行声明 ⇒ 该行无 `(` ⇒ 直接 `continue`；
    /// ③ 函数名不以 `coreDesign` 开头就被丢弃——而命名约定并不是机器强制的。
    /// ⇒ 改用正则跨行匹配，且**不按前缀过滤**（命名约定另立一条断言）。
    static func declaredEntryPoints() throws -> Set<String> {
        let text = try String(contentsOf: Self.metalSource, encoding: .utf8)
        let pattern = #"\[\[\s*stitchable\s*\]\]\s+\w+\s+(\w+)\s*\("#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex..., in: text)
        var found = Set<String>()
        for m in regex.matches(in: text, range: range) {
            guard let r = Range(m.range(at: 1), in: text) else { continue }
            found.insert(String(text[r]))
        }
        return found
    }

    @Test("手工清单与 .metal 里的 [[stitchable]] 入口互为子集")
    func listMatchesSource() throws {
        let declared = try Self.declaredEntryPoints()
        // ⚠️ **非空断言**：正则失配时两个集合都空，双向差集恒等 ⇒ 假绿。
        let listed = Set(ShaderLibraryLoadTests.entryPoints)
        // ⚠️ **非空断言**：正则失配时两个集合都空，双向差集恒等 ⇒ 假绿。
        // ⚠️ 阈值取 `listed.count` 而非魔数 7（终审 S）——将来**合法地**删掉一个
        // shader 时，魔数会以「判据多半失配了」这条误导性消息判红。
        #expect(declared.count >= listed.count,
                "只从 .metal 抓到 \(declared.count) 个入口、清单有 \(listed.count) 个 —— 判据多半失配了")
        #expect(declared.subtracting(listed).isEmpty,
                ".metal 里有、清单里没有（新增 shader 忘了登记）：\(declared.subtracting(listed).sorted())")
        #expect(listed.subtracting(declared).isEmpty,
                "清单里有、.metal 里没有（改名或删除后忘了同步）：\(listed.subtracting(declared).sorted())")
    }

    /// 命名约定单独成一条——**不再把它混进抓取正则**（混进去会让"命名不符"表现为
    /// "根本不存在"，两种问题给同一条误导性消息）。
    @Test("入口函数名统一 coreDesign 前缀")
    func namingConvention() throws {
        let declared = try Self.declaredEntryPoints()
        let offenders = declared.filter { !$0.hasPrefix("coreDesign") }.sorted()
        #expect(offenders.isEmpty, "入口名未用 coreDesign 前缀：\(offenders)")
    }
}


// MARK: - FR-13：装饰层的 a11y

/// ⚠️ FR-13 的实现有两处：`ProceduralBackground` 的 `.accessibilityHidden(true)`
/// 与 `GlassSymbol` 本轮新加的可撤销入口。前者是无条件的、无可断言的分支；
/// 后者的判定是纯值级的，抽出来即可测（与 `elapsed` 同一手法）。
@Suite("FR-13 装饰层判定")
struct DecorativeLayerTests {

    @Test("无 label ⇒ 当装饰（隐藏）；有 label ⇒ 不隐藏")
    func decorativeDependsOnLabel() {
        #expect(GlassSymbol.isDecorative(accessibilityLabel: nil))
        #expect(!GlassSymbol.isDecorative(accessibilityLabel: Text(verbatim: "成就徽章")))
    }
}
