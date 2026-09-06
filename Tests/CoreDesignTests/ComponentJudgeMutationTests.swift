import Foundation
import Testing

@Suite("组件判据端到端变异")
struct ComponentJudgeMutationTests {
    private func copySources() throws -> URL {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("component-judge-mutation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for root in ComponentRegistryGuard.componentScanRoots {
            try FileManager.default.copyItem(
                at: root.url, to: destination.appendingPathComponent(root.target)
            )
        }
        return destination
    }

    private func copiedRoots(in destination: URL) -> [(target: String, url: URL)] {
        ComponentRegistryGuard.componentScanRoots.map {
            ($0.target, destination.appendingPathComponent($0.target))
        }
    }

    private func applyMutation(
        root: URL, relativePath: String, find: String, replace: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let url = root
            .appendingPathComponent(GuardScanRoots.primaryTargetName)
            .appendingPathComponent(relativePath)
        let original = try String(contentsOf: url, encoding: .utf8)
        let mutated = original.replacingOccurrences(of: find, with: replace)
        #expect(mutated != original,
                "变异没命中：\(relativePath) 里找不到「\(find)」—— 不自证的话后面「判据仍绿」会被误读成判据失效",
                sourceLocation: sourceLocation)
        try mutated.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("`#270` 扩根实证：新 target 里未登记的 public 类型，多根下判红、单根下完全不红")
    func multiRootCatchesUnregisteredTypeInNewTarget() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }

        let probe = "ZZUnregisteredProbeView"
        let probeSource = """
        import SwiftUI

        /// 变异用的合成类型：形态与 `Shine` / `GlowSweep` 等同款（`public struct: View`），
        /// 唯一的区别是**登记表里没有它**。
        public struct \(probe): View {
            public init() {}
            public var body: some View { Color.clear }
        }
        """
        try probeSource.write(
            to: root.appendingPathComponent("CoreDesignEffects/ZZUnregisteredProbe.swift"),
            atomically: true, encoding: .utf8
        )

        let entries = try ComponentRegistryGuard.loadRegistry()
        let registered = Set(entries.filter { $0.repo == "coredesign" }.map(\.component))
            .subtracting(ComponentRegistryGuard.knownOffScannerComponents)

        let multiRoot = try ComponentRegistryGuard.scanTypes(roots: self.copiedRoots(in: root))
        let multi = compareRegistryToScan(scanned: multiRoot.components, registered: registered)
        #expect(multi.missing == [probe],
                "多根扫描下未登记类型没有被判成缺失，实际缺失集合：\(multi.missing.sorted())")
        #expect(multi.ghosts.isEmpty, "多根扫描下出现了幽灵条目：\(multi.ghosts.sorted())")

        let singleRoot = try ComponentRegistryGuard.scanTypes(
            root: root.appendingPathComponent(GuardScanRoots.primaryTargetName)
        )
        let single = compareRegistryToScan(scanned: singleRoot.components, registered: registered)
        #expect(!single.missing.contains(probe),
                "单根扫描竟然看到了 CoreDesignEffects 里的类型 —— 前后对照失效，本条证明不了任何事")
        #expect(single.missing.isEmpty, """
        单根扫描下的缺失集合本应为空（旧判据看不见 Sources/CoreDesignEffects），实际 \(single.missing.sorted())。
        """)

        let afterRegistering = compareRegistryToScan(
            scanned: multiRoot.components, registered: registered.union([probe])
        )
        #expect(afterRegistering.missing.isEmpty,
                "补登记后仍判缺失：\(afterRegistering.missing.sorted())")
        #expect(afterRegistering.ghosts.isEmpty,
                "补登记后出现幽灵条目：\(afterRegistering.ghosts.sorted())")
    }

    @Test("端到端：副本未变异时，三条判据的结果与真实源码一致（基线）")
    func copiedTreeReproducesBaseline() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        let entries = try ComponentRegistryGuard.loadRegistry()
        let copied = try scanComponentJudgeInputs(roots: self.copiedRoots(in: root))
        let real = try ComponentJudgeSources.scan()

        #expect(copied.bareTextKeys == real.bareTextKeys, "副本与真实源码的裸文本参数集合不一致 —— 拷贝有问题")
        #expect(copied.styleProtocolNames == real.styleProtocolNames)
        #expect(copied.typeDeclFiles == real.typeDeclFiles, """
        副本与真实源码的**类型声明文件键**不一致 —— 要么拷贝出了问题，要么根内相对路径的
        推导又被路径分叉污染了（`#311`）。上面两条比的是符号键，看不见这一味。
        """)
        #expect(Set(judgeExtensionPoints(entries: entries, scan: copied).missing)
                == ComponentExtensionPointGuard.knownMissingExtensionPoints,
                "副本的 J-2 缺口与真实红名单不一致 —— 拷贝有问题，或红名单没同步")
        #expect(judgeNativeProtocolPurity(entries: entries, scan: copied).violations.isEmpty)
        #expect(Set(judgeTextParamCoverage(
            entries: entries, scan: copied, ownerAliases: ComponentTextParamGuard.ownerAliases
        ).violations) == ComponentTextParamGuard.knownUnregisteredSymbolParams)
    }

    @Test("端到端 J-2 变异：把 BannerStyle 协议声明改名 ⇒ Banner 判缺扩展点")
    func j2EndToEndMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public protocol BannerStyle {", replace: "public protocol BannerAppearanceContract {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeExtensionPoints(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        #expect(Set(result.missing) == ComponentExtensionPointGuard.knownMissingExtensionPoints.union(["Banner"]),
                "登记表说 Banner 的扩展点是 BannerStyle，源码里没有这个协议声明了 ⇒ 必须判红")
        #expect(result.diagnostics.contains { $0.contains("Banner：") && $0.contains("无该协议声明") })
    }

    @Test("端到端 J-2 变异：删掉 BannerStyle 的全部实现 ⇒ Banner 判缺扩展点（『定义 + 使用』的使用侧）")
    func j2EndToEndMutationImplementationsRemoved() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public struct PlainBannerStyle: BannerStyle {", replace: "public struct PlainBannerStyle {"
        )
        try self.applyMutation(
            root: root, relativePath: "Components/Banner/Banner.swift",
            find: "public struct BorderedBannerStyle: BannerStyle {", replace: "public struct BorderedBannerStyle {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeExtensionPoints(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        #expect(Set(result.missing) == ComponentExtensionPointGuard.knownMissingExtensionPoints.union(["Banner"]))
        #expect(result.diagnostics.contains { $0.contains("Banner：") && $0.contains("无实现类型") },
                "只查协议声明、不查实现的话，把两个 style 实现删光判据照绿 —— AC 原文是『定义 + 使用』")
    }

    @Test("端到端 J-3 变异（通道 i）：往 ProgressIndicator.swift 塞一个自有样式协议 ⇒ 判红")
    func j3EndToEndMutationDeclarationChannel() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
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
        let result = judgeNativeProtocolPurity(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        #expect(result.violations.map(\.symbol) == ["ProgressIndicatorStyle"])
        #expect(result.violations.map(\.channel) == ["作用域内声明"])
        #expect(result.violations.map(\.component) == ["ProgressIndicator"])
    }

    @Test("端到端 J-3 变异（通道 ii）：让 ProgressIndicator 采纳 BannerStyle ⇒ 判红")
    func j3EndToEndMutationConformanceChannel() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/ProgressIndicator/ProgressIndicator.swift",
            find: "public struct ProgressIndicator: View {",
            replace: "extension ProgressIndicator: BannerStyle {}\n\npublic struct ProgressIndicator: View {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeNativeProtocolPurity(entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)))
        #expect(result.violations.map(\.symbol) == ["BannerStyle"])
        #expect(result.violations.map(\.channel) == ["组件采纳"])
    }

    @Test("端到端 FR-4 变异：给 Avatar 加一个未登记的裸 String 参数 ⇒ 判红；补登记 ⇒ 转绿")
    func fr4EndToEndMutation() throws {
        let root = try self.copySources()
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Avatar/Avatar.swift",
            find: "public init(name: String) {", replace: "public init(name: String, caption: String) {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try scanComponentJudgeInputs(roots: self.copiedRoots(in: root))

        let red = judgeTextParamCoverage(
            entries: entries, scan: scan, ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(Set(red.violations) ==
                ComponentTextParamGuard.knownUnregisteredSymbolParams.union(["Avatar.init#caption"]),
                "新增未登记的裸 String 参数必须判红，且违规集合精确")

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
        defer { try? FileManager.default.removeItem(at: root) }
        try self.applyMutation(
            root: root, relativePath: "Components/Avatar/Avatar.swift",
            find: "public init(name: String) {", replace: "public init(displayName: String) {"
        )
        let entries = try ComponentRegistryGuard.loadRegistry()
        let result = judgeTextParamCoverage(
            entries: entries, scan: try scanComponentJudgeInputs(roots: self.copiedRoots(in: root)),
            ownerAliases: ComponentTextParamGuard.ownerAliases
        )
        #expect(result.ghostRegistryParams == ["Avatar.name"],
                "反向差集必须抓到『登记表有、源码没有』—— 这是参数被改写成扫描器看不见的形态时的第二道防线")
        #expect(result.violations.contains("Avatar.init#displayName"))
    }
}
