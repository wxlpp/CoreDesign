import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Toast 公开入口的参数转发")
struct ToastPublicEntryForwardingGuard {
    private nonisolated final class FunctionFinder: SyntaxVisitor {
        let target: String
        var nodes: [FunctionDeclSyntax] = []

        init(target: String, viewMode: SyntaxTreeViewMode) {
            self.target = target
            super.init(viewMode: viewMode)
        }
        override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            if n.name.text == self.target { self.nodes.append(n) }
            return .skipChildren
        }
    }

    private nonisolated final class BodyCollector: SyntaxVisitor {
        var forwarded: [String: String] = [:]
        var localBindings: Set<String> = []

        var argumentsByLabel: [String: [String]] = [:]

        override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            for arg in n.arguments {
                guard let label = arg.label?.text else { continue }
                self.argumentsByLabel[label, default: []].append(arg.expression.trimmedDescription)
            }
            return .visitChildren
        }

        override func visit(_ n: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
            if let ident = n.pattern.as(IdentifierPatternSyntax.self) {
                self.localBindings.insert(ident.identifier.text)
            }
            return .visitChildren
        }

        override func visit(_ n: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
            if let ident = n.pattern.as(IdentifierPatternSyntax.self) {
                self.localBindings.insert(ident.identifier.text)
            }
            return .visitChildren
        }

        override func visit(_ n: ClosureSignatureSyntax) -> SyntaxVisitorContinueKind {
            switch n.parameterClause {
            case let .simpleInput(list):
                for p in list { self.localBindings.insert(p.name.text) }
            case let .parameterClause(clause):
                for p in clause.parameters {
                    self.localBindings.insert(p.secondName?.text ?? p.firstName.text)
                }
            case .none:
                break
            }
            for capture in n.capture?.items ?? [] {
                self.localBindings.insert(capture.name.text)
            }
            return .visitChildren
        }

        override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            for p in n.signature.parameterClause.parameters {
                self.localBindings.insert(p.secondName?.text ?? p.firstName.text)
            }
            return .visitChildren
        }
    }

    private func sourceFiles(declaring functionName: String) -> [URL] {
        var hits: [URL] = []
        for root in ComponentRegistryGuard.componentScanRoots {
            for url in GuardScanRoots.swiftFiles(in: root.url) {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                if text.contains("func \(functionName)(") { hits.append(url) }
            }
        }
        return hits
    }

    @Test("承重：别名表里每个 modifier 入口都把签名参数**逐名转发**下去")
    func aliasEntriesForwardEveryParameter() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.component, $0) })
        #expect(!ComponentHostAliases.table.isEmpty, "别名表为空 —— 本守卫会在空循环上恒真，必须先红")

        for (component, modifierNames) in ComponentHostAliases.table.sorted(by: { $0.key < $1.key }) {
            guard let styleEnum = byName[component]?.styleEnum else {
                continue
            }
            for modifierName in modifierNames.sorted() {
                let files = self.sourceFiles(declaring: modifierName)
                #expect(!files.isEmpty,
                        "别名表 `\(component)` → `\(modifierName)`：全仓找不到 `func \(modifierName)(` 的声明 —— 入口不存在或已改名，本守卫无从核对函数体转发")
                #expect(files.count <= 1,
                        "`func \(modifierName)(` 在 \(files.count) 个文件里都有声明 \(files.map(\.lastPathComponent).sorted()) —— 本守卫按「唯一入口」设计，同名多处时必须回来改成逐处校验")
                for url in files {
                    guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
                    self.assertForwarding(source: source, function: modifierName,
                                          component: component, styleEnum: styleEnum)
                }
            }
        }
    }

    private func assertForwarding(source: String, function functionName: String,
                                  component: String, styleEnum: String) {
        #expect(source.contains("func \(functionName)("),
                "\(component) 的源码里没有 `func \(functionName)(` —— 别名表指向的入口不存在或已改名，本守卫会在空集上恒真")

        let finder = FunctionFinder(target: functionName, viewMode: .sourceAccurate)
        finder.walk(SwiftParser.Parser.parse(source: source))
        #expect(finder.nodes.count == 1,
                "\(component) 里有 \(finder.nodes.count) 个 `\(functionName)` 声明 —— 本守卫按「唯一公开入口」设计。新增重载时必须回来把它改成逐个校验，别让它静默只守其中一个")
        guard let function = finder.nodes.first else {
            Issue.record("没找到 func \(functionName) —— 它可能被改名了，别名表需同步更新")
            return
        }
        guard let body = function.body else {
            Issue.record("\(functionName) 没有函数体 —— 实现结构变了")
            return
        }

        let params = function.signature.parameterClause.parameters.map {
            ($0.firstName.text == "_" ? ($0.secondName?.text ?? "_") : $0.firstName.text)
        }
        let collector = BodyCollector(viewMode: .sourceAccurate)
        collector.walk(body)

        #expect(!collector.argumentsByLabel.isEmpty,
                "\(functionName) 体内没有任何带标签的函数调用 —— 实现结构变了，本守卫无从核对转发")

        for param in params {
            let passed = collector.argumentsByLabel[param] ?? []
            #expect(passed.contains(param),
                    "\(component) 的 `\(functionName)` 参数 `\(param)` 没有逐名转发下去（实参里出现的是 \(passed.isEmpty ? "（该标签根本没出现）" : String(describing: passed))）—— 签名上有、函数体里丢掉或改写了它。判据只读签名、渲染护栏又绕过这一行，这条逃逸没有别的守卫抓得到")

            let hijacked = passed.filter { $0 != param }
            #expect(hijacked.isEmpty,
                    "\(component) 的 `\(functionName)` 有 \(hijacked.count) 处把 `\(param):` 传成了别的值 \(hijacked) —— 即使另有一处正确转发，被写死的那条分支照样会让参数失效")
        }

        for param in params where collector.localBindings.contains(param) {
            Issue.record("\(component) 的 `\(functionName)` 体内有与参数 `\(param)` **同名的局部绑定** —— 本守卫是纯语法比对、不做语义分析，同名遮蔽会让「逐名转发」这条断言判绿而实际转发的是局部变量。转发型入口里不需要同名局部变量；要改实现请改签名或改守卫，别靠遮蔽绕过")
        }
    }
}
