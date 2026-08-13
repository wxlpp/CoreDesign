import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// J-1（public 声明不得含未豁免的 Bool 参数）+ 豁免基线 + 棘轮的守卫。
//
// ⚠️ **判据实现选型已在 `39-plan.md` 钉死：SwiftSyntax，不用 `swift symbolgraph-extract`。**
// 否决 symbolgraph 的理由**不是它不可用**（它可用，且给到参数级粒度、精确命中了
// `SolidButtonStyle.init(role:glass:)`），**是它的范围错**：它出的是「模块的完整 public
// 符号表面（含从 SwiftUI 协议扩展继承来的成员）」，而 J-1 要的是「本仓源码里写下的声明」。
// 实测：`surface(_:bordered:)` 在符号图里出现 **42 次**（每个 CoreDesign 类型各继承一份），
// 源码里只定义 **1 次**；`AsyncButton/alert(_:isPresented:)` 这种 **SwiftUI 自己的 API**
// 也被算进来，「带 Bool 参数的 public 符号」总计 **6373 个**。⇒ J-1 会淹在假阳性里，
// 或需要一张巨大的 SwiftUI 白名单——而白名单在本 epic 已被定性为负债
// （见 `ComponentRegistryGuard.knownOffScannerComponents` 的文档注释）。
//
// ⚠️ **豁免基线设计为两份文件**（`39-plan.md` 选型 2）：`docs/bool-exemptions.json` 是清单
// 本身，Task 4 已消费它；`docs/bool-exemptions-baseline.json` 只记一个上限，
// 已随 Task 5 落地——`baselineRatchetHoldsExactly` 判据读取它并与清单条目数严格相等比对。
// 一份文件时「改清单」与「改基线」是**同一个动作**，棘轮的唯一实现只能是
// 「diff `main` 的历史版本」，而本仓 CI 是 `actions/checkout@v4` 默认
// `fetch-depth: 1`（历史里没有 `main`），且五个 CoreDesign 任务集成在
// `epic/component-contract`、`main` 上在 #42 之前根本没有这个文件
// ⇒ 那条路要么永久红、要么退化成「文件读不到 ⇒ 绿」。详见 `39-plan.md`。
//
// ⚠️ **`decidedBy` 在本文件里指「裁决人」，与 `ComponentRegistryGuard.Entry.decidedBy`
// （指判定法的哪一步）同名不同义**——两个是彼此独立的 schema，不受公约第 4 节末尾
// 「判定法枚举的三方同步义务」约束（那条通则的范围明写为 `kind` / `decidedBy` /
// `textParams[].category` 三个**登记表**字段）。此处点名，免得后人以为要同步。
@Suite("Bool 豁免基线与棘轮")
struct BoolExemptionGuard {

    // MARK: - 路径

    /// ⚠️ 用 `#filePath` 推导，worktree 与主仓两种布局下都稳（上三级到仓库根）。
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    static var coreDesignSources: URL { repoRoot.appendingPathComponent("Sources/CoreDesign") }
    static var exemptionsURL: URL { repoRoot.appendingPathComponent("docs/bool-exemptions.json") }
    static var baselineURL: URL { repoRoot.appendingPathComponent("docs/bool-exemptions-baseline.json") }

    // MARK: - 扫描缓存

    /// ⚠️ **只缓存「成功且非空」的结果**（#38 同款约束）：`scanBoolParams` 的三条失败路径
    /// （路径不存在 / 无法枚举 / 解析出错）都会产出空集。若把空集也缓存下来，第一条判据
    /// 吃到失败、后几条却拿着缓存里的空集算差集 ⇒「零命中 ⇒ 零违规 ⇒ **绿**」。
    /// ⇒ 空结果不入缓存，让后续判据**重新扫、重新失败**，每条各自报出自己的诊断。
    /// 本仓 `.defaultIsolation(MainActor.self)` ⇒ 测试串行，这个可变静态量不需要额外同步。
    private static var cachedScan: BoolScanResult?

    /// 本 suite 的**唯一**扫描入口，不要直接调 `scanBoolParams(root:)`。
    static func boolScan() throws -> BoolScanResult {
        if let cached = Self.cachedScan { return cached }
        let result = try scanBoolParams(root: Self.coreDesignSources)
        if !result.hits.isEmpty { Self.cachedScan = result }
        return result
    }

    // MARK: - 判据体系之外的参照物

    /// **公约与 PRD 白纸黑字点名的 14 个参数**，是本判据的**外部参照物**。
    ///
    /// ⚠️ **为什么必须有它**：变异证伪只能证「判据对它**看得见**的东西有效」，
    /// 证不了「它看得见的**够不够**」——#38 就是靠 `docs/README.md` 索引这个判据体系
    /// **之外**的清单，才发现 `Toast` / `BottomInputBar` 两行漏网。这里扮演同一角色的是
    /// **人写的规范文本**：前 12 条来自 `39.md` Technical Details 的「已知违规实例」
    /// （PRD 原文 10 条 + `SolidButtonStyle(glass:)` / `LightButtonStyle(glass:)`），
    /// 后 2 条来自公约本身（附录 A.3 的 `surface(bordered:)`、第 3 节例外条款点名的
    /// `SegmentedControlStyleConfiguration.Segment.isSelected`）。
    /// 扫描器的匹配逻辑一旦被改窄（比如漏了 `public extension` 这条路径），这些名字会
    /// 掉出来，判据立刻红。
    ///
    /// ⚠️ **PRD 写的 `Sidebar(showsChevron:)` 实际落在 `SidebarSection` 上**
    /// ——`Sidebar` 是 `docs/README.md` 的行名，不是类型名（登记表按六个子类型分别登记,
    /// 没有一条叫 `Sidebar`，见 `ComponentRegistryGuard.knownReadmeContainerPrefixes`）。
    static let contractNamedKeys: Set<String> = [
        "Badge.init#outlined",
        "Card.init#bordered",
        "SidebarSection.init#showsChevron",
        "Tag.init#removable",
        "Rating.init#allowsHalfStar",
        "Rating.init#isReadOnly",
        "PinCode.init#isSecure",
        "Skeleton.init#isLoading",
        "Carousel.init#autoAdvance",
        "TagInput.init#allowDuplicates",
        "SolidButtonStyle.init#glass",
        "LightButtonStyle.init#glass",
        "View.surface#bordered",
        "SegmentedControlStyleConfiguration.Segment.init#isSelected",
    ]

