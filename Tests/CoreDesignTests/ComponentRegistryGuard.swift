import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// 组件登记表的守卫。
//
// ⚠️ **登记单位是「public 类型」，不是「文档索引行」**：公约约束的是类型的 API 形状,
// J-2/J-3 也在类型上跑；而 docs/README.md 一行可能是三个类型
// （`Skeleton（SkeletonLine / SkeletonRect / SkeletonCircle）`），判据没法在「行」上跑。
//
// ⚠️ **本守卫只覆盖 CoreDesign 侧**（裁决 D2）。StoryUI 侧的源码↔登记表比对移交 #43
// —— CI 三个 job 都只 checkout 本仓，读另一个（私有）仓会让本仓 CI 永久红。
// 登记表**仍收全两仓**，只是 StoryUI 侧的条目在 #43 落地前无机器拦截。
@Suite("组件登记表")
struct ComponentRegistryGuard {

    struct Entry: Codable {
        let component: String
        let repo: String                    // coredesign | storyui
        let kind: String                    // semantic | prescriptive | excluded
        let decidedBy: String               // step1|step2|step3|tiebreaker|precedent|exclusion
        let nativeProtocol: String?         // Apple 原生协议名
        let customStyleProtocol: String?    // 自有协议名
        // ⚠️ 上两者必须分开（裁决 D3）：#40 的 J-3 是「标注了 nativeProtocol 的组件
        // 源码中不得出现自定义样式协议符号」—— 一字段两用会让 SegmentedControl
        // 被自己的协议判红。
        let needsExtensionPoint: Bool
        let textParams: [TextParam]
        let notes: String
    }
    struct TextParam: Codable { let name: String; let category: String }  // A|B|C|by-type

    static let validKinds: Set<String> = ["semantic", "prescriptive", "excluded"]
    static let validDecidedBy: Set<String> = [
        "step1", "step2", "step3", "tiebreaker", "precedent",
        "exclusion",   // ⚠️ 弃用条款先于步骤 1–4，AC 的五个取值没有一个对应它
    ]
    static let validCategories: Set<String> = ["A", "B", "C", "by-type"]
    static let validRepos: Set<String> = ["coredesign", "storyui"]

    /// ⚠️ 用 `#filePath` 推导，worktree 与主仓两种布局下都稳（上三级到仓库根）。
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    static var coreDesignSources: URL { repoRoot.appendingPathComponent("Sources/CoreDesign") }
    static var registryURL: URL { repoRoot.appendingPathComponent("docs/component-registry.json") }

    static func loadRegistry() throws -> [Entry] {
        try JSONDecoder().decode([Entry].self, from: Data(contentsOf: registryURL))
    }

    /// ⚠️ **分类返回**（裁决 D1）：Style 实现**不是**登记表条目。
    /// 混在一个 Set 里会让完整性判据的双向差集**永久非空**。
    struct ScanResult { var components: Set<String> = []; var styleImpls: Set<String> = [] }

