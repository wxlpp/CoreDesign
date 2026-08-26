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
    /// 找到 `func toastHost(...)` 声明本身。
    ///
    /// ⚠️ **不用「全文件 walk + `sawFunction` 标志位」**（自查实测的漏洞）：标志位一旦置 true
    /// 就不复位，文件内**后续任何** `ToastHostModifier(...)` 调用都会被当成 `toastHost` 体内的
    /// —— 顺序反转即误判。改成先定位函数节点、再**只在它的 body 里**收集。
    private nonisolated final class FunctionFinder: SyntaxVisitor {
        var nodes: [FunctionDeclSyntax] = []
        override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            if n.name.text == "toastHost" { self.nodes.append(n) }
            return .skipChildren
        }
    }

    /// 只在给定 body 内收集对 `ToastHostModifier(...)` 的调用实参，并记录同名局部绑定。
    private nonisolated final class BodyCollector: SyntaxVisitor {
        var forwarded: [String: String] = [:]
        var localBindings: Set<String> = []

        var callCount = 0

        override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard n.calledExpression.trimmedDescription == "ToastHostModifier" else { return .visitChildren }
            self.callCount += 1
            for arg in n.arguments where self.forwarded[arg.label?.text ?? "_"] == nil {
                self.forwarded[arg.label?.text ?? "_"] = arg.expression.trimmedDescription
            }
            return .visitChildren
        }

        /// ⚠️ 采局部 `let` / `var` 绑定名 —— 用于堵**同名遮蔽**（见守卫第 2 条）。
        override func visit(_ n: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
            if let ident = n.pattern.as(IdentifierPatternSyntax.self) {
                self.localBindings.insert(ident.identifier.text)
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

        let finder = FunctionFinder(viewMode: .sourceAccurate)
        finder.walk(SwiftParser.Parser.parse(source: source))
        // ⚠️ **结构漂移必须判红、不能静默缩窄**（PR #210 复审 Important-1）：
        // 本守卫自称「这条逃逸没有别的守卫抓得到」——唯一防线自己不能有静默失效模式。
        // 加一个 `toastHost` 重载（convenience 重载、带 host 的预览版都很现实）时，
        // 若只取第一个/最后一个，原函数的转发就**从此不再被校验且不红**。
        #expect(finder.nodes.count == 1,
                "Toast.swift 里有 \(finder.nodes.count) 个 `toastHost` 声明 —— 本守卫按「唯一公开入口」设计。新增重载时必须回来把它改成逐个校验，别让它静默只守其中一个")
        guard let function = finder.nodes.first else {
            Issue.record("没找到 func toastHost —— 它可能被改名了，本守卫需同步更新")
            return
        }
        guard let body = function.body else {
            Issue.record("toastHost 没有函数体 —— 实现结构变了")
            return
        }

        // ⚠️ 无标签参数（`_ foo:`）：签名侧取 `secondName`、实参侧记 `"_"` ⇒ 二者对不上
        // 会**假阳性**（红得响、不是静默放过），届时按需扩本守卫（复审 Suggestion）。
        // `toastHost` 目前两个参数都有外部标签，不触发。
        let params = function.signature.parameterClause.parameters.map {
            ($0.firstName.text == "_" ? ($0.secondName?.text ?? "_") : $0.firstName.text)
        }
        let collector = BodyCollector(viewMode: .sourceAccurate)
        collector.walk(body)

        #expect(!collector.forwarded.isEmpty, "toastHost 体内没有对 ToastHostModifier 的调用 —— 实现结构变了")
        // ⚠️ 同理：体内若出现**第二个** `ToastHostModifier(...)`（if/else 分支、`#if os` ——
        // `SyntaxVisitor` 对 inactive `#if` 区域照走），first-wins 去重会让写死的那个被
        // 正确的那个掩掉。⇒ 调用数漂移也判红。
        #expect(collector.callCount == 1,
                "toastHost 体内有 \(collector.callCount) 处 `ToastHostModifier(...)` 调用 —— 本守卫的 first-wins 去重会掩掉其中一处。要分支就把本守卫改成逐调用校验")

        // 第 1 条：每个参数逐名转发。
        for param in params {
            #expect(collector.forwarded[param] == param,
                    "toastHost 的参数 `\(param)` 没有逐名转发给 ToastHostModifier（实际传的是 `\(collector.forwarded[param] ?? "缺失")`）—— 签名上有、函数体里丢掉或改写了它，而判据只读签名、渲染护栏又绕过了这一行，这条逃逸没有别的守卫抓得到")
        }

        // 第 2 条：⚠️ **堵同名遮蔽**（自查实测的漏洞）。
        // 本守卫是**纯语法**的：它比的是标识符名字，不做语义分析。于是
        // `let presentation = ToastPresentation.floatingCapsule` 在体内遮蔽参数后再
        // `presentation: presentation` 转发，**照样判绿** —— 实测确认。
        // ⇒ 直接禁掉「函数体内出现与参数同名的局部绑定」这种写法（它在这个只有一行转发的
        // 函数里也毫无正当用途）。
        for param in params where collector.localBindings.contains(param) {
            Issue.record("toastHost 体内有与参数 `\(param)` **同名的局部绑定** —— 本守卫是纯语法比对、不做语义分析，同名遮蔽会让「逐名转发」这条断言判绿而实际转发的是局部变量。这个只有一行转发的函数里不需要同名局部变量；要改实现请改签名或改守卫，别靠遮蔽绕过")
        }
    }
}
