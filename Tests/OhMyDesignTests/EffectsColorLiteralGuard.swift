import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 禁色相字面量 / No hue literals in the new targets（Issue #246）

@Suite("新 target 禁色相字面量")
struct EffectsColorLiteralGuard {
    nonisolated static let hueNames: Set<String> = [
        "black", "blue", "brown", "cyan", "darkGray", "gray", "green", "indigo",
        "lightGray", "magenta", "mint", "orange", "pink", "purple", "red", "teal",
        "white", "yellow",
    ]

    nonisolated static let colorTypeNames: Set<String> = ["Color", "UIColor", "NSColor", "CGColor", "SwiftUI"]

    nonisolated static let colorAnnotationNames: Set<String> = ["Color", "UIColor", "NSColor", "CGColor"]

    nonisolated static let numericColorLabels: Set<String> = ["red", "white", "hue"]

    nonisolated struct Violation: Hashable, Sendable {
        let file: String
        let line: Int
        let snippet: String
        var description: String { "\(self.file):\(self.line) → \(self.snippet)" }
    }

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
        处置：换成已有语义 token；缺 token 就去 `Sources/OhMyDesign/Colors/` 补一个**名字**，
        不要把色相硬编码进新 target。
        """)
    }

    @Test("探测器真的会开火：合成输入逐形态变红自证")
    func detectorFiresOnSyntheticSource() {
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

        let clean: [(name: String, source: String)] = [
            ("语义 token", "let c = Color.accent"),
            ("`.clear` 不是色相", "let c = Color.clear"),
            ("`.primary` / `.secondary` 是语义色", "let a = Color.primary; let b = Color.secondary"),
            ("同名成员但宿主不是颜色类型", "let v = pixel.red + pixel.green"),
            ("注释与字符串里的色相名", """
            // 这里说的是 .white 与 Color(red: 1, green: 0, blue: 0)
            let s = "白色 .white"
            """),
            ("`#Preview` 里的原色（有意跳过：预览不进产物，不受色相纪律约束）", """
            import SwiftUI
            #Preview { Color.red }
            """),
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
            ("非颜色类型的**隐式** `.init(red:)`（F-2 风险路径）", """
            struct Pixel { init(red: Int) {} }
            let p: Pixel = .init(red: 1)
            """),
            ("非颜色类型的**隐式** `.init(white:)`（F-2 风险路径）", """
            struct Insets { init(white: Int) {} }
            let x: Insets = .init(white: 3)
            """),
            ("`hue:` 标签的非颜色类型（`OhMyDesignEffects` 现实会出现的形态）", """
            struct HSBComponents { init(hue: Double, saturation: Double, brightness: Double) {} }
            let hsb: HSBComponents = .init(hue: 0.5, saturation: 1, brightness: 1)
            """),
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

    @Test("上下文类型：实参位置不继承外层返回类型；三元 / `??` 不截断（第 4 轮终审 I-1 / I-2）")
    func contextualTypeDoesNotLeakAcrossArgumentPositions() {
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

    @Test("上下文类型：赋值右侧 / 默认参数值 / 条件绑定各按自己的类型判（第 5 轮终审 I-a / I-b）")
    func contextualTypeRespectsAssignmentsDefaultsAndBindings() {
        let falsePositives: [(name: String, source: String)] = [
            ("`didSet` 里的赋值右侧（I-a）", """
            import SwiftUI
            struct S {
                var cache = 0
                var tint: Color = .clear { didSet { self.cache = .init(hue: 1, saturation: 1, brightness: 1) } }
            }
            """),
            ("计算属性 `set` 里的赋值右侧（I-a）", """
            import SwiftUI
            struct S {
                var store = 0
                var c: Color { get { .clear } set { self.store = .init(hue: 1, saturation: 1, brightness: 1) } }
            }
            """),
            ("`willSet` 里的赋值右侧（I-a）", """
            import SwiftUI
            struct S {
                var cache = 0
                var tint: Color = .clear { willSet { self.cache = .init(hue: 1, saturation: 1, brightness: 1) } }
            }
            """),
            ("`didSet` 里的**复合**赋值右侧（`+=`，第 5 轮终审 I-1）", """
            import SwiftUI
            struct S {
                var x = 0.0
                var tint: Color = .clear { didSet { self.x += .init(white: 1) } }
            }
            """),
            ("计算属性 `set` 里的复合赋值右侧（`*=`）", """
            import SwiftUI
            struct S {
                var store = 0.0
                var c: Color { get { .clear } set { self.store *= .init(white: 1) } }
            }
            """),
            ("单表达式函数体里的复合赋值右侧（`-=`）", """
            import SwiftUI
            func f() -> Color { g -= .init(white: 1) }
            """),
            ("默认参数值继承了外层返回类型（I-b①）", """
            import SwiftUI
            struct Pixel { init(red: Int, green: Int, blue: Int) {} }
            func makeColor(p: Pixel = .init(red: 1, green: 0, blue: 0)) -> Color { .clear }
            """),
            ("条件绑定自带的类型标注被换成外层标注（I-b②）", """
            import SwiftUI
            struct Pixel { init(red: Int) {} }
            var c: Color { if let p: Pixel = .init(red: 1) { .clear } else { .clear } }
            """),
        ]
        for c in falsePositives {
            let hits = Self.scan(source: c.source)
            #expect(hits.isEmpty, """
            \(c.name)：误报 \(hits.map(\.description))
            —— 这些位置的类型各有自己的来源（左值 / 形参 / 绑定自己的标注），
            与外层属性标注、外层返回类型无关。
            """)
        }

        let falseNegatives: [(name: String, source: String)] = [
            ("默认参数值写了颜色类型（I-b① 的镜像）", """
            import SwiftUI
            struct S { func f(c: Color = .init(red: 1, green: 0, blue: 0)) {} }
            """),
            ("`guard let c: Color = .init(…)`（I-b② 的镜像）", """
            import SwiftUI
            func f() -> Color {
                guard let c: Color = .init(red: 1, green: 0, blue: 0) else { return .clear }
                return c
            }
            """),
            ("`if let c: Color = .init(…)`", """
            import SwiftUI
            func f() { if let c: Color = .init(white: 0.5) { _ = c } }
            """),
        ]
        for c in falseNegatives {
            #expect(!Self.scan(source: c.source).isEmpty, """
            \(c.name)：漏报 —— 上下文里**写下了**颜色类型（形参类型 / 绑定自己的 `typeAnnotation`），
            按口子 4 的判据（「上下文真的写下了颜色类型」）这就该判红。
            """)
        }

        #expect(Self.scan(source: """
        import SwiftUI
        var scrim: Color { convert(.init(hue: 0.5, saturation: 1, brightness: 1)) }
        """).isEmpty, "实参位置的旧修法回退了（第 4 轮 I-1）")
        #expect(!Self.scan(source: """
        import SwiftUI
        let c: Color = flag ? .init(red: 1, green: 0, blue: 0) : .clear
        """).isEmpty, "三元不截断的旧修法回退了（第 4 轮 I-2）")
        #expect(!Self.scan(source: """
        import SwiftUI
        let c: Color = .init(red: 1, green: 0, blue: 0)
        """).isEmpty, "类型标注这条基本形态被本轮修法误伤")
    }

    @Test("探测器在真实源码上非真空：拿主 target 当靶场必须打出命中")
    func detectorFiresOnRealSource() throws {
        let hits = try Self.scan(root: GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName))
        #expect(hits.count > 10, """
        在 Sources/OhMyDesign 上只打出 \(hits.count) 处色相字面量 —— 探测器疑似失效。
        本条**不是**要求主 target 保持违规，而是「新 target 的零命中必须来自干净、
        不是来自坏掉的探测器」这句话的活证据。若主 target 真的被治理干净了，
        请把本条改成扫一份常驻 fixture，而不是直接删掉它。
        """)
    }
}

// MARK: - 采集器 / Collector

private nonisolated final class ColorLiteralCollector: SyntaxVisitor {
    var violations: [EffectsColorLiteralGuard.Violation] = []

    private let fileName: String
    private let converter: SourceLocationConverter

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }

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
        if let base = node.base {
            let root = base.trimmedDescription.split(separator: ".").map(String.init)
            guard let first = root.first,
                  EffectsColorLiteralGuard.colorTypeNames.contains(first) else { return .visitChildren }
        }
        self.record(node, snippet: node.trimmedDescription)
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        var callee = node.calledExpression.trimmedDescription
            .split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let isInitForm = callee.last == "init"
        if isInitForm { callee.removeLast() }
        let host = callee.last ?? ""
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
        let oneLine = snippet.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        self.violations.append(
            .init(file: self.fileName, line: line, snippet: String(oneLine.prefix(120)))
        )
    }
}

// MARK: - 隐式成员表达式的上下文类型 / Contextual type of an implicit member expression

nonisolated enum ImplicitMemberContext {
    static func contextualTypeName(of node: some SyntaxProtocol) -> String? {
        var current = Syntax(node)
        let origin = Syntax(node).position
        var inReturnPosition = true
        var sawReturnStmt = false
        while let parent = current.parent {
            if parent.is(ClosureExprSyntax.self) { return nil }
            if parent.is(LabeledExprSyntax.self) { return nil }
            if let call = parent.as(FunctionCallExprSyntax.self),
               Syntax(call.calledExpression).id != current.id {
                return nil
            }
            if let parameter = parent.as(FunctionParameterSyntax.self) {
                return Self.leafTypeName(parameter.type)
            }
            if let condition = parent.as(OptionalBindingConditionSyntax.self) {
                return condition.typeAnnotation.flatMap { Self.leafTypeName($0.type) }
            }
            if let binding = parent.as(PatternBindingSyntax.self) {
                guard inReturnPosition else { return nil }
                return binding.typeAnnotation.flatMap { Self.leafTypeName($0.type) }
            }
            if let asExpr = parent.as(AsExprSyntax.self) { return Self.leafTypeName(asExpr.type) }
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
                if let assignment = elements.first(where: { Self.isAssignmentOperator($0) }),
                   origin > assignment.position {
                    return nil
                }
                current = parent
                continue
            }
            if parent.is(ReturnStmtSyntax.self) { sawReturnStmt = true }
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

    nonisolated static let assignmentOperators: Set<String> = [
        "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=",
        "&+=", "&-=", "&*=", "&<<=", "&>>=", "??=",
    ]

    static func isAssignmentOperator(_ element: ExprSyntax) -> Bool {
        if element.is(AssignmentExprSyntax.self) { return true }
        if let binary = element.as(BinaryOperatorExprSyntax.self) {
            return Self.assignmentOperators.contains(binary.operator.text)
        }
        return false
    }

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
