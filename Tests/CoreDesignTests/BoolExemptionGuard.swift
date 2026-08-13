import Foundation
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
// ⚠️ **豁免基线是两份文件**（`39-plan.md` 选型 2）：`docs/bool-exemptions.json` 是清单本身，
// `docs/bool-exemptions-baseline.json` 只记一个上限。一份文件时「改清单」与「改基线」是
// **同一个动作**，棘轮的唯一实现只能是「diff `main` 的历史版本」，而本仓 CI 是
// `actions/checkout@v4` 默认 `fetch-depth: 1`（历史里没有 `main`），且五个 CoreDesign
// 任务集成在 `epic/component-contract`、`main` 上在 #42 之前根本没有这个文件
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
        // ⚠️ **要打名单不只是数**：Task 3 要照这份名单写 `bool-exemptions.json`。
        print("【J-1 命中】\(scan.keys.count) 个豁免键 / \(scan.hits.count) 处源码位置：")
        for hit in scan.hits.sorted() { print("  \(hit.key)  ←  \(hit.file):\(hit.line)") }
        print("【裁决 (b) 归类为 .boolCarrying，不判违规】\(scan.carrying.count) 处：")
        for hit in scan.carrying.sorted() { print("  \(hit.key)  ←  \(hit.file):\(hit.line)") }
        print("【裁决 (d) public Bool 属性，只清点不判据】\(scan.publicBoolProperties.count) 处：")
        for name in scan.publicBoolProperties.sorted() { print("  \(name)") }
        print("【裁决 (f) 含 Bool 的 public typealias，必须为 0】\(scan.publicBoolTypeAliases.count) 处：")
        for name in scan.publicBoolTypeAliases.sorted() { print("  \(name)") }
    }
}
