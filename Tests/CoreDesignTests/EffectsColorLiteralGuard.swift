import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 禁色相字面量 / No hue literals in the new targets（Issue #246）
//
// 本仓的四层色彩系统（`CLAUDE.md`《分层色彩系统》）明写「不要在组件中直接使用底层原子色」，
// 而 `0.3.0` 把地基换成 Apple HIG 之后，第 3 层多数 token 直接指系统语义色、随系统外观
// 与对比度设置自动更新。**一个写死 `.cyan` 的动效在暗色模式 / 高对比度下就是坏的**，
// 而且它不会报错、只会难看——没有机器判据的话，表达性视觉层正是最容易堆积这类硬编码的地方。
//
// ## 射程：**只有新 target**
//
// `GuardScanRoots.newTargetRoots`（`CoreDesignEffects` / `CoreDesignCharts`）。
// **不回溯改造 `CoreDesign` 现状**（`#246` 任务书逐字）：主 target 现有 120 处色相字面量，
// 其中相当一部分是 `ColorExtension` 的调色板实现本身与 glass 描边的既有裁决，
// 回溯改造不是本 task 的题目。
//
// ⚠️ **但 `CoreDesign` 在本文件里仍有用处**——见 `detectorFiresOnRealSource`：
// 它是**探测器非真空的活证据**。两个新 target 今天是骨架文件、命中必然为 0，
// 「零违规」与「探测器坏了」在这种输入上**不可分辨**；拿主 target 当靶场跑一遍，
// 零命中就说明探测器失效，而不是「新 target 很干净」。
//
// ## 判据形态：语法树，不是 grep
//
// 逐字符 grep 会把注释与字符串里的 `.white` 一起抓进来（主 target 的 120 处命中里
// 就有一大半在文档注释里）。这里走 SwiftSyntax：
// · **隐式成员访问** `.cyan` / `.white.opacity(0.2)`（`.white` 自身是一个成员访问）；
// · **显式限定** `Color.cyan` / `UIColor.red` / `SwiftUI.Color.white` 里的色相名；
// · **数值构造** `Color(red:green:blue:)` / `Color(white:)` / `Color(hue:…)` /
//   `UIColor(red:…)` / `NSColor(…)`，**含 `.init` 形态**
//   `Color.init(red:…)` / `SwiftUI.Color.init(white:)` / `let c: Color = .init(red:…)`；
// · **`#colorLiteral(red:green:blue:alpha:)`** —— Xcode 取色器自动插入的那一种。
//
// ## 三个**已知的口子**（写在明处，不是漏了）
//
// 1. **`#Preview` 整体跳过**：预览是视觉冒烟入口、不是产品路径（与 a11y 守卫跳过
//    `#if DEBUG` 同一条裁断）。把违规写进 `#Preview` 里它看不见。之所以接受：
//    预览块不进消费者的二进制，而禁止预览里用 `.red` 会把「拿原色标出布局边界」
//    这种正当用法也一起禁掉。
// 2. **`system*` 族有意不算色相**（PR #265 终审 I-1 的裁定，见 `hueNames` 的文档）。
// 3. **本守卫暂无例外台账**——本仓其余守卫（`bool-exemptions.json` /
//    `a11y-exemptions.json` / `knownMissingExtensionPoints`）都有带署名理由的逐站点
//    逃生门，本条与 `ChromeTextLiteralGuard` 都还没有。⚠️ **出现第一个正当例外时，
//    应新增台账（形态照 `bool-exemptions.json`：键 + 署名 reason + 双向差集），
//    不得放宽判据、更不得删掉本守卫**——「用削弱判据来消化一个正当例外」正是 G-7
//    记在案的失效形态。follow-up 见 `246.md` 的《后续》。
// 4. **隐式 `.init(…)` 只在「上下文类型写得出来」时才判**（PR #265 第 3 轮终审 F-2）：
//    `ImplicitMemberContext.contextualTypeName(of:)` 只认**语法上真的写下了类型**的三处
//    ——`let c: Color = .init(red:…)` 的类型标注、`.init(red:…) as Color` 的 `as` 断言、
//    `func c() -> Color { .init(red:…) }` 的**返回位置**（单表达式体或 `return` 的直接子表达式，
//    含计算属性）。类型只存在于**推断**里
//    的位置（数组字面量元素、函数实参、`self.x = .init(red:…)` 里 stored property 的类型、
//    闭包返回值）看不见 ⇒ 放行。
//    ⚠️⚠️ **本条此前描述的收紧并不成立，已改码补上**（PR #265 第 4 轮终审 I-1）：
//    首版的上行走查遇到实参位置（`LabeledExprSyntax` / `FunctionCallExprSyntax`）**不停**，
//    一路走到外层的 `returnClause` / `typeAnnotation` ⇒ 把外层返回类型**错安**到实参上。
//    实测 4/4 误报，其中就有本条自己拿来当动机的那一种：
//    `var scrim: Color { convert(.init(hue: 0.5, saturation: 1, brightness: 1)) }`
//    ——`HSBComponents` 形态只要出现在 `-> Color` 函数体的实参位置就仍然误报。
//    现在实参位置一律 `return nil`，外层返回类型只在**返回位置**上采信。
//    ⚠️⚠️ **三元 / `??` 此前会截断上行走查**（同一轮终审 I-2）：`SequenceExprSyntax` 分支
//    找不到 `as` 就直接 `return nil`，于是 `let c: Color = flag ? .init(red:…) : .clear` 与
//    `let c: Color = maybe ?? .init(red:…)` 这两条**写了类型标注的真违规**被放行
//    ——既不在本条列举的四种漏报里，又违反本条自己的判据。已改成继续往上找。
//    两处的实证在 `contextualTypeDoesNotLeakAcrossArgumentPositions`。
//    **这是拿一条漏报换掉一条误报**：首版对**任何**宿主为空的
//    `.init` + `red`/`white`/`hue` 标签一律判红，实测把 `let p: Pixel = .init(red: 1)` /
//    `let x: Insets = .init(white: 3)` 都报成了违规——而 `hue` 在 `numericColorLabels` 里、
//    `CoreDesignEffects` 恰恰是会出现 `let hsb: HSBComponents = .init(hue:saturation:brightness:)`
//    的地方。在例外台账（口子 3）落地之前，第一个误报的唯一便宜出路就是**削弱
//    `numericColorLabels`**，那正是本文件自己禁止的 G-7 形态 ⇒ 宁可留这条**可枚举的**漏报。
// 5. **`typealias` 可以绕过**（PR #265 第 3 轮终审 S-c）：本守卫按**文本宿主名**判宿主
//    （`colorTypeNames` / `colorAnnotationNames`），`typealias C = Color; let x = C.red` 因此
//    看不见——纯语法、逐文件的扫描器解不了 alias（要解就得两遍扫描建跨文件映射，与
//    `BoolScanResult.publicBoolTypeAliases` 的裁断同源）。**没人会为了绕守卫这么写**，
//    但上面那句「已知口子写在明处」要求它被登记，而不是留在读者的想象里。
@Suite("新 target 禁色相字面量")
struct EffectsColorLiteralGuard {

