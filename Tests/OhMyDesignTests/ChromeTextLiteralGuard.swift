import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 禁 chrome 文案裸字面量 / No bare chrome text literals（Issue #246）

@Suite("新 target 禁 chrome 文案裸字面量")
struct ChromeTextLiteralGuard {
    nonisolated static let textConstructors: Set<String> = [
        "Text", "Label", "Button", "Toggle", "Section",
        "TextField", "SecureField", "Stepper", "Picker",
        "Menu", "Link", "NavigationLink", "GroupBox", "ContentUnavailableView", "DatePicker",
    ]

    nonisolated static let textModifiers: Set<String> = [
        "navigationTitle", "navigationSubtitle", "navigationBarTitle",
        "alert", "confirmationDialog", "help", "searchable",
    ]

    nonisolated static let labeledProseArguments: [String: Set<String>] = [
        "searchable": ["prompt"],
    ]

    nonisolated struct Violation: Hashable, Sendable {
        let file: String
        let line: Int
        let literal: String
        let snippet: String
        var description: String { "\(self.file):\(self.line) → 「\(self.literal)」| \(self.snippet)" }
    }

    nonisolated struct ScanResult: Sendable {
        var violations: [Violation] = []
        var verbatimSites: [String] = []
    }

    nonisolated static func isProse(_ literal: String) -> Bool {
        literal.contains(where: { $0.isLetter })
    }

    static func scan(source: String, fileName: String = "Synthetic.swift") -> ScanResult {
        let tree = SwiftParser.Parser.parse(source: source)
        if tree.hasError {
            Issue.record("解析出错：\(fileName) —— swift-syntax major 可能与工具链不配套")
        }
        let converter = SourceLocationConverter(fileName: fileName, tree: tree)
        let collector = ChromeTextCollector(fileName: fileName, converter: converter)
        collector.walk(tree)
        return ScanResult(violations: collector.violations, verbatimSites: collector.verbatimSites)
    }

    static func scan(root: URL) throws -> ScanResult {
        var out = ScanResult()
        for url in GuardScanRoots.swiftFiles(in: root) {
            let partial = Self.scan(
                source: try String(contentsOf: url, encoding: .utf8),
                fileName: GuardScanRoots.relativePath(url)
            )
            out.violations += partial.violations
            out.verbatimSites += partial.verbatimSites
        }
        return out
    }

