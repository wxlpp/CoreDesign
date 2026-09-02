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
        let decidedBy: String               // step1|step2|step3|tiebreaker|precedent|exclusion
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
    }
    struct TextParam: Codable { let name: String; let category: String }  // A|B|C|by-type

    static let validKinds: Set<String> = ["semantic", "prescriptive", "excluded"]
    static let validDecidedBy: Set<String> = [
        "step1", "step2", "step3", "tiebreaker", "precedent",
        "exclusion",   // ⚠️ 弃用条款先于步骤 1–4，AC 的五个取值没有一个对应它
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
    /// `coreDesignScan().styleImpls` 里，把白名单变成**承重**的判据。
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
        _ name: String, isTombstone: Bool, registered: Set<String>, styleImpls: Set<String>
    ) -> Bool {
        if registered.contains(name) { return true }
        if isTombstone { return Self.knownReadmeTombstones.contains(name) }
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

    /// 抽出 `docs/README.md` 「## 组件索引」小节里的表格数据行（跳过表头与分隔行），
    /// 每个元素是该行第一列的原始文本。
    static func readmeIndexRows(_ text: String) -> [String] {
        guard let sectionStart = text.range(of: "## 组件索引") else { return [] }
        let sectionEnd = text.range(
            of: "## 生成预览图", range: sectionStart.upperBound..<text.endIndex
        )?.lowerBound ?? text.endIndex
        let section = text[sectionStart.upperBound..<sectionEnd]

        return section.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") else { return nil }
            // ⚠️ `trimmed` 以 "|" 开头，`split(separator: "|")` 会在 index 0 产出一个
            // 空字符串（前导定界符前的内容），第一个真实单元格是 index 1，不是 index 0。
            let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count > 1 else { return nil }
            let first = cells[1]
            guard !first.isEmpty else { return nil }
            guard first != "组件" else { return nil }                       // 表头行
            guard !first.allSatisfy({ $0 == "-" }) else { return nil }      // 分隔行
            return first
        }
    }

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
    private static var cachedCoreDesignScan: ScanResult?

    /// 三条判据统一走这个入口，不要直接调 `scanTypes(root: coreDesignSources)`。
    static func coreDesignScan() throws -> ScanResult {
        if let cached = Self.cachedCoreDesignScan { return cached }
        let result = try Self.scanTypes(root: Self.coreDesignSources)
        // 见上：空结果说明扫描失败，不缓存。
        if !result.components.isEmpty { Self.cachedCoreDesignScan = result }
        return result
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
        #expect(entries.filter { $0.repo == "coredesign" }.count == 47,
                "CoreDesign 侧条目数不是 47（#221 把 BottomInputBar 提为 public 并按判定法补录后由 46 变为 47）——若为新增属预期变化请同步改这个数字；若无源码变更条目却变了，是静默删条目/改 repo 的信号")
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

    @Test("扫描器真的扫到了 CoreDesign 的类型")
    func scannerFindsCoreDesignTypes() throws {
        let r = try Self.coreDesignScan()
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
        let scanned = try Self.coreDesignScan().components
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
        let scan = try Self.coreDesignScan()
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

        var unresolved: [String] = []
        for raw in rows {
            let (names, isTombstone) = Self.candidateNames(fromReadmeCell: raw)
            for name in names
            where !Self.resolveReadmeCandidate(
                name, isTombstone: isTombstone, registered: registered, styleImpls: scan.styleImpls
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
