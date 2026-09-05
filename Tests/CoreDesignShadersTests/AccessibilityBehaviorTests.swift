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
// ⚠️ 本文件**不碰 Metal**（只测纯值计算），因此在本地原生 `swift test` 下也能编译并通过。
// ⚠️ **但 CI 的 native SwiftPM 腿跑不到它**：`.github/workflows/ci.yml` 的 `Test` 步骤是
// `swift test --skip CoreDesignShadersTests`，**整个 target 一起跳过**。本文件在 CI 上的
// 覆盖来自另外两条腿——`Test (swiftbuild) — CoreDesignShaders` 步骤
//（`swift test --build-system swiftbuild --filter CoreDesignShadersTests`）与 iOS Simulator 腿
//（`xcodebuild test -scheme CoreDesign-Package`，未 `-skip-testing` 本 target）。
//
// ⚠️ 该 `--skip` 的成因是同 target 的 `ShaderLibraryLoadTests`（在 `PlasmaTests.swift`）：
// 原生 SwiftPM 不编译 `.metal`，bundle 里没有 metallib，而 `assertShaderLibraryLoadable`
// 是 **fail-closed** 的（缺 device / 缺 library / 缺函数一律 `throw`）⇒ 原生腿上必红。
// **那才是"有意在原生腿判红"的 suite。**
//
// ⚠️ 需要 GPU 的渲染证明在 `RenderProofTests`，但它**整个文件包在 `#if os(iOS)` 里**
//（首行 `#if os(iOS)` / 末行 `#endif`）⇒ macOS 上根本不编译，**不可能判红**；
// 它只在 iOS Simulator 腿上真正运行。（上一版这里把它写成"有意在原生腿判红"，
// 与 `ModuleSmokeTests` 里已更正过的那句是同一处失真；第 3 轮 review 抓到。）

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

    /// 抓一个入口的**形参名列表**。
    ///
    /// ⚠️ 形参名而不是类型：`time` 与 `frequency` 都是 `float`，按类型分不出来。
    static func parameterNames(of entryPoint: String) throws -> [String] {
        let text = try String(contentsOf: Self.metalSource, encoding: .utf8)
        // ⚠️ 与 `declaredEntryPoints()` 同款的跨行匹配，且同样容忍 `[[ stitchable ]]` 带空格。
        let pattern = #"\[\[\s*stitchable\s*\]\]\s+\w+\s+"# + entryPoint + #"\s*\(([^)]*)\)"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: range),
              let r = Range(m.range(at: 1), in: text) else { return [] }
        return String(text[r])
            .split(separator: ",")
            .compactMap { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).last }
            .map(String.init)
    }

    /// ⚠️⚠️ **FR-12 在 `#283` 那一批上只兑现了一半，这条把那一半钉成机器判据。**
    ///
    /// FR-12 说「`layerEffect` 类冻结**时间**输入、保留手势 / 倾斜的**空间**输入」。
    /// `#283` 的两件（`coreDesignGlassOrb` / `coreDesignHalftone`）**根本没有时间输入**
    /// ⇒ 「冻结时间」那半条在它们身上是空的，本 task 不作声称；
    /// 能声称的是「空间输入不被 a11y 偏好改写」，由 `ContentEffectStopTests.focusFollowsGesture`
    /// 与 `RenderProofTests.glassOrbConsumesFocusAndSoftness` 覆盖。
    ///
    /// ⚠️ 本条守的是**那个前提本身**：有人哪天给这两个入口加了 `time` 形参，
    /// 上面那句「没有可冻结的东西」就变成假话，而**没有任何别的判据会发现**。
    ///
    /// ⚠️ **带反恒真对照**：同一台解析器必须在 `coreDesignPlasma` 上**抓得到** `time`。
    /// 抓不到 ⇒ 正则失配 ⇒ 上半条在空列表上恒真。
    @Test("两个内容层效果没有时间形参（对照：Plasma 必须抓得到 time）")
    func contentLayerEffectsHaveNoTimeInput() throws {
        let animated = try Self.parameterNames(of: "coreDesignPlasma")
        #expect(animated.contains("time"), """
        在 `coreDesignPlasma` 上都抓不到 `time` 形参 —— 形参解析失配，\
        下面那条「没有时间输入」是在空列表上恒真。实际抓到：\(animated)
        """)

        for entryPoint in ["coreDesignGlassOrb", "coreDesignHalftone"] {
            let names = try Self.parameterNames(of: entryPoint)
            #expect(!names.isEmpty, "\(entryPoint) 的形参列表抓成了空 —— 解析失配")
            #expect(!names.contains("time"), """
            \(entryPoint) 出现了 `time` 形参 —— 它从"纯空间效果"变成了动画效果，\
            FR-12 的「冻结时间输入」那半条从此对它**适用**，而本批的文档与测试都写着它不适用。\
            要么撤销这个形参，要么补齐 Reduce Motion 的冻结路径并改掉那些文档。\
            实际形参：\(names)
            """)
        }
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
