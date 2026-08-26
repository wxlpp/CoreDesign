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

    /// 只在给定 body 内收集对 `ToastHostModifier(...)` 的调用实参，并记录同名局部绑定。
    private nonisolated final class BodyCollector: SyntaxVisitor {
        var forwarded: [String: String] = [:]
        var localBindings: Set<String> = []

        /// 每个实参标签 → 它被传过的**全部**表达式（不去重、不 first-wins）。
        ///
        /// ⚠️ **不限定被调类型**（泛化的代价与收益，两侧都写）：本守卫由别名表驱动，各条目
        /// 转发的目标类型名不固定，写死 `ToastHostModifier` 就泛化不了。改为采**所有**调用的
        /// 实参，再断言「不存在 `param: <非 param 的东西>`」。
        ///
        /// **收益**：比「first-wins + 调用数 == 1」**更精确** —— 多处调用里只要有一处把参数
        /// 写死就红，不必要求只能有一处调用。实测新抓到「if/else 一处正确一处写死」这个
        /// 旧版盲区。
        ///
        /// ⚠️ **代价（已知逃逸，如实记下 —— PR #210 Copilot 复审后的第 3 轮 S-1）**：旧版
        /// 限定被调类型 + 调用数 == 1，所以「产线调用改走另一个 init 并把参数写死」必红；
        /// 新版只要体内**任意**调用带过 `param: param` 就过第 1 条。于是一个
        /// **「诱饵调用携带同名转发 + 真实构造挪进不带这两个标签的 helper」** 的构造能全绿。
        /// - 实测**构造 A**（诱饵 + 真实调用仍带同名标签）⇒ **判红**，第 2 条抓到；
        /// - **构造 B**（真实构造挪进无参 helper）理论可逃，我的尝试因 public extension 的
        ///   可见性约束编译不过 —— 要走通还需额外结构改动。
        /// ⇒ 这需要**蓄意构造**（意外回归到不了这个形状），且语法守卫本就防不了对抗性实现。
        /// 接受这个代价换泛化，但不假装它不存在。
        var argumentsByLabel: [String: [String]] = [:]

        override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            for arg in n.arguments {
                guard let label = arg.label?.text else { continue }
                self.argumentsByLabel[label, default: []].append(arg.expression.trimmedDescription)
            }
            return .visitChildren
        }

        /// ⚠️ 采局部绑定名 —— 用于堵**同名遮蔽**（见守卫第 2 条）。
        ///
        /// ⚠️ **四种绑定形态都要采，只采 `PatternBindingSyntax` 只挡了一半**
        /// （PR #210 本地 Copilot CLI 复审实测跑通的绕过）：
        /// `guard let presentation = Optional(.floatingCapsule) else { … }` 走的是
        /// `OptionalBindingConditionSyntax`，不是 `PatternBindingSyntax` ⇒ 遮蔽检查
        /// **完全看不见它**，而 `forwarded["presentation"] == "presentation"` 照样成立
        /// ⇒ 写死 `presentation` 的回归重新变得不可见。
        override func visit(_ n: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
            if let ident = n.pattern.as(IdentifierPatternSyntax.self) {
                self.localBindings.insert(ident.identifier.text)
            }
            return .visitChildren
        }

        /// `if let x` / `guard let x` / `while let x`。
        override func visit(_ n: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
            if let ident = n.pattern.as(IdentifierPatternSyntax.self) {
                self.localBindings.insert(ident.identifier.text)
            }
            return .visitChildren
        }

        /// 闭包形参（`{ presentation in … }`）与捕获列表。
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

        /// 嵌套函数 / 嵌套闭包里的形参。
        override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            for p in n.signature.parameterClause.parameters {
                self.localBindings.insert(p.secondName?.text ?? p.firstName.text)
            }
            return .visitChildren
        }
    }

    /// 别名表里每个 `(component, modifier 方法名)` 的**源码位置**。
    ///
    /// ⚠️ **本守卫由 `ComponentHostAliases.table` 驱动，不硬编码 `toastHost`**
    /// （PR #210 本地 Copilot CLI 复审的第 4 条 —— 那条指出的是**流程性缺口**，
    /// 不是某一行的 bug）：
    ///
    /// J-2 与别名表的五条守卫**全程只读签名**（「该 modifier 方法的参数类型是不是这个
    /// 枚举」），从不看函数体。`#65` 是靠一份手写的、专属于 `toastHost` 的语法守卫才把
    /// 这个洞堵上的。若那份守卫**不随别名表泛化**，将来任何新增的别名条目
    /// （如 `"Foo": ["fooHost"]`）只要签名里声明了对应枚举参数，五条守卫全绿、J-2 判
    /// `satisfied`，而函数体完全可以像本轮修复前的 `toastHost` 一样把参数写死 ——
    /// **不会有人自动提醒「记得再写一份 FooPublicEntryForwardingGuard」**。
    ///
    /// ⇒ 改成遍历别名表：**新增条目自动被覆盖**，缺失源码时判红而非静默跳过。
    /// 按**函数声明**定位源文件，而不是按文件名。
    ///
    /// ⚠️ **不能用「文件名 == component 名」**（自查实测）：全 registry 46 条本仓条目里
    /// **14 条不同名** —— `SidebarUtilityRow` / `SidebarNavigationRow` / `SidebarSection`
    /// 等全在 `Sidebar.swift` 里，`SkeletonCircle` / `SkeletonLine` / `SkeletonRect` 在
    /// `Skeleton.swift` 里。今天别名表只有 `Toast` 一条、恰好同名，但泛化的意义正是
    /// **给未来的条目用** —— 靠一个七成成立的约定，第二条别名进来时就会静默失效。
    /// ⇒ 直接扫全仓找 `func <modifierName>(` 的声明所在文件。
    private func sourceFiles(declaring functionName: String) -> [URL] {
        let root = ComponentRegistryGuard.coreDesignSources
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }
        var hits: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("func \(functionName)(") { hits.append(url) }
        }
        return hits
    }

    @Test("承重：别名表里每个 modifier 入口都把签名参数**逐名转发**下去")
    func aliasEntriesForwardEveryParameter() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.component, $0) })
        // ⚠️ 非空前置：表空了本测试会在空循环上恒真。
        #expect(!ComponentHostAliases.table.isEmpty, "别名表为空 —— 本守卫会在空循环上恒真，必须先红")

        for (component, modifierNames) in ComponentHostAliases.table.sorted(by: { $0.key < $1.key }) {
            guard let styleEnum = byName[component]?.styleEnum else {
                // 死条目由 `ComponentHostAliasGuard` 的棘轮管，这里跳过即可。
                continue
            }
            for modifierName in modifierNames.sorted() {
                let files = self.sourceFiles(declaring: modifierName)
                // ⚠️ **找不到时判红、不静默跳过** —— 别名表指向一个不存在的入口时，
                // 「循环体没执行 ⇒ 全绿」是最坏的失效形态。
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
        // ⚠️ 非空前置：文件改名 / 函数改名会让下面的断言在**空集合上恒真**。
        #expect(source.contains("func \(functionName)("),
                "\(component) 的源码里没有 `func \(functionName)(` —— 别名表指向的入口不存在或已改名，本守卫会在空集上恒真")

        let finder = FunctionFinder(target: functionName, viewMode: .sourceAccurate)
        finder.walk(SwiftParser.Parser.parse(source: source))
        // ⚠️ **结构漂移必须判红、不能静默缩窄**（PR #210 复审 Important-1）：
        // 本守卫自称「这条逃逸没有别的守卫抓得到」——唯一防线自己不能有静默失效模式。
        // 加一个 `toastHost` 重载（convenience 重载、带 host 的预览版都很现实）时，
        // 若只取第一个/最后一个，原函数的转发就**从此不再被校验且不红**。
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

        // ⚠️ 无标签参数（`_ foo:`）：签名侧取 `secondName`、实参侧记 `"_"` ⇒ 二者对不上
        // 会**假阳性**（红得响、不是静默放过），届时按需扩本守卫（复审 Suggestion）。
        // `toastHost` 目前两个参数都有外部标签，不触发。
        let params = function.signature.parameterClause.parameters.map {
            ($0.firstName.text == "_" ? ($0.secondName?.text ?? "_") : $0.firstName.text)
        }
        let collector = BodyCollector(viewMode: .sourceAccurate)
        collector.walk(body)

        #expect(!collector.argumentsByLabel.isEmpty,
                "\(functionName) 体内没有任何带标签的函数调用 —— 实现结构变了，本守卫无从核对转发")

        // 第 1 条：每个签名参数都必须**至少**以同名实参转发过一次。
        for param in params {
            let passed = collector.argumentsByLabel[param] ?? []
            #expect(passed.contains(param),
                    "\(component) 的 `\(functionName)` 参数 `\(param)` 没有逐名转发下去（实参里出现的是 \(passed.isEmpty ? "（该标签根本没出现）" : String(describing: passed))）—— 签名上有、函数体里丢掉或改写了它。判据只读签名、渲染护栏又绕过这一行，这条逃逸没有别的守卫抓得到")

            // 第 2 条：⚠️ 且**不得**有任何一处把它换成别的值。
            // 这比「first-wins + 调用数 == 1」精确：if/else 或 `#if os` 分支里只要有一处
            // 写死，本条就红，而不需要禁止多处调用。
            let hijacked = passed.filter { $0 != param }
            #expect(hijacked.isEmpty,
                    "\(component) 的 `\(functionName)` 有 \(hijacked.count) 处把 `\(param):` 传成了别的值 \(hijacked) —— 即使另有一处正确转发，被写死的那条分支照样会让参数失效")
        }

        // 第 3 条：⚠️ **堵同名遮蔽**（自查 + Copilot CLI 实测的漏洞）。
        // 本守卫是**纯语法**的：它比的是标识符名字，不做语义分析。于是
        // `let presentation = ToastPresentation.floatingCapsule` 在体内遮蔽参数后再
        // `presentation: presentation` 转发，**照样判绿** —— 实测确认。
        // ⇒ 直接禁掉「函数体内出现与参数同名的局部绑定」这种写法（它在这个只有一行转发的
        // 函数里也毫无正当用途）。
        for param in params where collector.localBindings.contains(param) {
            Issue.record("\(component) 的 `\(functionName)` 体内有与参数 `\(param)` **同名的局部绑定** —— 本守卫是纯语法比对、不做语义分析，同名遮蔽会让「逐名转发」这条断言判绿而实际转发的是局部变量。转发型入口里不需要同名局部变量；要改实现请改签名或改守卫，别靠遮蔽绕过")
        }
    }
}
