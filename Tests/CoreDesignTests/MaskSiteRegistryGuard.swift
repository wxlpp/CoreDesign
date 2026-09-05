import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 的 `.mask` 点位台账（Issue #276）
//
// ## 它治什么
//
// `.mask { … }` 读的是遮罩内容的 **alpha 通道**。基色但凡不是满不透明，被遮的内容
// 就整体变淡一档——**不报错、只难看**，而本仓既有的位图判据全是「a != b」/
//「!= blank」形态，**一条都抓不到**。#276 的四处遮罩就是这么在树上待了几个 epic 的：
// 一条写错的注释（「`.primary` 恒为不透明 ⇒ 与写死 `.white` 等效」）被逐处复制，
// 每一处都拿它当选型理由。
// ⚠️ 那条注释的 α 说法是**平台相关**的：macOS `labelColor` = 0.8471、
// iOS `label` = 1.0（`MaskOpaqueTokenTests.primaryAlphaIsPlatformDependent`）
// ⇒ 它在 iOS 腿上恰好成立，这正是它能被复制五份而无人察觉的原因。
//
// ## 它**不**治什么（读小一点，别读大）
//
// ⚠️⚠️ **本守卫不检查遮罩基色的 alpha，一个都不查。** 它只做一件事：
// **让新增的 `.mask` 点位无法悄悄进树**——点位必须先登记，登记时人要读到这段账。
// 真正钉住 α 的是四条**性质**判据，各自带反向变异实证：
//
// | 点位 | 性质判据 |
// |---|---|
// | `Color.maskOpaque` 本身 | `MaskOpaqueTokenTests`（α == 1 / 满遮罩是 no-op / mask 不读 RGB） |
// | `AnimatedMeshGradient` | `AnimatedMeshGradientAlphaRangeTests.tintAlphaMaskSpansItsDeclaredRange` |
// | `ProcessingSweep` ×2 | `ProcessingSweepTests.maskStopsAreFullyOpaqueAtTheirPeak` |
// | `BeforeAfterSlider` | `BeforeAfterSliderTests.endpointRenderIsIndependentOfTheHiddenLayer`（该处已改走裁剪，无遮罩） |
//
// ⚠️ **为什么不做成"逐点位查 alpha"**：遮罩内容是任意视图，基色可以经**任意层间接**
// 到达（`AnimatedMeshGradient` 的色标就来自 `MeshDrift.tintAlphaMask(phase:)` 这个函数，
// 遮罩闭包里根本看不到任何颜色名）。一个只看闭包里字面颜色名的守卫会在这类形态上
// **静默漏过**，而它长得像在守——那正是本仓反复记账的失效形态。
// ⇒ 这里明说自己是**形状级的完备性闸**，不是性质判据；性质在上表那四条里。
//
// ## 射程：只有新 target
//
// `GuardScanRoots.newTargetRoots`（`CoreDesignEffects` / `CoreDesignCharts`），
// 与 `EffectsColorLiteralGuard` / `ChromeTextLiteralGuard` / `ExtensionEntryPointGuard`
// 同一条射程裁定（「不回溯改造 `CoreDesign` 现状」，`#246` 任务书逐字）。
// 主 target 现有的 `.mask` 用点不在本守卫射程内。
//
// ## 键的形态与它的已知脆弱面
//
// 键 = `<仓库根相对路径>#<最近的具名声明>`，例如
// `Sources/CoreDesignEffects/ProcessingSweep.swift#glowRing`。
//
// ⚠️ **不用行号**：行号今天全对，任何人在文件里插一行就全错，而且改动是无声的
//（`GuardScanRoots.relativePath` 的文档里记着同一条：「本 PR 刚把行号引用统一改成
// 符号名，写回行号是反向漂移」）。
// ⚠️ **已知脆弱面照录**：同一个声明里有**两处** `.mask` 时，两者的键相同 ⇒ 台账只需
// 一条就都放行。今天四个点位各在自己的声明里（实测），但这不是结构上的保证。
// 出现同一声明两处遮罩时，正确处置是**把键细化**（例如带上出现序号），
// 不是给台账加一条了事。
@Suite("新 target 的 .mask 点位台账")
struct MaskSiteRegistryGuard {