    /// ⚠️ **必须先断言路径存在**：`FileManager.enumerator(at:)` 对不存在的路径
    /// **静默产出空序列** ⇒「零类型 ⇒ 零缺失 ⇒ 绿」会静默通过。
    static func scanTypes(root: URL) throws -> ScanResult {
        guard FileManager.default.fileExists(atPath: root.path) else {
            Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
            return ScanResult()
        }
        var result = ScanResult()
        for case let url as URL in FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
            // ⚠️ **解析保真检查**：parser major 与工具链不配套时会静默产出 error node
            // ⇒ 类型被漏采，而扫描器照样「成功」返回一个偏小的集合。
            if tree.hasError {
                Issue.record("解析出错：\(url.lastPathComponent) —— swift-syntax major 可能与工具链不配套")
            }
            let c = PublicTypeCollector()
            c.walk(tree)
            result.components.formUnion(c.components)
            result.styleImpls.formUnion(c.styleImpls)
        }
        return result
    }

    @Test("登记表每条含全部必需字段，且取值在允许域内")
    func registrySchemaIsValid() throws {
        let entries = try Self.loadRegistry()
        // ⚠️ 非空断言：零条目会让下面所有断言静默通过。
        #expect(entries.count >= 4, "登记表只有 \(entries.count) 条 —— 疑似没读到或是空壳")

        for e in entries {
            #expect(Self.validKinds.contains(e.kind), "\(e.component) kind=\(e.kind) 不在允许域")
            #expect(Self.validDecidedBy.contains(e.decidedBy), "\(e.component) decidedBy=\(e.decidedBy) 不在允许域")
            #expect(Self.validRepos.contains(e.repo), "\(e.component) repo=\(e.repo) 不在允许域")
            for tp in e.textParams {
                #expect(Self.validCategories.contains(tp.category),
                        "\(e.component).\(tp.name) category=\(tp.category) 不在允许域")
            }
            #expect(e.notes.count >= 10, "\(e.component) 的 notes 只有 \(e.notes.count) 字符，像占位")
            if e.kind == "prescriptive" {
                #expect(!e.needsExtensionPoint, "\(e.component) 判为 prescriptive 却要扩展点 —— 自相矛盾")
            }
            if e.kind == "excluded" {
                #expect(!e.needsExtensionPoint, "\(e.component) 已弃用却要扩展点 —— 自相矛盾")
            }
            #expect((e.kind == "excluded") == (e.decidedBy == "exclusion"),
                    "\(e.component)：kind=excluded 与 decidedBy=exclusion 必须同时成立")
            #expect(!(e.nativeProtocol != nil && e.customStyleProtocol != nil),
                    "\(e.component) 同时标了原生协议与自有协议 —— 正是 J-3 要禁的形态")
        }
    }

    @Test("扫描器真的扫到了 CoreDesign 的类型")
    func scannerFindsCoreDesignTypes() throws {
        let r = try Self.scanTypes(root: Self.coreDesignSources)
        // ⚠️ 非空断言先行：扫描器失效时「零类型 ⇒ 零缺失 ⇒ 绿」会静默通过。
        // ⚠️ 下界是**量级**断言，不是精确数 —— 精确数由本次运行给出（见 print）。
        #expect(r.components.count > 15, "只扫到 \(r.components.count) 个组件类型 —— 扫描器失效")
        #expect(r.styleImpls.count > 5, "只扫到 \(r.styleImpls.count) 个 Style 实现 —— 协议清单可能又漏了")
        // ⚠️ 用 print 不用 `Issue.record` —— 后者记录的是 failure，会让测试永远红。
        // ⚠️ **要打名单不只是数**：step1 种子的回填（Step 3b）与 Task 2 的填表都需要名单;
        // 只有数的话执行者得从完整性测试的失败消息里倒推，绕。
        print("组件 \(r.components.count) 个：\(r.components.sorted())")
        print("Style 实现 \(r.styleImpls.count) 个：\(r.styleImpls.sorted())")
    }
}

/// 收 public struct，**分类**放进 components / styleImpls。
private nonisolated final class PublicTypeCollector: SyntaxVisitor {
    var components: Set<String> = []
    var styleImpls: Set<String> = []

    /// ⚠️ **手拼清单是 C6 的病根**：第一版漏了 `PrimitiveButtonStyle`，而
    /// `CoreBorderlessButtonStyle.swift:62` 就是它 —— **用错的清单量出来的数本身就是错的**。
    /// 清单外还有 `TextFieldStyle` / `GaugeStyle` / `MenuStyle` 等 ⇒ 见 Step 3 的盲区核对。
    private static let styleProtocols: Set<String> = [
        "ButtonStyle", "PrimitiveButtonStyle", "ToggleStyle", "LabelStyle",
        "ProgressViewStyle", "DisclosureGroupStyle", "LabeledContentStyle",
    ]
    /// 显式排除（裁决 D1）：Layout / Shape 不是组件。
    private static let excluded: Set<String> = ["Layout", "Shape", "InsettableShape"]

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        for clause in node.clauses where clause.elements != nil { walk(clause.elements!) }
        return .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        guard node.modifiers.contains(where: { $0.name.text == "public" }) else { return .visitChildren }
        guard !name.hasSuffix("Demo"), !name.hasSuffix("Preview"), !name.hasSuffix("PreviewHost")
        else { return .visitChildren }

        // 取最后一段：容忍 `SwiftUI.View` 这类限定名。
        let inherited = (node.inheritanceClause?.inheritedTypes ?? [])
            .map { $0.type.trimmedDescription.split(separator: ".").last.map(String.init) ?? "" }

        if inherited.contains(where: { Self.excluded.contains($0) }) { return .visitChildren }
        if inherited.contains(where: { Self.styleProtocols.contains($0) }) {
            styleImpls.insert(name)
        } else if inherited.contains("View") || inherited.contains("ViewModifier") {
            components.insert(name)
        }
        return .visitChildren
    }
}