    /// SwiftUI / UIKit / AppKit 的具名色相。
    ///
    /// ⚠️ **`.clear` 不在表里**：它不是色相，是「不画」。
    /// ⚠️ **`.primary` / `.secondary` / `.accentColor` 也不在表里**：它们本身就是语义色。
    /// ⚠️ **`system*` 族（`UIColor.systemPink` / `NSColor.systemRed` / `Color(.systemBlue)`）
    /// 同样不在表里，这是一条裁定而不是遗漏**（PR #265 终审 I-1）：
    /// 本守卫要防的失效形态是「**写死的颜色在暗色模式 / 高对比度下不会跟着变**」，
    /// 而 `system*` 是 Apple 的 **dynamic color**——它按外观模式与对比度设置自动取值，
    /// 恰恰**具备**本守卫要保护的那个性质，与 `.primary` / `.secondary` 同类。
    /// 且 `CLAUDE.md`《分层色彩系统》把系统语义色列为第 3 层 token 的**推荐来源**
    /// （`0.3.0` 换地基的方向本身），禁掉它会与仓库自己的地基方向相反。
    /// ⚠️ **代价照录**：`systemPink` 毕竟仍是「粉」，拿它当装饰色堆在新 target 里
    /// 本守卫看不见——这是上面口子 2 的确切含义，不是「它一定没问题」。
    ///
    /// ⚠️ **`magenta` / `darkGray` / `lightGray` 是 UIKit / AppKit 独有的三个，SwiftUI
    /// `Color` 上没有对应物**（PR #265 第 3 轮终审 F-4）：本表原按 SwiftUI 的 15 个色相列，
    /// 而 `colorTypeNames` 有意含 `UIColor` / `NSColor` / `CGColor` ⇒ `UIColor.magenta`
    /// （「写死、不随外观变化」的典型）此前被放行。
    /// **它们确实非 dynamic，已实测**（macOS 26 / AppKit）：三者的 `NSColor.type` 都是
    /// `.componentBased`，在 `.aqua` 与 `.darkAqua` 两种 appearance 下 sRGB 取值**逐位相同**
    /// （magenta 恒为 1 0 1、darkGray 恒为 0.333、lightGray 恒为 0.667），与已在表内的
    /// `.red` 同类；作为对照，`systemRed` / `systemPink` / `labelColor` 的 `type` 是
    /// `.catalog` 且两种 appearance 下取值**不同**——这正是口子 2 里 `system*` 被豁免所依据的
    /// 那条性质，两处裁定用的是同一把尺子。
    nonisolated static let hueNames: Set<String> = [
        "black", "blue", "brown", "cyan", "darkGray", "gray", "green", "indigo",
        "lightGray", "magenta", "mint", "orange", "pink", "purple", "red", "teal",
        "white", "yellow",
    ]

