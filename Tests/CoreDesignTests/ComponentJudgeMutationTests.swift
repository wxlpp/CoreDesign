import Foundation
import Testing

/// 端到端变异证伪：在 `Sources/CoreDesign` 的**临时副本**上改源码，跑真实扫描 + 真实规则。
///
/// ⚠️ **三条纪律，缺一条这个测试就会变成自己制造的绿**：
/// 1. **先证基线**：未变异的副本上，判据结果必须与真实源码上的结果一致——否则拷贝本身
///    出了问题（漏文件 / 编码问题），后面的「变异后判红」毫无意义。
/// 2. **变异自证**：`applyMutation` 断言替换命中次数 > 0；`replacingOccurrences` 找不到
///    目标时**静默返回原串**，不自证就会得到「变异了个寂寞 ⇒ 判据当然还是绿」。
/// 3. **违规集合精确**：断言 `== [期望的那一条]` 而不是 `!isEmpty`。这是「红要证明是
///    **这条**断言造成的」在纯函数世界里的等价落法。
@Suite("组件判据端到端变异")
struct ComponentJudgeMutationTests {

    /// 把源码树拷到临时目录，返回副本根路径。调用方负责在 `defer` 里删掉。
    private func copySources() throws -> URL {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("component-judge-mutation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let root = destination.appendingPathComponent("CoreDesign")
        try FileManager.default.copyItem(at: ComponentRegistryGuard.coreDesignSources, to: root)
        return root
    }

    /// 在副本的某个文件上做文本替换，并**断言真的替换到了**。
    private func applyMutation(
        root: URL, relativePath: String, find: String, replace: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let url = root.appendingPathComponent(relativePath)
        let original = try String(contentsOf: url, encoding: .utf8)
        let mutated = original.replacingOccurrences(of: find, with: replace)
        #expect(mutated != original,
                "变异没命中：\(relativePath) 里找不到「\(find)」—— 不自证的话后面「判据仍绿」会被误读成判据失效",
                sourceLocation: sourceLocation)
        try mutated.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("端到端：副本未变异时，三条判据的结果与真实源码一致（基线）")
    func copiedTreeReproducesBaseline() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let entries = try ComponentRegistryGuard.loadRegistry()
        let copied = try scanComponentJudgeInputs(root: root)
        let real = try ComponentJudgeSources.scan()

        #expect(copied.bareTextKeys == real.bareTextKeys, "副本与真实源码的裸文本参数集合不一致 —— 拷贝有问题")
        #expect(copied.styleProtocolNames == real.styleProtocolNames)
        #expect(judgeExtensionPoints(entries: entries, scan: copied).missing == ["AvatarGroup", "SidebarUtilityRow", "SpinningModifier", "Steps", "Timeline", "Toast"])
        #expect(judgeNativeProtocolPurity(entries: entries, scan: copied).violations.isEmpty)
        #expect(Set(judgeTextParamCoverage(
            entries: entries, scan: copied, ownerAliases: ComponentTextParamGuard.ownerAliases
        ).violations) == ComponentTextParamGuard.knownUnregisteredSymbolParams)
    }

    @Test("端到端 J-2 变异：把 BannerStyle 协议声明改名 ⇒ Banner 判缺扩展点")
    func j2EndToEndMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public protocol BannerStyle {", replace: "public protocol BannerAppearanceContract {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeExtensionPoints(entries: entries, scan: try scanComponentJudgeInputs(root: root))
        #expect(result.missing == ["AvatarGroup", "Banner", "SidebarUtilityRow", "SpinningModifier", "Steps", "Timeline", "Toast"],
                "登记表说 Banner 的扩展点是 BannerStyle，源码里没有这个协议声明了 ⇒ 必须判红")
        #expect(result.diagnostics.contains { $0.contains("Banner：") && $0.contains("无该协议声明") })
    }

    @Test("端到端 J-2 变异：删掉 BannerStyle 的全部实现 ⇒ Banner 判缺扩展点（『定义 + 使用』的使用侧）")
    func j2EndToEndMutationImplementationsRemoved() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public struct PlainBannerStyle: BannerStyle {", replace: "public struct PlainBannerStyle {"
        )
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public struct BorderedBannerStyle: BannerStyle {", replace: "public struct BorderedBannerStyle {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeExtensionPoints(entries: entries, scan: try scanComponentJudgeInputs(root: root))
        #expect(result.missing == ["AvatarGroup", "Banner", "SidebarUtilityRow", "SpinningModifier", "Steps", "Timeline", "Toast"])
        #expect(result.diagnostics.contains { $0.contains("Banner：") && $0.contains("无实现类型") },
                "只查协议声明、不查实现的话，把两个 style 实现删光判据照绿 —— AC 原文是『定义 + 使用』")
    }

    @Test("端到端 J-3 变异（通道 i）：往 ProgressIndicator.swift 塞一个自有样式协议 ⇒ 判红")
    func j3EndToEndMutationDeclarationChannel() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        try self.applyMutation(
            root: root, relativePath: "Components/ProgressIndicator/ProgressIndicator.swift",
            find: "public struct ProgressIndicator: View {",
            replace: """
            public protocol ProgressIndicatorStyle {
                associatedtype Body: View
                func makeBody(configuration: Self.Configuration) -> Body
                typealias Configuration = Int
            }

            public struct ProgressIndicator: View {
            """
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeNativeProtocolPurity(entries: entries, scan: try scanComponentJudgeInputs(root: root))
        #expect(result.violations.map(\.symbol) == ["ProgressIndicatorStyle"])
        #expect(result.violations.map(\.channel) == ["作用域内声明"])
        #expect(result.violations.map(\.component) == ["ProgressIndicator"])
    }

    @Test("端到端 J-3 变异（通道 ii）：让 ProgressIndicator 采纳 BannerStyle ⇒ 判红")
    func j3EndToEndMutationConformanceChannel() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        try self.applyMutation(
            root: root, relativePath: "Components/ProgressIndicator/ProgressIndicator.swift",
            find: "public struct ProgressIndicator: View {",
            replace: "extension ProgressIndicator: BannerStyle {}\n\npublic struct ProgressIndicator: View {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeNativeProtocolPurity(entries: entries, scan: try scanComponentJudgeInputs(root: root))
        #expect(result.violations.map(\.symbol) == ["BannerStyle"])
        #expect(result.violations.map(\.channel) == ["组件采纳"])
    }

    @Test("端到端 FR-4 变异：给 Avatar 加一个未登记的裸 String 参数 ⇒ 判红；补登记 ⇒ 转绿")
    func fr4EndToEndMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        try self.applyMutation(
            root: root, relativePath: "Components/Avatar/Avatar.swift",
            find: "public init(name: String) {", replace: "public init(name: String, caption: String) {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try scanComponentJudgeInputs(root: root)

        let red = judgeTextParamCoverage(
            entries: entries, scan: scan, ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(Set(red.violations) ==
                ComponentTextParamGuard.knownUnregisteredSymbolParams.union(["Avatar.init#caption"]),
                "新增未登记的裸 String 参数必须判红，且违规集合精确")

        // 「补登记 ⇒ 转绿」：登记表只读，因此在**内存里**补一条条目，不碰 JSON。
        let patched = entries.map { entry -> ComponentRegistryGuard.Entry in
            guard entry.component == "Avatar" else { return entry }
            return makeTestEntry(
                component: entry.component, repo: entry.repo, kind: entry.kind, decidedBy: entry.decidedBy,
                nativeProtocol: entry.nativeProtocol, customStyleProtocol: entry.customStyleProtocol,
                needsExtensionPoint: entry.needsExtensionPoint,
                textParams: entry.textParams + [ComponentRegistryGuard.TextParam(name: "caption", category: "B")],
                notes: entry.notes
            )
        }
        let green = judgeTextParamCoverage(
            entries: patched, scan: scan, ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(Set(green.violations) == ComponentTextParamGuard.knownUnregisteredSymbolParams,
                "补登记后新增的那条应消失，已知的四条不受影响 —— AC 原文的『补登记 → 判据变绿』")
    }

    @Test("端到端 FR-4 反向变异：把已登记参数改名 ⇒ 登记表条目变成幽灵")
    func fr4EndToEndGhostMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        try self.applyMutation(
            root: root, relativePath: "Components/Avatar/Avatar.swift",
            find: "public init(name: String) {", replace: "public init(displayName: String) {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeTextParamCoverage(
            entries: entries, scan: try scanComponentJudgeInputs(root: root),
            ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(result.ghostRegistryParams == ["Avatar.name"],
                "反向差集必须抓到『登记表有、源码没有』—— 这是参数被改写成扫描器看不见的形态时的第二道防线")
        #expect(result.violations.contains("Avatar.init#displayName"))
    }
}