    @Test("新 target 里零 chrome 文案裸字面量（公约 A 类）")
    func noBareChromeTextInNewTargets() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.newTargetRoots))

        var result = ScanResult()
        var scannedFiles = 0
        for root in GuardScanRoots.newTargetRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count
            let partial = try Self.scan(root: root.url)
            result.violations += partial.violations
            result.verbatimSites += partial.verbatimSites
        }
        #expect(scannedFiles > 0, "新 target 一个源文件都没扫到 —— 「零违规」不可信")

        print("【chrome 文案】新 target 的 `Text(verbatim:)` 共 \(result.verbatimSites.count) 处：\(result.verbatimSites)")

        #expect(result.violations.isEmpty, """
        新 target 里出现了写死的 chrome 文案（公约 A 类）：
        \(result.violations.map(\.description).joined(separator: "\n"))
        —— 下游 App 换语言时这些字会突然说英文，而组件自己不带 String Catalog。
        处置（按优先级）：
        1. 把文案**交给调用方**（做成 init 参数，那样它落 B 类、由登记表的 textParams 管）；
        2. 确实该由库提供时，走 `String(localized:bundle:)` 指向**该 target 自己的**
           String Catalog——`Package.swift` 的 `resources:` **与**
           `Sources/<target>/Resources/` 目录**必须同轮一起加**
           （`GuardScanRootsGuard.moduleBundleOwnership` 钉住这条一致性；
           ⚠️ 括注更新（#253 PR #273 终审 S-3）：`OhMyDesignCharts` 与 `OhMyDesignEffects`
           **今天都已经有资源包了** —— 上一版这里写「新 target 今天**没有**资源包，
           写 `bundle: .module` 编译不过」，处方本身没错，括注已失真）；
        3. 那串东西根本不是自然语言（数字 / 符号 / 用户数据）时用 `Text(verbatim:)`，
           它会被清点并打印出来。
        """)
    }

    @Test("探测器真的会开火：合成输入逐形态变红自证")
    func detectorFiresOnSyntheticSource() {
        let cases: [(name: String, source: String, literal: String)] = [
            ("`Text(\"…\")`", """
            import SwiftUI
            public struct A: View {
                public var body: some View { Text("Loading") }
            }
            """, "Loading"),
            ("`Label(\"…\", systemImage:)`", """
            import SwiftUI
            public struct B: View {
                public var body: some View { Label("Retry", systemImage: "arrow.clockwise") }
            }
            """, "Retry"),
            ("折行写法", """
            import SwiftUI
            let t = Text(
                "Something went wrong"
            )
            """, "Something went wrong"),
            ("限定形态 `SwiftUI.Label(\"…\", systemImage:)`（仓内 `Tag.swift:219` 在用）", """
            import SwiftUI
            let l = SwiftUI.Label("verified", systemImage: "checkmark.seal.fill")
            """, "verified"),
            ("initializer 形态 `Text.init(\"…\")`", """
            import SwiftUI
            let t = Text.init("Loading")
            """, "Loading"),
            ("`Button(\"…\") { }`", """
            import SwiftUI
            let b = Button("Retry") { }
            """, "Retry"),
            ("`Toggle(\"…\", isOn:)`", """
            import SwiftUI
            let t = Toggle("Reduce Motion", isOn: $flag)
            """, "Reduce Motion"),
            ("`Section(\"…\")`", """
            import SwiftUI
            let s = Section("Legend") { EmptyView() }
            """, "Legend"),
            ("`TextField(\"…\", text:)`", """
            import SwiftUI
            let f = TextField("Search", text: $q)
            """, "Search"),
            ("`Stepper(\"…\", value:)`", """
            import SwiftUI
            let s = Stepper("Speed", value: $v)
            """, "Speed"),
            ("`.navigationTitle(\"…\")`（modifier 形态）", """
            import SwiftUI
            let v = EmptyView().navigationTitle("Settings")
            """, "Settings"),
            ("`.alert(\"…\", isPresented:)`", """
            import SwiftUI
            let v = EmptyView().alert("Something failed", isPresented: $shown) { }
            """, "Something failed"),
            ("`Menu(\"…\") { }`（图例现实用法）", """
            import SwiftUI
            let m = Menu("Options") { EmptyView() }
            """, "Options"),
            ("`Link(\"…\", destination:)`", """
            import SwiftUI
            let l = Link("Open docs", destination: url)
            """, "Open docs"),
            ("`NavigationLink(\"…\") { }`", """
            import SwiftUI
            let n = NavigationLink("Next") { EmptyView() }
            """, "Next"),
            ("`GroupBox(\"…\") { }`（图例现实用法）", """
            import SwiftUI
            let g = GroupBox("Legend") { EmptyView() }
            """, "Legend"),
            ("`ContentUnavailableView(\"…\", systemImage:)`（空状态现实用法）", """
            import SwiftUI
            let e = ContentUnavailableView("Nothing here", systemImage: "x")
            """, "Nothing here"),
            ("`DatePicker(\"…\", selection:)`", """
            import SwiftUI
            let d = DatePicker("When", selection: $date)
            """, "When"),
            ("`.navigationBarTitle(\"…\")`（modifier 形态）", """
            import SwiftUI
            let v = EmptyView().navigationBarTitle("Settings")
            """, "Settings"),
            ("`.searchable(text:prompt:)`——文案在**带标签**实参上（`labeledProseArguments`）", """
            import SwiftUI
            let v = EmptyView().searchable(text: $q, prompt: "Search charts")
            """, "Search charts"),
            ("隐式 `.init` 形态 `let t: Text = .init(\"…\")`（S-b，与色相守卫对齐）", """
            import SwiftUI
            let t: Text = .init("Loading")
            """, "Loading"),
            ("已知误报面：非 SwiftUI 接收者的 `.help(…)`（口子 6）", """
            let x = logger.help("this is documentation")
            """, "this is documentation"),
            ("已知误报面：非 SwiftUI 接收者的 `.alert(…)`（口子 6）", """
            let x = validator.alert("some message", isPresented: $b)
            """, "some message"),
            ("已知误报面：模块限定的同名类型 `MyNS.Section(…)`（口子 6）", """
            let s = MyNS.Section("Legend")
            """, "Legend"),
            ("已知误报面：裸同名类型 `Link(…)`（图论 edge 的惯用名，口子 6）", """
            struct Link { init(_ id: String) {} }
            let e = Link("node-a to node-b")
            """, "node-a to node-b"),
            ("已知误报面：裸同名类型 `Section(…)`（口子 6）", """
            struct Section { init(_ id: String) {} }
            let s = Section("legend area")
            """, "legend area"),
            ("已知误报面：标识符形态被 `isProse` 判成文案（口子 9）", """
            import SwiftUI
            let e = ContentUnavailableView("no-results-id", systemImage: "x")
            """, "no-results-id"),
        ]
        for c in cases {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.contains(where: { $0.literal == c.literal }),
                    "\(c.name)：探测器漏报（期望「\(c.literal)」，实得 \(hits.map(\.literal))）—— 上面那条「零违规」毫无意义")
        }

        let clean: [(name: String, source: String)] = [
            ("文案来自参数", """
            import SwiftUI
            public struct C: View {
                let title: String
                public var body: some View { Text(self.title) }
            }
            """),
            ("走 String Catalog", #"let t = Text(String(localized: "Loading", bundle: .module))"#),
            ("`Text(verbatim:)`（口子 1，只清点）", #"let t = Text(verbatim: "42")"#),
            ("`Label` 的 systemImage 不是文案", """
            import SwiftUI
            let l = Label(self.title, systemImage: "star")
            """),
            ("非文案字面量（无字母）", #"let t = Text("•")"#),
            ("`#Preview` 里的写死文案（有意跳过：预览不进产物，不需要本地化）", """
            import SwiftUI
            #Preview { Text("Preview only") }
            """),
            ("同名但不是 SwiftUI 构造（注释与字符串）", """
            // Text("in a comment")
            let s = "Label(\\"in a string\\")"
            """),
            ("非文案 modifier 的字面量实参（不在 `textModifiers` 里）", """
            import SwiftUI
            let v = EmptyView().accessibilityIdentifier("legend-row")
            """),
            ("`Picker` 的标签式写法（首个实参有标签）", """
            import SwiftUI
            let p = Picker(selection: $mode, label: label) { EmptyView() }
            """),
            ("口子 7：`typealias` 改名后按文本判构造器名看不见 ⇒ 放行", """
            import SwiftUI
            typealias T = Text
            let t = T("Loading")
            """),
            ("口子 8：隐式 `.init` 的上下文类型只存在于推断里（数组元素位置）⇒ 放行", """
            import SwiftUI
            let rows: [Text] = [.init("Loading")]
            """),
            ("隐式 `.init` 但上下文类型不是文案构造器 ⇒ 放行", """
            struct Tooltip { init(_ body: String) {} }
            let t: Tooltip = .init("Loading")
            """),
        ]
        for c in clean {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.isEmpty, "\(c.name)：误报 \(hits.map(\.description))")
        }

        #expect(Self.scan(source: #"let t = Text(verbatim: "42")"#).verbatimSites.count == 1,
                "`Text(verbatim:)` 没有被清点 —— 那个口子就真成了盲区")
        #expect(Self.scan(source: #"let t = Text.init(verbatim: "42")"#).verbatimSites.count == 1,
                "`Text.init(verbatim:)` 没有被清点 —— 记账通道被 initializer 形态绕过")
        #expect(Self.scan(source: #"let t: Text = .init(verbatim: "42")"#).verbatimSites.count == 1,
                "隐式 `.init(verbatim:)` 没有被清点 —— 记账通道被隐式成员形态绕过")

        #expect(Self.scan(source: #"let v = EmptyView().accessibilityHint("Opens settings")"#)
                .violations.isEmpty,
                "a11y modifier 被本守卫重复报了一遍 —— 同一处违规会被两条守卫各报一次")
    }

    @Test("上下文类型：实参位置不继承外层返回类型；三元 / `??` 不截断（第 4 轮终审 I-1 / I-2）")
    func contextualTypeDoesNotLeakAcrossArgumentPositions() {
        let falsePositives: [(name: String, source: String)] = [
            ("函数返回类型被错安到实参", """
            import SwiftUI
            func title() -> Text { render(.init("Loading")) }
            """),
            ("计算属性返回类型被错安到实参", """
            import SwiftUI
            var title: Text { render(.init("Loading")) }
            """),
        ]
        for c in falsePositives {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.isEmpty, """
            \(c.name)：误报 \(hits.map(\.description))
            —— `.init("…")` 落在实参位置时类型来自形参，与外层 `-> Text` 无关。
            """)
        }

        let falseNegatives: [(name: String, source: String, literal: String)] = [
            ("三元的分支（有类型标注）", """
            import SwiftUI
            let t: Text = flag ? .init("Loading") : other
            """, "Loading"),
            ("`??` 的右侧（有类型标注）", """
            import SwiftUI
            let t: Text = maybe ?? .init("Loading")
            """, "Loading"),
        ]
        for c in falseNegatives {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.contains(where: { $0.literal == c.literal }),
                    "\(c.name)：漏报（期望「\(c.literal)」，实得 \(hits.map(\.literal))）")
        }

        #expect(Self.scan(source: """
        import SwiftUI
        let t: Text = .init("Loading")
        """).violations.contains(where: { $0.literal == "Loading" }),
                "类型标注形态被收紧判据误伤 —— 这不是 I-1 / I-2 要的结果")
        #expect(Self.scan(source: """
        import SwiftUI
        func title() -> Text { .init("Loading") }
        """).violations.contains(where: { $0.literal == "Loading" }),
                "单表达式返回位置被收紧判据误伤 —— 这不是 I-1 / I-2 要的结果")
    }

    @Test("上下文类型：赋值右侧 / 默认参数值 / 条件绑定各按自己的类型判（第 5 轮终审 I-a / I-b）")
    func contextualTypeRespectsAssignmentsDefaultsAndBindings() {
        let falsePositives: [(name: String, source: String)] = [
            ("计算属性 `set` 里的赋值右侧（I-a）", """
            import SwiftUI
            struct S {
                var store = Identifier("")
                var title: Text { get { other } set { self.store = .init("Loading") } }
            }
            """),
            ("`didSet` 里的赋值右侧（I-a）", """
            import SwiftUI
            struct S {
                var store = Identifier("")
                var title: Text = other { didSet { self.store = .init("Loading") } }
            }
            """),
            ("计算属性 `set` 里的**复合**赋值右侧（`+=`，第 5 轮终审 I-1）", """
            import SwiftUI
            struct S {
                var log = ""
                var title: Text { get { other } set { self.log += .init("Loading") } }
            }
            """),
            ("`didSet` 里的复合赋值右侧（`+=`）", """
            import SwiftUI
            struct S {
                var log = ""
                var title: Text = other { didSet { self.log += .init("Loading") } }
            }
            """),
            ("默认参数值继承了外层返回类型（I-b①）", """
            import SwiftUI
            struct Identifier { init(_ raw: String) {} }
            func title(id: Identifier = .init("Loading")) -> Text { other }
            """),
            ("条件绑定自带的类型标注被换成外层标注（I-b②）", """
            import SwiftUI
            struct Identifier { init(_ raw: String) {} }
            var title: Text { if let id: Identifier = .init("Loading") { other } else { other } }
            """),
        ]
        for c in falsePositives {
            let hits = Self.scan(source: c.source).violations
            #expect(!hits.contains(where: { $0.literal == "Loading" }), """
            \(c.name)：误报 \(hits.map(\.description))
            —— 共用的 `ImplicitMemberContext` 把外层标注 / 返回类型错安到了这里。
            """)
        }

        let falseNegatives: [(name: String, source: String)] = [
            ("默认参数值写了 `Text`（I-b① 的镜像）", """
            import SwiftUI
            struct S { func f(t: Text = .init("Loading")) {} }
            """),
            ("`guard let t: Text = .init(…)`（I-b② 的镜像）", """
            import SwiftUI
            func title() -> Text {
                guard let t: Text = .init("Loading") else { return other }
                return t
            }
            """),
        ]
        for c in falseNegatives {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.contains(where: { $0.literal == "Loading" }),
                    "\(c.name)：漏报（期望「Loading」，实得 \(hits.map(\.literal))）")
        }

        #expect(!Self.scan(source: """
        import SwiftUI
        func title() -> Text { render(.init("Loading")) }
        """).violations.contains(where: { $0.literal == "Loading" }),
                "实参位置的旧修法回退了（第 4 轮 I-1）")
        #expect(Self.scan(source: """
        import SwiftUI
        let t: Text = .init("Loading")
        """).violations.contains(where: { $0.literal == "Loading" }),
                "类型标注这条基本形态被本轮修法误伤")
    }

    @Test("探测器在真实源码上非真空：拿主 target 当靶场必须打出命中")
    func detectorFiresOnRealSource() throws {
        let hits = try Self.scan(root: GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)).violations
        #expect(hits.count > 10, """
        在 Sources/OhMyDesign 上只打出 \(hits.count) 处裸 chrome 文案 —— 探测器疑似失效。
        本条**不是**要求主 target 保持违规，而是「新 target 的零命中来自干净、不是来自
        坏掉的探测器」这句话的活证据。主 target 真被治理干净时，请改成扫常驻 fixture，
        不要直接删掉它。
        """)
    }
}

// MARK: - 采集器 / Collector

private nonisolated final class ChromeTextCollector: SyntaxVisitor {
    var violations: [ChromeTextLiteralGuard.Violation] = []
    var verbatimSites: [String] = []

    private let fileName: String
    private let converter: SourceLocationConverter

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private static func proseText(of literal: StringLiteralExprSyntax) -> String {
        literal.segments.compactMap { segment -> String? in
            segment.as(StringSegmentSyntax.self)?.content.text
        }.joined()
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }

    private static func chromeCallName(of callee: ExprSyntax) -> String? {
        if let ref = callee.as(DeclReferenceExprSyntax.self) {
            return ChromeTextLiteralGuard.textConstructors.contains(ref.baseName.text)
                ? ref.baseName.text : nil
        }
        guard let member = callee.as(MemberAccessExprSyntax.self) else { return nil }
        let memberName = member.declName.baseName.text
        if ChromeTextLiteralGuard.textModifiers.contains(memberName) { return memberName }
        var segments = callee.trimmedDescription
            .split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let isInitForm = segments.last == "init"
        if isInitForm { segments.removeLast() }
        if isInitForm, segments.last == "" || segments.isEmpty {
            guard let annotated = ImplicitMemberContext.contextualTypeName(of: callee),
                  ChromeTextLiteralGuard.textConstructors.contains(annotated) else { return nil }
            return annotated
        }
        guard let last = segments.last,
              ChromeTextLiteralGuard.textConstructors.contains(last) else { return nil }
        return last
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let callName = Self.chromeCallName(of: node.calledExpression)
        else { return .visitChildren }

        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let snippet = node.trimmedDescription
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")

        if let labels = ChromeTextLiteralGuard.labeledProseArguments[callName] {
            for argument in node.arguments {
                guard let label = argument.label?.text, labels.contains(label),
                      let literal = argument.expression.as(StringLiteralExprSyntax.self)
                else { continue }
                let text = Self.proseText(of: literal)
                guard ChromeTextLiteralGuard.isProse(text) else { continue }
                self.violations.append(
                    .init(file: self.fileName, line: line, literal: text, snippet: String(snippet.prefix(120)))
                )
            }
        }

        guard let first = node.arguments.first else { return .visitChildren }

        if first.label?.text == "verbatim" {
            self.verbatimSites.append("\(self.fileName):\(line)")
            return .visitChildren
        }
        guard first.label == nil,
              let literal = first.expression.as(StringLiteralExprSyntax.self)
        else { return .visitChildren }

        let text = Self.proseText(of: literal)
        guard ChromeTextLiteralGuard.isProse(text) else { return .visitChildren }

        self.violations.append(
            .init(file: self.fileName, line: line, literal: text, snippet: String(snippet.prefix(120)))
        )
        return .visitChildren
    }
}
