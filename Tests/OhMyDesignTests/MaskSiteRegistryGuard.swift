import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 的 `.mask` 点位台账（Issue #276）

@Suite("新 target 的 .mask 点位台账")
struct MaskSiteRegistryGuard {
    nonisolated static let registeredSites: [String: String] = [
        "Sources/OhMyDesignEffects/AnimatedMeshGradient.swift#body":
            """
            `.tint` 档：`Rectangle().fill(.tint)` + 一张 alpha 网格遮罩。
            基色走 `Color.maskOpaque`；量程由 `tintAlphaMaskSpansItsDeclaredRange` 钉住。
            ⚠️ 遮罩是**必要**的——这里要的是空间上变化的 alpha 场，裁剪替代不了。
            """,
        "Sources/OhMyDesignEffects/ProcessingSweep.swift#outline":
            """
            边框辉光：默认 tint 或宿主 ShapeStyle 描边 + 角向 alpha 渐变遮罩。outline 同时用于清晰描边和柔和光晕。
            色标走 `ProcessingSweep.ringMaskStops`（基色 `Color.maskOpaque`）；
            峰值由 `maskStopsAreFullyOpaqueAtTheirPeak` 钉住。同样是"变化的 alpha 场"。
            """,
        "Sources/OhMyDesignEffects/ProcessingSweep.swift#lightBand":
            """
            表面光带：`Rectangle().fill(.tint)` + 线性 alpha 渐变遮罩。
            色标走 `ProcessingSweep.bandMaskStops`，判据同上。
            """,
        "Sources/OhMyDesignEffects/Shine.swift#body":
            """
            `.shine(trigger:)`：`.mask(content)` —— 遮罩内容是**被修饰的视图本身**，
            用的正是它自己的 alpha（把高光裁到内容形状内）。
            ⚠️ 本条与 #276 那一族**不同源**：它没有"遮罩基色"这个自由度，
            也就没有"基色选错了"这种失效形态。已知限度：内容被实例化两次。
            """,
    ]

    nonisolated struct Site: Hashable, Sendable {
        let key: String
        let line: Int
    }

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
        #expect(!found.isEmpty, """
        新 target 里一处 `.mask` 都没扫到 —— 台账里却登记着 \(Self.registeredSites.count) 条。
        这更可能是探测器坏了，而不是遮罩全被删光了。
        """)

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
        都省掉，而"被人读到"是本守卫唯一在做的事（它只查登记，不查 alpha）。
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
        · 或者干脆不用遮罩 —— 纯几何的揭示走 `clipShape`（裁剪不涉及 alpha，
          `BeforeAfterRevealClip` 是现成先例）。
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
