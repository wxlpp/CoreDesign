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
// ⚠️ **例外（终审 I4 收窄，AD-2 同步）**：`Toast` 是「以 README 行名命名的聚合条目」——
// 它的 public 表面由 `ToastHost`/`ToastItem`/`ToastDefaults` 三个类型组成，登记表按
// README 行名 `Toast` 记一条，不拆成三条按类型登记。这不是推翻上一条不变量，而是 AD-2
// 收窄后的复合条件（「有 public 类型的 API 表面 **且被 README 组件索引收录**」）在
// 「一行对应多个非 View/ViewModifier 类型」时的落地方式——见
// `docs/component-contract.md` AD-2 裁决「终审 I4 收窄」段。
//
// ⚠️ **本守卫只覆盖 CoreDesign 侧**（裁决 D2）。StoryUI 侧的源码↔登记表比对移交 #43
// —— CI 三个 job 都只 checkout 本仓，读另一个（私有）仓会让本仓 CI 永久红。
// 登记表**仍收全两仓**，只是 StoryUI 侧的条目在 #43 落地前无机器拦截。
//
// ⚠️ **终审 C1 第 3 点——README 索引 ↔ 登记表对账，一次性人工核对结果（历史记录）**：
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
//     的「第四个盲区」文档）。已在终审 C1 处置：`Toast` 补登记表 + 加入
//     `knownOffScannerComponents` 白名单；`BottomInputBar` **当时**定性为排除，写死进
//     `docs/component-contract.md` AD-2 与 oh-my-story 的 `38-plan.md` 排除清单。
//     ⚠️ **`BottomInputBar` 那一半已被 #221 取代**：它提为 public 后按判定法正常登记，
//     不再是排除项。本段保留为 C1 当时的处置记录。
// ⇒ 处置后：37 = 37 有归宿，0 漏网。
//
// ⚠️ **终审第 2 轮 I1：上面这段「37 = 37」已机器化，不再只是注释**——见
// `readmeIndexReconcilesWithRegistry` 测试。理由：注释里这份对账**不会自己保鲜**——
// 整个 `Tests/` 下此前没有一处真的读 `docs/README.md`，`Toast`/`BottomInputBar` 这两行
// 漏网恰恰就是靠「下次新增行时人工核对本注释」这种机制没能发现的，继续只写注释等于把
// 已经证伪的机制原样再用一次。下面这条判据把「README 第一列的每个候选名，必须落进
// 登记表 / styleImpls / 已知墓碑 / 已知排除四个桶之一」变成断言，本节的散文对账结果
// 保留作**已归档的一次性核对记录**，不再是判据本身的落点。
@Suite("组件登记表")
struct ComponentRegistryGuard {

    struct Entry: Codable {
        let component: String
        let repo: String                    // coredesign | storyui
        let kind: String                    // semantic | prescriptive | excluded
        let decidedBy: String               // step1|step2|step3|tiebreaker|precedent|exclusion|pendingStep2
        let nativeProtocol: String?         // Apple 原生协议名
        let customStyleProtocol: String?    // 自有协议名
        // ⚠️ 形态 D（`docs/component-contract.md` §2「样式扩展点：四选一」，由 `D-59-1` 裁定）。
        // D1 外观槽：写 `TypeName.paramName`（如 `TimelineItem.node`）；D2 配置枚举：写枚举名。
        // ⚠️ **只在「该组件的候选形态能被这个槽/枚举完整承载」时才填** —— 覆盖不全就别填，
        // 填了不覆盖比不填更糟（J-2 会判绿，而设计空间其实没开）。J-2 只能核「源码里真的
        // 存在这个槽/枚举」，**核不了「够不够」** —— 那是作者的判断，须在 notes 写明。
        let styleSlot: String?              // 形态 D1：`TypeName.paramName`
        let styleEnum: String?              // 形态 D2：公开枚举名
        // ⚠️ 上两者必须分开（裁决 D3）：#40 的 J-3 是「标注了 nativeProtocol 的组件
        // 源码中不得出现自定义样式协议符号」—— 一字段两用会让 SegmentedControl
        // 被自己的协议判红。
        let needsExtensionPoint: Bool
        let textParams: [TextParam]
        let notes: String

        /// 只换 `decidedBy` 的副本 —— 只服务 `pendingStep2LedgerIsLoadBearing` 的两个变异，
        /// **不要**拿它去改真实登记表（登记表的唯一来源是 `docs/component-registry.json`）。
        func withDecidedBy(_ value: String) -> Entry {
            Entry(
                component: self.component, repo: self.repo, kind: self.kind, decidedBy: value,
                nativeProtocol: self.nativeProtocol, customStyleProtocol: self.customStyleProtocol,
                styleSlot: self.styleSlot, styleEnum: self.styleEnum,
                needsExtensionPoint: self.needsExtensionPoint,
                textParams: self.textParams, notes: self.notes
            )
        }
    }
    struct TextParam: Codable { let name: String; let category: String }  // A|B|C|by-type

    static let validKinds: Set<String> = ["semantic", "prescriptive", "excluded"]
    static let validDecidedBy: Set<String> = [
        "step1", "step2", "step3", "tiebreaker", "precedent",
        "exclusion",   // ⚠️ 弃用条款先于步骤 1–4，AC 的五个取值没有一个对应它
        // ⚠️ **`pendingStep2` 不是判定法的第七个出口，是「还没判」这件事本身**
        // （PR #297 终审 I-1）：公约步骤 2 的停止规则写着「不满足停止规则 ⇒ 枚举视为
        // 未完成，**不得据以走任一出口**，补足后重判」。`#270` 有 6 条条目的候选枚举
        // 与来源核验**一次都没做**，却援引步骤 3 门槛的兜底句（「重跑至多一次；**重跑后**
        // (A) 仍不成立 ⇒ 落步骤 4」）落了 `tiebreaker` —— 那句**以「重跑发生过」为前置**，
        // 一次都没做时它不成立；公约另有一条直接点名「败在 (A)（诚实枚举后其实举得出
        // ≥2 个非皮肤候选）⇒ **不是 tiebreaker**」。
        // ⇒ 与其在机器读的数据文件里写一个**合约不支持的出处声称**（且与另外 9 条正当的
        // `tiebreaker` 判定**无法区分**），不如另起一个取值如实说「没判」：条目按**可逆的
        // 那一侧**（`prescriptive` / 不给扩展点）缓办登记，落点留给 `#299` 补做枚举后重判。
        // ⚠️ 新增本取值同时触发公约「判定法枚举的三方同步义务」⇒ 已回写
        // `docs/component-contract.md`（`contractMentionsEveryGuardAllowedValue` 会核）、
        // 记入 `docs/contract-defects.md`（`D-270-1`）、台账 `docs/component-contract-revisions.md`（`R-47`）。
        "pendingStep2",
    ]
    static let validCategories: Set<String> = ["A", "B", "C", "by-type"]
    static let validRepos: Set<String> = ["coredesign", "storyui"]

