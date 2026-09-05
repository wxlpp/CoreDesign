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
// 本身，Task 4 已消费它；`docs/bool-exemptions-baseline.json` 记 `maxEntries` /
// `sourceSites` 两个上限 + `raisedBy` / `raisedOn` / `rationale`（共 5 个字段），
// 已随 Task 5 落地、Task 8 终审补齐 `sourceSites`——`baselineRatchetHoldsExactly`
// 判据读取它并与清单条目数 / 源码位置数严格相等比对。
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

    /// ⚠️ **`#246` 多根化**：扫描根从单根 `Sources/CoreDesign` 改为
    /// `GuardScanRoots.allRoots`（当下三个已存在的 library target）。
    /// 根列表、fail-closed 断言与「新 target 忘了扩根即红」的自守卫全在
    /// `GuardScanRoots.swift` 里，本文件不再自己拼路径——两处各自维护一份根列表
    /// 正是漂移的起点。
    static var scanRoots: [(target: String, url: URL)] { GuardScanRoots.allRoots }
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
        let result = try scanBoolParams(roots: Self.scanRoots)
        if !result.hits.isEmpty { Self.cachedScan = result }
        return result
    }

    // MARK: - 判据体系之外的参照物

    /// **公约与 PRD 白纸黑字点名的参数**，是本判据的**外部参照物**（现存 **8** 条；
    /// 原始基线 **14** 条，#41 已按裁决逐条移出 6 条——见下方数组尾注，#41 收尾时更新，
    /// S-T3-1）。
    ///
    /// ⚠️ **为什么必须有它**：变异证伪只能证「判据对它**看得见**的东西有效」，
    /// 证不了「它看得见的**够不够**」——#38 就是靠 `docs/README.md` 索引这个判据体系
    /// **之外**的清单，才发现 `Toast` / `BottomInputBar` 两行漏网。这里扮演同一角色的是
    /// **人写的规范文本**：原始基线里前 12 条来自 `39.md` Technical Details 的「已知违规
    /// 实例」（PRD 原文 10 条 + `SolidButtonStyle(glass:)` / `LightButtonStyle(glass:)`，
    /// 其中 5 条已随 #41 裁决移出，现存 **7** 条），后 2 条来自公约本身（附录 A.3 的
    /// `surface(bordered:)`——已随裁决 1 移出——与第 3 节例外条款点名的
    /// `SegmentedControlStyleConfiguration.Segment.isSelected`，现存 **1** 条）。
    /// 扫描器的匹配逻辑一旦被改窄（比如漏了 `public extension` 这条路径），这些名字会
    /// 掉出来，判据立刻红。
    ///
    /// ⚠️ **PRD 写的 `Sidebar(showsChevron:)` 实际落在 `SidebarSection` 上**
    /// ——`Sidebar` 是 `docs/README.md` 的行名，不是类型名（登记表按六个子类型分别登记,
    /// 没有一条叫 `Sidebar`，见 `ComponentRegistryGuard.knownReadmeContainerPrefixes`）。
    static let contractNamedKeys: Set<String> = [
        "Badge.init#outlined",
        "SidebarSection.init#showsChevron",
        "Tag.init#removable",
        "PinCode.init#isSecure",
        "Skeleton.init#isLoading",
        "Carousel.init#autoAdvance",
        "TagInput.init#allowDuplicates",
        "SegmentedControlStyleConfiguration.Segment.init#isSelected",
        // ⚠️ #41 已移出六条：`Card.init#bordered` / `View.surface#bordered`（裁决 1）、
        // `SolidButtonStyle.init#glass` / `LightButtonStyle.init#glass`（裁决 3）、
        // `Rating.init#allowsHalfStar`（裁决 4a）、`Rating.init#isReadOnly`（裁决 4b）。
        // 它们的源码参数已不存在 ⇒ 留在这里会让 `:343` 的子集断言判红。移出的是
        // **参照物条目**，不是「公约没点过它们」——公约与 PRD 的裁决记录仍在，
        // 只是被裁决的对象走完了终局条款 / 替代路径。
    ]

    /// **公约 A.3 已裁决、但按 39.md 的 AC 刻意不放进豁免清单的违规**。
    ///
    /// ⚠️ **#41 裁决 1 落地后本集合已清空**：唯一成员 `View.surface#bordered` 的源码
    /// 参数已删除（改由 `SurfaceKind.grouped` 表达），`j1NoUnexemptedBoolParameters`
    /// 里那条只包住 J-1 字面陈述的 `withKnownIssue` 块也随之删除——块内不再记录 issue
    /// 时 Swift Testing 会判「Known issue was not recorded」而主动红，这正是 #39 设计
    /// 的机器强制到期，本轮如期触发。
    ///
    /// ⚠️ **保留这个空集合，不要连常量一起删**：它是「已知违规、数量不许涨」的登记位。
    /// 下一次出现「公约已裁决不合规、但按 AC 刻意不豁免」的参数时，往这里加一个键
    /// **就是一次完整的 J-1 豁免**（不占 `maxEntries`、不受棘轮保护，见
    /// `Baseline` 文档里的通道 (A)）——那必须是一次显式的、看得见的动作，
    /// 而不是先删常量、再重新发明一个同样的机制。
    /// `j1ViolationSetIsExactlyTheContractPending` 的两条差集断言在空集上照常工作：
    /// `unexpected` 变成「任何未豁免违规都判红」，`disappeared` 恒空。
    static let pendingViolationKeys: Set<String> = []

    // MARK: - 与 #38 登记表的交叉核对（39.md 最后一条 AC 的收窄落地）

    /// 一个豁免宿主为什么不可能有 `component-registry.json` 条目。
    enum OwnerExclusionKind: Sendable {
        /// 扩展的是 SwiftUI / 外部协议，本仓根本没有该类型的声明（当前唯一实例：`View`）。
        /// ⚠️ `ButtonStyle` 曾属本分类，已由 `#48` 按 `#44` SC-8 的裁断**回收**（见台账注释）。
        /// ⚠️ **Task 8 S-1**：这句「根本没有该类型的声明」由 `declaredTypeNames()` 核对，
        /// 而它**不采集 `typealias`**（`DeclaredTypeNameCollector` 只访问
        /// `struct`/`class`/`enum`/`protocol`/`actor`）——若本仓出现
        /// `typealias View = ...` 这类遮蔽声明，本条判据看不见，「根本没有」这句话
        /// 会略宽于实际核对范围。当前 `grep -rn "typealias View\b"` 零命中，
        /// 不构成现存漏洞，留痕供未来审阅。
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
    /// 根本不可能有条目**（⚠️ **`#48` 回收 `ButtonStyle` 后台账是 6 条** —— 「7」是当时
    /// 的实测数，保留作历史记录；现值以 `ownersWithoutRegistryEntry` 本身为准），且各有各的 AD 依据（任务书只点了 `BottomInputBar` 一例——
    /// ⚠️ **该例已于 #221 失效**：它提为 public 并登记后，其宿主在登记表里**有**条目了；
    /// 但结论不变，实际范围本就宽得多——凡是自由函数与非组件 public 类型都落在外面）。
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
        "SolidButtonStyle": .styleImplementation,
        "LightButtonStyle": .styleImplementation,
        "StepItem": .nonViewPublicType,
        "ButtonRoleStyleRole": .nonViewPublicType,
        "SegmentedControlStyleConfiguration.Segment": .nonViewPublicType,
        // ⚠️ **#41 裁决 3 之后，两条宿主处于「休眠」态**：`SolidButtonStyle` /
        // `LightButtonStyle` 已没有活的豁免键 ⇒ 按豁免键遍历的那条通路不会访问它们。
        // ⚠️ **但 `#48` G-2 加了「全表 pass」之后，休眠不再等于零覆盖** ——
        // 台账里的每条宿主，无论有没有活豁免键，分类标注都会被核。
        // 保留这两行的理由也因此从「保留唯一样本」变成更直接的一条：它们的分类
        // （`.styleImplementation`）今天仍然成立，没有回收依据。
        //
        // ✅ **`ButtonStyle` 已回收**（`#48` 执行）：它原挂 `ButtonStyle.solid#glass` /
        // `ButtonStyle.light#glass`，#41 删 `glass` 后无活豁免键；绑的是
        // `.externalProtocolExtension`，而该分类由 `View` 撑着 11 个活豁免键、
        // 正向核对非零覆盖 ⇒ 不落在「保留唯一样本」的理由里。
        // 依据是 **`#44` SC-8 裁断 (ii)②「回收条件已满足」**（`docs/component-contract.md`
        // 的 G-2 裁断），**不是 `#48` 新裁**；#48 只是执行那条早已成立的裁断。
        // ⚠️ 回收前实跑过全量测试确认无判据依赖它。
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
    /// 标 `.externalProtocolExtension` 的宿主（`#48` 回收 `ButtonStyle` 后只剩 `View`）
    /// 是顶层单段名，不触发；留痕供未来审阅。
    /// ⚠️ **`#246` 起跨全部已存在 target**：「本仓根本没有该类型的声明」这句话的
    /// 定义域是**整个包**，不是主 target 一家——只扫 `Sources/CoreDesign` 的话，
    /// 新 target 里声明一个同名 `View`/`ButtonStyle` 会让这条正向核对继续说「没有」。
    static func declaredTypeNames() throws -> Set<String> {
        if let cached = Self.cachedDeclaredTypeNames { return cached }
        GuardScanRoots.assertRootsExist(Self.scanRoots)
        var names: Set<String> = []
        for root in Self.scanRoots {
            for url in GuardScanRoots.swiftFiles(in: root.url) {
                let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
                if tree.hasError {
                    // ⚠️ **诊断走仓库根相对路径，不是 `lastPathComponent`**（PR #265 第 3 轮
                    // Copilot A-1）：本函数自 `#246` 起扫**多个根**，两个 target 各有一个
                    // `Foo.swift` 时裸文件名指不出是哪一个。
                    Issue.record("解析出错：\(GuardScanRoots.relativePath(url)) —— swift-syntax major 可能与工具链不配套")
                }
                let collector = DeclaredTypeNameCollector()
                collector.walk(tree)
                names.formUnion(collector.names)
            }
        }
        if !names.isEmpty { Self.cachedDeclaredTypeNames = names }
        return names
    }

    /// 台账里一条宿主的**分类核对**。键遍历与全表 pass **共用本函数**（`#48` G-2）。
    ///
    /// ⚠️ 每种分类都必须绑**真实核对**，不是认个名字就放行。
    static func assertOwnerClassification(
        owner: String,
        kind: OwnerExclusionKind,
        scan: ComponentRegistryGuard.ScanResult,
        declaredTypeNames: Set<String>,
        readmeNames: Set<String>
    ) {
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
            // ⚠️ **`#48` G-2：这一格此前只有上面两条「负向」断言** —— 「不在组件集合」
            // 「不在 README」。于是把一个 style 实现改标成本分类，两条都过 ⇒ **静默判绿**
            // （spec §3.2b 实测：改标 `SolidButtonStyle` 后 7 tests 全绿）。
            // 该文件原注释自己把这半边记作「残余等价性，未被机器判据钉死」。
            //
            // ⇒ **正向**：它得真的是一个本仓声明过的类型。
            #expect(declaredTypeNames.contains(root),
                    "「\(root)」被标为「非 View 的公开类型」，但本仓源码里根本没有这个类型的声明 —— 分类过期或名字写错了")
            // ⇒ **排他**：它不能是样式实现（那该标 `.styleImplementation`）。
            //    ⚠️ 这条才是让「改标 style 实现」这类腐坏判红的东西。
            #expect(!scan.styleImpls.contains(root),
                    "「\(root)」被标为「非 View 的公开类型」，但扫描器把它采集为**样式实现** —— 它该标 .styleImplementation，分类错了")
            // ⚠️ **已知盲区之二，留痕**（PR #211 终审 I-2）：`scan.styleImpls` 的口径是
            // `PublicTypeCollector.styleProtocols` —— **只含 7 个 SwiftUI 原生协议**。
            // `PlainBannerStyle` / `StarRatingStyle` 这类**自有** style 协议的实现
            // **不进 `styleImpls`**。⇒ 两个分类的机器边界实际是「**原生**协议清单」，
            // 而 `.styleImplementation` 的语义（AD-3）是「style 实现」**全集**：
            //   · 自有 style 实现标 `.styleImplementation` ⇒ 正向条找不到它 ⇒ **假红**；
            //   · 标 `.nonViewPublicType` ⇒ 排他条看不见它 ⇒ 四条**全过、假绿**。
            // 当前六条宿主不触发（Solid/Light 走原生 `ButtonStyle`），属**潜伏**。
            // ⚠️ 别以为下面这条排他钉死了整个「style 实现 vs 非 View 类型」边界。
            //
            // ⚠️ **已知盲区，留痕**：正向条核的是 **root（容器）**存在，不是**叶子**。
            // `Foo.Bar` 这类点分宿主，只要 `Foo` 真实存在就过 —— 将来出现「容器真、
            // 叶子假」（如 `SegmentedControlStyleConfiguration.Nonexistent`）会**假绿**。
            // 与本文件 Task 8 S-2 记的是同一族病，当前三条宿主不触发。
        }
    }

    /// 从豁免键 `Owner.decl#param` 里取回宿主名。
    /// `SegmentedControlStyleConfiguration.Segment.init#isSelected` ⇒
    /// `SegmentedControlStyleConfiguration.Segment`（去掉 `#` 之后的参数与最后一段 decl 名）。
    /// ⚠️ **`#246`：先剥掉 target 前缀**（`CoreDesignEffects/Foo.init#flag` ⇒ 宿主 `Foo`）。
    /// 不剥的话新 target 的宿主名会带着 `CoreDesignEffects/` 去查登记表与台账，
    /// 永远查不到 ⇒ 一律落进 `unaccounted` 判红，诊断指向完全错误的方向。
    static func owner(ofExemptionKey key: String) -> String {
        let head = GuardScanRoots.baseKey(key).split(separator: "#").first.map(String.init)
            ?? GuardScanRoots.baseKey(key)
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
    /// `git log -p docs/bool-exemptions-baseline.json` 是 **`maxEntries` 变更**的完整
    /// 台账，一条不多一条不少。
    ///
    /// ⚠️ **这不是「豁免面被放宽」的完整台账**（Task 8 终审 Important-3 收窄措辞，
    /// 详细论证见 `docs/component-contract.md` 对应段落）：至少两条通道不经过
    /// `maxEntries`、因此不出现在这份 git log 里——
    /// (A) `pendingViolationKeys`（本文件里写死的集合，不占 `maxEntries`、不受棘轮
    /// 保护，往里加一个键就是一次完整的 J-1 豁免）；
    /// (B) 键碰撞（`BoolScanResult.keys` 是 `Set`，新增一个 public 声明只要键已在
    /// 清单里就不增加清单条目数，`sourceSites` 之前未被断言、`hits.count` 可以漂移
    /// 而这里的 git log 看不出来——已在 `baselineRatchetHoldsExactly` 补严格等式堵上）。
    struct Baseline: Codable {
        /// ⚠️⚠️ **自 `#246` 起，`maxEntries` / `sourceSites` 的计数定义域是「全包」，
        /// 不再是「CoreDesign」**（PR #265 终审 I-5）：`boolScan()` 的扫描根已从单根
        /// `Sources/CoreDesign` 改成 `GuardScanRoots.allRoots`（`CoreDesign` +
        /// `CoreDesignEffects` + `CoreDesignCharts`），而这两个数字仍与合并后的结果比
        /// ⇒ **Effects / Charts 里新增一个 public `Bool` 会把 `sourceSites` 顶到 36 ≠ 35，
        /// 判红**。这是**收紧**不是放宽（FR-10 只要求「既有 CoreDesign 判据字面不变」，
        /// 32 / 35 两个数字一个字没动）。
        ///
        /// ⚠️ **但下面 `rationale` 里的文字仍整段用 CoreDesign 的口径说话**
        /// （`BottomInputBar` 的 27 → 32 / 30 → 35），`docs/bool-exemptions-baseline.json`
        /// 里的那份同样如此——**那是历史记录，不是定义域说明**。Epic A 第一个带
        /// public `Bool` 的动效 / 图表组件会撞上这两个数字，届时：
        /// · 它的豁免键**必须带 `<Target>/` 前缀**（`GuardScanRoots.qualifiedKey(target:base:)`；
        ///   裸形只属于主 target，由 `exemptionKeysAreCanonicallyQualified` 钉死）；
        /// · 抬高 `maxEntries` / `sourceSites` 时，`rationale` 里**必须写明这次抬高来自哪个
        ///   target**——这条由**树内**的 `rationaleTargetProblems(_:)` 强制，
        ///   而**不是**由 `scripts/bool-exemptions-ratchet.sh` 强制。
        ///   ⚠️⚠️ **本条此前描述了那个脚本并不具备的能力**（PR #265 第 3 轮终审 S-e）：
        ///   原文写「否则跨历史闸会把一次 Effects 的新增读成 CoreDesign 的回归」，
        ///   读起来像是脚本会判红或会误归属。实读 `scripts/bool-exemptions-ratchet.sh`
        ///   （`CUR_WHY` / `BASE_WHY` 的比较，到脚本末尾那几行 `echo` + `exit 0`）：
        ///   抬高时它**只**要求 `rationale` 与 base 逐字不同，随后打印一段 `⚠️⚠️` warning
        ///   并 **`exit 0`**——既不读 target、也不读 `sourceSites`、更不会判红。
        ///   ⇒ 真实行为**比原文预测的更糟**：它带 warning 静默放过。
        ///   ⇒ 这条「必须」因此不能只靠约定——本文件自己的论点就是「只靠约定的 ratchet
        ///   必然漂」（见下方 `sourceSites` 文档的残余 2）。装牙的形态是两条**树内**判据：
        ///   `rationaleTargetProblems(_:)`（rationale 必须点名至少一个 target）与
        ///   `perTargetProblems(perTarget:exemptionKeys:hits:)`（逐 target 计数，
        ///   让定义域扩张对机器可见）。
        let maxEntries: Int?
        let raisedBy: String?
        let raisedOn: String?
        let rationale: String?
        /// ⚠️ **Task 8 终审 I-3 通道 B 的机器闸——只保证这次变化在 diff 里可见，不是
        /// 「关掉通道」**（Task 8 终审第 3 轮 Important-2 收窄措辞）：`scanBoolParams`
        /// 产出的 `hits.count`（源码位置数，含同键多处声明的重复计数）此前只有
        /// `scannerFindsPublicBoolParameters` 里的量级下界 `> 20`，真实数字 38
        /// 只出现在 `print` 里、从未被任何等式断言钉住——新增一个 public 声明只要
        /// 键已经在 `docs/bool-exemptions.json` 里就能全绿过关、`keys.count` 与
        /// `maxEntries` 都不变，这条键碰撞通道因此对棘轮不可见。这里补一个与
        /// `maxEntries` 同款的严格等式钉住 `scan.hits.count`——实际成本仍是**改一行
        /// JSON**（`sourceSites` 的 `38 → 39`），只是这一行现在会出现在 diff 里、
        /// 逼一次署名。
        /// ⚠️ **`sourceSites` 未纳入 `maxEntries` 那套跨历史破例流程**：
        /// `scripts/bool-exemptions-ratchet.sh` 从头到尾只读 `maxEntries`（该脚本
        /// `read_field` 的两处调用），完全不读 `sourceSites`——树内这条等式只挡
        /// 「本次 diff 里 `sourceSites` 与源码位置数不一致」，挡不住「`sourceSites`
        /// 与 `maxEntries` 在同一次改动里一起被静默抬高」这类跨历史场景；跨历史闸
        /// 移交 #41/#43。
        /// ⚠️ **两条评审补的残余，威胁模型未被端到端跑过**：
        /// 1. **变异证的是「期望值」不是「被测对象」**——迄今三次验证这条断言
        ///    （37/39/38）都是在改**基线里的数字**后确认变红，从未真的新增一个键
        ///    碰撞的 public 声明再看它是否变红。方向没错（红能归因到这条断言），
        ///    但威胁模型那一侧没被端到端跑过。
        /// 2. **计数型闸门天然可被对冲**——删掉一处已有碰撞位 + 新增一处碰撞位，
        ///    `hits.count` 仍等于 `sourceSites`、`keys.count` 仍等于 `maxEntries`、
        ///    清单不变 ⇒ 全绿。要真正关死需要钉**键 → 位置数的多重集**，不是总数；
        ///    移交 #41/#43。
        let sourceSites: Int?

        /// **逐 target 分账**（PR #265 第 3 轮终审 S-e）。
        ///
        /// ⚠️ **它堵的是「跨 target 对冲」**：`maxEntries` / `sourceSites` 自 `#246` 起是
        /// 全包合计，于是**删掉一个 CoreDesign 的 Bool + 新增一个 Effects 的 Bool**
        /// 会让两个总数都不变 ⇒ 全绿，而定义域实际上已经从主 target 漂到了新 target。
        /// 逐 target 的严格等式让这次移动必须改 JSON、因此必须出现在 diff 里。
        /// （`sourceSites` 文档里记的**另一条**对冲——同一 target 内删一处碰撞位、
        /// 加一处碰撞位——仍未关死：要关死需要钉「键 → 位置数」的多重集，移交 #41/#43。）
        ///
        /// ⚠️ **键集合必须与 `GuardScanRoots.targetNames` 逐字吻合**，含计数为 0 的 target
        /// ——漏一个 target 就等于给它留了一个不受棘轮约束的额度（那正是 `<=` 版本判据的
        /// 老漏洞）。新增 target 时这里必须同轮加一条 `{"exemptions": 0, "sourceSites": 0}`。
        let perTarget: [String: TargetCounts]?

        /// 一个 target 的两个计数。`exemptions` 对 `docs/bool-exemptions.json` 里前缀属于该
        /// target 的条目数，`sourceSites` 对扫描命中里落在该 target 的源码位置数。
        struct TargetCounts: Codable, Hashable, Sendable {
            let exemptions: Int
            let sourceSites: Int
        }
    }

    // MARK: - 棘轮判据的纯函数（终审 S-e：装牙 + 可合成证伪）

    /// `rationale` 必须**点名至少一个 target**，否则返回一条问题。
    ///
    /// ⚠️ **这是 `Baseline` 文档里那条「必须写明来自哪个 target」的牙**：
    /// `scripts/bool-exemptions-ratchet.sh` 只比较 rationale 是否逐字变了、然后 warning + `exit 0`，
    /// 它读不出「这次抬高属于哪个 target」。定义域自 `#246` 起是全包 ⇒ 一条不点名 target 的
    /// rationale 会让读者默认按 CoreDesign 的老口径理解，而实际可能来自 Effects / Charts。
    ///
    /// ⚠️⚠️ **这条判据的实际强度只有「一个 target 名都不提就红」，不是归属校验**
    /// （PR #265 第 4 轮终审 S-1，如实记录）：它只做 `rationale.contains(任一 targetName)`，
    /// 而 `"CoreDesign"` 是极常见子串——任何提到 `Sources/CoreDesign/…` / `CoreDesignTests` /
    /// 甚至仓库名本身的理由都自动通过。⇒ 它**区分不了**「点名本次抬高属于哪个 target」与
    /// 「顺手提了个路径」。真正承重的归属判据是 `perTargetProblems(perTarget:exemptionKeys:hits:)`
    /// ——逐 target 的严格等式，改不了措辞就蒙混不过去。
    /// ⚠️ **仍然保留本条**：它至少挡住「一条 target 名都不提」的 rationale，成本为零。
    /// ⚠️ **装实牙的路径（follow-up，不在 `#246` 射程内）**：给 `Baseline` 加一个结构化字段
    /// `raisedForTargets: [String]`，并与 `perTarget` **相对上一版基线的变化集合**做交叉核对
    /// ——声称为 A 抬高、实际动的是 B 的计数时当场红。那需要读上一版基线（跨历史），
    /// 与 `sourceSites` 的跨历史闸同属 #41/#43 的题目。
    static func rationaleTargetProblems(_ rationale: String?) -> [String] {
        guard let rationale, !rationale.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ["棘轮基线缺 rationale —— 无从判断这次抬高属于哪个 target"]
        }
        guard GuardScanRoots.targetNames.contains(where: { rationale.contains($0) }) else {
            return ["""
            棘轮基线的 rationale 没有点名任何 target（\(GuardScanRoots.targetNames)）。
            `maxEntries` / `sourceSites` 自 `#246` 起是**全包**计数，一次抬高可能来自任一 target；
            rationale 不点名，读者只能按主 target 的老口径理解，而
            `scripts/bool-exemptions-ratchet.sh` 对此完全看不见（它只比较 rationale 是否逐字变了，
            随后 warning + exit 0）。⇒ 请在 rationale 里写明这次变化落在哪个 target 上。
            """]
        }
        return []
    }

    /// 逐 target 计数的严格等式。返回它违反的每一条。
    static func perTargetProblems(
        perTarget: [String: Baseline.TargetCounts]?,
        exemptionKeys: [String],
        hits: [BoolParamHit]
    ) -> [String] {
        guard let perTarget else {
            return ["棘轮基线缺 perTarget 字段 —— 跨 target 对冲（删一个 CoreDesign 的、加一个 Effects 的）对棘轮不可见"]
        }
        var problems: [String] = []
        let declared = Set(perTarget.keys)
        let expected = Set(GuardScanRoots.targetNames)
        if declared != expected {
            problems.append("""
            棘轮基线 perTarget 的键集合 \(declared.sorted()) 与 `GuardScanRoots.targetNames`
            \(expected.sorted()) 不吻合 —— 少一个 target 等于给它留一个不受棘轮约束的额度。
            """)
        }
        var actualExemptions: [String: Int] = [:]
        for key in exemptionKeys {
            actualExemptions[GuardScanRoots.target(ofKey: key), default: 0] += 1
        }
        var actualSites: [String: Int] = [:]
        for hit in hits { actualSites[hit.target, default: 0] += 1 }

        for target in GuardScanRoots.targetNames {
            let counts = perTarget[target] ?? .init(exemptions: 0, sourceSites: 0)
            let exemptions = actualExemptions[target] ?? 0
            let sites = actualSites[target] ?? 0
            // ⚠️ **失败文案按方向分两支**（PR #265 第 4 轮终审 S-1）：这条判据是**严格等式**，
            // 计数**下降**（治理掉一个 Bool、删掉一条不再需要的豁免）同样会红，而那是**好方向**
            // ——对它说「请同轮更新（连同 raisedBy / raisedOn / rationale）」语义不贴切：
            // 收紧不需要署名破例，只需要把基线跟着降下来。
            if counts.exemptions != exemptions {
                let raised = exemptions > counts.exemptions
                problems.append("""
                逐 target 棘轮：\(target) 的豁免条目数 \(exemptions) ≠ 基线 \(counts.exemptions)。
                总数 `maxEntries` 不变**不代表**没变化——删一个 CoreDesign 的、加一个 Effects 的，
                总数纹丝不动而定义域已经漂了。
                \(raised
                    ? "本次是**抬高**（\(counts.exemptions) → \(exemptions)）⇒ 这是一次破例，请同轮更新 docs/bool-exemptions-baseline.json 的 perTarget，**连同 raisedBy / raisedOn / rationale**（rationale 必须点名 target）。"
                    : "本次是**下降**（\(counts.exemptions) → \(exemptions)）⇒ 治理掉了豁免，这是好方向，不是破例：只需把 docs/bool-exemptions-baseline.json 的 perTarget 跟着降下来，**不必**改 raisedBy / raisedOn / rationale（那三项记的是上一次抬高）。")
                """)
            }
            if counts.sourceSites != sites {
                let raised = sites > counts.sourceSites
                problems.append("""
                逐 target 棘轮：\(target) 的源码位置数 \(sites) ≠ 基线 \(counts.sourceSites)。
                同上——`sourceSites` 的全包合计挡不住跨 target 的一加一减。
                \(raised
                    ? "本次是**抬高**（\(counts.sourceSites) → \(sites)）⇒ 破例，署名同上。"
                    : "本次是**下降**（\(counts.sourceSites) → \(sites)）⇒ 好方向，把基线跟着降下来即可。")
                """)
            }
        }
        return problems
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
        // `Configuration`）⇒ 这条断言当前为空，**不改变** 27 键 / 27 条 / maxEntries=27
        // （sourceSites 30 处；#41 收尾时同步实测值，S-T3-1）。
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
        // ⚠️ **`#246` 多根化后的逐 target 清点**：新 target 今天各是 0，这是**现状**
        // 而不是「守卫覆盖到了」的证据——真正让「新 target 逃出 J-1」判红的是
        // `GuardScanRootsGuard.libraryTargetsAreCoveredByScanRoots`（根列表 vs manifest
        // 双向差集）。这行 print 是让「哪个 target 贡献了几条」在 CI 日志里看得见。
        for root in Self.scanRoots {
            let n = scan.hits.filter { $0.target == root.target }.count
            print("【J-1 逐 target】\(root.target)：\(n) 处")
        }
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
                "豁免清单只有 \(entries.count) 条 —— 下界取 PRD 点名的 10 条 + 两条实测补入（StepItem.init#isError / View.bottomInputBar#autoFocus），低于它疑似没读到或是空壳。⚠️ 原文案写的「10 条 + 两个 glass」已随 #41 裁决 3 过期：两个 glass 已按终局条款 (b) 删除、不再在清单里。")

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

    // MARK: - `#246`：台账键的 target 前缀

    /// 一个台账键的前缀判据，**抽成纯函数**：返回它违反的每一条（合法则空）。
    ///
    /// ⚠️ **抽出来是因为原地写在循环里的版本今天结构性恒绿**（PR #265 终审 S-1）：
    /// 循环体第二行 `guard parameter.contains("/") else { continue }` 对**现存 32 个键
    /// 全部成立**（它们都是裸形），于是下面两条 `#expect` 从来没有被求值过——
    /// 「守卫」与「空循环」不可分辨。这正是本 task 要防的「0 输入恒绿」，只是下沉了一层。
    /// ⇒ 判据搬进纯函数，由 `qualificationValidatorActuallyFires` 用合成键逐条打红。
    static func qualificationProblems(ofKey parameter: String) -> [String] {
        guard parameter.contains("/") else { return [] }   // 裸形 = 主 target，合法
        let target = GuardScanRoots.target(ofKey: parameter)
        var problems: [String] = []
        // ① 前缀必须指向一个**当下真的存在**的 target。
        if !GuardScanRoots.targetNames.contains(target) {
            problems.append("""
            豁免键「\(parameter)」的 target 前缀「\(target)」不在 `GuardScanRoots.targetNames` 里
            —— 要么 target 名写错了，要么它还没落地。挂在不存在的 target 上的豁免永远匹配不到
            任何命中，只会以「过期条目」的面目红掉，诊断绕远路。
            """)
        }
        // ② 主 target 的**唯一**合法拼法是裸形。允许两种拼法 = 同一条豁免有两个键，
        //    差集会把其中一种当成过期条目，而另一种静默生效。
        if target == GuardScanRoots.primaryTargetName {
            problems.append("""
            豁免键「\(parameter)」给主 target 写了显式前缀 —— 主 target 的规范形态是**裸形**
            `Owner.decl#param`（见 `GuardScanRoots.qualifiedKey(target:base:)` 的文档）。
            同一条豁免存在两种拼法时，扫描器只产出其中一种，另一种恒为过期条目。
            """)
        }
        return problems
    }

    @Test("台账键的 target 前缀合法且唯一形态：裸形只属于主 target，带前缀者必须指向已存在的 target")
    func exemptionKeysAreCanonicallyQualified() throws {
        let entries = try Self.loadExemptions()
        #expect(!entries.isEmpty, "豁免清单为空 —— 本判据会在空循环上恒真")

        for entry in entries {
            guard let parameter = entry.parameter else { continue }
            for problem in Self.qualificationProblems(ofKey: parameter) { Issue.record("\(problem)") }
        }
    }

    @Test("前缀判据真的会开火：合成键逐条变红自证（终审 S-1）")
    func qualificationValidatorActuallyFires() {
        // ① 主 target 写了显式前缀 —— 同一条豁免有两个键。
        #expect(!Self.qualificationProblems(ofKey: "CoreDesign/Foo.init#flag").isEmpty,
                "主 target 的显式前缀不会红 —— 上面那条判据在现存 32 个裸形键上从不执行")
        // ② 前缀指向一个不存在的 target。
        // ⚠️ **`#279` 把这里写死的 `"CoreDesignShaders"` 换成了 `nonexistentFixtureTargetName`**：
        // 那个名字在 `#279` 当天变成了**合法** target 名 ⇒ 本条从「反例」退化成「正例」、
        // 静默变绿。反例名必须由一条判据保证它真的不存在
        // （`GuardScanRootsGuard.nonexistentFixtureTargetIsReallyAbsent`）。
        #expect(!Self.qualificationProblems(
            ofKey: "\(GuardScanRoots.nonexistentFixtureTargetName)/Foo.init#flag"
        ).isEmpty, "不存在的 target 前缀不会红")
        // ③ 反向：合法形态不误报。
        #expect(Self.qualificationProblems(ofKey: "CoreDesignEffects/Foo.init#flag").isEmpty,
                "合法的新 target 前缀被误报")
        #expect(Self.qualificationProblems(ofKey: "Badge.init#outlined").isEmpty,
                "主 target 的裸形键被误报")
    }

    // MARK: - Task 4 的判据：双向精确匹配

    @Test("J-1：public 声明不得含未豁免的 Bool 参数")
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

        ⚠️ **#41 之后这里预期为空**：`View.surface#bordered` 这条历史例外已随裁决 1 消失，
        `pendingViolationKeys` 也已清空 ⇒ 本断言不再有 `withKnownIssue` 包裹，是裸判据。
        新增的 Bool 参数要么改掉，要么按公约第 3 节终局条款**先试 (b) 删除**、
        (b) 不成立才走 (a) 记入豁免基线（并同轮抬高 bool-exemptions-baseline.json 的 maxEntries）。
        """

        // ⚠️ **#41 裁决 1 落地：原先那条 `withKnownIssue` 块已删除**。
        // 它包住的唯一断言就是下面这句；`View.surface#bordered` 的参数消失后块内不再
        // 记录 issue，Swift Testing 会判「Known issue was not recorded」而主动红——
        // 这是 #39 刻意设计的机器强制到期（不依赖任何人给 #41 加 AC），本轮如期触发。
        // 现在 J-1 的字面陈述是**裸断言**：任何未豁免的 public Bool 参数直接判红。
        #expect(diff.violations.isEmpty, "\(violationMessage)")
    }

    /// ⚠️ **本条是「新违规」的唯一非 known-issue 出口**：`j1NoUnexemptedBoolParameters`
    /// 里原先包住新违规断言的 `withKnownIssue` 块已在 #41 裁决 1 落地时随
    /// `View.surface#bordered` 一起删除（见该判据 `:487` 的说明）——现在两条判据都是
    /// 裸断言，本条不再是「known issue 之外唯一能抓新违规」的独占出口。但断言逻辑本身
    /// 仍然正确：`pendingViolationKeys` 现为空集 ⇒ `unexpected` 恒等于
    /// `diff.violations`、`disappeared` 恒为空 ⇒ 本条在空集上继续正确工作，留作「若
    /// 未来公约又新增一条待处置例外」时的现成骨架（#41 收尾时更新，S-T2-1）。
    @Test("未豁免违规集合与 pendingViolationKeys（现为空集）恰好相等（这条是**绿**的，专抓新违规）")
    func j1ViolationSetIsExactlyTheContractPending() throws {
        let scan = try Self.boolScan()
        #expect(scan.keys.count > 20, "只扫到 \(scan.keys.count) 个豁免键 —— 扫描器失效")

        let diff = compareBoolHitsToExemptions(hits: scan.keys, exempted: try Self.exemptedKeys())
        let unexpected = diff.violations.subtracting(Self.pendingViolationKeys)
        #expect(unexpected.isEmpty,
                "出现了公约未预期的未豁免 Bool 参数：\(unexpected.sorted()) —— pendingViolationKeys 现为空集，没有任何预期的红，出现即是新增违规")

        let disappeared = Self.pendingViolationKeys.subtracting(diff.violations)
        let disappearedMessage = """
        这些条目已不再是未豁免违规：\(disappeared.sorted())
        —— 若 #41 已经删除/改造了它们，请**同轮**把它们从 pendingViolationKeys 移走
        （若改造成了别的形状而仍带 Bool，还要同轮进豁免清单 + 抬高 maxEntries）。
        本条断言的存在就是为了不让这个待办被忘掉：它不会自己保鲜，所以由判据保鲜。
        """
        #expect(disappeared.isEmpty, "\(disappearedMessage)")
    }

    @Test("棘轮：豁免清单条目数与基线 maxEntries 严格相等、源码位置数与 sourceSites 严格相等，且基线自身字段齐全")
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

        // ⚠️ **Task 8 终审 I-3 通道 B 的机器闸**：`keys.count`（去重后的豁免键集合）
        // 与 `maxEntries` 的等式拦不住「新增一个 public 声明，但它的键恰好已经在清单里」
        // 这种**键碰撞**——`BoolParamHit.key` 只按 `Owner.decl#param` 聚合，两处不同的
        // 源码位置可以共用同一个键（本仓当前真实的键碰撞：`Tag.init#removable` 2 处、
        // `SidebarNavigationRow.init#isSelected` 2 处、`Badge.init#outlined` 2 处
        // ——27 个键、30 处源码位置，多出的 3 正好是这三次碰撞，见
        // `scannerFindsPublicBoolParameters` 的 print 明细）。新增一个键碰撞不会让
        // `keys.count` 或清单条目数变化，棘轮对它不可见；
        // 唯一会变化的量是 `hits.count`（源码位置数），而它此前只有
        // `scannerFindsPublicBoolParameters` 里的量级下界 `> 20`、真实数字只出现在
        // `print` 里，从未被任何等式钉住。这里补一条与 `maxEntries` 同款的严格相等，
        // 把这条通道纳入同一份「抬高需要署名」的台账（见 `Baseline.sourceSites` 文档）。
        guard let sourceSites = baseline.sourceSites else {
            Issue.record("棘轮基线缺 sourceSites 字段 —— Task 8 终审补的键碰撞棘轮无法工作")
            return
        }
        #expect(sourceSites > 0, "sourceSites=\(sourceSites) —— 零不是「很严」，是判据没配置")
        let scan = try Self.boolScan()
        #expect(scan.hits.count == sourceSites, """
        豁免键碰撞棘轮：源码里的 Bool 参数位置数 \(scan.hits.count) ≠ 基线 sourceSites \(sourceSites)。
        `keys.count` 与 `maxEntries` 的等式拦不住「新增一个 public 声明但它的键已在清单里」这种键碰撞
        ——它不增加 `keys.count`，只增加 `hits.count`。若这个数变了，请核实是否出现了新的键碰撞
        （多处源码位置共用同一个豁免键），并**同轮**更新 docs/bool-exemptions-baseline.json 的
        sourceSites（连同 raisedBy / raisedOn / rationale，与 maxEntries 走同一套破例流程）。
        """)

        // ⚠️ **终审 S-e 补的两颗牙**：`Baseline` 文档里那条「抬高时 rationale 必须写明来自
        // 哪个 target」此前**只是约定**——`scripts/bool-exemptions-ratchet.sh` 对它一无所知
        // （抬高时只比较 rationale 是否逐字变了，然后 warning + `exit 0`）。
        for problem in Self.rationaleTargetProblems(baseline.rationale) { Issue.record("\(problem)") }
        for problem in Self.perTargetProblems(
            perTarget: baseline.perTarget,
            exemptionKeys: try Self.loadExemptions().compactMap(\.parameter),
            hits: scan.hits
        ) { Issue.record("\(problem)") }
    }

    @Test("棘轮的两颗新牙真的会开火：合成基线逐条变红自证（终审 S-e）")
    func ratchetTeethActuallyFire() {
        // ① rationale 不点名任何 target ⇒ 红。这正是终审要求实证的那个输入：
        //    「抬高了基线，但 rationale 里一个 target 名都没有」。
        #expect(!Self.rationaleTargetProblems("""
        这条理由写得又长又像模像样，凑够了四十个字符以上，也换了措辞因此过得了
        scripts/bool-exemptions-ratchet.sh 的逐字比较，但它一个 target 名都没写。
        """).isEmpty, "不点名 target 的 rationale 不会红 —— 那条「必须」就仍然只是约定")
        // 反向：点名了就该干净。
        #expect(Self.rationaleTargetProblems(
            "本次抬高来自 CoreDesignEffects 的第一个动效组件，理由写足四十字符以上。"
        ).isEmpty)
        #expect(!Self.rationaleTargetProblems(nil).isEmpty, "缺 rationale 不会红")

        // ② 逐 target 计数：**跨 target 对冲**（删一个 CoreDesign 的 + 加一个 Effects 的）
        //    在合计上纹丝不动，这里必须红。
        func hit(_ target: String, _ owner: String) -> BoolParamHit {
            BoolParamHit(owner: owner, decl: "init", parameter: "flag",
                         file: "X.swift", line: 1, target: target)
        }
        // ⚠️ **`#279` 起由 `GuardScanRoots.targetNames` 派生，不再逐字列 target**：
        // 原写法硬列三个名字，`#279` 加进第四个 target 的当天，`perTargetProblems` 的
        // 「键集合必须吻合」那一条会对**本 fixture 的每一次调用**开火 ⇒ 下面几条
        // 「反向：对得上就该干净」的 `isEmpty` 断言全部变红，而它们与本条要证的
        // 跨 target 对冲毫无关系。派生之后新增 target 不再顶动本 fixture。
        var baseline: [String: Baseline.TargetCounts] = [:]
        for name in GuardScanRoots.targetNames {
            baseline[name] = .init(exemptions: 0, sourceSites: 0)
        }
        baseline[GuardScanRoots.primaryTargetName] = .init(exemptions: 2, sourceSites: 2)
        // 合计不变（2 条豁免 / 2 处位置），但一条从主 target 挪到了 Effects。
        let hedged = Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag", "CoreDesignEffects/B.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesignEffects", "B")]
        )
        #expect(!hedged.isEmpty, """
        跨 target 对冲不会红 —— 删一个 CoreDesign 的 Bool、加一个 Effects 的，
        `maxEntries` / `sourceSites` 两个合计都不变，定义域却已经漂了。
        """)
        // 反向：对得上就该干净。
        #expect(Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag", "C.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesign", "C")]
        ).isEmpty)
        // ③ 缺字段 / 键集合缺 target ⇒ 红（fail-closed，不退化成「零差异 ⇒ 绿」）。
        #expect(!Self.perTargetProblems(perTarget: nil, exemptionKeys: [], hits: []).isEmpty,
                "缺 perTarget 字段不会红 —— 跨 target 对冲会重新变成盲区")
        #expect(!Self.perTargetProblems(
            perTarget: [GuardScanRoots.primaryTargetName: .init(exemptions: 0, sourceSites: 0)],
            exemptionKeys: [], hits: []
        ).isEmpty, "perTarget 少列一个 target 不会红 —— 那个 target 就有了免审额度")

        // ④ **失败文案按方向分两支**（PR #265 第 4 轮终审 S-1）：这条判据是严格等式，
        //    计数**下降**（治理掉一个 Bool）同样判红，而那是好方向——对它说
        //    「请同轮更新 raisedBy / raisedOn / rationale」语义不贴切。
        let raised = Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag", "C.init#flag", "D.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesign", "C")]
        )
        #expect(raised.contains(where: { $0.contains("抬高") && $0.contains("破例") }),
                "抬高方向的文案没说这是破例：\(raised)")
        let lowered = Self.perTargetProblems(
            perTarget: baseline,
            exemptionKeys: ["A.init#flag"],
            hits: [hit("CoreDesign", "A"), hit("CoreDesign", "C")]
        )
        #expect(lowered.contains(where: { $0.contains("下降") && $0.contains("好方向") }),
                "下降方向仍在用「破例」口吻：\(lowered)")
        #expect(!lowered.contains(where: { $0.contains("下降") && $0.contains("连同 raisedBy") }),
                "下降方向仍在要求补署名 —— 治理掉一个豁免不是破例")
    }

    @Test("豁免宿主要么在登记表里，要么在 AD 台账里且该分类真的成立")
    func exemptionOwnersReconcileWithRegistry() throws {
        let registered = Set(
            try ComponentRegistryGuard.loadRegistry()
                .filter { $0.repo == "coredesign" }.map(\.component)
        )
        #expect(registered.count > 30, "登记表只读到 \(registered.count) 条 coredesign 条目 —— 疑似没读到")

        let scan = try ComponentRegistryGuard.componentScan()
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
        // ⚠️ **`#48` G-2：`styleImpls` 的非空前置** —— 新增的排他条
        // `!scan.styleImpls.contains(root)` 在该集合**为空时恒真放行（fail-open）**，
        // 而此前的五条非空前置（registered / components / readmeRows / readmeNames /
        // declaredTypeNames）**没有一条守它**。
        // ⚠️ 别拿「`.styleImplementation` 的正向条会在空集上判红」当后备 —— 那要等
        // 全表遍历落地**且**台账里仍有该分类的行才成立，是**条件性**后备，不是前置。
        #expect(scan.styleImpls.count > 3,
                "扫描器只采到 \(scan.styleImpls.count) 个样式实现 —— 疑似扫描失效；下面 .nonViewPublicType 的排他条会在空集上恒真放行")
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
            // ⚠️ 分类核对**不在这里做** —— 统一交给下面的**全表 pass**（`#48` G-2）。
            // 上一版在这里也调一次 `assertOwnerClassification`，于是有 11 个活豁免键的
            // `View` 会被断言 **12 次**（11 次键遍历 + 1 次全表）。断言是纯函数、结果必然
            // 一致，**不是正确性问题**，但失败时会打印 12 条重复 Issue —— 诊断噪音
            // （PR #211 本地 Copilot CLI 复审第 3 条）。
            //
            // ⚠️ **本循环保留的职责是另一件事**：豁免键的宿主必须「已登记 ∨ 在台账」，
            // 否则进 `unaccounted` 判红。那条**只有按豁免键遍历才做得到**，全表 pass
            // 替代不了它。
            _ = kind
        }

        // ⚠️ **`#48` G-2：全表 pass** —— 上面的循环按**豁免键**遍历，于是「休眠」宿主
        // （台账里有、但已无任何活豁免键指向它）**根本不被访问** ⇒ 它们的分类标注
        // **零覆盖**，腐了也没人知道。#41 删掉 `glass` 之后 `SolidButtonStyle` /
        // `LightButtonStyle` 正是这个状态。
        //
        // ⚠️ **这是「新增」不是「替换」**：上面的键遍历还负责「豁免键的宿主必须
        // 已登记 ∨ 在台账」（`unaccounted` 判红），换掉它会丢掉那条。
        for (owner, kind) in Self.ownersWithoutRegistryEntry {
            Self.assertOwnerClassification(
                owner: owner, kind: kind, scan: scan,
                declaredTypeNames: declaredTypeNames, readmeNames: readmeNames
            )
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