    /// 允许作为色相名前缀的限定符（`Color.cyan` 合法地被抓，`rgba.red` 不被抓）。
    nonisolated static let colorTypeNames: Set<String> = ["Color", "UIColor", "NSColor", "CGColor", "SwiftUI"]

    /// 隐式成员 `.init(…)` 形态可接受的**上下文类型名**。
    ///
    /// ⚠️ **不是 `colorTypeNames`**：那里的 `SwiftUI` 是**模块名**（用于 `SwiftUI.Color.white`
    /// 这种限定前缀），拿它当类型标注判会把 `let x: SwiftUI.Anything = .init(red:)` 一起收进来。
    /// 类型标注侧只认真正的颜色**类型**——`SwiftUI.Color` 经
    /// `ImplicitMemberContext.leafTypeName(_:)` 剥成 `"Color"` 后照样命中。
    nonisolated static let colorAnnotationNames: Set<String> = ["Color", "UIColor", "NSColor", "CGColor"]

    /// 数值构造的实参标签——命中其一即判「用数字调色」。
    nonisolated static let numericColorLabels: Set<String> = ["red", "white", "hue"]

    nonisolated struct Violation: Hashable, Sendable {
        let file: String
        let line: Int
        let snippet: String
        var description: String { "\(self.file):\(self.line) → \(self.snippet)" }
    }

    /// 合成输入入口——变红自证与边界形态都走它，不碰磁盘。
    static func scan(source: String, fileName: String = "Synthetic.swift") -> [Violation] {
        let tree = SwiftParser.Parser.parse(source: source)
        if tree.hasError {
            Issue.record("解析出错：\(fileName) —— swift-syntax major 可能与工具链不配套")
        }
        let converter = SourceLocationConverter(fileName: fileName, tree: tree)
        let collector = ColorLiteralCollector(fileName: fileName, converter: converter)
        collector.walk(tree)
        return collector.violations
    }

    /// 扫一个根，返回全部命中。
    static func scan(root: URL) throws -> [Violation] {
        var out: [Violation] = []
        for url in GuardScanRoots.swiftFiles(in: root) {
            out += Self.scan(
                source: try String(contentsOf: url, encoding: .utf8),
                fileName: GuardScanRoots.relativePath(url)
            )
        }
        return out
    }