    /// `decidedBy` ⇒ `kind` 的强制映射（公约 `docs/component-contract.md` 的 Tiebreaker 小节
    /// ——「**默认判为规定性组件 / 不给扩展点**，并在登记表里记 `kind: prescriptive` +
    /// `decidedBy: tiebreaker`」那句：
    /// 「tiebreaker ⇒ prescriptive」、步骤 3 ⇒ 规定性、步骤 1/2 ⇒ 语义、祖父条款
    /// （`precedent`）⇒ semantic）。⚠️ 终审 M1：`38.md` 点名「AC 要求而守卫不查
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
        // ⚠️ 缓办也必须落在**可逆的那一侧**：公约自陈「少给扩展点可逆 / 多给不可逆」
        // （public 协议一旦发布，删它是破坏性变更）⇒ `pendingStep2` ⇒ `prescriptive`。
        // 这不是「判成了规定性」，是「在补足枚举之前先站到能撤回的那一边」。
        "pendingStep2": "prescriptive",
    ]

    // MARK: - 缓办台账：步骤 2 枚举未完成的条目（PR #297 终审 I-2）

    /// 承接 issue 号。**写成常量并被下面的断言引用**，而不是只出现在散文里 ——
    /// 散文里的指针没有任何东西核对它是否还在。
    static let pendingStep2FollowUpIssue = "#299"

    /// `decidedBy == "pendingStep2"` 的条目名单。
    ///
    /// ## ⚠️ 为什么这张表必须存在（散文留不住这次缓办）
    ///
    /// `#270` 有 6 条条目跳过了公约步骤 2 的候选枚举与来源核验。初版的处置是**只在
    /// `notes` 里写明**——而本文件顶端那段注释已经为同一种失效付过一次代价，逐字：
    /// 「注释里这份对账**不会自己保鲜**……继续只写注释等于把已经证伪的机制原样再用一次。」
    /// 同一论证逐字适用于这 6 段 `notes`：
    /// · 它们与另外 9 条正当的 `tiebreaker` 判定在数据上**曾经完全同形**（同 `kind`、同
    ///   `decidedBy`）⇒ 永远不会有东西判红，删掉标记没人知道，新增一条也没人知道；
    /// · `docs/contract-defects.md` 与承接 issue 都是**人**要去读的，不是机器要读的。
    ///
    /// ⇒ 落成**双侧等式**（形态照搬 `ComponentTextParamGuard.knownUnmappedOwnerParams` /
    /// `knownFunctionSideBareText`）：**缩小要删标记、增大要过评审**。
    /// 变红时的正确处置是**补做枚举并按公约重判**（`#299`），不是改这张表让它变绿。
    ///
    /// ⚠️ **6 条而不是 5 条**：`OrbitingLogos` 是 PR #297 终审 I-3 从「干净的 10 条」里
    /// 挪进来的 —— 它的 `notes` 曾把「换轨道形状」判成「同一槽内的画法变化 ⇒ 装饰」，
    /// 而公约的**排布**定义是「子视图之间的空间关系改变」；把 logo 从圆轨道改成椭圆 / 螺旋
    /// 改变的正是它们**彼此之间**的落点 ⇒ 命中排布、本该计入 ≥2。⇒ 与另外 5 条同因。
    ///
    /// ⚠️ **空集时本表退化为「不许再有 pendingStep2 条目」，语义更强不是更弱** ——
    /// `#299` 收口后 6 条全部离开本取值，届时把这张表清空即可。
    static let knownPendingStep2Enumeration: Set<String> = [
        "ActivityHeatmap", "BeforeAfterSlider", "NetworkGraph",
        "OrbitingLogos", "RadarChart", "RingChart",
    ]

    /// 纯函数：登记表里 `decidedBy == "pendingStep2"` 的条目名集合。
    ///
    /// ⚠️ 抽成纯函数是为了让「删一条标记 ⇒ 判红 / 加一条未登记的 ⇒ 判红」这两个方向
    /// 能在 **CI 里常驻**证伪，而不是靠一次性手工改文件的 transcript
    /// （与 `compareRegistryToScan` 抽出来的理由同型，见本文件顶端）。
    static func pendingStep2Components(in entries: [Entry]) -> Set<String> {
        Set(entries.filter { $0.decidedBy == "pendingStep2" }.map(\.component))
    }

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
    /// 现状只有 `Toast` 一条。
    /// ⚠️ **`BottomInputBar` 曾是这段说明里的第二个例子**（当时它「同样没有 public
    /// 表面类型、走排除而非登记」）——#221 把它提为 public 后，扫描器**能采到它**，
    /// 它已按判定法正常登记，既不在本白名单也不在排除集合里。此处保留为成因记录。
    static let knownOffScannerComponents: Set<String> = ["Toast"]

    // MARK: - README 索引 ↔ 登记表对账（终审第 2 轮 I1）

    /// 墓碑行：源码已整体删除或从未落地，不需要登记表条目，也不应该再出现在 `scanned` 里
    /// （若出现，说明组件「复活」了，需要回填登记表并把名字从这张表移走）。
    static let knownReadmeTombstones: Set<String> = ["Typography", "EmptyState"]

    /// 显式排除：裁决明确「不登记」的 README 行名。现存唯一一条是 `FlowLayout`
    /// （裁决 D1：Layout 不是组件）。同样反向不得出现在 `scanned` 里——出现即说明
    /// 源码形态变了，排除裁决需要重新核对。
    /// ⚠️ **`BottomInputBar` 已于 #221 移出本集合**：它此前在这里，依据是终审 C1
    /// 「struct 无 public 修饰符 ⇒ 没有可被 `PublicTypeCollector` 采集的 public 类型
    /// ⇒ 排除」。#221 走了 C1 自己给的第二条出路（给它一个可登记的 public 类型表面），
    /// 排除的**前提已经消失**，故按判定法正常登记、从排除集合移除。
    /// 保留这段说明是因为：`resurrectedExclusions` 判据的存在意义正是逼人**重新裁决**
    /// 而不是顺手把名字删掉——裁决过程写在 `component-registry.json` 的 notes 里。
    static let knownExcludedReadmeRows: Set<String> = ["FlowLayout"]

    /// AD-3 裁决覆盖的「style 实现，不是登记表条目」行：这些 README 主名本身不是
    /// public View/ViewModifier 类型（`Button`/`FloatButton` 是套了自定义 `ButtonStyle`
    /// 的原生 `Button`，`.core Control Styles` 是套了 `.core` style 的原生系统控件），
    /// 因此永远不会出现在 `registered` 里，也不指望出现在 `scanned` 里——它们的存在性
    /// 由 `scannerFindsCoreDesignTypes` 打印的 `styleImpls` 清单与 AD-3 裁决本身覆盖。
    ///
    /// ⚠️ **不是纯白名单——每一项都绑定「扫描器必须真的采到的 style 实现」**
    /// （PR #193 Copilot 第 3 轮 suppressed comment）：第一版只有一个名字集合，
    /// 于是这三行是被**硬编码放行**的，`styleImpls` 一次都没被用到——测试名却写着
    /// 「登记表 / styleImpls / 已知墓碑 / 已知排除**四选一**」。后果不只是描述不实：
    /// 把 `Sources/CoreDesign/Components/Style/` 整个删掉，这三行照样绿。
    /// ⇒ 改成映射，值是该行必须存在的 style 实现类型名；判据要求它们真的出现在
    /// `componentScan().styleImpls` 里，把白名单变成**承重**的判据。
    static let knownStyleAnnotationRows: [String: Set<String>] = [
        // 这三个是 `Button` 行背后的 ButtonStyle 实现（README 行名本身不是类型名）。
        "Button": ["SolidButtonStyle", "LightButtonStyle", "CoreBorderlessButtonStyle"],
        // README 行自己就把这两个名字写在括号里：`FloatButton（ExtendedFloatButtonStyle / …）`。
        "FloatButton": ["ExtendedFloatButtonStyle", "CircularGlassButtonStyle"],
        // `.core` Control Styles（ProgressView / Label / DisclosureGroup）——AD-3 点名的三个,
        // 外加同族的 `CoreLabeledContentStyle`。
        ".core Control Styles": [
            "CoreProgressViewStyle", "CoreLabelStyle", "CoreDisclosureGroupStyle", "CoreLabeledContentStyle",
        ],
    ]

    /// README 行里与主组件同格但本身不是 `View`（因此不登记、不进 `scanned`）的辅助类型。
    /// 现状只有 `RadioOption`：`RadioGroup / RadioOption` 一行，`RadioOption` 是
    /// `Identifiable & Sendable` 的数据结构，不是 `View`。
    static let knownReadmeAuxiliaryNames: Set<String> = ["RadioOption"]

    /// README 行名与登记表条目名不同字面量的别名（现状只有 `spinning`：README 行用的是
    /// modifier 函数名 `View.spinning(_:text:)`，登记表与扫描器认的是类型名
    /// `SpinningModifier`）。
    static let knownReadmeAliases: [String: String] = ["spinning": "SpinningModifier"]

    /// README 索引行名 → `component-registry.json` `entryPoints` 里的**成员名**
    /// （`View.confetti` 的 `confetti`）。`#270` 随「动效与图表索引进入定义域」新增。
    ///
    /// ⚠️ **只收「行名与成员名确实不同」的两条**：`## 动效与图表索引` 里 24 行的行名
    /// 与成员名逐字相同（`shake` ↔ `View.shake`），直接命中上面的成员名匹配；
    /// 只有这两行按**类型名**列（`Confetti` 是 `ConfettiLayer` 那一整套的俗名、
    /// `ParticleTransition` 是转场类型名），而它们的公开入口分别是
    /// `View.confetti` 与 `Transition.particle`。
    /// ⚠️ **不许靠「大小写不敏感」把 `Confetti` 混过去** —— 那会顺带放行任何大小写写错的
    /// 行名。显式两条，且由 `readmeEntryPointRowsAreLoadBearing` 断言「每条都真的被用到」。
    static let knownReadmeEntryPointRows: [String: String] = [
        "Confetti": "confetti",
        "ParticleTransition": "particle",
    ]

    /// README 行名是「容器名」、登记表按子类型分别登记（不存在与容器同名的条目）时，
    /// 只要求登记表里存在以该前缀开头的条目。现状只有 `Sidebar`：README 一行索引，
    /// 登记表按 `SidebarDocumentRow` / `SidebarNavigationRow` / `SidebarSection` /
    /// `SidebarStatusFooter` / `SidebarTagRow` / `SidebarUtilityRow` 六条子类型分别登记，
    /// 没有一条叫 `Sidebar`。
    static let knownReadmeContainerPrefixes: [String: String] = ["Sidebar": "Sidebar"]

    // MARK: - README 行 → 登记条目的聚合映射（`#48` G-3）

    /// 一条 README 索引行**覆盖**哪些登记条目。
    ///
    /// ## 为什么需要它
    ///
    /// `readmeIndexReconcilesWithRegistry` 此前只做 **README → 登记表**一个方向：
    /// 索引**缺行不会红**。补反向断言时实测落差 **11/45 ≈ 24%** —— 但那 11 条**全部是
    /// 结构性的合法未索引**（六条 `Sidebar*` 子行的父行在 README、`SettingsRowChevron`
    /// 与 `AsyncButton` 同理、三条 `*Modifier` 根本不是组件行）。
    ///
    /// ⚠️ 而现有解析器 `candidateNames(fromReadmeCell:)` 在**首个括号处截断**、按 `/` 切分
    /// ⇒ `Sidebar` 行只产出 `["Sidebar"]`、`spinning（…）` 行只产出**小写** `["spinning"]`，
    /// 11 条**一条都对不上**。⇒ 不是「小白名单」量级，需要**聚合映射**。
    ///
    /// ## ⚠️ 两个方向共用这一份数据
    ///
    /// `resolveReadmeCandidate`（正向）与反向断言**都**从本表派生。上一版的容器前缀表
    /// 只服务正向；若反向另起一张表，两个方向会各自漂移、将来只改一边 —— 那正是本表
    /// 要防的（`#38`「白名单必须升级成映射」的教训）。
    ///
    /// ## key 与 value 的不对称
    ///
    /// **key 是 README 的行名，不要求自身是登记条目**（`Sidebar` / `Button` 都不是）；
    /// **value 必须条条是真条目**（由 `ComponentRegistryGuard` 的自洽守卫钉死）。
    /// `readmeRowCoverage` 里**没有结构关系**、但确有正当理由的 (行名, 条目) 对。
    ///
    /// ⚠️ **当前为空** —— 五条映射的 value 全部与 key 有前缀或去后缀关系。
    /// 这张表存在的意义是：把「结构性判据挡不住的例外」变成**显式、需要写理由的**动作，
    /// 而不是把结构性判据本身放宽。⚠️ 往这里加东西前先问：是不是该给它补一条 README 行。
    static let readmeCoverageStructuralExemptions: [String: Set<String>] = [
        // `Button` 行覆盖 `AsyncButton`：命名上 `AsyncButton` 不以 `Button` 为前缀
        // （前缀是 `Async`），但它就是 Button 族的异步变体，README 的 Button 行展示了它。
        "Button": ["AsyncButton"],
        // `FloatButton` 行覆盖两个 modifier：它们提供该行展示的浮动按钮外观，
        // 命名上与行名无前缀关系（一个是 `Floating*`、一个是 `Telegram*`）。
        "FloatButton": ["FloatingGlassModifier", "TelegramGlassButtonModifier"],
    ]

    static let readmeRowCoverage: [String: (entries: Set<String>, reason: String)] = [
        "Sidebar": (
            ["SidebarSection", "SidebarNavigationRow", "SidebarUtilityRow",
             "SidebarDocumentRow", "SidebarTagRow", "SidebarStatusFooter"],
            "Sidebar 行覆盖全部子行；子行不单列索引"
        ),
        "SettingsRow": (
            ["SettingsRow", "SettingsRowChevron"],
            "SettingsRow 行覆盖它的内部部件 SettingsRowChevron"
        ),
        "Button": (
            ["AsyncButton"],
            "Button 行覆盖 AsyncButton（同一按钮族的异步变体）"
        ),
        "spinning": (
            ["SpinningModifier"],
            "README 行名是 modifier 的调用名 spinning，与类型名 SpinningModifier 大小写/后缀均不同，必须显式映射"
        ),
        // ⚠️ `#270`：`Shine` 是 `shine` 那一行的**第二种形态**。`docs/components/shine.md`
        // 首段逐字写着「两种形态，同一套实现」——`View.shine(trigger:highlight:)` 与
        // 容器 `Shine { }`。README 的动效索引按**入口点名**（小写 `shine`）列行，
        // 于是容器类型 `Shine` 没有属于自己的行。⇒ 挂到同一行下，而不是给同一份实现
        // 再开一行索引。（结构关系成立：`Shine`.lowercased() 以行名 `shine` 为前缀。）
        "shine": (
            ["Shine"],
            "shine.md 同时收录 View.shine 修饰符与容器形态 Shine，README 按入口点名列行，容器类型挂在同一行下"
        ),
        "Skeleton": (
            ["SkeletonLine", "SkeletonRect", "SkeletonCircle"],
            "三种骨架形状写在 Skeleton 行的括号里，而解析器在首个括号处截断、不递归解析括号内容"
        ),
        "FloatButton": (
            ["FloatingGlassModifier", "TelegramGlassButtonModifier"],
            "两个 modifier 服务于 FloatButton 行展示的浮动按钮外观，不单列索引"
        ),
    ]

    /// 从 README 组件索引表的第一列原始文本里提取候选名。
    ///
    /// ⚠️ **只解析括号前的主名 + 顶层 `/` 切分，不递归解析括号内容**：括号里可能是
    /// 子类型枚举（`Skeleton（SkeletonLine / ...）`）、style 实现清单
    /// （`FloatButton（ExtendedFloatButtonStyle / ...）`）、纯注释性文字
    /// （`ProgressIndicator（含 text: 文案 init）`）三种不同形状，通用规则区分不出
    /// 「这是需要单独核对的名字」还是「这是一句话注释」——本判据只保证**主名**（能捕获
    /// 「新增 README 行但没登记」这个真正撞上过的失败），括号内容不独立核对，是已知的
    /// 精度上限，不是假装成全量解析。
    static func candidateNames(fromReadmeCell raw: String) -> (names: [String], isTombstone: Bool) {
        let isTombstone = raw.contains("~~")
        var s = raw.replacingOccurrences(of: "~~", with: "")
        s = s.replacingOccurrences(of: "`", with: "")
        let parenChars: Set<Character> = ["（", "("]
        if let idx = s.firstIndex(where: { parenChars.contains($0) }) {
            s = String(s[s.startIndex..<idx])
        }
        let names = s.split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (names, isTombstone)
    }

    /// 单个候选名是否有归宿。四个正常桶 + 墓碑专属桶（`isTombstone` 时才检查
    /// `knownReadmeTombstones`，避免一个正常行的名字意外撞上墓碑清单被放行）。
    ///
    /// ⚠️ **`styleImpls` 是真参数，不是摆设**（PR #193 Copilot 第 3 轮）：style 注记行
    /// 不再靠名字白名单直接放行，而是要求 `knownStyleAnnotationRows` 给它列出的每个
    /// style 实现类型都真的被扫描器采到。测试名里的「styleImpls」这一项此前是空话。
    static func resolveReadmeCandidate(
        _ name: String, isTombstone: Bool, registered: Set<String>, styleImpls: Set<String>,
        entryPointMembers: Set<String>
    ) -> Bool {
        if registered.contains(name) { return true }
        // ⚠️ **墓碑分支必须排在入口点桶之前**（PR #297 终审 P-1）：`#270` 初版把入口点桶
        // 插在这一行**上面**，于是「名字恰好与某个入口点成员相同的墓碑行」会先被入口点桶
        // 认掉、绕过 `knownReadmeTombstones` 的核对 —— 墓碑清单对它形同虚设。
        // 今天无碰撞（墓碑是 `Typography` / `EmptyState`，入口点成员全是小写成员名），
        // 但「今天不可达」不是把顺序写错的理由，调换零成本。
        if isTombstone { return Self.knownReadmeTombstones.contains(name) }
        // ⚠️ **入口点桶（`#270` 新增）**：`## 动效与图表索引` 进入定义域后，那一节里
        // **一半的行不是类型而是入口点**（`shake` / `blur` / `iris` …）——它们按 AD-4
        // 《下游连锁二》登记在 `component-registry.json` 的 `entryPoints` 数组里，
        // 结构上永远不会出现在 `components` 里。⇒ 给它们一个自己的桶，而不是塞进
        // 豁免清单当特例。**匹配的是成员名本身**（`View.shake` 的 `shake`），
        // 大小写敏感、不做模糊比对：README 行名与 Swift 成员名本来就该逐字相同，
        // 放宽成大小写不敏感等于给「行名写错一个字母」发一张通行证。
        // 两个行名与成员名确实不同的（`Confetti` / `ParticleTransition`）走下面的
        // `knownReadmeEntryPointRows` 显式映射，由 `readmeEntryPointRowsAreLoadBearing`
        // 钉住「不许有过期条目、也不许有本来就能直接匹配的多余条目」。
        if entryPointMembers.contains(name) { return true }
        if let member = Self.knownReadmeEntryPointRows[name] { return entryPointMembers.contains(member) }
        if Self.knownExcludedReadmeRows.contains(name) { return true }
        if let required = Self.knownStyleAnnotationRows[name] {
            // 该行背后的 style 实现必须全部还在源码里——删光 `Components/Style/` 就该红。
            return required.isSubset(of: styleImpls)
        }
        // ⚠️ **`#48` G-3：coverage 表排在辅助名单**之前**，两个方向共用同一份数据。
        //
        // ⚠️ **排在哪里是有讲究的**（PR #211 终审 C-1 实测）：上一版把它放在**所有**旧表
        // 之后，结果六个 key **无一能到达它**。逐 key 归因（**对照四张表逐条核过**）：
        //
        //   | key | 旧版在哪条分支返回 |
        //   |---|---|
        //   | `SettingsRow` / `Skeleton` | ① `registered.contains` —— 它们**自身就是登记条目** |
        //   | `Button` / `FloatButton`   | ③ `knownStyleAnnotationRows`（该表的 key 恰好就是这两个）|
        //   | `spinning`                 | ⑥ `knownReadmeAliases`（`"spinning": "SpinningModifier"`）|
        //   | `Sidebar`                  | ⑦ `knownReadmeContainerPrefixes`（`"Sidebar": "Sidebar"`）|
        //
        // **那个分支是彻底的死代码**，而 DocC、公约 G-3 行、`D-48-1` 三处都声称
        // 「两个方向共用同一份数据」。
        // ⇒ 「加上了 consult」不等于「共用」；不可达的 consult 等于没有。
        //
        // ⚠️ **上一版这段注释把四个 key 的归因写错了**（终审复审 I-A）：写成
        // 「`Sidebar`/`spinning` 在 `knownReadmeAuxiliaryNames` 返回、`Button`/`FloatButton`
        // 在 `knownExcludedReadmeRows` 返回」—— 而 `knownReadmeAuxiliaryNames` 只有
        // `["RadioOption"]`、`knownExcludedReadmeRows` 只有 `["FlowLayout"]`
        // （#221 前还含 `BottomInputBar`）。
        // 「死代码」这个**结论**不受影响，但 trace 写错会让下一个读者对两张表的内容得出
        // **在 100 行内就能证伪**的错误认知 —— 而 C-1 之所以是 Critical，正是因为
        // 「三处声称与代码不符」。同一把尺子也量这段注释。
        // ⚠️ 错因：我用一个按**臆想的分支顺序**写的脚本去判，没有对照真实的表内容。
        if let coverage = Self.readmeRowCoverage[name] {
            return coverage.entries.allSatisfy { registered.contains($0) }
        }
        if Self.knownReadmeAuxiliaryNames.contains(name) { return true }
        // ⚠️ **下面两个分支在守卫绿态下不可达**（终审复审 S-A，如实记下）：
        // `coverageTableIsTheSingleSourceOfTruth` 强制「alias / prefix 能推出的覆盖必须
        // 已在 `readmeRowCoverage` 里」⇒ 守卫绿时 `spinning` / `Sidebar` 恒在上面的
        // coverage 分支命中，这里到不了。
        // ⇒ 保留它们是 **belt-and-suspenders**（守卫红时仍有 fallback），**不是**承重通路。
        // ⚠️ 本轮 C-1 的教训正是「不可达的分支 + 活着的声称」—— 所以这里把「不可达」
        // 写在明处，而不是让它继续看起来像在承重。
        if let alias = Self.knownReadmeAliases[name] { return registered.contains(alias) }
        if let prefix = Self.knownReadmeContainerPrefixes[name] {
            return registered.contains(where: { $0.hasPrefix(prefix) })
        }
        return false
    }

    /// `docs/README.md` 里**两个索引小节**的边界（起始标题 → 终止标题）。
    ///
    /// ⚠️ **`#270` 之前只有第一段**：`## 动效与图表索引` 整节落在
    /// `## 生成预览图` **之后**，因此不在解析范围内。这是 `#256` 的**有意选择**，
    /// 它在 README 里逐字写明了理由——「这 40 个单位不是登记条目，写进主索引会让
    /// `readmeIndexReconcilesWithRegistry` 当场判红」。`#270` 把两个新 target 的 public
    /// 类型纳入登记表之后，那个前提消失，反过来变成：**这 14 条登记条目在 README 里
    /// 没有任何行覆盖** ⇒ `registryEntriesAreCoveredByReadme` 判红。
    ///
    /// ⚠️ **为什么扩解析范围而不是把行搬进 `## 组件索引`**：公约 AD-4《下游连锁三》
    /// 写的是「三个 target 全部进主索引」，但它的**论据**是解析范围止于 `## 生成预览图`
    /// 这条工程事实，不是「必须同一个 `##` 标题」这条规范要求；AD-4 自己下一句就写着
    /// 「每行仍须带模块名……那是**可读性要求**」。而按 `import` 分组恰恰是可读性的那一侧
    /// （调用方要知道 `import CoreDesignEffects` 还是 `CoreDesign`）。
    /// ⇒ 保留 `#256` 的分节，把**判据的定义域**扩到两节。
    ///
    /// ⚠️ **这是收紧不是放松**：定义域从**一节**扩到**两节**，第二节的每一行都必须
    /// 在 `resolveReadmeCandidate` 的桶里找到归宿（入口点行由此第一次与
    /// `component-registry.json` 的 `entryPoints` 数组对上账），任何一行落空即红。
    /// ⚠️ **不写现状条数**（PR #297 终审 S-4）：上一版写「定义域从 37 行涨到 77 行」，
    /// 而按 `tableFirstCells` 的真实口径实测是第 1 节 38 行 + 第 2 节 35 行 = 73 行
    /// —— `37` 继承自本文件顶端那段**已归档**的一次性人工核对（那是单节时代的值、
    /// 现已陈旧），`77` 则由一个把**行**与**单位**混为一谈的加法得出
    /// （`iris / wipe / blinds / clock / glare / dissolve` 是 **1 行 / 6 单位**）。
    /// 这正是本 PR 自己往 `docs/component-contract.md` 加的那条纪律要禁的形态：
    /// 「⚠️ **不写现状条数**……那个数字在写下几个月后就成了化石」。
    /// **权威计数在判据里**：`readmeIndexSectionsAllParse` 的逐节下界会在解析失效时判红，
    /// 精确数由它的失败消息给出。
    static let readmeIndexSections: [(start: String, end: String)] = [
        (start: "## 组件索引", end: "## 生成预览图"),
        (start: "## 动效与图表索引", end: "## NFR-1 帧率基准"),
    ]

    /// 抽出 `docs/README.md` 两个索引小节里的表格数据行（跳过表头与分隔行），
    /// 每个元素是该行第一列的原始文本。
    static func readmeIndexRows(_ text: String) -> [String] {
        var out: [String] = []
        for section in Self.readmeIndexSections {
            guard let range = Self.readmeSectionRange(in: text, section) else { continue }
            out += Self.tableFirstCells(in: text[range])
        }
        return out
    }

    /// 一个索引小节在全文里的范围（不含起始标题行本身）。
    ///
    /// ⚠️ **必须锚在行首（`\n` + 标题），不能裸 `range(of: "## …")`**（`#270` 实测踩到）：
    /// README 正文里就有**行内**提到这些标题的地方（本轮改写的 `#256` 落点说明里逐字写着
    /// 「解析范围 `## 组件索引 → ## 生成预览图` 与 `## 动效与图表索引 → ## NFR-1 帧率基准`」）。
    /// 裸子串搜索会把**第二节内部**那句行内提及当成该节的终止标题 ⇒ 整节被截成几行，
    /// 第二节整节静默掉出定义域，而 `rows.count > 20` 这类合计下界**照样成立**
    /// ——正是「解析器失效 ⇒ 空输入 ⇒ 恒绿」那一族。
    /// ⇒ 行内提及一律以 `` ` `` 包裹、位于行中，锚 `\n` 即可与真标题区分。
    /// 这一条同时由 `readmeIndexSectionsAllParse` 的**逐节**下界断言接住。
    static func readmeSectionRange(
        in text: String, _ section: (start: String, end: String)
    ) -> Range<String.Index>? {
        guard let start = text.range(of: "\n" + section.start) else { return nil }
        let end = text.range(
            of: "\n" + section.end, range: start.upperBound..<text.endIndex
        )?.lowerBound ?? text.endIndex
        return start.upperBound..<end
    }

    /// 一段 markdown 里全部表格数据行的第一列。
    ///
    /// ⚠️ **表头行按结构识别，不按字面**（`#270`）：上一版写的是
    /// `guard first != "组件"`，而两个索引小节的表头分别是 `组件` 与 `单位`
    /// ——把 `单位` 也加进字面清单只是把同一个坑挖深一格（第三张表换个词就又漏）。
    /// markdown 对「表头」的定义是**下一行是分隔行**，这里就按这条结构判：
    /// 一个 `|` 行若紧跟着一个全 `-` 的 `|` 行，它是表头。
    /// ⇒ 表头再叫什么名字都跑不掉，而字面清单只钉得住已经见过的那两个词。
    static func tableFirstCells(in section: Substring) -> [String] {
        func firstCell(_ line: Substring) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") else { return nil }
            // ⚠️ `trimmed` 以 "|" 开头，`split(separator: "|")` 会在 index 0 产出一个
            // 空字符串（前导定界符前的内容），第一个真实单元格是 index 1，不是 index 0。
            let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count > 1 else { return nil }
            let first = cells[1]
            return first.isEmpty ? nil : first
        }
        func isSeparator(_ cell: String) -> Bool {
            !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
        }

        let cells = section.split(separator: "\n", omittingEmptySubsequences: true).map(firstCell)
        var out: [String] = []
        for (index, cell) in cells.enumerated() {
            guard let cell else { continue }
            if isSeparator(cell) { continue }                                   // 分隔行
            let next = index + 1 < cells.count ? cells[index + 1] : nil
            if let next, isSeparator(next) { continue }                         // 表头行（下一行是分隔行）
            out.append(cell)
        }
        return out
    }

    /// ⚠️ 用 `#filePath` 推导，worktree 与主仓两种布局下都稳（上三级到仓库根）。
    ///
    /// ⚠️ **不要在这里另拼一份 `Sources/<target>`** —— 根列表的单一来源是
    /// `GuardScanRoots`（见 `componentScanRoots`）。本属性只服务
    /// `registryURL` / `docs/README.md` 这类**仓库根相对**的资源路径。
    static var repoRoot: URL { GuardScanRoots.repoRoot }

    /// 组件登记表的扫描根 —— **多根**，直接复用 `GuardScanRoots.allRoots`（`#270`）。
    ///
    /// ⚠️ **`#270` 之前这里是单根 `Sources/CoreDesign`**（一个 `URL`，名叫
    /// `coreDesignSources`）：`#244`/`#245` 落地 `CoreDesignEffects` / `CoreDesignCharts`
    /// 两个 library target 之后，这两个 target 里的 **public 类型对本登记表结构上不可见**
    /// ——`PublicTypeCollector` 采不到它们，双向差集自然不会红，「少登记一条」这件事
    /// **没有任何判据能发现**。公约 `docs/component-contract.md` AD-4《下游连锁一》
    /// 把这条链记在案（挂给 `#255`，`#255` 未做），`#270` 把它接过来收口。
    ///
    /// ⚠️ **必须是 `GuardScanRoots.allRoots` 本身，不许在这里再列一份名字**
    /// （`#270` AC 逐字）：两套根列表必然漂 —— `GuardScanRoots` 那份由
    /// `libraryTargetsAreCoveredByScanRoots` 与 `Package.swift` 做双向差集钉着，
    /// 而本文件里另抄的一份不受任何判据约束，将来新增 target 时只会更新前者。
    ///
    /// ⚠️ **根列表带 target 名，不只是 `URL`**：诊断要走
    /// `GuardScanRoots.relativePath(_:)`（`CoreDesign/Foo.swift` 与
    /// `CoreDesignEffects/Foo.swift` 的裸文件名一模一样），而
    /// `assertRootsExist(_:)` 的失败消息也要报出是哪个 target 的根不见了。
    ///
    /// ## ⚠️ 扩根之后**仍然存在**的绕过路径（`#270` 逐条推演的结果，明知而接受）
    ///
    /// 本仓反复付出代价的失效形态是「判据钉形状而非性质」，所以这里不写「已堵死」，
    /// 只如实列出**我能想到的等价改写**，以及每条今天由谁接住 / 没人接住：
    ///
    /// 1. **新增一个 library target 而不动 `GuardScanRoots.targetNames`**
    ///    ⇒ 由 `GuardScanRootsGuard.libraryTargetsAreCoveredByScanRoots` 与
    ///    `Package.swift` 的双向差集接住。⚠️ **但那条判据靠一个手写的 manifest 词法器**，
    ///    它自己已登记了两条已知边缘写法限度（本仓 4 个 known issue 里的 2 个）
    ///    ⇒ 用那两种写法声明的 target **仍然逃逸**。**没人接住。**
    /// 2. **把 public 类型放进非 library target**（executable / 只在某个 trait 下可达的 target）
    ///    ⇒ `declaredLibraryTargets()` 只收 library ⇒ 根本不进根列表。**没人接住。**
    /// 3. **换一种声明形态**：`public enum` / `class` / `actor` 挂 `View`，
    ///    或把 `: View` 一致性挂在 `extension` 上 ⇒ `PublicTypeCollector` 结构上看不见
    ///    （它只覆写 `visit(_:StructDeclSyntax)` 并只读**声明处**的继承子句）。
    ///    这是本类**早于 `#270` 就登记在案的第三 / 第四个盲区**，扩根**没有**缩小它。
    ///    **没人接住**（`ReachableTypeRegistryGuard` 守的是另一件事）。
    /// 4. **两个 target 里放同名类型 / 同名 style 实现 / 同名入口点** ⇒ 由
    ///    `scannerFindsComponentTypes` 里的跨 target 同名检查接住。
    ///    ⚠️ **上句原写「它只查 `components`；`styleImpls` 跨 target 同名仍会静默塌成一条」
    ///    ——PR #297 终审 S-1 指出还漏了第三个桶 `entryPoints`，本轮已把三个桶一并查**：
    ///    `scanTypes(roots:)` 合并的是 `components` / `styleImpls` / `entryPoints` 三个
    ///    `Set`，`entryPoints` 是 README 入口点桶与 `knownReadmeEntryPointRows` 的依据
    ///    （`View.shine` 在两个 target 各声明一次就会塌）。三个桶今天都零同名，
    ///    判据把「今天为零」钉住，第一条同名出现时当场红。**已接住。**
    /// 5. **给 README 加第三个索引小节** ⇒ 该节的行不进 `readmeIndexRows` 的定义域。
    ///    ⚠️ 这一条**方向是安全的**：新组件仍会被「扫描器 ↔ 登记表」双向差集抓成缺失，
    ///    补登记后又会被 `registryEntriesAreCoveredByReadme` 要求某条**已知小节**里的行覆盖
    ///    ⇒ fail-closed。它能造成的只是「文档写了但判据看不见」，不是「少登记不会红」。
    /// 6. **给新类型起一个与既有入口点成员同名的 README 行名**（例如给某个新类型写一行
    ///    叫 `blur`）⇒ 它会在入口点桶里被认掉。⚠️ 同样**只影响 README 对账那一路**：
    ///    类型本身照旧被双向差集抓。且入口点桶**只比对成员名、不比对 host**
    ///    （`View.blur` 与 `Transition.blur` 在这里无法区分）—— 明知而接受，
    ///    因为收紧到 `Host.member` 会要求 README 行名写成 `Transition.blur` 那种形态，
    ///    而那一列是给人读的调用名。
    /// 7. **在一行表格数据行后面紧跟一行「全是 `-`」的行** ⇒ 前一行会被结构性表头识别
    ///    当成表头跳过。这是 markdown 表头定义本身的形状，换成字面清单（只跳 `组件`/`单位`）
    ///    只会把坑挖深一格（第三张表换个表头词就漏）。**明知而接受。**
    /// 8. **把新条目登记成 `tiebreaker` / `prescriptive`** ⇒ 它不进 J-2 定义域，
    ///    永远不必交出扩展点。⚠️ 这**不是漏洞，是公约写死的默认值**（「少给扩展点是可逆的」），
    ///    `#270` 自己的 15 条走的就是这条路。它的约束是**社会性的**（notes 要写明两可理由、
    ///    评审可以质疑），不是机器性的 —— 本行把这一点写在明处，免得后人以为机器在管。
    /// 9. **`Sources/<targetName>` 这条路径推断本身**（PR #297 终审 S-2 补入）：
    ///    `GuardScanRoots.sourcesURL(of:)` 按 **target 名**推根，而 `DeclaredTarget`
    ///    只记 `name` / `isLibrary` / `hasResources`、**不记 `path:`**。
    ///    若某天有 library target 写成 `.target(name: "Foo", path: "Sources/Bar")`，
    ///    同时仓库里还留着一棵陈旧的 `Sources/Foo/`，则五族守卫会去扫**错的树**，
    ///    而 `assertRootsExist`（目录存在）与 `libraryTargetsAreCoveredByScanRoots`
    ///    （名字双向差集）**双双满足** ⇒ **静默 fail-open**。
    ///    ⚠️ 这与上面第 1 条**不是同一条**：那里 target 是**缺席**的（差集能抓），
    ///    这里 target **在场且名字匹配**，差集抓不到。
    ///    ⚠️ 它是 `#246` 就存在的既存形态，但 `#270` 把爆炸半径从「四类字面量守卫」
    ///    扩到了**组件登记表**（扫错树 ⇒ 双向差集对着错的类型集算），故记进这份由
    ///    `#270` 写下的清单。
    ///    ⇒ **今天不可达**（`Package.swift` 无任何 `path:`），且已由
    ///    `GuardScanRoots.declaredTargets` 的 `path:` 探测**改成 fail-closed**：
    ///    manifest 里一旦出现 `path:`，解析器当场 `Issue.record` 逼人处置，
    ///    不再是「悄悄扫错树」。**已接住（以判红的方式，不是以支持 `path:` 的方式）。**
    static var componentScanRoots: [(target: String, url: URL)] { GuardScanRoots.allRoots }
    static var registryURL: URL { repoRoot.appendingPathComponent("docs/component-registry.json") }

    /// 登记表的**入口点**条目（AD-4《下游连锁二》）。
    ///
    /// ⚠️ **它与 `Entry` 是两套 schema，刻意不合并**：`Entry` 的九个字段
    /// （`kind` / `decidedBy` / `nativeProtocol` / `needsExtensionPoint` / …）
    /// 描述的是「一个**组件类型**按判定法落在哪一格」，而一个 `public extension View`
    /// 方法或一个 `Transition` 静态成员没有「样式扩展点」可言——硬塞进 `Entry`
    /// 会让 `registrySchemaIsValid` 的一串蕴含断言全部语义错配
    /// （与 `ReachableTypeRegistryGuard` 当初另起一份文件的理由同型）。
    /// ⇒ 同一份文件、**两个数组**。
    struct EntryPoint: Codable {
        /// 所属 target。必须是 `GuardScanRoots.targetNames` 里的名字。
        let target: String
        /// 被扩展的类型：`View` / `Transition` / `AnyTransition`。
        let host: String
        /// 成员名。**含参重载算同一条**（`251.md`：计数单位是「一种 transition」
        /// 不是「一个静态成员」）——扫描器按名字去重，这里也一样。
        let member: String
        let notes: String
    }

    /// `docs/component-registry.json` 的顶层形状。
    ///
    /// ⚠️ **`#246` 把顶层从「裸数组」改成了对象**：AD-4《下游连锁二》指定
    /// 24 个公开入口点「登记进 `component-registry.json` 的 `entryPoints` 数组」，
    /// 而 JSON 的顶层只能有一个值 ⇒ 要在同一份文件里放第二个数组，顶层必须是对象。
    /// 全仓**只有 `loadRegistry()` 一处读这个文件**，九个消费者都经它拿 `[Entry]`，
    /// 故改动面止于本结构体：`loadRegistry()` 的签名与返回值逐字不变。
    /// ⚠️ 两个字段都是**非可选**：缺 `entryPoints` 键时解码直接失败（fail-closed），
    /// 而不是退化成「零入口点 ⇒ 零差集 ⇒ 绿」。
    struct RegistryFile: Codable {
        let components: [Entry]
        let entryPoints: [EntryPoint]
    }

    static func loadRegistryFile() throws -> RegistryFile {
        try JSONDecoder().decode(RegistryFile.self, from: Data(contentsOf: registryURL))
    }

    static func loadRegistry() throws -> [Entry] {
        try Self.loadRegistryFile().components
    }

    static func loadEntryPoints() throws -> [EntryPoint] {
        try Self.loadRegistryFile().entryPoints
    }

    /// ⚠️ **分类返回**（裁决 D1）：Style 实现**不是**登记表条目。
    /// 混在一个 Set 里会让完整性判据的双向差集**永久非空**。
    ///
    /// ⚠️ **`entryPoints` 是 `#246` 新增的第三个桶**（AD-4《下游连锁二》）：
    /// `public extension View` 上的方法与 `Transition` 的静态成员**不是类型**，
    /// `PublicTypeCollector` 原本结构上看不到它们——task 250 的 8 个 modifier +
    /// task 251 的 16 个转场 = **24 个公开入口点**对所有守卫不可见。
    /// 它**不进** `components`（那样会被登记表的双向差集判成幽灵条目），
    /// 而是由 `ExtensionEntryPointGuard` 与 `component-registry.json` 的
    /// `entryPoints` 数组比对。元素是**基键** `Host.member`（不含 target 前缀）。
    struct ScanResult {
        var components: Set<String> = []
        var styleImpls: Set<String> = []
        var entryPoints: Set<String> = []
    }

    /// `Sources/CoreDesign` 扫描结果的缓存。
    ///
    /// 本仓 `Package.swift` 设了 `.defaultIsolation(MainActor.self)`，测试因此**串行**执行
    /// ——三条判据各扫一遍 74 个源文件，实测单次 1.03s、本 suite 合计 3.22s，恰是 3×。
    /// 缓存后降到一次（PR #193 Copilot 第 2 轮 suppressed comment；数字是应它的建议实测的，
    /// 不是估算）。MainActor 串行同时意味着这个可变静态量不需要额外同步。
    ///
    /// ⚠️ **只缓存「成功且非空」的结果，这是本缓存的关键约束**：`scanTypes` 的三条失败
    /// 路径（路径不存在 / 无法枚举 / 解析出错）都会返回或产出**空集**。若把空集也缓存下来,
    /// 第一条判据吃到失败、后两条却拿着缓存里的空集算差集 ⇒「零类型 ⇒ 零缺失 ⇒ **绿**」
    /// ——正是本 issue 反复栽的「测量工具制造自己的绿」。⇒ 空结果不入缓存，让后续判据
    /// **重新扫、重新失败**，每条都各自报出自己的诊断。
    private static var cachedComponentScan: ScanResult?

    /// 三条判据统一走这个入口，不要直接调 `scanTypes(roots:)`。
    ///
    /// ⚠️ `#270` 起它扫的是**三个 target**（`GuardScanRoots.allRoots`），不再只有
    /// `Sources/CoreDesign` —— 旧名 `coreDesignScan()` 已随之改名，免得名字继续声称
    /// 一个已经不成立的射程。
    static func componentScan() throws -> ScanResult {
        if let cached = Self.cachedComponentScan { return cached }
        let result = try Self.scanTypes(roots: Self.componentScanRoots)
        // 见上：空结果说明扫描失败，不缓存。
        if !result.components.isEmpty { Self.cachedComponentScan = result }
        return result
    }

    /// 多根扫描。**列表级** fail-closed 断言先行（`GuardScanRoots.assertRootsExist`），
    /// 逐根再走 `scanTypes(root:)` 自己那条**逐根**断言。
    ///
    /// ⚠️ **`components` 是按名字合并的 `Set`** ⇒ 两个 target 里的同名 public 类型会
    /// **塌成一条**（`Entry` 没有 target 字段，登记表按名字对账）。塌掉的那一条在双向
    /// 差集里看不见 —— 与 `#246` 给豁免台账键加 target 前缀所防的是同一种病。
    /// 这里不改 `Entry` 的 schema（那会顶动九个消费者），而是由
    /// `componentTypeNamesAreUniqueAcrossTargets` 把「今天跨 target 无同名」钉成判据：
    /// 第一条同名类型出现时当场红，而不是静默合并。
    static func scanTypes(roots: [(target: String, url: URL)]) throws -> ScanResult {
        var result = ScanResult()
        for (_, one) in try Self.scanTypesByTarget(roots: roots) {
            result.components.formUnion(one.components)
            result.styleImpls.formUnion(one.styleImpls)
            result.entryPoints.formUnion(one.entryPoints)
        }
        return result
    }

    /// 逐 target 的扫描结果。合并版 `scanTypes(roots:)` 会把三个 target 的集合并成一份，
    /// **谁来自哪个 target 这个信息在合并里丢失** —— 而它正是
    /// `componentTypeNamesAreUniqueAcrossTargets` 需要的那一份。
    static func scanTypesByTarget(
        roots: [(target: String, url: URL)],
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) throws -> [(target: String, scan: ScanResult)] {
        GuardScanRoots.assertRootsExist(roots)
        let out = try roots.map { ($0.target, try Self.scanTypes(root: $0.url)) }
        // ⚠️ **逐根非空断言放在共享入口，不是只放在某一条判据里**（PR #297 终审 S-3）：
        // 「新根静默产出空集」是多根扫描最容易的假绿，而合并集合的下界
        // （`components.count > 15` 之类）在主 target 一家就够数时**照样成立**。
        // 此前这条断言只写在 `scannerFindsComponentTypes` 里 ⇒ 其余经 `componentScan()`
        // 取数的判据（`registryCoversCoreDesignTypes`、`BoolExemptionGuard` 的
        // `scan.components.count > 15`）各自都不自足，只能靠「同 suite 另一条会红」。
        // 放到这里之后，**每个消费者**都自带这道 fail-closed。
        // ⚠️ 下界写「非空」而不是精确数：它挡的是「整根空掉」，不是「少一个类型」。
        for (target, scan) in out where scan.components.isEmpty {
            Issue.record(
                "扫描根 \(target) 一个 public 组件类型都没采到 —— 多根扫描最常见的假绿就是新根静默产出空集，这不是「零违规」",
                sourceLocation: sourceLocation
            )
        }
        return out
    }

    /// ⚠️ **必须先断言路径存在**：`FileManager.enumerator(at:)` 对不存在的路径
    /// **静默产出空序列** ⇒「零类型 ⇒ 零缺失 ⇒ 绿」会静默通过。
    static func scanTypes(root: URL) throws -> ScanResult {
        guard FileManager.default.fileExists(atPath: root.path) else {
            Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
            return ScanResult()
        }
        var result = ScanResult()
        // ⚠️ **不要强制解包**（PR #193 Copilot 第 1 轮）：`enumerator(at:)` 在权限 / IO
        // 异常时返回 `nil`，`!` 会让整个测试进程崩掉——判据连「为什么失败」都报不出来。
        // 与上面两处（路径不存在、解析出错）保持同一纪律：**失败要变成可读的测试失败，
        // 不是崩溃**。
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作，这不是「零违规」")
            return ScanResult()
        }
        for case let url as URL in walker
        where url.pathExtension == "swift" {
            let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
            // ⚠️ **解析保真检查**：parser major 与工具链不配套时会静默产出 error node
            // ⇒ 类型被漏采，而扫描器照样「成功」返回一个偏小的集合。
            // ⚠️ **诊断走 `GuardScanRoots.relativePath` 而不是 `lastPathComponent`**
            // （`#270`）：`GuardScanRoots.relativePath` 的文档逐字写着「它们哪天扩到多根，
            // 必须同轮改成 `relativePath`」—— `#270` 正是那一天。裸文件名在三根之下会指错文件。
            //
            // ⚠️ **但根取的是被扫的那个 `root`、外面再补一段根目录名，不是仓库根**
            //（`#313` 第 2 轮终审 I-3；`#270` 落地时这里写的是单参 `relativePath(_:)`）：
            // 本函数也被 `ComponentJudgeMutationTests.multiRootCatchesUnregisteredTypeInNewTarget`
            // 喂**副本树的根**（`NSTemporaryDirectory()` 之下）。用仓库根相对路径的话，`url`
            // **结构性地**不在 `repoRoot` 之下 ⇒ 这条 parse-error 分支一旦触发，就会顺带踩响
            // `GuardScanRoots.relativePath(_:from:)` 的兜底、额外记一条「结构上不该发生……
            // 又冒出了一类路径分叉」——而真实原因只是一个**已知且合法**的副本根，诊断方向指反了。
            // 附带修掉的第二件事：单参重载在 `#313` 之前无法转发 `sourceLocation`
            // ⇒ 从它落进兜底时 `Issue.record` 的位置一律指向 `GuardScanRoots.swift` 那一行。
            // ⚠️ 前缀取 `root.lastPathComponent`，与 `scanComponentJudgeInputs(root:)` 的台账键
            // 同一形态（`<根目录名>/<根内相对路径>`）⇒ 真实根与副本根上诊断串的形状一致。
            if tree.hasError {
                let site = root.lastPathComponent + "/" + GuardScanRoots.relativePath(url, from: root)
                Issue.record("解析出错：\(site) —— swift-syntax major 可能与工具链不配套")
            }
            let c = PublicTypeCollector()
            c.walk(tree)
            result.components.formUnion(c.components)
            result.styleImpls.formUnion(c.styleImpls)
            result.entryPoints.formUnion(c.entryPoints)
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
        // ⚠️ **47 → 62 的出处（`#270`）**：扫描根由单根 `Sources/CoreDesign` 扩成
        // `GuardScanRoots.allRoots` 三根后，`PublicTypeCollector` 在
        // `Sources/CoreDesignEffects` 采到 **11** 个、`Sources/CoreDesignCharts` 采到 **4** 个
        // `public struct: View` ⇒ 15 条新条目。**这 15 个数不是估的**，是本轮
        // `scannerFindsComponentTypes` 那条 print 逐 target 打出来的实测名单
        // （Effects：AnimatedMeshGradient / BeforeAfterSlider / CharSphere / DotSphere /
        // FullScreenButton / GlowSweep / LightSweep / OrbitingLogos / ScanningOverlay /
        // Shine / TypewriterText；Charts：ActivityHeatmap / NetworkGraph / RadarChart / RingChart）。
        // ⚠️ **本 issue 正文点名的是 8 个**（`Shine` + 四个图表 + `ScanningOverlay` /
        // `GlowSweep` / `LightSweep`）—— 那是按**产出它们的三个 task**（#250 / #252 / #255）
        // 数的；`#253` / `#254` 落地的另外 7 个（TypewriterText / AnimatedMeshGradient /
        // BeforeAfterSlider / OrbitingLogos / DotSphere / CharSphere / FullScreenButton）
        // 同样是 `public struct: View`、同样对本登记表结构上不可见，只是没被 issue 正文数进去。
        // ⇒ 本轮收口的是**扫描器实测到的 15 个**，不是 issue 正文的 8 个。
        #expect(entries.filter { $0.repo == "coredesign" }.count == 62,
                "CoreDesign 侧条目数不是 62（#270 扩扫描根到三个 target，Effects 11 + Charts 4 共 15 条按判定法补录后由 47 变为 62）——若为新增属预期变化请同步改这个数字；若无源码变更条目却变了，是静默删条目/改 repo 的信号")
        #expect(entries.filter { $0.repo == "storyui" }.count == 25,
                "StoryUI 侧条目数不是 25——CI 无法跨仓核对源码，这条固定计数断言是 #43 落地前唯一挡「静默删条目」的机器判据，不得放宽为 print")

        // ⚠️ 终审 M1：`decidedBy` ⇒ `kind` 的映射公约 `:82-83` 已经写死
        // （tiebreaker ⇒ prescriptive、step1/2 ⇒ semantic、step3 ⇒ prescriptive、
        // precedent ⇒ semantic），但此前守卫没查——`38.md`「AC 要求而守卫不查，正是 #30 的病型复刻」点名的正是这类
        // 「AC 要求而守卫不查」的 #30 病型复刻。当前 70 条全部满足，补上零成本。
        for e in entries where e.decidedBy != "exclusion" {
            if let expected = Self.expectedKindForDecidedBy[e.decidedBy] {
                #expect(e.kind == expected,
                        "\(e.component)：decidedBy=\(e.decidedBy) 按公约必须 kind=\(expected)，实际是 \(e.kind)")
            }
        }

        // ⚠️ 终审第 2 轮 M1：`expectedKindForDecidedBy` 是 `if let` 可选查表——往
        // `validDecidedBy` 新增一个取值却忘了同步这张映射表时，上面的循环对新取值
        // 静默不做任何断言（`if let expected = ...` 找不到就直接跳过）。这条断言把
        // 「两张表必须同步」本身钉成判据：`validDecidedBy` 的每个非 `exclusion` 取值
        // 都必须在 `expectedKindForDecidedBy` 里有对应键，`exclusion` 单独走上面
        // `registrySchemaIsValid` 里 `(kind == "excluded") == (decidedBy == "exclusion")`
        // 那条断言，不重复出现在这张表里。
        let m1SyncMessage = """
        validDecidedBy 与 expectedKindForDecidedBy 不同步——新增 decidedBy 取值必须同步\
        加进 expectedKindForDecidedBy（除非它和 exclusion 一样另有专门断言），否则 M1\
        判据对新取值静默无声
        """
        #expect(Set(Self.expectedKindForDecidedBy.keys).union(["exclusion"]) == Self.validDecidedBy,
                "\(m1SyncMessage)")

        // ⚠️ **缓办台账的双侧等式**（PR #297 终审 I-2）：`pendingStep2` 是「步骤 2 枚举
        // 未完成」的显式标记，不是判定法的出口。两个方向都要红：
        // · 集合**缩小** ⇒ 有人把标记删了（把缓办悄悄说成已判）；
        // · 集合**增大** ⇒ 又多了一条跳过枚举的条目，须过评审并挂进承接 issue。
        // ⚠️ 正确处置是补做枚举并按公约重判（`\(Self.pendingStep2FollowUpIssue)`），
        // **不是**改 `knownPendingStep2Enumeration` 让它变绿。
        let pendingStep2 = Self.pendingStep2Components(in: entries)
        #expect(pendingStep2 == Self.knownPendingStep2Enumeration, """
        `decidedBy: pendingStep2` 的条目集合变了：实际 \(pendingStep2.sorted())，        已知 \(Self.knownPendingStep2Enumeration.sorted())。
        `pendingStep2` 的含义是「公约步骤 2 的候选枚举与来源核验尚未完成，本条不声称任何出口，        按可逆的一侧（prescriptive / 不给扩展点）缓办登记」——它是**台账**，不是判定结论。
        · 变小：若某条真的补完了枚举，落点应改成 step1/step2/step3/tiebreaker 之一，        并同步从本表移除；若只是把标记删掉，那是把缓办伪装成已判。
        · 变大：又出现了一条跳过枚举的条目 —— 须在 notes 里写明成因，并挂进承接 issue \(Self.pendingStep2FollowUpIssue)。
        """)

        // ⚠️ **承接指针要承重**：只在散文里写一句「已开 issue」，issue 号错了 / 条目换了
        // 都没人知道。每条缓办条目的 notes 必须写着承接 issue 号。
        for e in entries where e.decidedBy == "pendingStep2" {
            #expect(e.notes.contains(Self.pendingStep2FollowUpIssue), """
            \(e.component) 是 pendingStep2 条目，但 notes 里没有承接 issue 号 \(Self.pendingStep2FollowUpIssue)             —— 缓办没有落点等于永久缓办
            """)
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
            // ⚠️ **四个扩展点字段至多一个非空**（形态 D 由 `D-59-1` 裁定后补上这条）。
            // J-2 的判定链是 customStyleProtocol → nativeProtocol → styleSlot → styleEnum，
            // **靠前的命中就 return** ⇒ 两个字段同时非空时，靠后那条通路**从未被核对**，
            // 而判据照样绿。这与本文件上一条断言防的是同一种病（#38 裁决 D3「分开读」
            // 没说过可以同时填），形态 D 的两个新字段必须一并纳入。
            let extensionPointFields = [
                e.nativeProtocol, e.customStyleProtocol, e.styleSlot, e.styleEnum,
            ].compactMap { $0 }
            #expect(
                extensionPointFields.count <= 1,
                """
                \(e.component) 同时标了 \(extensionPointFields.count) 个扩展点字段\
                （nativeProtocol / customStyleProtocol / styleSlot / styleEnum 至多填一个）\
                 —— J-2 只会按判定链的第一个裁决，其余通路静默略过
                """
            )
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

    /// ⚠️ **本条是 `knownPendingStep2Enumeration` 的变红自证**（PR #297 终审 I-2 的验证要求）：
    /// 上面那条双侧等式在**提交态恒真**（数据自洽时判据自然沉默）⇒ 「把等式换成
    /// `isSubset(of:)`」这类放松改写在提交态测不出来。这里用**合成条目**把两个方向都跑一遍，
    /// 与 `ComponentTextParamGuard.proseDataJudgeCatchesRealIncidents` 是同一条纪律：
    /// **判据在真实数据上零命中时，必须另有 fixture 证明它还活着。**
    @Test("`pendingStep2` 台账承重：删一条标记判红、加一条未登记的标记也判红")
    func pendingStep2LedgerIsLoadBearing() throws {
        let entries = try Self.loadRegistry()
        let known = Self.knownPendingStep2Enumeration

        // ⚠️ 非空前置：台账空了下面两个方向都会在空集上恒真。
        #expect(!known.isEmpty, "`knownPendingStep2Enumeration` 为空 —— 本条会在空集上恒真")
        #expect(Self.pendingStep2Components(in: entries) == known, "基线不成立，下面两个变异证明不了任何事")

        // ---- 方向 ① 删一条标记（把某条改回 tiebreaker）⇒ 集合缩小 ⇒ 判红 ----
        let victim = try #require(known.sorted().first)
        let markerRemoved = entries.map { e -> Entry in
            e.component == victim ? e.withDecidedBy("tiebreaker") : e
        }
        #expect(Self.pendingStep2Components(in: markerRemoved) != known, """
        把 \(victim) 的 pendingStep2 标记改回 tiebreaker 之后集合竟然没变 —— \
        双侧等式的「缩小」方向失效，缓办可以被静默说成已判
        """)

        // ---- 方向 ② 加一条未登记的标记 ⇒ 集合增大 ⇒ 判红 ----
        let intruder = try #require(entries.first { $0.decidedBy == "tiebreaker" && !known.contains($0.component) })
        let markerAdded = entries.map { e -> Entry in
            e.component == intruder.component ? e.withDecidedBy("pendingStep2") : e
        }
        #expect(Self.pendingStep2Components(in: markerAdded) != known, """
        把 \(intruder.component) 改成 pendingStep2 之后集合竟然没变 —— \
        双侧等式的「增大」方向失效，新的跳过枚举条目可以不过评审就落盘
        """)
    }

    @Test("扫描器真的扫到了三个 target 的类型，且类型名跨 target 不重名")
    func scannerFindsComponentTypes() throws {
        let r = try Self.componentScan()
        // ⚠️ 非空断言先行：扫描器失效时「零类型 ⇒ 零缺失 ⇒ 绿」会静默通过。
        // ⚠️ 下界是**量级**断言，不是精确数 —— 精确数由本次运行给出（见 print）。
        #expect(r.components.count > 15, "只扫到 \(r.components.count) 个组件类型 —— 扫描器失效")
        #expect(r.styleImpls.count > 5, "只扫到 \(r.styleImpls.count) 个 Style 实现 —— 协议清单可能又漏了")
        // ⚠️ 用 print 不用 `Issue.record` —— 后者记录的是 failure，会让测试永远红。
        // ⚠️ **要打名单不只是数**：step1 种子的回填（Step 3b）与 Task 2 的填表都需要名单;
        // 只有数的话执行者得从完整性测试的失败消息里倒推，绕。
        print("组件 \(r.components.count) 个：\(r.components.sorted())")
        print("Style 实现 \(r.styleImpls.count) 个：\(r.styleImpls.sorted())")

        // ⚠️ **逐 target 打印 + 逐 target 非空断言**（`#270`）：合并集合的下界
        // （上面那两条）在「Effects / Charts 两根整个扫不到」时**照样成立** ——
        // 主 target 一家就有 46 个，`> 15` 恒真。多根扫描最容易的假绿正是
        // 「新根静默产出空集」，故每个根各自也要有非空断言。
        // ⚠️ 下界写 `> 0` 而不是精确数：精确数由本条 print 给出，写进断言会让
        // 每加一个组件都要来改这里，而它挡的是「整根空掉」不是「少一个」。
        let byTarget = try Self.scanTypesByTarget(roots: Self.componentScanRoots)
        #expect(byTarget.count == GuardScanRoots.targetNames.count,
                "逐 target 扫描只回来 \(byTarget.count) 组，根列表有 \(GuardScanRoots.targetNames.count) 个")
        for (target, scan) in byTarget {
            print("· \(target)：组件 \(scan.components.count) 个 \(scan.components.sorted())"
                  + "；Style 实现 \(scan.styleImpls.count) 个；入口点 \(scan.entryPoints.count) 个")
            // ⚠️ **同款断言现已下沉到 `scanTypesByTarget` 这个共享入口**（PR #297 终审 S-3）,
            // 让每个经 `componentScan()` 取数的判据各自自足；这里保留一条**同址**的断言，
            // 是为了让本判据的失败消息就在本判据里（与 `assertRootsExist` 的
            // 「列表级 + 逐根级两者都要」同一条纪律）。
            #expect(!scan.components.isEmpty,
                    "扫描根 \(target) 一个组件类型都没采到 —— 多根扫描最常见的假绿就是新根静默产出空集")
        }

        // ⚠️ **跨 target 同名会在 `components` 这个 `Set` 里静默塌成一条**：`Entry` 没有
        // target 字段，登记表按名字对账 ⇒ 两个 target 里的同名 public 类型只需一条登记
        // 就能同时喂饱双向差集的两个方向，「少登记一条」看不出来。这与 `#246` 给豁免台账键
        // 加 target 前缀所防的是同一种病。今天三根之间零同名，本条把「今天为零」钉成判据。
        // ⚠️ **不改 `Entry` 的 schema 给它加 target 字段**：那会顶动九个消费者与
        // 一整套按名字建的索引（`byComponent` / `ownerAliases` / `readmeRowCoverage` …），
        // 收益是「将来某天可能出现的同名」，成本是现在就要改一圈 —— 先钉住，撞上再改。
        // ⚠️ **三个桶全查，不只是 `components`**（PR #297 终审 S-1）：`scanTypes(roots:)`
        // 合并的是 `components` / `styleImpls` / `entryPoints` **三个** `Set`，
        // 而初版只查了第一个 —— 另外两个的跨 target 同名同样静默塌成一条：
        // · `styleImpls` 是 `knownStyleAnnotationRows` 判 README 行归宿的依据；
        // · `entryPoints` 是 README 入口点桶与 `knownReadmeEntryPointRows` 的依据
        //   （`View.shine` 若在 CoreDesign 与 CoreDesignEffects 各声明一次就会塌）。
        // 三者今天都零同名（`styleImpls` 只有主 target 有，`entryPoints` 三根互不重名），
        // 本条把「今天为零」一并钉成判据 —— 写它的人自称枚举了「我能想到的等价改写」，
        // 那份清单里漏了这一条，靠加断言而不是靠记得住来补。
        func collisions(in bucket: (ScanResult) -> Set<String>) -> [String] {
            var seenIn: [String: String] = [:]
            var out: [String] = []
            for (target, scan) in byTarget {
                for name in bucket(scan).sorted() {
                    if let previous = seenIn[name] {
                        out.append("\(name)（\(previous) 与 \(target)）")
                    } else {
                        seenIn[name] = target
                    }
                }
            }
            return out
        }
        let buckets: [(name: String, get: (ScanResult) -> Set<String>, why: String)] = [
            ("components", { $0.components },
             "登记表按**名字**对账（`Entry` 无 target 字段）⇒ 一条登记就能同时满足双向差集的两个方向，「少登记一条」不会红"),
            ("styleImpls", { $0.styleImpls },
             "`knownStyleAnnotationRows` 用它判 README 行的归宿 ⇒ 一个 target 里的 style 实现能替另一个 target 的同名行放行"),
            ("entryPoints", { $0.entryPoints },
             "README 的入口点桶与 `knownReadmeEntryPointRows` 都按 `Host.member` 比对 ⇒ 一个 target 的入口点能替另一个 target 的同名行放行"),
        ]
        for bucket in buckets {
            let found = collisions(in: bucket.get)
            #expect(found.isEmpty, """
            `ScanResult.\(bucket.name)` 里这些名字在两个 target 里同时出现：\(found)。
            合并成一个 Set 之后它们会**塌成一条**，而 \(bucket.why)。
            处置：给其中一个改名，或把对应的索引改成按 (target, name) 建 ——
            **不要**为了让本条变绿把它删掉。
            """)
        }
    }

    @Test("CoreDesign 侧：登记表覆盖全部组件类型，且无幽灵条目")
    func registryCoversCoreDesignTypes() throws {
        let entries = try Self.loadRegistry()
        let scanned = try Self.componentScan().components
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

        // ⚠️ 终审第 2 轮 M2：`knownOffScannerComponents` 白名单本身没有自洽断言——
        // 既不断言成员必须在登记表里（已经隐含在上面 `registered.subtracting(...)`,
        // 若成员不在登记表里减去它是无意义操作，但也不会报错），也不断言成员真的
        // **扫不到**。若将来扫描器能力扩展到认出 `Toast` 那一类声明，这条白名单会
        // 静默把它从双向差集的两个方向一起抹掉，判据不会提醒「白名单条目已经不需要
        // 白名单了」。用未减去白名单的原始 `scanned` 集合核对：
        let registeredCoreDesign = Set(entries.filter { $0.repo == "coredesign" }.map(\.component))
        #expect(Self.knownOffScannerComponents.isSubset(of: registeredCoreDesign),
                "knownOffScannerComponents 里有条目不在登记表里，白名单本身失去了豁免对象")
        let m2ExpiredMessage = """
        白名单条目已经能被扫描器看到 ⇒ 该移出 knownOffScannerComponents，\
        否则将来扫描器能力扩展、真扫到它时，判据不会提醒你这条豁免已经过期
        """
        #expect(scanned.isDisjoint(with: Self.knownOffScannerComponents), "\(m2ExpiredMessage)")
    }

    @Test("README 组件索引每个候选名都有归宿：登记表 / styleImpls（须真的扫到）/ 墓碑 / 排除 / **聚合映射** / 辅助类型 / 别名与容器前缀（守卫绿态下不可达）")
    func readmeIndexReconcilesWithRegistry() throws {
        let entries = try Self.loadRegistry()
        let registered = Set(entries.filter { $0.repo == "coredesign" }.map(\.component))
        let scan = try Self.componentScan()
        let scanned = scan.components

        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rows = Self.readmeIndexRows(readmeText)
        // ⚠️ 非空断言先行：解析器失效（标题文案改了、表格语法变了）会让下面「零候选名 ⇒
        // 零漏网 ⇒ 绿」静默通过——本次终审留痕的人工核对结果是 37 行，下界给宽松量级。
        let parseFailureMessage = """
        README 组件索引只解析到 \(rows.count) 行 —— 解析器可能失效，不是真的「组件索引缩水了」
        """
        #expect(rows.count > 20, "\(parseFailureMessage)")

        // ⚠️ 入口点成员名取自**登记表**而不是扫描器：本条判据核的是「README 行 ↔ 登记表」，
        // 拿扫描器当参照会让「源码有、登记表没有」的入口点也放行 —— 那个方向由
        // `ExtensionEntryPointGuard` 的双向差集守，两条判据各守各的方向。
        let entryPointMembers = Set(try Self.loadEntryPoints().map(\.member))
        #expect(entryPointMembers.count > 20,
                "登记表只读到 \(entryPointMembers.count) 个入口点成员 —— 疑似解析失效，入口点桶会在空集上把整节判红")

        var unresolved: [String] = []
        for raw in rows {
            let (names, isTombstone) = Self.candidateNames(fromReadmeCell: raw)
            for name in names
            where !Self.resolveReadmeCandidate(
                name, isTombstone: isTombstone, registered: registered,
                styleImpls: scan.styleImpls, entryPointMembers: entryPointMembers
            ) {
                unresolved.append("「\(raw)」→ 「\(name)」")
            }
        }
        let unresolvedMessage = """
        README 组件索引里这些候选名，既不在登记表也不在任何已知豁免清单（墓碑 / 排除 / \
        style 注记 / 辅助类型 / 别名 / 容器前缀）里，是本判据存在的理由——正是这类「新增 \
        README 行但没登记」曾经放过 Toast / BottomInputBar：\n\(unresolved.joined(separator: "\n"))
        """
        #expect(unresolved.isEmpty, "\(unresolvedMessage)")

        // ⚠️ **反向**：已知墓碑 / 已知排除项若在源码里「复活」了，也要红——否则墓碑清单
        // 本身会悄悄变成过期信息，没人会因为「判据还是绿的」而想起去核对它。
        let resurrectedTombstones = Self.knownReadmeTombstones.intersection(scanned)
        let tombstoneMessage = """
        这些墓碑组件在源码里又出现了，需要回填登记表并把名字从 knownReadmeTombstones \
        移走：\(resurrectedTombstones.sorted())
        """
        #expect(resurrectedTombstones.isEmpty, "\(tombstoneMessage)")
        let resurrectedExclusions = Self.knownExcludedReadmeRows.intersection(scanned)
        #expect(resurrectedExclusions.isEmpty,
                "这些排除项在源码里被扫描器采集到了，需要重新裁决是否登记：\(resurrectedExclusions.sorted())")
    }

    // MARK: - `#48` G-3：反向对账 + 快照存在性 + 映射表自洽

    @Test("反向：每个非 excluded 的 coredesign 条目都被 README 索引覆盖")
    func registryEntriesAreCoveredByReadme() throws {
        let entries = try Self.loadRegistry()
        let targets = entries.filter { $0.repo == "coredesign" && $0.kind != "excluded" }
        // ⚠️ 非空前置：registry 解析失效时下面会在空集上恒真。
        #expect(targets.count > 30, "只读到 \(targets.count) 条非 excluded 的 coredesign 条目 —— 疑似解析失效")

        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rows = Self.readmeIndexRows(readmeText)
        #expect(rows.count > 20, "README 组件索引只解析到 \(rows.count) 行 —— 解析器可能失效")

        // README 行自身产出的候选名。
        var covered: Set<String> = []
        for raw in rows {
            let (names, _) = Self.candidateNames(fromReadmeCell: raw)
            covered.formUnion(names)
            // ⚠️ 聚合映射：一条行覆盖的全部条目（与正向共用同一份数据）。
            for name in names {
                // ⚠️ **反向只认 `readmeRowCoverage` 一张表**（PR #211 终审 C-1）。
                // 上一版还叠加了 `knownReadmeContainerPrefixes` 与 `knownReadmeAliases`
                // ⇒ `Sidebar` 的覆盖事实同时活在 prefix 表与 coverage 表、
                // `SpinningModifier` 同时活在 alias 表与 coverage 表，**两处无一致性绑定**
                // ⇒ 新增 `SidebarFooRow`（有源码、无 README 行）会被 prefix 分支**静默覆盖**，
                // coverage 表从此欠账而四条自洽守卫全绿。那正是「两张表各自漂移」。
                if let coverage = Self.readmeRowCoverage[name] { covered.formUnion(coverage.entries) }
            }
        }

        let missing = targets.map(\.component).filter { !covered.contains($0) }.sorted()
        #expect(missing.isEmpty, """
        这些登记条目在 README 组件索引里**没有任何行覆盖**：\(missing)
        —— 索引缺行此前不会红（G-3 的单向缺口）。要么给它补索引行，要么在
        `readmeRowCoverage` 里挂到某条已有行下并写明理由。
        """)
    }

    @Test("README 索引引用的快照 PNG 必须真的存在")
    func readmeSnapshotsExist() throws {
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        // 抽 `<img src="snapshots/xxx.png">` 里的路径。
        var refs: [String] = []
        var rest = Substring(readmeText)
        while let open = rest.range(of: "src=\"snapshots/") {
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "\"") else { break }
            refs.append(String(after[..<close.lowerBound]))
            rest = after[close.upperBound...]
        }
        // ⚠️ 非空前置：解析失效会让「零引用 ⇒ 零缺失 ⇒ 绿」静默通过。
        #expect(refs.count > 20, "README 里只解析到 \(refs.count) 个快照引用 —— 解析器可能失效")

        let dir = Self.repoRoot.appendingPathComponent("docs/snapshots")
        // ⚠️ **比对精确文件名集合，不用 `fileExists`**（PR #211 终审 S-4）：macOS 默认的
        // APFS 是**大小写不敏感**的 ⇒ README 把 `Button.png` 写成 `button.png` 时
        // `fileExists` **返回 true**，本地与 CI 全绿，而 GitHub 网页端 404。
        let actual = Set(
            (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        )
        #expect(actual.count > 20, "docs/snapshots 只枚举到 \(actual.count) 个文件 —— 疑似路径错，本断言会在空集上把所有引用判红")
        let missing = refs.filter { !actual.contains($0) }.sorted()
        #expect(missing.isEmpty, "README 索引引用了不存在的快照（**区分大小写**）：\(missing)")

        // ⚠️ **只做这一个方向**（README → PNG），**不做**「PNG 必须被 README 引用」：
        // `docs/snapshots/` 有 39 个 PNG 而索引 37 行，多出来的是**正常的未索引快照**，
        // 反向断言会把它们判红。这个方向选择是有意的，不是漏了。
    }

    @Test("覆盖事实的单一来源：prefix / alias 表能推出的覆盖，coverage 表必须已经包含")
    func coverageTableIsTheSingleSourceOfTruth() throws {
        // ⚠️ **本条守的是「两张表不许各自漂移」**（PR #211 终审 C-1）。
        // `Sidebar` 的覆盖事实曾同时活在 `knownReadmeContainerPrefixes` 与
        // `readmeRowCoverage`、`SpinningModifier` 同时活在 `knownReadmeAliases` 与
        // coverage 表，**没有任何断言绑定两处** ⇒ 改一边不会红。
        let entries = try Self.loadRegistry()
        let targets = entries.filter { $0.repo == "coredesign" && $0.kind != "excluded" }.map(\.component)
        #expect(!targets.isEmpty, "registry 解析为空 —— 本守卫会在空集上恒真")

        for (rowName, prefix) in Self.knownReadmeContainerPrefixes {
            let derived = Set(targets.filter { $0.hasPrefix(prefix) })
            let declared = Self.readmeRowCoverage[rowName]?.entries ?? []
            let missing = derived.subtracting(declared).sorted()
            #expect(missing.isEmpty, """
            `knownReadmeContainerPrefixes["\(rowName)"]` 能推出 \(missing) 被覆盖，            但 `readmeRowCoverage["\(rowName)"]` 里没有它们 —— 两张表已漂移。            覆盖事实必须以 coverage 表为准；prefix 表只是正向的 fallback。
            """)
        }
        for (rowName, alias) in Self.knownReadmeAliases {
            let declared = Self.readmeRowCoverage[rowName]?.entries ?? []
            #expect(declared.contains(alias), """
            `knownReadmeAliases["\(rowName)"] = "\(alias)"`，但             `readmeRowCoverage["\(rowName)"]` 里没有它 —— 两张表已漂移。
            """)
        }
    }

    @Test("两个 README 索引小节都真的解析出了行（`#270`：定义域扩了要有活证据）")
    func readmeIndexSectionsAllParse() throws {
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        // ⚠️ **逐节断言，不是只看合计**：合计行数在「第二节整个解析不到」时**照样 > 20**
        // ——主索引一节的行数就远超那个下界 ⇒ 只看合计等于没守住新扩的那一半。
        // ⚠️ 此处**有意不写现状条数**（PR #297 终审 S-4）：上一版写「主索引一节就有 37 行」，
        // 实测是 38；那个 37 继承自本文件顶端**已归档**的单节时代核对，写下即化石。
        // 改了 README 的小节标题、或把某节整个搬走时，本条给出的诊断是「哪一节没解析到」，
        // 而不是让人从 `registryEntriesAreCoveredByReadme` 的一屏缺失条目里倒推。
        for section in Self.readmeIndexSections {
            guard let range = Self.readmeSectionRange(in: readmeText, section) else {
                Issue.record("README 里找不到行首小节标题「\(section.start)」—— 该节的行整段掉出定义域，判据对它恒真")
                continue
            }
            // ⚠️ 从**小节起点**往后找终止标题，不能在 `range` 内找：`range` 的上界正是终止标题
            // 那个 `\n` 的位置 ⇒ 终止标题本身不在 `range` 里，在里面找必然找不到、恒红。
            #expect(readmeText.range(
                        of: "\n" + section.end, range: range.lowerBound..<readmeText.endIndex
                    ) != nil,
                    "README 里「\(section.start)」之后找不到行首终止标题「\(section.end)」—— 解析范围会一路吃到文末")
            let rows = Self.tableFirstCells(in: readmeText[range])
            #expect(rows.count > 10,
                    "README 小节「\(section.start)」只解析到 \(rows.count) 行 —— 解析器或标题文案可能失效")
            // ⚠️ 表头行必须被结构性地剔除掉：两节的表头分别是 `组件` 与 `单位`，
            // 任何一个漏进来都会变成一个永远解析不掉的候选名。
            #expect(!rows.contains("组件") && !rows.contains("单位"),
                    "小节「\(section.start)」的表头行没被剔除：\(rows.filter { $0 == "组件" || $0 == "单位" })")
        }
    }

    @Test("`knownReadmeEntryPointRows` 承重：两条映射都真的被用到，且都不是多余的")
    func readmeEntryPointRowsAreLoadBearing() throws {
        let entries = try Self.loadRegistry()
        let registered = Set(entries.filter { $0.repo == "coredesign" }.map(\.component))
        let entryPointMembers = Set(try Self.loadEntryPoints().map(\.member))
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rowNames = Set(Self.readmeIndexRows(readmeText).flatMap { Self.candidateNames(fromReadmeCell: $0).names })

        // ⚠️ 非空前置：三个集合任一为空，下面的循环会在空集上恒真。
        #expect(!Self.knownReadmeEntryPointRows.isEmpty, "映射表为空 —— 本守卫会在空循环上恒真")
        #expect(!rowNames.isEmpty, "README 行名解析为空 —— 第 ① 条会恒假、其余恒真")
        #expect(entryPointMembers.count > 20, "登记表只读到 \(entryPointMembers.count) 个入口点成员 —— 疑似解析失效")

        for (rowName, member) in Self.knownReadmeEntryPointRows.sorted(by: { $0.key < $1.key }) {
            // ① key 必须真的是 README 索引里的行名（悬空键 = 过期条目）。
            #expect(rowNames.contains(rowName),
                    "`knownReadmeEntryPointRows` 的 key「\(rowName)」不是 README 索引里的行名 —— 悬空键")
            // ② value 必须真的是登记表 `entryPoints` 里的成员名。
            #expect(entryPointMembers.contains(member),
                    "`knownReadmeEntryPointRows[\(rowName)]` 指向的入口点成员「\(member)」不在登记表的 entryPoints 里")
            // ③ ⚠️ **不许有多余条目**：key 若本来就能被前面几个桶接住（登记条目名 / 成员名
            //    直接同名），这条映射就是**死代码**，而死代码会让人误以为「这里已经守着了」
            //    ——本文件的 `resolveReadmeCandidate` 上一版正是栽在「加了 consult 却不可达」。
            #expect(!registered.contains(rowName) && !entryPointMembers.contains(rowName),
                    "`knownReadmeEntryPointRows` 的 key「\(rowName)」不用映射也能解析（它本身就是登记条目名或入口点成员名）—— 这条是死代码，删掉")
        }
    }

    @Test("`readmeRowCoverage` 自洽：key 真在 README、value 真是条目、理由不是空话")
    func readmeRowCoverageIsSelfConsistent() throws {
        let entries = try Self.loadRegistry()
        let known = Set(entries.map(\.component))
        let readmeText = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/README.md"), encoding: .utf8
        )
        let rowNames = Set(Self.readmeIndexRows(readmeText).flatMap { Self.candidateNames(fromReadmeCell: $0).names })

        // ⚠️ 非空前置：表空了下面全在空循环上恒真。
        #expect(!Self.readmeRowCoverage.isEmpty, "readmeRowCoverage 为空 —— 本守卫会在空循环上恒真")
        #expect(!rowNames.isEmpty, "README 行名解析为空 —— 第 ① 条会恒假、其余恒真")

        for (key, coverage) in Self.readmeRowCoverage.sorted(by: { $0.key < $1.key }) {
            // ① key 必须真的是 README 里的行名。⚠️ key **不要求**自身是登记条目
            //    （`Sidebar` / `Button` 都不是），别把这两条混起来。
            #expect(rowNames.contains(key),
                    "`readmeRowCoverage` 的 key「\(key)」不是 README 组件索引里的行名 —— 悬空键")
            // ② 每个 value 必须真的是登记条目。
            for entry in coverage.entries.sorted() {
                #expect(known.contains(entry),
                        "`readmeRowCoverage[\(key)]` 里的「\(entry)」不是 component-registry.json 的条目 —— 挂了个不存在的名字")
            }
            // ③ 覆盖集合不能为空（空集合等于这条 key 什么都没干）。
            #expect(!coverage.entries.isEmpty, "`readmeRowCoverage[\(key)]` 的覆盖集合为空 —— 删掉它")
            // ④ 理由不能是空话。⚠️ 复用 `BoolExemptionGuard` 的词表，**不复制**（复制即漂移）。
            let lowered = coverage.reason.lowercased()
            let banned = BoolExemptionGuard.bannedReasonPhrases.filter { lowered.contains($0.lowercased()) }
            #expect(banned.isEmpty,
                    "`readmeRowCoverage[\(key)]` 的理由命中空话词 \(banned)：「\(coverage.reason)」—— 「显式理由」这条通道不接空话拦截的话，映射表就还剩一条『写句空话就挂进去』的窄缝")
            #expect(coverage.reason.count >= 8, "`readmeRowCoverage[\(key)]` 的理由太短：「\(coverage.reason)」")
            // ⑤ ⚠️ **value 与 key 必须有结构性对应** —— 这条是 PR #211 本地 Copilot CLI
            //    复审实测的 bypass 补的：前四条只核「名字都真实存在 + 理由不含空话词」，
            //    **没有任何一条核实 value 与 key 之间真有关系**。于是任何真实行名都能挂上
            //    任意真实条目 + 一句「听起来像理由」的话，直接让反向断言对该条目**消音** ——
            //    G-3 想堵的「索引缺行不会红」被绕开。实测：把 `Carousel` 挂到 `Button` 行下、
            //    再从 README 删掉 Carousel 行 ⇒ **四条守卫全过、反向断言也过**。
            //
            //    ⚠️ `bannedReasonPhrases` 是**只挡十来个占位词的黑名单**，挡不住
            //    「听起来像理由但没有实证」的文本 —— 这是那条通道固有的浅层验证。
            //    spec §4.3 原文要求的是「结构关系（前缀 / 同文件 / 显式标注理由）」，
            //    我上一版把「显式理由」当成了**替代项**，实际它只是**补充项**。
            //
            //    结构性判据（满足其一即可，都不满足则必须**显式豁免**并写清）：
            //    · value 以 key 为前缀（`Sidebar` → `SidebarSection`）；
            //    · key 以 value 为前缀（`SettingsRow` → `SettingsRow`）；
            //    · value 去掉常见后缀后与 key 大小写无关地相等（`spinning` → `SpinningModifier`）。
            for entry in coverage.entries.sorted() {
                let lowerKey = key.lowercased()
                let lowerEntry = entry.lowercased()
                let stripped = ["modifier", "style", "view"].reduce(lowerEntry) { acc, suffix in
                    acc.hasSuffix(suffix) ? String(acc.dropLast(suffix.count)) : acc
                }
                let related = lowerEntry.hasPrefix(lowerKey)
                    || lowerKey.hasPrefix(lowerEntry)
                    || stripped == lowerKey
                    || Self.readmeCoverageStructuralExemptions[key]?.contains(entry) == true
                #expect(related, """
                `readmeRowCoverage[\(key)]` 挂了「\(entry)」，但两者**没有结构关系**                 （既非前缀、去掉常见后缀后也不相等）—— 一条真实行名 + 一句不含空话词的理由，                就能把任意条目「洗白」、让反向断言对它消音，那正是 G-3 要堵的口子。                若确有正当理由，加进 `readmeCoverageStructuralExemptions` 并写清依据。
                """)
            }
        }
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
/// - ⚠️ **`BottomInputBar` 曾是本盲区的第二个实例，#221 已使其出盲区**：当时
///   `struct BottomInputBar: View` 没有 `public` 修饰符，本类的
///   `visit(_:StructDeclSyntax)` 一开始就 `guard node.modifiers.contains("public")`，
///   于是整体不可见。#221 把它提为 public 后**扫描器能采到它**，它已按判定法登记。
///   盲区**机制本身不变**（非 public 类型仍整体不可见），只是少了一个实例。
///
/// **现状如何处置**：`Toast` 已人工登记进 `component-registry.json`（终审 C1），并把
/// 条目名加进 `ComponentRegistryGuard.knownOffScannerComponents` 白名单，豁免
/// `registryCoversCoreDesignTypes` 的幽灵条目检查（否则一个扫描器永远看不到的名字
/// 会被永久判「幽灵」）。`BottomInputBar` 走另一条路——公约 AD-2 明确排除「连 public
/// 类型都没有的 modifier 写法」，因此**不登记**，改为在 `docs/component-contract.md`
/// AD-2 与 `oh-my-story` 的 `38-plan.md` 排除清单里点名写死，并把它的 6 个 Bool 参数
/// 移交 `39.md` 给 J-1/FR-4 执行者。⚠️ **这段处置已被 #221 取代**：它提为 public 后
/// 走的是正常登记，不再需要排除条款；其 Bool 参数在 struct 与 modifier 两面各自
/// 登记豁免（见 `docs/bool-exemptions.json`）。⚠️ 本注释与上面白名单注释一样是**留痕**，不是
/// **结构修复**——修复需要让 `PublicTypeCollector` 同时认出「public 但非 View/
/// ViewModifier 的类型」，成本明显更高（要重新定义『组件』在语法树上的判据，而不是
/// 加一个 conformance 名字），本次终审判断为超出 C1 的最小必要修复范围，留给后续任务。
///
/// ⚠️ **`#246` 扩到了 extension 成员**（AD-4《下游连锁二》）：上面记的第三 / 第四个盲区
/// 说的都是「不是 `public struct: View/ViewModifier` 的**类型**看不见」，而还有一整类
/// **根本不是类型**的公开表面同样看不见——`public extension View` 上的方法与
/// `Transition` 的静态成员。它们是调用方真正写下的入口点
/// （`.transition(.iris)` / `.confetti(...)`），task 250 + 251 一共 **24 个**。
/// ⇒ 新增 `entryPoints` 桶，由 `ExtensionEntryPointGuard` 与登记表的 `entryPoints`
/// 数组做双向差集。**它不进 `components`**：那样会被登记表的双向差集判成幽灵条目。
///
/// ⚠️ 本类由 `#246` 从 `private` 提为 internal —— `ExtensionEntryPointGuard` 要用它。
nonisolated final class PublicTypeCollector: SyntaxVisitor {
    var components: Set<String> = []
    var styleImpls: Set<String> = []
    /// `Host.member` 形状的入口点基键（不含 target 前缀）。
    var entryPoints: Set<String> = []

    /// 会产出「入口点」的被扩展类型。
    ///
    /// ⚠️ **不是「所有 extension 都算」**：`extension Tag where Label == Text` 上的
    /// 便利 init 属于 `Tag` 这个**类型**的表面，已经由登记表条目覆盖；只有扩展在
    /// **外部协议**上的成员才是「无处登记」的那一类——它们没有对应的登记表条目，
    /// 因为本仓根本没有 `View` / `Transition` 这两个类型的声明。
    static let entryPointHostTypes: Set<String> = ["View", "Transition", "AnyTransition"]

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

    /// 采 `public extension View` / `extension Transition where Self == …` 上的成员。
    ///
    /// ⚠️ **两种 public 写法都要认**：`public extension View { func f() }` 与
    /// `extension View { public func f() }` 完全等价，只认一种会漏掉半数入口点
    /// （`BoolParameterScanner` 当初踩过同一个坑，见它的「public extension 的两种写法」）。
    /// ⚠️ **含参重载合并成一条**：键是 `Host.member`，不含标签表——
    /// `251.md` 明写计数单位是「一种 transition」而不是「一个静态成员」。
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let host = node.extendedType.trimmedDescription
            .split(separator: ".").last.map(String.init) ?? ""
        guard Self.entryPointHostTypes.contains(host) else { return .visitChildren }
        let extensionIsPublic = node.modifiers.contains(where: { $0.name.text == "public" || $0.name.text == "open" })

        for member in node.memberBlock.members {
            let decl = member.decl
            if let fn = decl.as(FunctionDeclSyntax.self) {
                guard Self.isEffectivelyPublic(fn.modifiers, extensionIsPublic: extensionIsPublic)
                else { continue }
                self.entryPoints.insert("\(host).\(fn.name.text)")
            } else if let variable = decl.as(VariableDeclSyntax.self) {
                guard Self.isEffectivelyPublic(variable.modifiers, extensionIsPublic: extensionIsPublic)
                else { continue }
                for binding in variable.bindings {
                    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                    self.entryPoints.insert("\(host).\(pattern.identifier.text)")
                }
            }
        }
        return .visitChildren
    }

    /// extension 成员的有效可见性：extension 自带 `public` ⇒ 成员默认 public；
    /// 成员显式写了 `private` / `fileprivate` / `internal` ⇒ 以成员为准。
    ///
    /// ⚠️ **`open` 与 `public` 同等对待**（PR #265 Copilot A-2）：`open` 比 `public`
    /// **更**开放（下游还能覆写），只认 `public` 会让 `open` 成为一条绕过登记表覆盖
    /// 守卫的入口点通道。成本是一个字符串。
    /// ⚠️⚠️ **但这条是预防性的，且在当前的 host 清单下不可达**（PR #265 第 3 轮终审 S-f）：
    /// `open` 只对 class 及其成员合法，而 `entryPointHostTypes` 是
    /// `["View", "Transition", "AnyTransition"]`——两个协议 + 一个 struct，
    /// **没有一个能承载 `open` 成员** ⇒ `extension View { open func … }` 编译不过，
    /// 这条分支永远不会被真实输入触发（`ExtensionEntryPointGuard.scannerSeesExtensionMembers`
    /// 里那条 fixture 因此是 SwiftParser 解析得动、编译器接受不了的合成输入，
    /// 与本 PR 其余「植入真实可编译的违规文件」的证据标准不同，已在该处照录）。
    /// ⇒ 它的价值是「`entryPointHostTypes` 将来若纳入 class 宿主（如某个
    /// `open class` 的样式基类），这条不必再补」，**不是**「今天堵住了一条真实通道」。
    private static func isEffectivelyPublic(
        _ modifiers: DeclModifierListSyntax, extensionIsPublic: Bool
    ) -> Bool {
        let names = Set(modifiers.map(\.name.text))
        if names.contains("private") || names.contains("fileprivate") || names.contains("internal") {
            return false
        }
        return names.contains("public") || names.contains("open") || extensionIsPublic
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