    /// 已登记的遮罩点位 → 署名理由。
    ///
    /// ⚠️ **新增一处 `.mask` 必须同轮登记**，且登记时要回答一个问题：
    /// **遮罩基色的 α 是不是 1？谁在守着它？** 答不上来就别用遮罩——
    /// `MaskReveal.swift` 的文件头写着替代路线（`clipShape`，纯几何、不涉及 alpha）。
    nonisolated static let registeredSites: [String: String] = [
        "Sources/CoreDesignEffects/AnimatedMeshGradient.swift#body":
            """
            `.tint` 档：`Rectangle().fill(.tint)` + 一张 alpha 网格遮罩。
            基色走 `Color.maskOpaque`；量程由 `tintAlphaMaskSpansItsDeclaredRange` 钉住。
            ⚠️ 遮罩是**必要**的——这里要的是空间上变化的 alpha 场，裁剪替代不了。
            """,
        "Sources/CoreDesignEffects/ProcessingSweep.swift#glowRing":
            """
            边框辉光：`.strokeBorder(.tint)` + 角向 alpha 渐变遮罩。
            色标走 `ProcessingSweep.ringMaskStops`（基色 `Color.maskOpaque`）；
            峰值由 `maskStopsAreFullyOpaqueAtTheirPeak` 钉住。同样是"变化的 alpha 场"。
            """,
        "Sources/CoreDesignEffects/ProcessingSweep.swift#lightBand":
            """
            表面光带：`Rectangle().fill(.tint)` + 线性 alpha 渐变遮罩。
            色标走 `ProcessingSweep.bandMaskStops`，判据同上。
            """,
        "Sources/CoreDesignEffects/Shine.swift#body":
            """
            `.shine(trigger:)`：`.mask(content)` —— 遮罩内容是**被修饰的视图本身**，
            用的正是它自己的 alpha（把高光裁到内容形状内）。
            ⚠️ 本条与 #276 那一族**不同源**：它没有"遮罩基色"这个自由度，
            也就没有"基色选错了"这种失效形态。已知限度（内容被实例化两次）
            逐字记在 `Shine.swift` 的类型文档里。
            """,
    ]

    nonisolated struct Site: Hashable, Sendable {
        let key: String
        let line: Int
    }

    /// 扫一段源码，返回其中全部 `.mask(...)` / `.mask { … }` 调用点。
    static func scan(source: String, fileName: String) -> [Site] {
        let tree = SwiftParser.Parser.parse(source: source)
        if tree.hasError {
            Issue.record("解析出错：\(fileName) —— swift-syntax major 可能与工具链不配套")
        }
        let converter = SourceLocationConverter(fileName: fileName, tree: tree)
        let collector = MaskCallCollector(fileName: fileName, converter: converter)
        collector.walk(tree)
        return collector.sites
    }

    static func scan(root: URL) throws -> [Site] {
        var out: [Site] = []
        for url in GuardScanRoots.swiftFiles(in: root) {
            out += Self.scan(
                source: try String(contentsOf: url, encoding: .utf8),
                fileName: GuardScanRoots.relativePath(url)
            )
        }
        return out
    }

