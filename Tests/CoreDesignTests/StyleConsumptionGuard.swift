import Foundation
import SwiftParser
import SwiftSyntax
import Testing

/// **G-1**：登记表填了 `customStyleProtocol` 的组件，`body` 里必须真的**消费**那个 style
/// （`wxlpp/oh-my-story#48`）。
///
/// ## 缺口
///
/// J-2 的 `customStyleProtocol` 通路**只查符号存在性** —— 判绿条件是「协议已声明 +
/// 至少一个类型采纳」。组件完全可以声明协议、登记表填上名字，而 `body` 里**照旧硬渲染**
/// ⇒ J-2 照绿。公约把这条记作 **G-1**，此前的替代是 spy 测试（`Rating` / `RatingDisplay`
/// 各一条）——**靠人自觉，不是判据**。
///
/// ## 为什么语法级判据就够
///
/// 公约原文估「做成机器判据需要语义判断、成本明显更高」。**实测不然**：四个条目
/// （`Banner` / `Rating` / `RatingDisplay` / `SegmentedControl`）都在 `body` 内调用
/// `self.style.makeBody(configuration:)`，语法级就能守。
///
/// ⚠️ **但写法有三种，判据必须对三种都成立**：
/// - 单表达式 body（`Banner`）；
/// - **跨行**调用（`Rating` / `RatingDisplay`）；
/// - **多语句 body + `return AnyView(...)`**，调用前有局部量声明（`SegmentedControl`）。
///
/// ⚠️ **这条差点被单行 `grep` 误判**：`grep 'makeBody(configuration:'` 只捞到 2 处
/// （跨行那两个漏了），差点得出「形态不统一、判据做不了」的错误结论。
/// ⇒ **本守卫一律用 SwiftSyntax，不用正则。**
///
/// ## 精度上限（两条，必须写明）
///
/// 1. 守的是「**调用了** `makeBody`」，**不是**「调用的结果真的被渲染出来」。
///    `_ = self.style.makeBody(...)` 然后照旧硬渲染仍会判绿。
/// 2. receiver 已锚定为 `style` —— 不锚的话，硬编码 `PlainBannerStyle().makeBody(...)`
///    **绕开 environment 注入**照样判绿，那正好是 G-1 想守的「把定制权交出去」的反面。
///
/// ⇒ 公约 G- 表的 G-1 行据此写「**已部分覆盖**」，不是「已覆盖」。
///
/// ## 作用域
///
/// ⚠️ **只核 `repo == "coredesign"` 的条目**：registry 有 25 条 storyui 条目，本仓
/// **看不到它们的源码** ⇒ 不限定会假红。跨仓的参数级扫描是 `wxlpp/oh-my-story#67`
/// （G-8）的范围，两边口径要衔接：本守卫**不**尝试覆盖 storyui，那边落地时也不该
/// 反过来假设本守卫已覆盖。
@Suite("自有样式协议的消费判据")
struct StyleConsumptionGuard {
    /// 在某个类型声明的 `body` 内，找 `<receiver>.makeBody(configuration:)` 调用。
    ///
    /// ⚠️ **认 `FunctionCallExpr`（调用），不认 `FunctionDecl`（定义）**：样式实现里也有
    /// `public func makeBody(configuration:)` —— 那是协议见证的**定义**，不是组件在消费。
    private nonisolated final class ConsumptionFinder: SyntaxVisitor {
        let targetType: String
        /// 命中的 receiver 表达式（如 `self.style`）。
        var receivers: [String] = []
        /// 本文件里是否**声明**了目标类型。
        ///
        /// ⚠️ **用语法节点判，不用 `text.contains("public struct X")`**：那种写法会被
        /// **前缀**命中 —— 实测 `RatingDisplay.swift` 含 `public struct RatingDisplay`，
        /// 于是查 `Rating` 时它也命中，判据报「声明出现在 2 个文件里」。
        /// 这是本 issue 里**第四次**栽在窄匹配上（前三次：`makeBody` 单行 grep、
        /// `#65` 的「文件名 == 条目名」、`public nonisolated enum` 没命中）。
        var declaresTarget = false
        private var typeDepth = 0

        init(targetType: String, viewMode: SyntaxTreeViewMode) {
            self.targetType = targetType
            super.init(viewMode: viewMode)
        }

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            // ⚠️ **只进目标类型的声明**，不扫整文件：实测 `Rating.swift` 一个文件同时含
            // 条目 `Rating`、非条目的 `RatingStyleConfiguration`、协议、以及**两个含
            // `func makeBody` 定义**的类型。文件级搜索今天侥幸不炸，但形状是错的。
            guard node.name.text == self.targetType else { return .skipChildren }
            self.declaresTarget = true
            self.typeDepth += 1
            return .visitChildren
        }

