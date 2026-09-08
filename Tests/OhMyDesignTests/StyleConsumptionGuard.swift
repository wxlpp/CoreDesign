import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@Suite("自有样式协议的消费判据")
struct StyleConsumptionGuard {
    private nonisolated final class ConsumptionFinder: SyntaxVisitor {
        let targetType: String
        var receivers: [String] = []
        var declaresTarget = false
        private var typeDepth = 0

        init(targetType: String, viewMode: SyntaxTreeViewMode) {
            self.targetType = targetType
            super.init(viewMode: viewMode)
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.name.text == self.targetType else { return .skipChildren }
            self.declaresTarget = true
            self.typeDepth += 1
            return .visitChildren
        }

        override func visitPost(_ node: StructDeclSyntax) {
            if node.name.text == self.targetType { self.typeDepth -= 1 }
        }

        override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.extendedType.trimmedDescription == self.targetType else { return .skipChildren }
            self.typeDepth += 1
            return .visitChildren
        }

        override func visitPost(_ node: ExtensionDeclSyntax) {
            if node.extendedType.trimmedDescription == self.targetType { self.typeDepth -= 1 }
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard self.typeDepth > 0 else { return .visitChildren }
            guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
                  member.declName.baseName.text == "makeBody" else { return .visitChildren }
            guard node.arguments.contains(where: { $0.label?.text == "configuration" })
            else { return .visitChildren }
            self.receivers.append(member.base?.trimmedDescription ?? "")
            return .visitChildren
        }
    }

    @Test("承重：填了 customStyleProtocol 的组件，body 里真的调用了 style.makeBody(configuration:)")
    func componentsConsumeTheirStyle() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let targets = entries.filter { $0.repo == "ohmydesign" && $0.customStyleProtocol != nil }

        #expect(targets.count >= 4,
                "只找到 \(targets.count) 条填了 customStyleProtocol 的 ohmydesign 条目 —— 疑似 registry 解析失效；本判据会在空集上恒真")

        let sources = try Self.swiftSources()
        #expect(sources.count > 50, "只枚举到 \(sources.count) 个源文件 —— 扫描失效，本判据会在空集上恒真")

        for entry in targets.sorted(by: { $0.component < $1.component }) {
            var receivers: [String] = []
            var declaringFiles: [String] = []
            for (name, text) in sources {
                let finder = ConsumptionFinder(targetType: entry.component, viewMode: .sourceAccurate)
                finder.walk(SwiftParser.Parser.parse(source: text))
                if finder.declaresTarget { declaringFiles.append(name) }
                receivers.append(contentsOf: finder.receivers)
            }

            #expect(declaringFiles.count == 1,
                    "`\(entry.component)` 的 `public struct` 声明出现在 \(declaringFiles.count) 个文件里 \(declaringFiles.sorted()) —— 本判据按「唯一声明」设计，同名多处时须回来改成逐处校验")

            #expect(!receivers.isEmpty,
                    "`\(entry.component)` 登记表填了 customStyleProtocol=\(entry.customStyleProtocol ?? "?")，但它的 `body` 里**没有任何** `makeBody(configuration:)` 调用 —— 协议声明了、类型采纳了、组件却照旧硬渲染，这正是 J-2 只查符号存在性放过的那种情形（公约 G-1）")

            if !receivers.isEmpty {
                let anchored = receivers.filter { $0 == "self.style" || $0 == "style" }
                #expect(!anchored.isEmpty,
                        "`\(entry.component)` 调用了 makeBody，但 receiver 是 \(receivers) —— 没有一个是 `style`。硬编码某个具体样式（如 `PlainBannerStyle().makeBody(...)`）会**绕开 environment 注入**，那正是 G-1 想守的反面")
            }
        }
    }

    private static func swiftSources() throws -> [(String, String)] {
        let roots = ComponentRegistryGuard.componentScanRoots
        GuardScanRoots.assertRootsExist(roots)
        var out: [(String, String)] = []
        for root in roots {
            for url in GuardScanRoots.swiftFiles(in: root.url) {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    out.append((GuardScanRoots.relativePath(url), text))
                }
            }
        }
        return out
    }
}