    @Test("新 target 的每一处 .mask 都已登记，且台账里没有已消失的点位")
    func maskSitesMatchTheRegistry() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.newTargetRoots))

        var found: [Site] = []
        var scannedFiles = 0
        for root in GuardScanRoots.newTargetRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count
            found += try Self.scan(root: root.url)
        }
        #expect(scannedFiles > 0, "新 target 一个源文件都没扫到 —— 「零违规」不可信")
        // ⚠️ 非退化前置：今天树上确有遮罩点位。一个都扫不到时下面两条差集**双双为空**
        // ⇒ 全绿，而那恰好是"探测器坏了"的形态。
        #expect(!found.isEmpty, """
        新 target 里一处 `.mask` 都没扫到 —— 台账里却登记着 \(Self.registeredSites.count) 条。
        这更可能是探测器坏了，而不是遮罩全被删光了。
        """)

        let foundKeys = Set(found.map(\.key))
        let registeredKeys = Set(Self.registeredSites.keys)

        let unregistered = found.filter { !registeredKeys.contains($0.key) }
        #expect(unregistered.isEmpty, """
        新 target 里出现了**未登记**的 `.mask` 点位：
        \(unregistered.map { "\($0.key)（第 \($0.line) 行）" }.sorted().joined(separator: "\n"))

        `.mask` 吃的是 **alpha 通道** ⇒ 遮罩基色但凡不是满不透明，被遮的内容就整体变淡，
        而且**不会报错**（Issue #276：四处遮罩用 `Color.primary`，实测 α = 0.8471，
        整体暗 15%，全套位图判据一条都没抓到）。
        处置二选一：
        · 基色走 `Color.maskOpaque`（契约 α = 1），并**为这一处补一条性质判据**
          （量程 / 峰值 / 端点无关性，看它是哪一类），然后登记到
          `MaskSiteRegistryGuard.registeredSites`；
        · 或者干脆不用遮罩 —— 纯几何的揭示走 `clipShape`（`MaskReveal.swift` 文件头
          有完整论证，`BeforeAfterRevealClip` 是现成先例），裁剪不涉及 alpha。
        """)

        let vanished = registeredKeys.subtracting(foundKeys)
        #expect(vanished.isEmpty, """
        台账里登记着树上**已经不存在**的 `.mask` 点位：
        \(vanished.sorted().joined(separator: "\n"))
        —— 台账过时会让"未登记"那一半在错的基线上比对。删掉它们，或核对键有没有漂
        （键 = 相对路径 + `#` + 最近的具名声明；改函数名会让键跟着变）。
        """)
    }

    @Test("探测器真的会开火：合成输入逐形态变红自证")
    func detectorFiresOnSyntheticSource() {
        let cases: [(name: String, source: String, expected: String)] = [
            ("尾随闭包 `.mask { … }`", """
            import SwiftUI
            struct A: View {
                var body: some View { Color.clear.mask { Color.black } }
            }
            """, "Synthetic.swift#body"),
            ("带标签实参 `.mask(alignment:) { … }`", """
            import SwiftUI
            struct B: View {
                func layer() -> some View { Color.clear.mask(alignment: .leading) { Color.black } }
            }
            """, "Synthetic.swift#layer"),
            ("实参形态 `.mask(content)`", """
            import SwiftUI
            struct C: View {
                var overlayed: some View { Color.clear.mask(self.content) }
            }
            """, "Synthetic.swift#overlayed"),
        ]
        for (name, source, expected) in cases {
            let sites = Self.scan(source: source, fileName: "Synthetic.swift")
            #expect(sites.count == 1, "\(name)：扫到 \(sites.count) 处，期望 1 处 —— 探测器漏了这一形态")
            #expect(sites.first?.key == expected, """
            \(name)：键是 \(sites.first?.key ?? "nil")，期望 \(expected)
            —— 键的形态漂了，台账会对不上。
            """)
        }
    }

    /// ⚠️ 反向自证：不是所有 `.mask` 名字都算。**属性访问不是调用**，
    /// 且别的类型上的 `mask(...)`（`CGImage.masking` 之类另有其名）不在本守卫题内。
    @Test("不误报：`.mask` 作为属性访问不算点位")
    func propertyAccessIsNotACallSite() {
        let source = """
        import SwiftUI
        struct D {
            let mask: Int = 0
            var copy: Int { self.mask }
        }
        """
        let sites = Self.scan(source: source, fileName: "Synthetic.swift")
        #expect(sites.isEmpty, "把属性访问 `self.mask` 当成了遮罩点位：\(sites.map(\.key))")
    }
}

// MARK: - 探测器

private nonisolated final class MaskCallCollector: SyntaxVisitor {

    let fileName: String
    let converter: SourceLocationConverter
    var sites: [MaskSiteRegistryGuard.Site] = []

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
              member.declName.baseName.text == "mask" else {
            return .visitChildren
        }
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        self.sites.append(
            MaskSiteRegistryGuard.Site(
                key: "\(self.fileName)#\(Self.enclosingName(of: Syntax(node)))",
                line: line
            )
        )
        return .visitChildren
    }

    /// 最近的**具名**声明：函数 / 计算属性 / 类型。闭包与嵌套表达式一路往上穿。
    /// 找不到（顶层表达式）⇒ `<top-level>`。
    private static func enclosingName(of node: Syntax) -> String {
        var current: Syntax? = node.parent
        while let here = current {
            if let function = here.as(FunctionDeclSyntax.self) {
                return function.name.text
            }
            if let binding = here.as(PatternBindingSyntax.self),
               let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
                return identifier.identifier.text
            }
            if let structure = here.as(StructDeclSyntax.self) {
                return structure.name.text
            }
            if let extended = here.as(ExtensionDeclSyntax.self) {
                return extended.extendedType.trimmedDescription
            }
            current = here.parent
        }
        return "<top-level>"
    }
}
