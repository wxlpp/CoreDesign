import Foundation
import SwiftParser
import SwiftSyntax
import Testing

/// **纯函数**（终审 M2）：登记表条目名集合 vs 扫描器采集到的类型名集合的双向差集。
/// 抽成自由函数是为了能用**合成输入**写常驻单元测试（见
/// `ComponentRegistryCompareTests.swift`），证伪两个方向（漏登记 / 幽灵条目）不必再
/// 依赖真的改动 `docs/component-registry.json` 或真的从源码里挪走一个类型——此前
/// M1/S1 的变异证据是两个 gitignored 一次性脚本产出的 transcript，不可复现、也不在
/// CI 里常驻跑。
func compareRegistryToScan(scanned: Set<String>, registered: Set<String>) -> (missing: Set<String>, ghosts: Set<String>) {
    (missing: scanned.subtracting(registered), ghosts: registered.subtracting(scanned))
}

// 组件登记表的守卫。
//
// ⚠️ **登记单位是「public 类型」，不是「文档索引行」**：公约约束的是类型的 API 形状,
// J-2/J-3 也在类型上跑；而 docs/README.md 一行可能是三个类型
// （`Skeleton（SkeletonLine / SkeletonRect / SkeletonCircle）`），判据没法在「行」上跑。
//
// ⚠️ **本守卫只覆盖 CoreDesign 侧**（裁决 D2）。StoryUI 侧的源码↔登记表比对移交 #43
// —— CI 三个 job 都只 checkout 本仓，读另一个（私有）仓会让本仓 CI 永久红。
// 登记表**仍收全两仓**，只是 StoryUI 侧的条目在 #43 落地前无机器拦截。
//
// ⚠️ **终审 C1 第 3 点——README 索引 ↔ 登记表对账，一次性人工核对，非机器判据**：
// `docs/README.md` 的组件索引表共 **37 行**（不含表头/分隔行，`grep -n "^|" docs/README.md`
// 数出的真实数据行）。逐行核对去向：
//   - **35 行本有归宿**：直接对应 `component-registry.json` 条目（含一行映射多条目的情形，
//     如 `Skeleton（SkeletonLine / SkeletonRect / SkeletonCircle）` 对应 4 条）、或对应
//     `ScanResult.styleImpls`（`FloatButton（...ButtonStyle）` 的括注部分、`.core` Control
//     Styles 一行，均为 AD-3 裁决「style 实现不是登记表条目」覆盖）、或是墓碑行
//     （`~~Typography~~`／`~~EmptyState~~`／`~~ProgressBar~~`，源码已删或已弃用，`ProgressBar`
//     以 `kind: excluded` 登记，另两个源码不存在不需要登记）、或是显式排除（`FlowLayout`，
//     裁决 D1：Layout 不是组件）。
//   - **2 行漏网**：`BottomInputBar`（`:23`）与 `Toast`（`:78`）——README 已索引、未弃用、
//     有真实 public API 表面，但完整性判据结构上抓不到（见下方 `PublicTypeCollector`
//     的「第四个盲区」文档）。已在本次终审处置：`Toast` 补登记表 + 加入
//     `knownOffScannerComponents` 白名单；`BottomInputBar` 定性为排除，写死进
//     `docs/component-contract.md` AD-2 与 oh-my-story 的 `38-plan.md` 排除清单。
// ⇒ 处置后：37 = 37 有归宿，0 漏网。
//
// ⚠️ **为什么这里只留comment，不加机器判据**：理想判据是「README 索引行数 vs 登记表 +
// styleImpls + 显式排除清单，差额必须逐条有归宿」，但 README 表格里一行可能编码 0～4 个
// 登记表条目（纯 style 括注、多类型合并、墓碑行、真实排除）,把这条规则写成不脆弱的解析器
// 成本明显高于本次 C1 的最小必要修复——一个只匹配「行数」的断言挡不住新增行本身编码错误
// 类别（例如把新组件写成墓碑格式），反而可能造成误导性的绿。本次选择**把这次人工对账的
// 结论留痕在此**，下次新增 README 行时人工核对本注释是否需要更新（`swift test` 不会替你
// 检查这件事——这是本条判据的已知局限，不是假装成机器判据）。
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

    /// `decidedBy` ⇒ `kind` 的强制映射（公约 `docs/component-contract.md:82-83`
    /// 「tiebreaker ⇒ prescriptive」、步骤 3 ⇒ 规定性、步骤 1/2 ⇒ 语义、祖父条款
    /// （`precedent`）⇒ semantic）。⚠️ 终审 M1：`38.md:66` 点名「AC 要求而守卫不查
    /// ⇒ #30 的病型复刻」，本表把它落成机器判据。`exclusion` 不进本表——它对应
    /// `kind: excluded`，已由下面 `registrySchemaIsValid` 里
    /// `(e.kind == "excluded") == (e.decidedBy == "exclusion")` 单独断言，不需要
    /// 在这张「decidedBy ⇒ kind」表里重复描述同一件事。
    static let expectedKindForDecidedBy: [String: String] = [
        "step1": "semantic",
        "step2": "semantic",
        "step3": "prescriptive",
        "tiebreaker": "prescriptive",
        "precedent": "semantic",
    ]

    /// ⚠️ 已知扫描器盲区白名单（终审 C1 第 3/4 点）：这些登记表条目有真实的 public
    /// API 表面，但不是 `public struct: View/ViewModifier`，`PublicTypeCollector`
    /// **结构上**看不到它们（不是没扫到，是根本不采集这一类声明）——见下方
    /// `PublicTypeCollector` 类文档的盲区分类。若不豁免，它们会被
    /// `registryCoversCoreDesignTypes` 的双向差集误判为「幽灵条目」。
    ///
    /// - `Toast`：public 表面由 `ToastHost`（public **class**）+ `ToastItem`
    ///   （public struct，不含 `View` 一致性）+ `ToastDefaults`（public **enum**）
    ///   三者组成，没有一个是 `public struct: View`。
    ///
    /// ⚠️ **这张表本身是负债，不是解法**：条目数增长就是「盲区扩大」的信号——新条目
    /// 落进来时，先问「能不能扩展扫描器结构性识别它」，答不出来才加白名单占位。
    /// 现状只有 `Toast` 一条；`BottomInputBar` 同样没有 public 表面类型（详见
    /// `docs/component-contract.md` AD-2 裁决），但走的是**排除**而非登记，因此不
    /// 出现在这里——排除的条目本来就不该在 `component-registry.json` 里有条目，
    /// 无需白名单豁免。
    static let knownOffScannerComponents: Set<String> = ["Toast"]

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

        // ⚠️ **重名检查**（评审 Suggestion 2）：Task 2 的完整性判据做的是登记表条目名与
        // 扫描器名单的双向差集——重名条目会让「同一个名字出现两次」在差集运算里被吞掉
        // （差集看的是 Set，不看基数），现在两条同名条目全绿，必须在这里单独拦。
        #expect(Set(entries.map(\.component)).count == entries.count,
                "登记表存在重名 component 条目——差集判据会把重名静默吞掉")

        // ⚠️ 终审 I4：此前 CoreDesign 侧靠双向差集钉住条目数，StoryUI 侧因裁决 D2
        // 无法做源码比对，只 `print` 不 `#expect`——StoryUI 那一半删光 25 条仍然全绿。
        // 加固定计数断言作为回归钉子：#43 落地跨仓源码比对前，这是唯一挡「静默删条目」
        // 的机器判据。数字是本次终审实测值（45 + 25 = 70，含终审 C1 新增的 `Toast`
        // 条目——补录前是 44 + 25 = 69），#43 落地后若改用源码比对判据，可以放宽/
        // 移除本断言。
        #expect(entries.filter { $0.repo == "coredesign" }.count == 45,
                "CoreDesign 侧条目数不是 45——若为新增属预期变化请同步改这个数字；若无源码变更条目却变了，是静默删条目/改 repo 的信号")
        #expect(entries.filter { $0.repo == "storyui" }.count == 25,
                "StoryUI 侧条目数不是 25——CI 无法跨仓核对源码，这条固定计数断言是 #43 落地前唯一挡「静默删条目」的机器判据，不得放宽为 print")

        // ⚠️ 终审 M1：`decidedBy` ⇒ `kind` 的映射公约 `:82-83` 已经写死
        // （tiebreaker ⇒ prescriptive、step1/2 ⇒ semantic、step3 ⇒ prescriptive、
        // precedent ⇒ semantic），但此前守卫没查——`38.md:66` 点名的正是这类
        // 「AC 要求而守卫不查」的 #30 病型复刻。当前 70 条全部满足，补上零成本。
        for e in entries where e.decidedBy != "exclusion" {
            if let expected = Self.expectedKindForDecidedBy[e.decidedBy] {
                #expect(e.kind == expected,
                        "\(e.component)：decidedBy=\(e.decidedBy) 按公约必须 kind=\(expected)，实际是 \(e.kind)")
            }
        }

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
            // ⚠️ 评审 Suggestion 3：现有断言只反向核对了 prescriptive/excluded ⇒
            // !needsExtensionPoint，没断言正向的 semantic ⇒ needsExtensionPoint。
            if e.kind == "semantic" {
                #expect(e.needsExtensionPoint, "\(e.component) 判为 semantic 却不给扩展点 —— 自相矛盾")
            }
            // ⚠️ 评审 Suggestion 3：decidedBy 与对应协议字段的隐式不变量——step1 走的是
            // 判定法步骤 1「有原生协议」分支，precedent 走的是祖父条款「已发布自有协议」,
            // 两者各自的协议字段不能是 nil，否则条目自己都说不清自己是怎么判出来的。
            if e.decidedBy == "step1" {
                #expect(e.nativeProtocol != nil, "\(e.component) decidedBy=step1 却没填 nativeProtocol")
            }
            if e.decidedBy == "precedent" {
                #expect(e.customStyleProtocol != nil, "\(e.component) decidedBy=precedent 却没填 customStyleProtocol")
            }
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

    @Test("CoreDesign 侧：登记表覆盖全部组件类型，且无幽灵条目")
    func registryCoversCoreDesignTypes() throws {
        let entries = try Self.loadRegistry()
        let scanned = try Self.scanTypes(root: Self.coreDesignSources).components
        #expect(scanned.count > 15, "只扫到 \(scanned.count) 个类型 —— 扫描器失效")   // 与 Task 1 自检同下界

        // ⚠️ **分仓比对**（AC 原文要求「分 repo 计数吻合」）：合并成一个 Set 后
        // 查不出「登记在错误 repo 下」，两仓同名类型还会静默合并。
        //
        // ⚠️ 终审 C1：先减去 `knownOffScannerComponents` 白名单——这些条目的 public
        // 表面结构上不是 `public struct: View/ViewModifier`，永远不会出现在
        // `scanned` 里，不减去就会被下面的双向差集永久判成幽灵条目。
        let registered = Set(entries.filter { $0.repo == "coredesign" }.map(\.component))
            .subtracting(Self.knownOffScannerComponents)

        // ⚠️ **双向**：单向只能抓「登记表多写了」，抓不到「源码新增了组件而没登记」
        //（后者正是本判据存在的理由）。用抽出的纯函数 `compareRegistryToScan`（M2），
        // 逻辑与单元测试（`ComponentRegistryCompareTests.swift`）共用同一份实现。
        let diff = compareRegistryToScan(scanned: scanned, registered: registered)
        #expect(diff.missing.isEmpty,
                "这些 CoreDesign 类型在源码里但登记表没有：\(diff.missing.sorted())")
        #expect(diff.ghosts.isEmpty,
                "登记表有幽灵条目（CoreDesign 源码里找不到）：\(diff.ghosts.sorted())")

        // ⚠️ **StoryUI 侧的缺口要显式报告，不能静默当作「通过」**（裁决 D2）。
        let n = entries.filter { $0.repo == "storyui" }.count
        print("⚠️ StoryUI 侧 \(n) 条未做源码比对——CI 只 checkout 本仓；「源码新增组件而没登记」在 #43 落地前无机器拦截。")
    }
}