    /// **公约 A.3 已裁决、但按 39.md 的 AC 刻意不放进豁免清单的违规**。
    ///
    /// ⚠️ **这不是第二份豁免清单**：豁免清单说「这是可接受的 API」，本集合说
    /// 「这是一条**已知违规**，处置人是 #41，数量不许涨」。它只有一个成员、写死在
    /// 测试代码里、**不占 `maxEntries` 的格子、不受棘轮保护**，也不打算受——
    /// 它存在的唯一理由是让 `j1NoUnexemptedBoolParameters` 里那条 `withKnownIssue`
    /// **不掩盖新出现的违规**（`withKnownIssue` 会把块内**任何** issue 都算成已知，
    /// 所以「新违规」必须走**块外**的这条 canary，见 `39-plan.md` 的三种未来表）。
    ///
    /// ⚠️ **它会自我到期，且有两道**：#41 删掉或改造 `surface(bordered:)` 之后，
    /// (1) `j1NoUnexemptedBoolParameters` 的 `withKnownIssue` 块内不再记录到 issue
    /// ⇒ Swift Testing 判「Known issue was not recorded」⇒ **主判据自己红**；
    /// (2) `j1ViolationSetIsExactlyTheContractPending` 的 `disappeared` 断言也红。
    /// 两道都逼 #41 同轮清掉这个常量。⚠️ 第 (1) 道在「新违规与 #41 改造**同时**发生」
    /// 时会失效（块内仍有 issue），所以第 (2) 道不能省。
    static let pendingViolationKeys: Set<String> = ["View.surface#bordered"]

    // MARK: - 与 #38 登记表的交叉核对（39.md 最后一条 AC 的收窄落地）

    /// 一个豁免宿主为什么不可能有 `component-registry.json` 条目。
    enum OwnerExclusionKind: Sendable {
        /// 扩展的是 SwiftUI / 外部协议，本仓根本没有该类型的声明（`View` / `ButtonStyle`）。
        /// ⚠️ **Task 8 S-1**：这句「根本没有该类型的声明」由 `declaredTypeNames()` 核对，
        /// 而它**不采集 `typealias`**（`DeclaredTypeNameCollector` 只访问
        /// `struct`/`class`/`enum`/`protocol`/`actor`）——若本仓出现
        /// `typealias View = ...` 这类遮蔽声明，本条判据看不见，「根本没有」这句话
        /// 会略宽于实际核对范围。当前 `grep -rn "typealias View\b\|typealias ButtonStyle\b"`
        /// 零命中，不构成现存漏洞，留痕供未来审阅。
        case externalProtocolExtension
        /// style **实现**——按公约 AD-3 不是登记表条目。
        case styleImplementation
        /// 有 public 类型但不是 `View`/`ViewModifier`，且不是 `docs/README.md` 组件索引的行名
        /// ——按公约 AD-2 终审 I4 的**复合条件**不登记。
        case nonViewPublicType
    }

    /// ⚠️ **39.md 最后一条 AC 与公约 AD-2 的张力，处置见 `39-plan.md`「AC 最后一条与 AD-2」**。
    ///
    /// AC 原文要求「豁免清单里的每个参数名能在 component-registry.json 对应组件的记录里
    /// 找到出处」。实测把 34 条豁免的宿主逐个查过 45 条 coredesign 条目后，**7 个宿主
    /// 根本不可能有条目**，且各有各的 AD 依据（任务书只点了 `BottomInputBar` 一例,
    /// 实际范围宽得多——凡是自由函数与非组件 public 类型都落在外面）。
    ///
    /// ⇒ **收窄**：登记表交叉核对只适用于「宿主本来就该在登记表里」的那部分；
    /// 其余必须在本台账里显式列出并给出 AD 依据。
    /// ⇒ **补强**：AC 的原意（「不许凭空捏造出处」）改由一条**更强**的判据保证——
    /// 豁免键不是人写的自由文本，是**扫描器产出**的 `Owner.decl#param`，
    /// `j1NoUnexemptedBoolParameters` 的双向差集让「清单里出现源码里不存在的参数」直接判红。
    ///
    /// ⚠️ **本台账必须承重，不能是名字白名单**（照抄 #38 把 `knownStyleAnnotationRows`
    /// 从名字集合升级成映射的教训：升级前把 `Components/Style/` 整个删掉判据照样绿）。
    /// 下面 `exemptionOwnersReconcileWithRegistry` 对三种分类各自绑定了一条真实核对。
    static let ownersWithoutRegistryEntry: [String: OwnerExclusionKind] = [
        "View": .externalProtocolExtension,
        "ButtonStyle": .externalProtocolExtension,
        "SolidButtonStyle": .styleImplementation,
        "LightButtonStyle": .styleImplementation,
        "StepItem": .nonViewPublicType,
        "ButtonRoleStyleRole": .nonViewPublicType,
        "SegmentedControlStyleConfiguration.Segment": .nonViewPublicType,
    ]