    @Test("新 target 里零色相字面量")
    func noColorLiteralsInNewTargets() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.newTargetRoots))

        var offenders: [Violation] = []
        var scannedFiles = 0
        for root in GuardScanRoots.newTargetRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            // ⚠️ 逐根非空：目录在、文件没有 ⇒ 扫描器恒绿。
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count
            offenders += try Self.scan(root: root.url)
        }
        #expect(scannedFiles > 0, "新 target 一个源文件都没扫到 —— 「零违规」不可信")

        #expect(offenders.isEmpty, """
        新 target 里出现了色相字面量：
        \(offenders.map(\.description).joined(separator: "\n"))
        —— 本仓的色彩系统分四层，组件层只许用第 3/4 层的语义 token
        （`Color.accent` / `Color.contentPrimary` / `Color.statusDangerForeground` …）。
        写死的色相在暗色模式 / 高对比度下不会报错，只会难看。
        处置：换成已有语义 token；缺 token 就去 `Sources/CoreDesign/Colors/` 补一个**名字**，
        不要把色相硬编码进新 target。
        """)
    }

    @Test("探测器真的会开火：合成输入逐形态变红自证")
    func detectorFiresOnSyntheticSource() {
        // ⚠️ **本条是 `#246` AC「每条新守卫必须附一个会让它变红的 fixture」的落点**：
        // 两个新 target 今天是骨架文件，上面那条判据在 0 个命中上**必绿**，
        // 「零违规」与「探测器坏了」不可分辨。逐形态钉死。
        let cases: [(name: String, source: String)] = [
            ("隐式成员访问 `.cyan`", """
            import SwiftUI
            public struct A: View {
                public var body: some View { Color.clear.foregroundStyle(.cyan) }
            }
            """),
            ("`.white.opacity(…)`（AC 点名形态）", """
            import SwiftUI
            public struct B: View {
                public var body: some View { Color.clear.overlay(.white.opacity(0.2)) }
            }
            """),
            ("显式限定 `Color.red`", """
            import SwiftUI
            let c = Color.red
            """),
            ("数值构造 `Color(red:green:blue:)`（AC 点名形态）", """
            import SwiftUI
            let c = Color(red: 0.1, green: 0.2, blue: 0.3)
            """),
            ("数值构造 `Color(white:)`", """
            import SwiftUI
            let c = Color(white: 0.5)
            """),
            ("数值构造 `UIColor(hue:…)`", """
            import UIKit
            let c = UIColor(hue: 0.5, saturation: 1, brightness: 1, alpha: 1)
            """),
            // ⚠️ 以下四条是 PR #265 双评审补的**绕过形态**（Copilot A-3 / 终审 I-2、S-2）。
            ("`.init` 形态 `Color.init(red:green:blue:)`", """
            import SwiftUI
            let c = Color.init(red: 1, green: 0, blue: 0)
            """),
            ("限定 `.init` 形态 `SwiftUI.Color.init(white:)`", """
            import SwiftUI
            let c = SwiftUI.Color.init(white: 0.5)
            """),
            ("隐式成员 `.init` 形态 `let c: Color = .init(red:…)`", """
            import SwiftUI
            let c: Color = .init(red: 1, green: 0, blue: 0)
            """),
            ("`#colorLiteral(…)`（Xcode 取色器插入的形态）", """
            import SwiftUI
            let c = Color(#colorLiteral(red: 1, green: 0, blue: 0, alpha: 1))
            """),
            ("限定色相 `SwiftUI.Color.white`", """
            import SwiftUI
            let c = SwiftUI.Color.white
            """),
            // ⚠️ 以下是 PR #265 第 3 轮终审补的形态（F-2 / F-4）。
            ("UIKit 专有非 dynamic 色相 `UIColor.magenta`（F-4）", """
            import UIKit
            let c = UIColor.magenta
            """),
            ("AppKit 专有非 dynamic 色相 `NSColor.darkGray`（F-4）", """
            import AppKit
            let c = NSColor.darkGray
            """),
            ("UIKit 专有非 dynamic 色相 `UIColor.lightGray`（F-4）", """
            import UIKit
            let c = UIColor.lightGray
            """),
            ("`as` 断言给出的上下文类型 `.init(red:…) as Color`（F-2 收紧后仍要红）", """
            import SwiftUI
            let c = .init(red: 1, green: 0, blue: 0) as Color
            """),
            ("返回类型给出的上下文类型 `func … -> Color { .init(red:…) }`（F-2 收紧后仍要红）", """
            import SwiftUI
            func makeTint() -> Color { .init(red: 1, green: 0, blue: 0) }
            """),
            ("计算属性的类型标注 `var c: Color { .init(white:) }`（F-2 收紧后仍要红）", """
            import SwiftUI
            var scrim: Color { .init(white: 0.5) }
            """),
        ]
        for c in cases {
            #expect(!Self.scan(source: c.source).isEmpty, "\(c.name)：探测器漏报 —— 上面那条「零违规」毫无意义")
        }

        // 反向：不该误报的形态。
        let clean: [(name: String, source: String)] = [
            ("语义 token", "let c = Color.accent"),
            ("`.clear` 不是色相", "let c = Color.clear"),
            ("`.primary` / `.secondary` 是语义色", "let a = Color.primary; let b = Color.secondary"),
            ("同名成员但宿主不是颜色类型", "let v = pixel.red + pixel.green"),
            ("注释与字符串里的色相名", """
            // 这里说的是 .white 与 Color(red: 1, green: 0, blue: 0)
            let s = "白色 .white"
            """),
            ("`#Preview` 里的原色（有意跳过，见文件头）", """
            import SwiftUI
            #Preview { Color.red }
            """),
            // ⚠️ **裁定的落点**（终审 I-1）：`system*` 是 dynamic color、按外观自动取值，
            // 与 `.primary` / `.secondary` 同类，**有意不算色相**。这两条钉住裁定，
            // 免得后人把它当漏报「顺手补上」而与文件头的口子 2 打架。
            ("`system*` 是语义色，不是色相（裁定，见 `hueNames` 文档）", """
            import UIKit
            let a = UIColor.systemPink
            let b = NSColor.systemRed
            """),
            ("`Color(.systemBlue)` 是系统色桥接惯用法", """
            import SwiftUI
            let c = Color(.systemBlue)
            """),
            ("非颜色类型的 `.init` 数值构造（**显式**宿主，走 `host == \"Pixel\"` 的提前返回）", """
            struct Pixel { init(red: Int) {} }
            let p = Pixel.init(red: 1)
            """),
            // ⚠️⚠️ **下面两条才是真正钉住 F-2 的**（PR #265 第 3 轮终审）：上一条用的是
            // **显式**形态 `Pixel.init(red: 1)`，它走 `host == "Pixel"` 的提前返回分支，
            // 对「宿主为空的隐式 `.init`」这条风险路径**零覆盖**，读起来却像已经覆盖了。
            // 这两条走的正是那条路径——收紧前实测双双误报。
            ("非颜色类型的**隐式** `.init(red:)`（F-2 风险路径）", """
            struct Pixel { init(red: Int) {} }
            let p: Pixel = .init(red: 1)
            """),
            ("非颜色类型的**隐式** `.init(white:)`（F-2 风险路径）", """
            struct Insets { init(white: Int) {} }
            let x: Insets = .init(white: 3)
            """),
            ("`hue:` 标签的非颜色类型（`CoreDesignEffects` 现实会出现的形态）", """
            struct HSBComponents { init(hue: Double, saturation: Double, brightness: Double) {} }
            let hsb: HSBComponents = .init(hue: 0.5, saturation: 1, brightness: 1)
            """),
            // ⚠️ **以下两条钉的是「已知口子」，不是「本该干净」**（文件头口子 4 / 5）：
            // 它们**目前放行**，把这件事写成断言，后人若收紧了判据会在这里当场看见，
            // 必须同轮改口子清单——而不是让口子悄悄消失或悄悄变宽。
            ("口子 4：上下文类型只存在于推断里（数组元素位置）⇒ 放行", """
            import SwiftUI
            let palette: [Color] = [.init(red: 1, green: 0, blue: 0)]
            """),
            ("口子 5：`typealias` 改名后按文本判宿主看不见 ⇒ 放行", """
            import SwiftUI
            typealias C = Color
            let c = C.red
            """),
        ]
        for c in clean {
            let hits = Self.scan(source: c.source)
            #expect(hits.isEmpty, "\(c.name)：误报 \(hits.map(\.description))")
        }
    }

    /// PR #265 **第 4 轮**终审 I-1 / I-2 的探针实证。
    ///
    /// ⚠️ 这两条不是「再补几个 fixture」，而是**口子 4 的两处失真**：
    /// · I-1（4 条误报）——口子 4 声称「改为要求上下文真的写下了颜色类型」，
    ///   而外层函数 / 计算属性的返回类型此前会被**错安到实参位置**，
    ///   于是它自己拿来当动机的 `HSBComponents.init(hue:saturation:brightness:)`
    ///   形态只要出现在 `-> Color` 函数体的实参里**仍然误报**；
    /// · I-2（2 条漏报）——三元 / `??` 截断上行走查，源码里**明明白白写了类型标注**的
    ///   真违规被放行，而口子 4 列举的漏报只有「数组元素 / 函数实参 / stored property /
    ///   闭包返回值」四种，这两种既不在列又违反它自己的判据。
    @Test("上下文类型：实参位置不继承外层返回类型；三元 / `??` 不截断（第 4 轮终审 I-1 / I-2）")
    func contextualTypeDoesNotLeakAcrossArgumentPositions() {
        // ① I-1 的四条误报——修复后必须**清零**。
        let falsePositives: [(name: String, source: String)] = [
            ("计算属性返回类型被错安到实参（口子 4 的动机形态本身）", """
            import SwiftUI
            var scrim: Color { convert(.init(hue: 0.5, saturation: 1, brightness: 1)) }
            """),
            ("函数返回类型被错安到实参", """
            import SwiftUI
            func tint() -> Color { convert(.init(hue: 0.5, saturation: 1, brightness: 1)) }
            """),
            ("`return` 里的实参位置", """
            import SwiftUI
            func tint() -> Color { let a = 1; return convert(.init(red: 1, green: 0, blue: 0), a) }
            """),
            ("嵌套两层实参 + UIKit 返回类型", """
            import UIKit
            func tint() -> UIColor { UIColor(cgColor: make(.init(white: 3))) }
            """),
        ]
        for c in falsePositives {
            let hits = Self.scan(source: c.source)
            #expect(hits.isEmpty, """
            \(c.name)：误报 \(hits.map(\.description))
            —— 隐式成员在**实参位置**的类型来自形参，与外层返回类型无关。
            """)
        }

        // ② I-2 的两条漏报——源码里写了类型标注，修复后必须**判红**。
        let falseNegatives: [(name: String, source: String)] = [
            ("三元的分支（有类型标注）", """
            import SwiftUI
            let c: Color = flag ? .init(red: 1, green: 0, blue: 0) : .clear
            """),
            ("`??` 的右侧（有类型标注）", """
            import SwiftUI
            let c: Color = maybe ?? .init(red: 1, green: 0, blue: 0)
            """),
        ]
        for c in falseNegatives {
            #expect(!Self.scan(source: c.source).isEmpty, """
            \(c.name)：漏报 —— `SequenceExprSyntax` 分支找不到 `as` 时若直接终止上行走查，
            这条**写了类型标注**的真违规会被放行（口子 4 的判据是「上下文真的写下了颜色类型」）。
            """)
        }

        // ③ **没有换来新的漏报**：真返回位置 / 真标注位置必须仍然命中。
        let stillCaught: [(name: String, source: String)] = [
            ("类型标注 `let c: Color = .init(red:…)`", """
            import SwiftUI
            let c: Color = .init(red: 1, green: 0, blue: 0)
            """),
            ("显式 `return .init(white:)`（真返回位置）", """
            import SwiftUI
            func scrim() -> Color { return .init(white: 0.5) }
            """),
            ("多语句体里的显式 `return`（真返回位置）", """
            import SwiftUI
            func scrim() -> Color { let a = 1; _ = a; return .init(white: 0.5) }
            """),
            ("单表达式体 `func … -> Color { .init(red:…) }`", """
            import SwiftUI
            func makeTint() -> Color { .init(red: 1, green: 0, blue: 0) }
            """),
            ("计算属性单表达式体 `var c: Color { .init(white:) }`", """
            import SwiftUI
            var scrim: Color { .init(white: 0.5) }
            """),
            ("`as` 断言 `.init(red:…) as Color`", """
            import SwiftUI
            let c = .init(red: 1, green: 0, blue: 0) as Color
            """),
        ]
        for c in stillCaught {
            #expect(!Self.scan(source: c.source).isEmpty,
                    "\(c.name)：收紧上下文判据换来了一条新漏报 —— 这不是 I-1 / I-2 要的结果")
        }
    }

    @Test("探测器在真实源码上非真空：拿主 target 当靶场必须打出命中")
    func detectorFiresOnRealSource() throws {
        // ⚠️ **`CoreDesign` 不在本守卫射程内**（`#246` 明写不回溯改造），
        // 这里只把它当**靶场**：真实源码里必然有色相字面量（`ColorExtension` 的调色板、
        // glass 描边的 `.white.opacity(…)`）。零命中 ⇒ 探测器失效，
        // 那么新 target 上的「零违规」同样不可信。
        let hits = try Self.scan(root: GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName))
        #expect(hits.count > 10, """
        在 Sources/CoreDesign 上只打出 \(hits.count) 处色相字面量 —— 探测器疑似失效。
        本条**不是**要求主 target 保持违规，而是「新 target 的零命中必须来自干净、
        不是来自坏掉的探测器」这句话的活证据。若主 target 真的被治理干净了，
        请把本条改成扫一份常驻 fixture，而不是直接删掉它。
        """)
    }
}

// MARK: - 采集器 / Collector

/// 采集色相字面量。
///
/// ⚠️ **`base` 判别是刻意的**：只认「隐式成员访问」（`.cyan`）与「颜色类型限定」
/// （`Color.cyan`）两种。`pixel.red` 这类同名成员不算——否则任何叫 `red` 的属性
/// 都会变成违规，判据会淹在假阳性里、最后被人整条关掉。
private nonisolated final class ColorLiteralCollector: SyntaxVisitor {
    var violations: [EffectsColorLiteralGuard.Violation] = []

    private let fileName: String
    private let converter: SourceLocationConverter

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    /// `#Preview { … }` 整体跳过——预览不是产品路径（见文件头的裁断与它的已知口子）。
    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }

    /// ⚠️ **`#colorLiteral(red:green:blue:alpha:)` 必须在这里拦**（PR #265 终审 I-2）：
    /// 它解析成 `MacroExpansionExprSyntax`，子节点是一串**裸浮点字面量**的
    /// `LabeledExprListSyntax`——既没有 member access、也没有 function call，
    /// 下面两个 override 一个都碰不到它。而它正是 **Xcode 取色器自动插入的形态**，
    /// 是硬编码颜色最可能的入口：首版对非 `Preview` 宏一律 `.visitChildren`，
    /// 于是这条路径整个逃逸，且没有登记在「已知口子」里。
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        if node.macroName.text == "Preview" { return .skipChildren }
        if node.macroName.text == "colorLiteral" {
            self.record(node, snippet: node.trimmedDescription)
            return .skipChildren
        }
        return .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.declName.baseName.text
        guard EffectsColorLiteralGuard.hueNames.contains(name) else { return .visitChildren }
        // base 为 nil ⇒ 隐式成员访问 `.cyan`；否则必须是颜色类型名。
        if let base = node.base {
            let root = base.trimmedDescription.split(separator: ".").map(String.init)
            guard let first = root.first,
                  EffectsColorLiteralGuard.colorTypeNames.contains(first) else { return .visitChildren }
        }
        self.record(node, snippet: node.trimmedDescription)
        return .visitChildren
    }

    /// ⚠️ **`.init` 形态必须单独剥一层**（PR #265 Copilot A-3 / 终审 S-2）：
    /// 首版取点号链的**最后一段**判宿主类型，于是 `Color.init(red:green:blue:)` /
    /// `SwiftUI.Color.init(white:)` / `let c: Color = .init(red:…)` 的最后一段都是
    /// `"init"`、不在 `colorTypeNames` 里 ⇒ 「禁数值色字面量」有一条一行就能写出来的绕过。
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // ⚠️ `omittingEmptySubsequences: false`：隐式成员 `.init(red:…)` 的 callee 文本是
        // `.init`，丢掉空段后只剩 `["init"]`，与 `Foo.init` 不可分辨。
        var callee = node.calledExpression.trimmedDescription
            .split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let isInitForm = callee.last == "init"
        if isInitForm { callee.removeLast() }
        let host = callee.last ?? ""
        // ⚠️ **隐式成员 `.init(red:…)` 必须真的问一次上下文类型**（PR #265 第 3 轮终审 F-2）：
        // 首版在 `isInitForm && host.isEmpty` 上**无条件**接受、只靠下面的数值标签判据兜，
        // 并论证「误报面接近零」——实测为假：`let p: Pixel = .init(red: 1)` 与
        // `let x: Insets = .init(white: 3)` 都被判红，而 `hue` 也在 `numericColorLabels` 里
        // ⇒ `let hsb: HSBComponents = .init(hue:saturation:brightness:)` 同样中招。
        // 在例外台账落地之前，第一个误报的唯一便宜出路就是削弱 `numericColorLabels`，
        // 那正是本文件禁止的 G-7 形态 ⇒ 这里改成**要求上下文写出了颜色类型**才收。
        // 代价（一条可枚举的漏报）记在文件头口子 4。
        let isColorAnnotatedInit = isInitForm && host.isEmpty
            && ImplicitMemberContext.contextualTypeName(of: node)
                .map(EffectsColorLiteralGuard.colorAnnotationNames.contains) == true
        guard EffectsColorLiteralGuard.colorTypeNames.contains(host) || isColorAnnotatedInit
        else { return .visitChildren }
        let labels = node.arguments.compactMap { $0.label?.text }
        guard labels.contains(where: { EffectsColorLiteralGuard.numericColorLabels.contains($0) })
        else { return .visitChildren }
        self.record(node, snippet: node.trimmedDescription)
        return .visitChildren
    }

    private func record(_ node: some SyntaxProtocol, snippet: String) {
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        // 长表达式截断，报错信息才读得下去。
        let oneLine = snippet.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        self.violations.append(
            .init(file: self.fileName, line: line, snippet: String(oneLine.prefix(120)))
        )
    }
}

// MARK: - 隐式成员表达式的上下文类型 / Contextual type of an implicit member expression

/// `.init(…)` / `.foo(…)` 这类**隐式成员**表达式的宿主类型在语法树里不存在——它由类型检查
/// 从上下文推断。本工具只回答语法能回答的那一半：**源码里真的写下了类型**的三处。
///
/// ⚠️ **两条守卫共用它**（`EffectsColorLiteralGuard` 的 `.init(red:…)` 与
/// `ChromeTextLiteralGuard` 的 `let t: Text = .init("…")`）：#265 第 3 轮终审 S-b 指出
/// 两者对同一种形态的处理**不对称且无任何记录**，共用一份实现是那条不对称的结构性解法。
///
/// ⚠️ **它给不出的**（两条守卫的已知口子里各自登记）：数组 / 字典字面量的元素、
/// 函数实参位置、`self.stored = .init(…)` 里 stored property 的类型、闭包返回值
/// ——这些位置的类型只存在于推断里，语法树上没有可读的锚点。
nonisolated enum ImplicitMemberContext {

    /// 从 `node` 往上找最近的**显式类型**，找不到返回 `nil`。
    ///
    /// ⚠️ **实参位置一律 `return nil`**（PR #265 第 4 轮终审 I-1）：隐式成员落在实参位置时，
    /// 它的类型来自**形参**，与外层函数的返回类型 / 外层变量的标注**无关**。首版的上行走查
    /// 遇到 `LabeledExprSyntax` / `FunctionCallExprSyntax` 不停，一路走到
    /// `FunctionDeclSyntax` 的 `returnClause` 或 `PatternBindingSyntax` 的 `typeAnnotation`
    /// ⇒ 把外层返回类型**错安**到实参上。实测 4/4 全误报，且**恰好是**口子 4 拿来当动机的
    /// `HSBComponents.init(hue:saturation:brightness:)` 形态：
    /// `var scrim: Color { convert(.init(hue: 0.5, saturation: 1, brightness: 1)) }`。
    /// 同一工具被两条守卫共用 ⇒ chrome 守卫同样被传染
    /// （`func title() -> Text { render(.init("Loading")) }`）。
    ///
    /// ⚠️ **外层函数 / 计算属性的返回类型只在「返回位置」上采信**：单表达式体，或
    /// `ReturnStmtSyntax` 的直接子表达式。`func f() -> Color { _ = .init(red: 1); return .clear }`
    /// 里那个 `.init` 不是函数的结果，采信返回类型同样是把类型错安上去。
    static func contextualTypeName(of node: some SyntaxProtocol) -> String? {
        var current = Syntax(node)
        // 仍处在「函数 / 计算属性的返回位置」链上？一旦经过一个多语句块里的非 `return`
        // 语句，外层的返回类型就不再是本表达式的上下文类型。
        var inReturnPosition = true
        var sawReturnStmt = false
        while let parent = current.parent {
            // ⚠️ 闭包边界处**停**：闭包的返回类型多数写不出来，继续往上会把外层
            // `let v: Color = ...` 的标注错安到闭包体里的表达式上（误报方向）。
            if parent.is(ClosureExprSyntax.self) { return nil }
            // ⚠️ **实参位置处停**（终审 I-1）：`f(.init(red: 1))` 的类型来自 `f` 的形参。
            // 元组 / 下标的元素同样落在 `LabeledExprSyntax` 上，一并停——它们的上下文类型
            // 也不是外层的返回类型（`(Color, Color)` 这类元组类型 `leafTypeName` 本就给不出）。
            if parent.is(LabeledExprSyntax.self) { return nil }
            if let call = parent.as(FunctionCallExprSyntax.self),
               Syntax(call.calledExpression).id != current.id {
                // callee 之外的位置（trailing closure 等）同样不继承外层类型。
                return nil
            }
            if let binding = parent.as(PatternBindingSyntax.self) {
                // `let c: Color = .init(…)` 与 `var c: Color { .init(…) }` 走同一条。
                guard inReturnPosition else { return nil }
                return binding.typeAnnotation.flatMap { Self.leafTypeName($0.type) }
            }
            if let asExpr = parent.as(AsExprSyntax.self) { return Self.leafTypeName(asExpr.type) }
            // ⚠️ **`as` 在未折叠的语法树里不是 `AsExprSyntax`**：SwiftParser 产出的是
            // `SequenceExprSyntax`，`x as T` 落成 `[表达式, UnresolvedAsExprSyntax, TypeExprSyntax]`
            // 三个平铺元素（折叠成 `AsExprSyntax` 是类型检查阶段的事，本仓的守卫只解析不检查）。
            // 只认 `AsExprSyntax` 会让 `.init(red:…) as Color` 整条形态漏掉。
            if let sequence = parent.as(SequenceExprSyntax.self) {
                let elements = Array(sequence.elements)
                var asType: String?
                for (index, element) in elements.enumerated()
                where element.is(UnresolvedAsExprSyntax.self) {
                    guard index + 1 < elements.count,
                          let typeExpr = elements[index + 1].as(TypeExprSyntax.self) else { continue }
                    asType = Self.leafTypeName(typeExpr.type)
                    break
                }
                if let asType { return asType }
                // ⚠️ **找不到 `as` 时必须继续往上，不能 `return nil`**（PR #265 第 4 轮终审 I-2）：
                // 三元与 `??` 在未折叠的语法树里也是 `SequenceExprSyntax`，首版在这里直接终止
                // ⇒ `let c: Color = flag ? .init(red: 1, green: 0, blue: 0) : .clear` 与
                // `let c: Color = maybe ?? .init(red: 1, green: 0, blue: 0)` 这两条
                // **源码里明明白白写了类型标注**的真违规被放行——既不在口子 4 列举的
                // 漏报里，也违反口子 4 自己的判据（「上下文真的写下了颜色类型」）。
                current = parent
                continue
            }
            if parent.is(ReturnStmtSyntax.self) { sawReturnStmt = true }
            // 多语句体里的非 `return` 语句 ⇒ 本表达式不是函数的结果。
            if let list = parent.as(CodeBlockItemListSyntax.self), !sawReturnStmt, list.count != 1 {
                inReturnPosition = false
            }
            if let fn = parent.as(FunctionDeclSyntax.self) {
                guard inReturnPosition else { return nil }
                return fn.signature.returnClause.map { Self.leafTypeName($0.type) } ?? nil
            }
            current = parent
        }
        return nil
    }

    /// `Color` / `SwiftUI.Color` / `Color?` / `Color!` ⇒ `"Color"`。
    static func leafTypeName(_ type: TypeSyntax) -> String? {
        if let optional = type.as(OptionalTypeSyntax.self) { return Self.leafTypeName(optional.wrappedType) }
        if let forced = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return Self.leafTypeName(forced.wrappedType)
        }
        if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
        if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
        return nil
    }
}