/// 收 public struct，**分类**放进 components / styleImpls。
///
/// ⚠️ **第三个盲区（评审 Suggestion 1，未做机器拦截，留痕即可）**：本类只覆写了
/// `visit(_ node: StructDeclSyntax)`，public **enum / class / actor** 挂
/// `View` / `ViewModifier` / 本清单里任一 Style 协议 conformance 会**整体不可见**——
/// 不进 `components` 也不进 `styleImpls`，扫描器会「成功」返回一个偏小但看起来正常的集合，
/// 与 Step 3 记录的另外两个盲区（extension 挂载的 conformance、`Style` 结尾但未命中协议清单）
/// 性质相同：零命中不代表没有遗漏，只代表「用这一种匹配方式看，没看到」。
/// 评审实测：`grep -rnE "public (enum|class|actor) [A-Za-z]+\s*:[^{]*\b(View|ViewModifier|
/// ButtonStyle|PrimitiveButtonStyle|ToggleStyle|LabelStyle|ProgressViewStyle|
/// DisclosureGroupStyle|LabeledContentStyle)\b" Sources/CoreDesign/` 零命中——当前
/// CoreDesign 全部组件 / style 实现确实都是 `struct`，但这是**现状核对**，不是**结构保证**，
/// 后续新增一个 `enum`/`class`/`actor` 组件会被本扫描器静默漏采。
///
/// ⚠️ **第四个盲区（终审 C1，实锤命中，未做机器拦截）**：公约 AD-2 裁决登记单位是
/// 「有 public 类型的 API 表面」，不是「是不是 `public struct: View`」——但本扫描器
/// 只认后者。真实撞上的两例：
/// - `Toast`（`docs/README.md:78` 索引）：public 表面是 `ToastHost`（**class**）+
///   `ToastItem`（struct，不含 `View` 一致性）+ `ToastDefaults`（**enum**），三者
///   没有一个是 `public struct: View`——本类**完全看不到它们**，`registryCoversCoreDesignTypes`
///   此前的双向差集因此永远不会因为 `Toast` 缺条目而变红（零命中 ⇒ 零缺失 ⇒ 假绿，
///   与本类其余盲区同一种病：看不见不等于没有）。
/// - `BottomInputBar`：`struct BottomInputBar: View` **没有 `public` 修饰符**（只有
///   `public extension View { func bottomInputBar(...) }` 这一层暴露），本类的
///   `visit(_:StructDeclSyntax)` 一开始就 `guard node.modifiers.contains("public")`，
///   同样整体不可见。
///
/// **现状如何处置**：`Toast` 已人工登记进 `component-registry.json`（终审 C1），并把
/// 条目名加进 `ComponentRegistryGuard.knownOffScannerComponents` 白名单，豁免
/// `registryCoversCoreDesignTypes` 的幽灵条目检查（否则一个扫描器永远看不到的名字
/// 会被永久判「幽灵」）。`BottomInputBar` 走另一条路——公约 AD-2 明确排除「连 public
/// 类型都没有的 modifier 写法」，因此**不登记**，改为在 `docs/component-contract.md`
/// AD-2 与 `oh-my-story` 的 `38-plan.md` 排除清单里点名写死，并把它的 6 个 Bool 参数
/// 移交 `39.md` 给 J-1/FR-4 执行者。⚠️ 本注释与上面白名单注释一样是**留痕**，不是
/// **结构修复**——修复需要让 `PublicTypeCollector` 同时认出「public 但非 View/
/// ViewModifier 的类型」，成本明显更高（要重新定义『组件』在语法树上的判据，而不是
/// 加一个 conformance 名字），本次终审判断为超出 C1 的最小必要修复范围，留给后续任务。
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