    // MARK: - Important-2 (a)：`.externalProtocolExtension` 的正向核对
    //
    // ⚠️ **评审 Important-2**：三种 `OwnerExclusionKind` 里只有 `.styleImplementation`
    // 绑了正向核对（`scan.styleImpls.contains(owner)`）；`.externalProtocolExtension`
    // 与 `.nonViewPublicType` 都只有负向断言（`!scan.components.contains` 等），
    // 互换标签（把 `StepItem` 改标成 `.externalProtocolExtension`，或把 `View` 改标成
    // `.nonViewPublicType`）时两边都能滑过去，两个负向分类之间不可分辨。
    // ⇒ 给 `.externalProtocolExtension` 补一条正向核对，让它真正配得上文档里
    // 「本仓根本没有该类型的声明」这句话——直接扫 `Sources/CoreDesign` 里的**全部**
    // `struct`/`class`/`enum`/`protocol`/`actor` 声明（⚠️ **不限嵌套层级，不止顶层**：
    // 下面的 `DeclaredTypeNameCollector` 对这五种节点统一返回 `.visitChildren`，
    // 会继续递归进类型内部，把嵌套类型也一并采到——这对本条判据的目的是**更安全**而非
    // 缺陷，因为「本仓是否存在同名类型」这个问题本就不该只问顶层；不限访问级别、不限是否
    // 符合某个协议，因为 `View`/`ButtonStyle` 这类外部协议名如果被本仓意外声明成同名类型,
    // 不管它是不是 public、嵌在哪一层，都足以推翻「本仓没有这个类型」这句话），断言宿主名
    // 不在其中。
    //
    // ⚠️ 这条覆盖不了 `.nonViewPublicType` vs `.externalProtocolExtension` 互换的**另一
    // 半**——`StepItem` 改标成 `.externalProtocolExtension` 时，`declaredTypeNames()`
    // 会真的命中 `StepItem`（它确实是本仓声明的 struct）⇒ 这条新断言会红，等价于把
    // 这一半也钉死了。互换的反方向（`View` 改标成 `.nonViewPublicType`）由
    // `.nonViewPublicType` 分支已有的 `!scan.components.contains(root)` 覆盖不到
    // （`View` 本来就不在 `scan.components` 里，那条断言不会红）——这一半仍是本文件
    // 承认的**残余等价性**，未被机器判据钉死，留痕于 `OwnerExclusionKind.nonViewPublicType`
    // 的文档。
    private static var cachedDeclaredTypeNames: Set<String>?