        override func visitPost(_ node: StructDeclSyntax) {
            if node.name.text == self.targetType { self.typeDepth -= 1 }
        }

        /// ⚠️ **`extension Foo { var body … }` 也要进** —— 只 visit `StructDecl` 会让把
        /// `body` 写在 extension 里的组件**误红**（自查实测：把 `Banner.body` 挪进
        /// `extension Banner` 后守卫报「没有任何调用」）。那是**完全合法**的 Swift 写法，
        /// 本仓 `Rating.swift` 里就有 `extension` 承载成员。
        /// ⇒ 这个方向是**假阳性**（红得响、不会放过真缺陷），但误红同样会让人不信任判据。
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
            // 必须带 `configuration:` 标签 —— 与协议见证的形状对齐。
            guard node.arguments.contains(where: { $0.label?.text == "configuration" })
            else { return .visitChildren }
            self.receivers.append(member.base?.trimmedDescription ?? "")
            return .visitChildren
        }
    }

    @Test("承重：填了 customStyleProtocol 的组件，body 里真的调用了 style.makeBody(configuration:)")
    func componentsConsumeTheirStyle() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        // ⚠️ 作用域限定，见类型文档。
        let targets = entries.filter { $0.repo == "coredesign" && $0.customStyleProtocol != nil }

        // ⚠️ **非空前置**：registry 解析失效 / 字段全空时，下面的循环会在**空集上恒真**。
        #expect(targets.count >= 4,
                "只找到 \(targets.count) 条填了 customStyleProtocol 的 coredesign 条目 —— 疑似 registry 解析失效；本判据会在空集上恒真")

        let sources = try Self.swiftSources()
        #expect(sources.count > 50, "只枚举到 \(sources.count) 个源文件 —— 扫描失效，本判据会在空集上恒真")

        for entry in targets.sorted(by: { $0.component < $1.component }) {
            // ⚠️ **按类型声明定位，不用「文件名 == 条目名」**：那个约定在本仓 46 条条目里
            // **14 条不成立**（`SidebarUtilityRow` 在 `Sidebar.swift`、`Skeleton*` 三条在
            // `Skeleton.swift`），`#65` 实测过。
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

            // ⚠️ **锚定 receiver**：见类型文档的精度上限第 2 条。
            // ⚠️ 只在**确实有调用**时才判 receiver —— 否则「没有调用」会同时触发上下两条，
            // 而下面那条的消息（「调用了 makeBody 但 receiver 是 []」）**本身是假的**，
            // 会误导排查方向。两种缺陷要各报各的。
            if !receivers.isEmpty {
                let anchored = receivers.filter { $0.hasSuffix("style") || $0.hasSuffix("Style") }
                #expect(!anchored.isEmpty,
                        "`\(entry.component)` 调用了 makeBody，但 receiver 是 \(receivers) —— 没有一个是 `style`。硬编码某个具体样式（如 `PlainBannerStyle().makeBody(...)`）会**绕开 environment 注入**，那正是 G-1 想守的反面")
            }
        }
    }

    /// 全仓 `.swift` 源文件（文件名 → 内容）。
    private static func swiftSources() throws -> [(String, String)] {
        let root = ComponentRegistryGuard.coreDesignSources
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("无法枚举源码目录：\(root.path) —— 判据无法工作")
            return []
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                out.append((url.lastPathComponent, text))
            }
        }
        return out
    }
}
