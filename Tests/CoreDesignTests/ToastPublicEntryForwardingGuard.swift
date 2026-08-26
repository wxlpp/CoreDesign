import Foundation
import SwiftParser
import SwiftSyntax
import Testing

/// `View.toastHost(edge:presentation:)` 的**转发守卫**（`#65` / PR #210 终审 I-1）。
///
/// ## 为什么需要一条语法级守卫
///
/// 这个函数体是全测试体系**唯一没有任何自动化判据覆盖的产线行**。实测变异
/// 「转发时把 `presentation` 写死成 `.floatingCapsule`」**全测试全绿逃逸**：
///
/// - `ToastPresentationRenderTests` 的 9 条断言全部经 `ToastHostModifier(host:...)`
///   **直接构造**进入（那是 A9 的注入缝），`Tests/` 下零处调用 `.toastHost(`；
/// - J-2 判据与 `ComponentHostAliasGuard` 只读**签名**（扫描器采 `parameterClause`，
///   不看函数体）⇒ 参数还在签名上就判绿；
/// - 唯二走公开 API 的是 `App/Sources/Previews.swift`，而 `App/` 不进 CI，
///   快照流水线也只出图、不比对基线。
///
/// ⚠️ **这正是 `host:` 注入缝自己论证要消灭的病型** —— 缝把未覆盖边界**上移了一层**
/// （从「挂载方式」移到「公开入口转发」），而不是消灭了它。
/// ⇒ **加注入缝时要顺带问「缝之上还剩哪一行没人走过」。**
///
/// ## 为什么不用渲染判据
///
/// 试过，**不成立**：经 `.toastHost(...)` 挂载时 host 是 modifier 内部的 `@State`，
/// 测试够不着、队列恒空 ⇒ 三个形态都零尺寸占位、容器高度全等（实测 120/120/120）。
/// 这与 spec §5.1 记的探针 3 是同一个阻碍，只是发生在公开入口那一层。
@Suite("Toast 公开入口的参数转发")
struct ToastPublicEntryForwardingGuard {
    /// 收集 `func toastHost(...)` 体内对 `ToastHostModifier(...)` 的调用实参。
    // ⚠️ `nonisolated`：本包 `.defaultIsolation(MainActor.self)`，而 `SyntaxVisitor` 的
    // `init(viewMode:)` 与 `visit` 都是 nonisolated 的 —— 不标会报「actor isolation 与
    // 被覆写声明不符」。写法照抄 `ComponentJudgeScanner` 里 `ComponentJudgeCollector` 的成法。
    private nonisolated final class Collector: SyntaxVisitor {
        var found: [(label: String, expr: String)] = []
        var sawFunction = false
        var signatureParams: [String] = []

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.name.text == "toastHost" else { return .skipChildren }
            self.sawFunction = true
            self.signatureParams = node.signature.parameterClause.parameters.map {
                ($0.firstName.text == "_" ? ($0.secondName?.text ?? "_") : $0.firstName.text)
            }
            return .visitChildren
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard self.sawFunction,
                  node.calledExpression.trimmedDescription == "ToastHostModifier" else { return .visitChildren }
            for arg in node.arguments {
                self.found.append((arg.label?.text ?? "_", arg.expression.trimmedDescription))
            }
            return .visitChildren
        }
    }

    @Test("承重：toastHost 把签名上的每个参数**逐名转发**给 ToastHostModifier")
    func forwardsEveryParameter() throws {
        let url = ComponentRegistryGuard.coreDesignSources
            .appendingPathComponent("Components/Toast/Toast.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        // ⚠️ 非空前置：路径写错 / 文件改名会让下面的断言在**空集合上恒真**。
        #expect(source.contains("func toastHost("), "没读到 Toast.swift 或它已不含 toastHost —— 本守卫会在空集上恒真，必须先红")

        let collector = Collector(viewMode: .sourceAccurate)
        collector.walk(SwiftParser.Parser.parse(source: source))

        #expect(collector.sawFunction, "没找到 func toastHost —— 它可能被改名了，本守卫需同步更新")
        #expect(!collector.found.isEmpty, "toastHost 体内没有对 ToastHostModifier 的调用 —— 实现结构变了")

        let forwarded = Dictionary(collector.found.map { ($0.label, $0.expr) }, uniquingKeysWith: { a, _ in a })
        for param in collector.signatureParams {
            #expect(forwarded[param] == param,
                    "toastHost 的参数 `\(param)` 没有逐名转发给 ToastHostModifier（实际传的是 `\(forwarded[param] ?? "缺失")`）—— 签名上有、函数体里丢掉或改写了它，而判据只读签名、渲染护栏又绕过了这一行，这条逃逸没有别的守卫抓得到")
        }
    }
}
