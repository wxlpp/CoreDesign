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
// ⚠️ **顺带把射程的另一半也写成实测**（#276 终审 F5 的 M8）：`registeredSites` 的
// value（署名理由）是**自由文本，没有任何机器兜底**——把一处新点位登记成
// `"seam probe"`、基色写 `Color.primary.opacity(0.5)` ⇒ 本守卫**全绿**。
// 本守卫认的只有**键**，理由那一栏它一个字都不读。⇒ 那一栏的价值只在"新增点位的人
// 必须停下来把 α 这件事写清楚、并被评审读到"，α 本身仍由上表四条性质判据钉。
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
// ⚠️ **键碰撞：上一版只把它记成「已知脆弱面」，现在由一条判据钉住**（#276 终审 F4）。
// 形态：同一个声明里有**两处** `.mask` 时两者的键相同 ⇒ 台账只需一条就都放行。
// ⚠️⚠️ 上一版写「正确处置是把键细化」，但**守卫自己检测不到这个情形**，那条指令
// 因此永远不会被触发——而它恰好就是 `#276` 本身的失效形态（一处 α < 1 的遮罩静默
// 进树）。实测（终审 M10）：在已登记的 `ProcessingSweep.swift#glowRing` 里再插一处
// `.mask { Color.primary.opacity(0.5) }` ⇒ 全绿、台账零改动。
// ⇒ 现在 `maskSitesMatchTheRegistry` 里多一条 `dupes` 断言：同键多处当场判红。
// 今天四个点位各在自己的键上（该断言即为实证）。
//
// ⚠️ **键碰撞有两种成因，处置不同**（#276 终审 I2 更正——上一版这里与 `dupes` 的失败
// 文案都只写了第一种，并把第二种也指向"加出现序号"，那个处置对第二种是假的）：
// · **同一声明内的第二处 `.mask`** ⇒ 细化键（带上同一声明内的出现序号）；
// · **同文件里两个不同声明重名** ⇒ `enclosingName` 只取最内层具名声明、**不带类型
//   路径** ⇒ 一个文件里多个类型各有 `var body` 就会撞键。实证（终审 I2）：
//   `AnimatedMeshGradient.swift` 今天就有 3 个 `var body`（分属三个类型），
//   只要在其中一个里加一处 `.mask` 就与另一个已登记的 `#body` 撞键，`dupes`
//   报「共 2 处」。判红是对的，但**出现序号修不好它**，正确处置是给键加类型限定。
//
// ## 已知射程缺口（登记，不装作没有）
//
// · **探测器认"任何名为 `mask` 的成员调用"**，不区分它是不是 SwiftUI 的遮罩
//   （#276 终审 S1 实测：在 `glowRing` 里放一个与遮罩无关的 `CGFloat.mask(_:)` 调用
//   ⇒ `dupes` 当场判红）。上一版这枚过匹配只是"多登记一条"的无害噪声，`dupes` 把它
//   升成硬红。今天树上概率为 0（无此 API 在用），故只登记、不加白名单——加白名单要
//   么按名字放行（等于开洞）、要么做类型推断（本守卫明说自己是形状级闸）。
// · **反引号转义的标识符**（`` value.`mask` { … } ``）未验证是否被扫到（未构造变异，
//   仅代码推断；#276 终审 S4）。真出现时最坏形态是漏扫一处点位。
// · **`registeredSites` 是字典字面量 ⇒ 台账里写重键不是本守卫诊断的**（#276 终审 S2）：
//   编译期只有一条 warning，而 `ci.yml` 只给 `downstream-probe` 那条腿加了
//   `-Xswiftc -warnings-as-errors`，`swift test` 那条腿没有 ⇒ CI 上的表现是**运行期**
//   `Fatal error: Dictionary literal contains duplicate keys` / `signal code 5`，
//   整个 macOS test bundle 一起没。fail-closed、不是假绿，但形态很凶。
//   ⚠️ 想改成 `[(String, String)]` + 显式唯一性断言的话，注意本类型今天被
//   `registeredSites.keys` / `registeredSites[key]` 两处按字典用，改法不是一行。
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

        // ⚠️ **键碰撞要判红，不能只写在文档里**（#276 终审 F4，实测 M10）：同一声明里
        // 出现第二处 `.mask` 时两者的键相同 ⇒ 下面两条差集**双双满足**（`unregistered`
        // 空、`vanished` 空）⇒ 全绿、台账零改动，而那正是 `#276` 的失效形态。
        let dupes = Dictionary(grouping: found, by: \.key).filter { $0.value.count > 1 }
        #expect(dupes.isEmpty, """
        同一个**键**上出现了多处 `.mask` ⇒ 台账只要有一条就把它们全放行：
        \(dupes
            .map { "\($0.key)：第 \($0.value.map(\.line).sorted().map(String.init).joined(separator: " / ")) 行，共 \($0.value.count) 处" }
            .sorted().joined(separator: "\n"))
        ⚠️ 键 = 相对路径 + `#` + **最近的具名声明**（只取最内层名字、**不带类型路径**）
        ⇒ 碰撞有两种成因，处置不同，先看上面的行号分清是哪一种：
        · **同一个声明里出现了第二处 `.mask`**（两个行号落在同一个 `func` / `var` 体内）
          ⇒ 处置是**把键细化**，例如带上同一声明内的出现序号；
        · **同文件里两个不同声明重名**（两个行号分属不同声明；典型是一个文件里多个类型
          各有 `var body`）⇒ 出现序号**修不好**它，处置是**给键加类型限定**
          （把外层类型名拼进键里）。
        两种都**不是**"给台账加一条了事" —— 加一条只会让第二处遮罩连"被人读到"这一步
        都省掉，而"被人读到"是本守卫唯一在做的事（它不查 alpha，见文件头）。
        """)

        let foundKeys = Set(found.map(\.key))
        let registeredKeys = Set(Self.registeredSites.keys)

        let unregistered = found.filter { !registeredKeys.contains($0.key) }
        #expect(unregistered.isEmpty, """
        新 target 里出现了**未登记**的 `.mask` 点位：
        \(unregistered.map { "\($0.key)（第 \($0.line) 行）" }.sorted().joined(separator: "\n"))

        `.mask` 吃的是 **alpha 通道** ⇒ 遮罩基色但凡不是满不透明，被遮的内容就整体变淡，
        而且**不会报错**（Issue #276：四处遮罩用 `Color.primary`，**macOS 26** 上实测
        α = 0.8471 ⇒ 整体暗 15%，全套位图判据一条都没抓到）。
        ⚠️ 这个 α 是**平台相关**的，本守卫两条腿都跑，别把上面那个数当成你这条腿上的值：
        **iOS 26** 上 `label` 实测 α = 1.0 ⇒ iOS 腿上看不出问题
        （`MaskOpaqueTokenTests.primaryAlphaIsPlatformDependent` 在两端各解析一次）。
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
        // ⚠️ 取 **`mask` 这个成员名 token** 的位置，不是整条调用链的起点（#276 终审 F4
        // 收尾时实测）：`node.positionAfterSkippingLeadingTrivia` 落在链**最前面**那个
        // 表达式上 ⇒ 同一条链里的两处 `.mask` 会报出**同一个行号**，键碰撞那条断言的
        // 提示就退化成"第 172 / 172 行"，指不出第二处在哪。行号只进失败文案、不进键
        //（键刻意不含行号，见文件头）。
        let line = self.converter.location(
            for: member.declName.baseName.positionAfterSkippingLeadingTrivia
        ).line
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