    /// 本仓 `Sources/CoreDesign` 下所有具名类型声明的名字（`struct`/`class`/`enum`/
    /// `protocol`/`actor`，不限访问级别、不限嵌套层级）。⚠️ 缓存约束与 `cachedScan`
    /// 同款：只缓存「成功且非空」的结果，失败路径重新扫、重新报出自己的诊断。
    ///
    /// ⚠️ **Task 8 S-2**：`DeclaredTypeNameCollector` 只存**叶子名**（`node.name.text`），
    /// 不拼点分路径——嵌套类型 `Outer.Inner` 只留下 `"Inner"`。若未来
    /// `ownersWithoutRegistryEntry` 把某个**点分宿主**（如 `Foo.Bar`）标成
    /// `.externalProtocolExtension`，这里的 `declaredTypeNames.contains(owner)` 传入的
    /// 是完整点分字符串 `"Foo.Bar"`，而集合里只有叶子名 `"Bar"`，两者恒不相等
    /// ⇒ 该分类的正向核对会空转恒绿（假阴性）。当前 `ownersWithoutRegistryEntry` 里
    /// 标 `.externalProtocolExtension` 的两个宿主（`View`/`ButtonStyle`）都是顶层单段名，
    /// 不触发；留痕供未来审阅。
    static func declaredTypeNames() throws -> Set<String> {
        if let cached = Self.cachedDeclaredTypeNames { return cached }
        guard FileManager.default.fileExists(atPath: Self.coreDesignSources.path) else {
            Issue.record(
                "源码路径不存在：\(Self.coreDesignSources.path) —— 判据无法工作，这不是「本仓没有该类型」"
            )
            return []
        }
        guard let walker = FileManager.default.enumerator(
            at: Self.coreDesignSources, includingPropertiesForKeys: nil
        ) else {
            Issue.record("无法枚举源码目录：\(Self.coreDesignSources.path)（权限或 IO 异常）—— 判据无法工作")
            return []
        }
        var names: Set<String> = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
            if tree.hasError {
                Issue.record("解析出错：\(url.lastPathComponent) —— swift-syntax major 可能与工具链不配套")
            }
            let collector = DeclaredTypeNameCollector()
            collector.walk(tree)
            names.formUnion(collector.names)
        }
        if !names.isEmpty { Self.cachedDeclaredTypeNames = names }
        return names
    }

    /// 从豁免键 `Owner.decl#param` 里取回宿主名。
    /// `SegmentedControlStyleConfiguration.Segment.init#isSelected` ⇒
    /// `SegmentedControlStyleConfiguration.Segment`（去掉 `#` 之后的参数与最后一段 decl 名）。
    static func owner(ofExemptionKey key: String) -> String {
        let head = key.split(separator: "#").first.map(String.init) ?? key
        var parts = head.split(separator: ".").map(String.init)
        if parts.count > 1 { parts.removeLast() }
        return parts.joined(separator: ".")
    }

    static func exemptedKeys() throws -> Set<String> {
        Set(try Self.loadExemptions().compactMap(\.parameter))
    }

    // MARK: - 豁免清单 schema（J-4 的豁免基线部分）

    /// ⚠️ **四个字段全部声明为可选，是刻意的**：若写成非可选，缺字段会让
    /// `JSONDecoder` 直接 throw，测试以「解码失败」这种笼统形态红掉，报不出
    /// **是哪一条的哪个字段**缺了；AC 要求的是「缺一即红」并指出缺在哪。
    /// ⇒ 解码时全收可选，由下面的判据逐字段断言。
    struct Exemption: Codable {
        let parameter: String?
        let reason: String?
        let decidedBy: String?      // 裁决人（与登记表 Entry.decidedBy 同名不同义，见文件头）
        let decidedOn: String?      // ISO 日期 YYYY-MM-DD
    }

    /// 空话拦截词表（AC：理由为空或仅含「历史遗留」「TODO」这类占位词 → 红）。
    ///
    /// ⚠️ **是「占位符」不是「占位」**：本仓的 `Skeleton` 就是**骨架屏占位**组件，
    /// 它那条豁免的理由里「渲染占位还是内容」是**领域词**不是空话
    /// ——词表写成「占位」会把一条写得很具体的理由误杀。写 plan 时实测撞上过一次，
    /// 收窄到「占位符」。空理由本身由 `reason.count >= 40` 与「必须含『删除』」两条拦。
    static let bannedReasonPhrases: [String] = [
        "历史遗留", "TODO", "TBD", "FIXME", "fixme", "待定", "占位符", "暂无", "见上", "同上",
    ]

    static func loadExemptions() throws -> [Exemption] {
        try JSONDecoder().decode([Exemption].self, from: Data(contentsOf: Self.exemptionsURL))
    }

    // MARK: - 棘轮基线 schema（Task 5）

    /// 棘轮上限。**独立成一份文件**是 #39 的选型裁决（`39-plan.md` 选型 2）：
    ///
    /// 一份文件时，「改清单」与「抬高上限」是**同一个动作**，棘轮的唯一可能实现只剩
    /// 「diff `main` 的历史版本」，而 (1) 本仓 CI 用 `actions/checkout@v4` 默认
    /// `fetch-depth: 1`，历史里没有 `main`；(2) 五个 CoreDesign 任务集成在
    /// `epic/component-contract`，`main` 上在 #42 之前根本没有豁免文件 ⇒ 那条路要么
    /// 永久红、要么退化成「文件读不到 ⇒ 零条目 ⇒ 绿」；(3) 就算 git 可用，清单文件
    /// 会因改措辞、补日期而频繁变动，「上限被抬高」这个**破例动作**混在里面读不出来。
    ///
    /// ⇒ 按规则真正关心的轴切开：**内容**（常改、无害）vs **容量**（罕改、必须署名）。
    /// `git log -p docs/bool-exemptions-baseline.json` 就是完整台账，一条不多一条不少。
    struct Baseline: Codable {
        let maxEntries: Int?
        let raisedBy: String?
        let raisedOn: String?
        let rationale: String?
    }

    static func loadBaseline() throws -> Baseline {
        try JSONDecoder().decode(Baseline.self, from: Data(contentsOf: Self.baselineURL))
    }

    // MARK: - Task 2 的判据

    @Test("扫描器真的扫到了 public Bool 参数，且覆盖公约点名的每一条")
    func scannerFindsPublicBoolParameters() throws {
        let scan = try Self.boolScan()

        // ⚠️ **非空断言先行**：扫描器失效时「零命中 ⇒ 零违规 ⇒ 绿」会静默通过。
        // ⚠️ 下界是**量级**断言，不是精确数——精确数由本次运行给出（见 print）。
        //    AC 要求「至少覆盖 PRD 列出的 10 条 + 2 共 12 条以上」，这里取更宽松的
        //    量级下界 20，真正的判据是下面的参照物子集断言。
        //    **分母必须由真代码定，不由任务书定**（#38 的教训：任务书原估 57、实测 70）。
        #expect(scan.hits.count > 20, "只扫到 \(scan.hits.count) 处 Bool 参数 —— 扫描器失效")
        #expect(scan.keys.count > 20, "只得到 \(scan.keys.count) 个豁免键 —— 扫描器失效")

        // ⚠️ **判据体系之外的参照物**：见 `contractNamedKeys` 的文档。
        let missingNamed = Self.contractNamedKeys.subtracting(scan.keys)
        let namedMessage = """
        公约 / PRD 白纸黑字点名的这些 Bool 参数，扫描器没扫到：\(missingNamed.sorted())
        —— 这是判据体系**之外**的参照物，掉出来说明扫描器的匹配范围被改窄了，
        不是「这些参数不存在了」。若确实是源码删掉了它们（#41 的改造），
        请同轮把对应条目从 contractNamedKeys 里移走，并在 commit message 里说明。
        """
        #expect(missingNamed.isEmpty, "\(namedMessage)")

        // ⚠️ **裁决 (f) 的空断言——这条断言本身就是裁决，不是「顺手核对一下」**：
        // `public typealias Flag = Bool` + `public init(flag: Flag)` 会让参数类型文本
        // 变成 `"Flag"` ⇒ `.notBool` ⇒ **命中、清点、留痕三层同时看不见**，比裁决
        // (b′)/(b″) 更黑。扫描器是纯语法、逐文件的，代不进 alias（完整档要两遍扫描建
        // 跨文件映射，本仓现状不值这个成本）⇒ 走**最小档**：只清点声明侧，并在此断言为空。
        // ⇒ **本仓不得引入含 Bool 的 public typealias，除非同轮把扫描器扩到完整档。**
        // 第一例出现即红、逼人重新裁决——与 `Bool?` 的「先于第一例写死」同款，
        // 零跨文件解析成本。
        // 实测：本仓 `typealias .* = Bool` 零命中（现存四条 typealias 分别是
        // `FlowLayout.Cache = [CGSize]`、`Banner.Label = AnyView` 与两处非 public 的
        // `Configuration`）⇒ 这条断言当前为空，**不改变** 35 键 / 34 条 / maxEntries=34。
        let aliasMessage = """
        发现含 Bool 的 public typealias：\(scan.publicBoolTypeAliases.sorted())
        —— 它会让 `init(flag: Flag)` 这种签名在 J-1 的三层（命中 / 清点 / 留痕）里
        **同时消失**。判据不接受这种形状：要么改回写 `Bool`（照常进豁免清单并抬高
        maxEntries），要么同轮把扫描器扩成两遍扫描的完整档（建 alias 映射后代入分类），
        并在 commit message 里写明为何值得。**不要只把这条断言删掉。**
        """
        #expect(scan.publicBoolTypeAliases.isEmpty, "\(aliasMessage)")

        // ⚠️ 用 print 不用 `Issue.record`——后者记录的是 failure，会让测试永远红。
        // ⚠️ **要打名单不只是数**：Task 3 已照这份名单写好 `bool-exemptions.json`。
        print("【J-1 命中】\(scan.keys.count) 个豁免键 / \(scan.hits.count) 处源码位置：")
        for hit in scan.hits.sorted() { print("  \(hit.key)  ←  \(hit.file):\(hit.line)") }
        print("【裁决 (b) 归类为 .boolCarrying，不判违规】\(scan.carrying.count) 处：")
        for hit in scan.carrying.sorted() { print("  \(hit.key)  ←  \(hit.file):\(hit.line)") }
        print("【裁决 (d) public Bool 属性，只清点不判据】\(scan.publicBoolProperties.count) 处：")
        for name in scan.publicBoolProperties.sorted() { print("  \(name)") }
        print("【裁决 (f) 含 Bool 的 public typealias，必须为 0】\(scan.publicBoolTypeAliases.count) 处：")
        for name in scan.publicBoolTypeAliases.sorted() { print("  \(name)") }
    }

    @Test("J-4：豁免基线存在、可解析、每条四字段齐全且理由不是空话")
    func exemptionBaselineIsWellFormed() throws {
        // ⚠️ **非空断言先行**：文件读不到 ⇒ 零条目 ⇒ 下面每条 for 循环都空转 ⇒ 静默变绿。
        #expect(
            FileManager.default.fileExists(atPath: Self.exemptionsURL.path),
            "豁免基线不存在：\(Self.exemptionsURL.path) —— 判据无法工作，这不是「零豁免」"
        )
        let entries = try Self.loadExemptions()
        #expect(entries.count >= 12,
                "豁免清单只有 \(entries.count) 条 —— AC 要求至少覆盖 PRD 的 10 条 + 两个 glass，疑似没读到或是空壳")

        var seen: Set<String> = []
        for (index, entry) in entries.enumerated() {
            let label = "第 \(index + 1) 条（parameter=\(entry.parameter ?? "<缺失>")）"

            guard let parameter = entry.parameter, !parameter.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 parameter 字段")
                continue
            }
            // ⚠️ 重名会让下面的差集判据静默吞掉一条（Set 不看基数），单独拦。
            #expect(seen.insert(parameter).inserted, "\(label)：parameter 重复出现")

            guard let reason = entry.reason, !reason.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 reason 字段"); continue
            }
            guard let decidedBy = entry.decidedBy, !decidedBy.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 decidedBy（裁决人）字段"); continue
            }
            guard let decidedOn = entry.decidedOn, !decidedOn.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("\(label)：缺 decidedOn（日期）字段"); continue
            }

            #expect(reason.count >= 40, "\(label)：理由只有 \(reason.count) 字符，像占位")
            for banned in Self.bannedReasonPhrases where reason.contains(banned) {
                Issue.record("\(label)：理由含空话占位词「\(banned)」")
            }
            // ⚠️ 公约第 3 节终局条款 (a) 原文：「理由里**必须包含「为什么删不掉」**，
            // 而不只是「为什么四条都不适用」」。⇒ 每条理由必须正面处理删除这条出口。
            #expect(reason.contains("删除"),
                    "\(label)：理由没提「删除」——公约终局条款是**有序**的，先试 (b) 删除、(b) 不成立才用 (a) 记入豁免，理由必须写清为什么删不掉")

            #expect(decidedOn.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                    "\(label)：decidedOn=\(decidedOn) 不是 YYYY-MM-DD")
            for banned in Self.bannedReasonPhrases where decidedBy.contains(banned) {
                Issue.record("\(label)：裁决人字段里是占位词「\(banned)」，不是一个人")
            }
        }
    }

    @Test("豁免清单的每个键都是扫描器能产出的形状")
    func exemptionKeysAreScannerShaped() throws {
        let entries = try Self.loadExemptions()
        #expect(!entries.isEmpty, "豁免清单为空 —— 非空断言，见 exemptionBaselineIsWellFormed")
        for entry in entries {
            guard let parameter = entry.parameter else { continue }
            // ⚠️ 键的形状是 `Owner.decl#param`，由扫描器产出、不是人自由发挥的文本。
            // 形状检查挡的是「手写豁免时把 PRD 的 `Badge(outlined:)` 原样抄进来」这种，
            // 那样它永远匹配不上、只会以「过期条目」的面目红掉，诊断绕远路。
            #expect(parameter.contains("#") && parameter.contains("."),
                    "豁免键「\(parameter)」不是 `Owner.decl#param` 形状")
        }
    }

    // MARK: - Task 4 的判据：双向精确匹配

    @Test("J-1：public 声明不得含未豁免的 Bool 参数（⚠️ surface(bordered:) 记为 known issue，归 #41）")
    func j1NoUnexemptedBoolParameters() throws {
        let scan = try Self.boolScan()
        #expect(scan.keys.count > 20, "只扫到 \(scan.keys.count) 个豁免键 —— 扫描器失效")   // 与 Task 2 同下界

        let diff = compareBoolHitsToExemptions(hits: scan.keys, exempted: try Self.exemptedKeys())

        // ⚠️ **双向**：单向只能抓一头。
        // · violations = 源码里有、清单里没有 ⇒ 未豁免的 Bool 参数
        // · stale      = 清单里有、源码里没有 ⇒ 过期条目（AC 明写它同样判红）

        // ⚠️ **stale 在 withKnownIssue 之外**：过期条目与 surface(bordered:) 无关，
        // 不该被那条 known issue 顺带吞掉。
        let staleMessage = """
        豁免清单里这些条目在源码里已经找不到了：\(diff.stale.sorted())
        —— 过期条目同样判红（AC 原文）。删掉它们，并**同轮下调**
        bool-exemptions-baseline.json 的 maxEntries（棘轮不留 slack，见 baselineRatchet 判据）。
        """
        #expect(diff.stale.isEmpty, "\(staleMessage)")

        let violationMessage = """
        这些 public Bool 参数不在 docs/bool-exemptions.json 里：\(diff.violations.sorted())

        ⚠️ **到 #41 完成前，这里预期恰好有一条 `View.surface#bordered`**——公约附录 A.3 已裁决
        它「不合规」、且 39.md 的 AC 明写它**不放入初始豁免清单**，处置（豁免或改造）留给 #41。
        这是**预期状态**，不是本判据的缺陷。
        ⚠️ **若上面的清单不是恰好这一条，说明出现了新违规**，请看
        `j1ViolationSetIsExactlyTheContractPending`——那条判据在 known issue **之外**，
        专门抓这种情况。新增的 Bool 参数要么改掉，要么按公约第 3 节终局条款**先试 (b) 删除**、
        (b) 不成立才走 (a) 记入豁免基线（并同轮抬高 bool-exemptions-baseline.json 的 maxEntries）。
        """

        // ⚠️⚠️ **这里是全文件最容易做错的地方，改动前先读 `39-plan.md`
        // 「`surface(bordered:)` 的处置」一节。**
        //
        // `withKnownIssue` 只包住 **J-1 的字面陈述**（violations 必须为空）。它今天恰好被
        // `View.surface#bordered` 这一条打破——公约 A.3 已裁决、39.md 的 AC 明写它不入豁免清单。
        //
        // 为什么用 known issue 而不是让 CI 字面红（AC 偏离，已登记）：
        // · 两个仓的 epic/main **都没有分支保护** ⇒ 字面红拦不住任何合并，只是信号；
        // · 而字面红会让 `.github/workflows/ci.yml` 里「仅已知 flake 才重跑」的保护
        //   **恒走「直接判红」分支** ⇒ 整个 epic 期间 ToastHostTests 的 flake 重试变成死代码,
        //   代价由 #40 / #43 支付；
        // · known issue 的到期是**机器强制**的（见下），不依赖任何人给 #41 加 AC
        //   ——那正是 epic.md 备选方案（预置进豁免清单）被否决的理由，对本方案不适用。
        //
        // ⚠️ **`withKnownIssue` 会把块内任何 issue 都算成「已知」** ⇒ 块内**只能**放这一条断言。
        // 「新违规」由块外的 `j1ViolationSetIsExactlyTheContractPending` 抓，
        // 「过期条目」由上面块外的 stale 断言抓。**不要把它们挪进来。**
        //
        // ⚠️ **自动到期**：#41 删掉/改造 `bordered` 之后块内不再记录 issue，
        // Swift Testing 会判「Known issue was not recorded」⇒ 本判据**自己红**，
        // 逼 #41 同轮清掉这里与 `pendingViolationKeys`。
        // 本仓已有同款先例：`SystemBackgroundColorsMacOSTests.swift:62-64`。
        withKnownIssue(
            """
            公约附录 A.3 已裁决 `View.surface(_:bordered:)` 不合规，39.md 的 AC 明写它
            **不放入初始豁免清单**（因此它不占 maxEntries、不受棘轮保护）；
            处置（豁免或改造）归 #41。#41 一落地，本 known issue 会因「未被记录」自动判红。
            """
        ) {
            #expect(diff.violations.isEmpty, "\(violationMessage)")
        }
    }

    /// ⚠️ **本条是「新违规」的唯一非 known-issue 出口**：`j1NoUnexemptedBoolParameters`
    /// 里那条 `withKnownIssue` 会把块内任何 issue 都算成已知，所以新违规**必须**在这里红。
    /// 它同时是 `surface(bordered:)` 到期的第二道闸（`disappeared` 方向）——
    /// 在「新违规与 #41 改造同时发生」时，known issue 那道会失效，只剩这一道。
    @Test("未豁免违规集合恰好等于公约 A.3 点名的那一条（这条是**绿**的，专抓新违规）")
    func j1ViolationSetIsExactlyTheContractPending() throws {
        let scan = try Self.boolScan()
        #expect(scan.keys.count > 20, "只扫到 \(scan.keys.count) 个豁免键 —— 扫描器失效")

        let diff = compareBoolHitsToExemptions(hits: scan.keys, exempted: try Self.exemptedKeys())
        let unexpected = diff.violations.subtracting(Self.pendingViolationKeys)
        #expect(unexpected.isEmpty,
                "出现了公约未预期的未豁免 Bool 参数：\(unexpected.sorted()) —— 这不是 surface(bordered:) 那条预期的红")

        let disappeared = Self.pendingViolationKeys.subtracting(diff.violations)
        let disappearedMessage = """
        这些条目已不再是未豁免违规：\(disappeared.sorted())
        —— 若 #41 已经删除/改造了它们，请**同轮**把它们从 pendingViolationKeys 移走
        （若改造成了别的形状而仍带 Bool，还要同轮进豁免清单 + 抬高 maxEntries）。
        本条断言的存在就是为了不让这个待办被忘掉：它不会自己保鲜，所以由判据保鲜。
        """
        #expect(disappeared.isEmpty, "\(disappearedMessage)")
    }

    @Test("棘轮：豁免清单条目数与基线 maxEntries 严格相等，且基线自身四字段齐全")
    func baselineRatchetHoldsExactly() throws {
        // ⚠️ **非空断言先行**：基线文件读不到 ⇒ 无从比对 ⇒ 静默变绿。
        #expect(
            FileManager.default.fileExists(atPath: Self.baselineURL.path),
            "棘轮基线不存在：\(Self.baselineURL.path) —— 判据无法工作，这不是「上限没被抬高」"
        )
        let baseline = try Self.loadBaseline()

        guard let maxEntries = baseline.maxEntries else {
            Issue.record("棘轮基线缺 maxEntries 字段"); return
        }
        #expect(maxEntries > 0, "maxEntries=\(maxEntries) —— 零上限不是「很严」，是判据没配置")
        for (name, value) in [("raisedBy", baseline.raisedBy), ("raisedOn", baseline.raisedOn),
                              ("rationale", baseline.rationale)] {
            guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
                Issue.record("棘轮基线缺 \(name) 字段 —— 抬高上限是破例动作，必须留下署名、日期与理由")
                continue
            }
            for banned in Self.bannedReasonPhrases where value.contains(banned) {
                Issue.record("棘轮基线的 \(name) 里是占位词「\(banned)」")
            }
        }
        #expect(baseline.raisedOn?.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                "棘轮基线 raisedOn=\(baseline.raisedOn ?? "<缺失>") 不是 YYYY-MM-DD")
        #expect((baseline.rationale?.count ?? 0) >= 40,
                "棘轮基线 rationale 只有 \(baseline.rationale?.count ?? 0) 字符，像占位")

        let count = try Self.loadExemptions().count
        #expect(count <= maxEntries, """
        棘轮：豁免清单 \(count) 条 > 上限 \(maxEntries)。
        扩张豁免面是**破例**——要新增豁免，必须**同轮**抬高 docs/bool-exemptions-baseline.json
        的 maxEntries，并更新 raisedBy / raisedOn / rationale（理由要写清这条新豁免
        为什么过不了公约第 3 节终局条款 (b)「论证它本不该存在、走删除」）。
        """)
        #expect(count >= maxEntries, """
        棘轮 slack：豁免清单 \(count) 条 < 上限 \(maxEntries)，中间空出了 \(maxEntries - count) 个额度。
        缩小清单后**必须同轮把 maxEntries 降到新值**——留着 slack 等于给未来的新增
        留了一个**免审白名单额度**（那正是 `<=` 版本判据的真实漏洞，本条等式专门堵它）。
        棘轮的「只许缩」靠的就是这条把已释放的额度立刻收回来。
        """)
    }

    @Test("豁免宿主要么在登记表里，要么在 AD 台账里且该分类真的成立")
    func exemptionOwnersReconcileWithRegistry() throws {
        let registered = Set(
            try ComponentRegistryGuard.loadRegistry()
                .filter { $0.repo == "coredesign" }.map(\.component)
        )
        #expect(registered.count > 30, "登记表只读到 \(registered.count) 条 coredesign 条目 —— 疑似没读到")

        let scan = try ComponentRegistryGuard.coreDesignScan()
        #expect(scan.components.count > 15, "登记表扫描器只扫到 \(scan.components.count) 个组件类型 —— 失效")

        let readmeText = try String(
            contentsOf: ComponentRegistryGuard.repoRoot.appendingPathComponent("docs/README.md"),
            encoding: .utf8
        )
        let readmeRows = ComponentRegistryGuard.readmeIndexRows(readmeText)
        #expect(readmeRows.count > 20, "README 组件索引只解析到 \(readmeRows.count) 行 —— 解析器可能失效")
        // ⚠️ **M-3 留痕，不改逻辑**：`formUnion` 无差别收进每一行的候选名，没有按
        // `isTombstone` 排除墓碑行（`~~Foo~~` 剥掉 `~~` 后名字照收）。方向是安全的——
        // 某个 `.nonViewPublicType` 宿主若哪天以**墓碑**（已从 README 移除）形态出现，
        // 会误触下面 `!readmeNames.contains(root)` 的「该登记」红，而不是漏报；
        // 当前台账（`StepItem` / `ButtonRoleStyleRole` /
        // `SegmentedControlStyleConfiguration.Segment`）与已知墓碑清单
        // （`ComponentRegistryGuard.knownReadmeTombstones`）无交集，误红不会发生。
        var readmeNames: Set<String> = []
        for raw in readmeRows {
            readmeNames.formUnion(ComponentRegistryGuard.candidateNames(fromReadmeCell: raw).names)
        }
        // ⚠️ **Important-1**：`readmeRows.count > 20` 只保证「解析到了行」，不保证
        // `candidateNames(fromReadmeCell:)` 从这些行里聚合出了名字——若该函数的括号
        // 剥离 / `/` 切分逻辑对每行都返回空数组，行数照旧 > 20、`readmeNames` 却是空集
        // ⇒ 下面 `.nonViewPublicType` 分支的 `!readmeNames.contains(root)` 空转恒真，
        // README 绊线静默失效。行数与名字数当前同量级，下界给宽松量级。
        #expect(readmeNames.count > 20, "README 候选名解析失效：\(readmeRows.count) 行只聚合出 \(readmeNames.count) 个名字")

        // Important-2 (a)：`.externalProtocolExtension` 的正向核对，见该常量声明处文档。
        let declaredTypeNames = try Self.declaredTypeNames()
        #expect(declaredTypeNames.count > 30,
                "只扫到 \(declaredTypeNames.count) 个类型声明 —— 扫描器失效")

        var unaccounted: [String] = []
        for key in try Self.exemptedKeys() {
            let owner = Self.owner(ofExemptionKey: key)
            if registered.contains(owner) { continue }
            guard let kind = Self.ownersWithoutRegistryEntry[owner] else {
                unaccounted.append("\(key) → 宿主「\(owner)」")
                continue
            }
            // ⚠️ 分类必须**承重**：每一种都绑一条真实核对，不是认个名字就放行。
            switch kind {
            case .externalProtocolExtension:
                #expect(!scan.components.contains(owner) && !scan.styleImpls.contains(owner),
                        "「\(owner)」被标为外部协议扩展，但本仓源码里就有这个类型 —— 分类过期，该重新裁决")
                // ⚠️ Important-2 (a)：正向核对——上面两条只查「View/ViewModifier/style
                // 协议的 public struct」这个窄桶，这里直接查本仓**全部**类型声明（含嵌套、
                // 不限访问级别），真正对得起 `OwnerExclusionKind.externalProtocolExtension`
                // 文档里「本仓根本没有该类型的声明」这句话。
                #expect(!declaredTypeNames.contains(owner),
                        "「\(owner)」被标为外部协议扩展（本仓没有同名类型声明），但本仓源码里确实声明了一个同名类型 —— 分类过期，该重新裁决")
            case .styleImplementation:
                #expect(scan.styleImpls.contains(owner),
                        "「\(owner)」被标为 style 实现，但扫描器的 styleImpls 里没有它 —— 删光 Components/Button/styles/ 也会命中这条")
            case .nonViewPublicType:
                let root = owner.split(separator: ".").first.map(String.init) ?? owner
                #expect(!scan.components.contains(root),
                        "「\(root)」已被扫描器采集为组件类型 —— 它现在该进登记表了，从台账里移走")
                // AD-2 终审 I4 的复合条件：「有 public 类型 **且被 README 组件索引收录**」⇒ 登记。
                #expect(!readmeNames.contains(root),
                        "「\(root)」已出现在 docs/README.md 的组件索引里 —— 按 AD-2 终审 I4 的复合条件它该登记，重新裁决")
            }
        }
        let unaccountedMessage = """
        这些豁免的宿主既不在 component-registry.json 里，也不在 ownersWithoutRegistryEntry 台账里：
        \(unaccounted.sorted().joined(separator: "\n"))
        —— 39.md 最后一条 AC 的收窄版（见 39-plan.md）：宿主可以没有登记表条目，
        但必须写明是哪一条 AD 裁决让它没有，并让那条裁决在这里被真的核对一遍。
        """
        #expect(unaccounted.isEmpty, "\(unaccountedMessage)")

        // ⚠️ **反向**：台账里的宿主若哪天真进了登记表，台账就过期了，
        // 而判据不会因为「还是绿的」提醒任何人去核对（#38 终审第 2 轮 M2 同款）。
        let nowRegistered = Set(Self.ownersWithoutRegistryEntry.keys).intersection(registered)
        #expect(nowRegistered.isEmpty,
                "这些宿主已经进了登记表，该从 ownersWithoutRegistryEntry 移走：\(nowRegistered.sorted())")
    }
}

/// 采集 `Sources/CoreDesign` 里**所有**具名类型声明的名字（`struct`/`class`/`enum`/
/// `protocol`/`actor`），不限访问级别、不限嵌套层级、不看是否符合任何协议——供
/// `BoolExemptionGuard.declaredTypeNames()` 用，是 Important-2 (a) 「本仓根本没有
/// 该类型的声明」这句话的正向核对。⚠️ **不是「顶层」采集器**：五个 `visit` 都返回
/// `.visitChildren`，会继续递归进类型内部，嵌套类型同样被采到——对「这个名字在本仓
/// 是否被声明过一次」这个问题而言这是期望行为，不是失控的副作用。
/// ⚠️ 与 `ComponentRegistryGuard.PublicTypeCollector` 是两个不同的采集器：那个只收
/// public 且符合 `View`/`ViewModifier`/style 协议的 struct（为登记表核对服务），
/// 这个收全部访问级别、全部声明关键字、任意嵌套层级（为上面更宽的问题服务）。
private nonisolated final class DeclaredTypeNameCollector: SyntaxVisitor {
    var names: Set<String> = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.names.insert(node.name.text)
        return .visitChildren
    }
}
