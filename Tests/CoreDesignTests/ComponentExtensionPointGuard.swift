import Foundation
import Testing

// MARK: - 共享扫描入口 / Shared scan entry

/// 三条判据（J-2 / J-3 / FR-4）共用的源码扫描缓存。
///
/// 本仓 `Package.swift` 设了 `.defaultIsolation(MainActor.self)`，测试**串行**执行
/// ⇒ 这个可变静态量不需要额外同步（照 #38 `ComponentRegistryGuard.cachedCoreDesignScan`
/// 的成法）。
///
/// ⚠️ **只缓存「成功且非空」的结果**：`scanComponentJudgeInputs` 的失败路径（路径不存在 /
/// 无法枚举）返回空结果。若把空结果也缓存下来，第一条判据吃到失败、后两条却拿着缓存里的
/// 空集算差集 ⇒「零命中 ⇒ 零违规 ⇒ **绿**」——正是本 epic 反复栽的「测量工具制造自己的绿」。
enum ComponentJudgeSources {
    private static var cached: ComponentJudgeScanResult?

    static func scan() throws -> ComponentJudgeScanResult {
        if let cached = Self.cached { return cached }
        let result = try scanComponentJudgeInputs(root: ComponentRegistryGuard.coreDesignSources)
        if !result.textParams.isEmpty { Self.cached = result }
        return result
    }
}

// MARK: - J-2

@Suite("J-2 样式扩展点")
struct ComponentExtensionPointGuard {

    /// J-2 的**已知缺口**：登记表判定法已给出「应该有扩展点」的结论，源码里的扩展点尚未落地。
    ///
    /// ⚠️ **这两条是「待补的扩展点」，不是判据 bug**（`40.md` Technical Details 明令）：
    /// `Rating` 走判定法步骤 2（数字条 / 表情两种结构本身不同的替代形态），`Toast` 同理
    /// （贴边胶囊 / 全宽横幅 / 居中 HUD）——两条的 `customStyleProtocol` 都还是 `null`，
    /// 源码里没有 `RatingStyle` / `ToastStyle`。**正确处置是开后续任务补扩展点**，
    /// 不是回头改 J-2 的判据逻辑，也不是把 `needsExtensionPoint` 改回 `false`。
    static let knownMissingExtensionPoints: Set<String> = ["Rating", "Toast"]

    @Test("J-2：语义组件必须有样式扩展点（原生协议采纳 或 自有协议定义+使用）")
    func semanticComponentsHaveExtensionPoint() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeExtensionPoints(entries: entries, scan: scan)

        // ⚠️ **非空断言先行**（AC 原文点名）：若登记表里一个 semantic 组件都没有，
        // 「零输入 ⇒ 零违规 ⇒ 绿」会静默通过。判据必须能识别并报告这种异常。
        #expect(result.inspected.count == 5,
                "J-2 定义域实测 5 条（ProgressIndicator/SegmentedControl/Banner/Rating/Toast），实际 \(result.inspected.count) 条：\(result.inspected)")
        #expect(!result.satisfied.isEmpty,
                "没有任何语义组件被判为『扩展点存在』—— 扫描器失效时也会长这样，这不是零违规")
        // ⚠️ 扫描器承重自检：三条「已满足」的通路各自真的走通了，而不是集合恰好为空。
        #expect(result.satisfied["ProgressIndicator"]?.contains("ProgressViewStyle") == true,
                "nativeProtocol 通路未走通：\(result.satisfied["ProgressIndicator"] ?? "(缺)")")
        #expect(result.satisfied["Banner"]?.contains("BannerStyle") == true,
                "customStyleProtocol 通路未走通：\(result.satisfied["Banner"] ?? "(缺)")")
        #expect(result.satisfied["SegmentedControl"]?.contains("SegmentedControlStyle") == true,
                "customStyleProtocol 通路（第二例）未走通：\(result.satisfied["SegmentedControl"] ?? "(缺)")")

        // ⚠️ **主判据 —— `withKnownIssue` 只包住这一句**（#39 Task 8 变异实测：块里多包
        // 一句，新违规会被静默吞掉，只有块外的 canary 会红）。
        // ⚠️ 这条豁免的**到期是机器强制的**：`Rating` / `Toast` 补上扩展点之后块内不再
        // 记录 issue，Swift Testing 会主动判红，逼人回来删掉这段——这正是它优于
        // 「预置一个 expected 集合然后 `#expect(==)`」的地方（后者绿着，没人会回头看）。
        withKnownIssue(
            "J-2 已知缺口：Rating / Toast 的样式扩展点尚未落地（判定法结论已产出、实现未跟上）。补齐后本块无 issue 记录 ⇒ Swift Testing 主动判红，届时删除本块。"
        ) {
            #expect(result.missing.isEmpty, "这些语义组件缺样式扩展点：\n\(result.diagnostics.joined(separator: "\n"))")
        }

        // ⚠️ **块外 canary：新违规不能被上面的 knownIssue 吞掉**。
        // 这条与上面那条不是重复——上面那条负责「已知缺口到期」，这条负责「集合不许变大」。
        #expect(Set(result.missing) == Self.knownMissingExtensionPoints,
                """
                J-2 违规集合变了：实际 \(result.missing.sorted())，已知 \(Self.knownMissingExtensionPoints.sorted())。\
                变大 ⇒ 新增了缺扩展点的语义组件（上面的 withKnownIssue 会把它静默吞掉，靠本条抓）；\
                变小 ⇒ 已知缺口补上了，同步删除 knownMissingExtensionPoints 与上面的 withKnownIssue 块
                """)

        // ⚠️ **承重核对**：已知缺口条目必须仍是「semantic + 要扩展点 + 两个协议字段皆 null」。
        // 少了这条，把 `Rating` 的 `needsExtensionPoint` 改成 `false` 就能让它退出定义域、
        // 让上面两条断言一起变绿——正是任务书点名禁止的「回头改登记表让判据闭嘴」。
        for component in Self.knownMissingExtensionPoints {
            guard let entry = entries.first(where: { $0.component == component }) else {
                Issue.record("已知缺口条目 \(component) 已不在登记表里 —— 请同步更新 knownMissingExtensionPoints")
                continue
            }
            #expect(entry.kind == "semantic" && entry.needsExtensionPoint,
                    "\(component) 不再是『semantic + 要扩展点』（kind=\(entry.kind), needs=\(entry.needsExtensionPoint)）—— 任务书明令不得靠改登记表让 J-2 闭嘴")
            #expect(entry.nativeProtocol == nil && entry.customStyleProtocol == nil,
                    "\(component) 已经填上了协议字段但源码没跟上，或反之 —— 请重新核对，不要留在已知缺口里")
        }

        // ⚠️ **两个协议字段互斥棘轮 —— 堵掉 `judgeExtensionPoints` 的分支序静默口**。
        // 该函数是 `if let custom … else if let native …`，custom 在前 ⇒ 两字段同时非空时
        // native 侧被静默略过、判据照绿。实测今日零此形态；这条断言把「今日为零」变成机器
        // 判据，第一条这样的条目出现时立刻红，而不是悄悄走 custom 分支。
        // （规则层同时会往 `diagnostics` 里留一行，两处互为备份。）
        let bothProtocolFields = entries.filter {
            $0.repo == "coredesign" && $0.nativeProtocol != nil && $0.customStyleProtocol != nil
        }
        #expect(bothProtocolFields.isEmpty,
                """
                这些条目 nativeProtocol 与 customStyleProtocol 同时非空：\(bothProtocolFields.map(\.component))。\
                judgeExtensionPoints 会按 customStyleProtocol 优先裁决、静默略过 native 侧 —— \
                请回 #38 确认两字段是否应互斥，或把判据改成两侧都核对（并同步删掉本断言）
                """)

        // ⚠️ **跨仓裁决 (a)：显式报告 + 棘轮**，不静默略过。
        #expect(result.skippedRepos == ["storyui": 25],
                "跨仓跳过计数变了：实际 \(result.skippedRepos)。CI 只 checkout 本仓，StoryUI 侧无源码可核对（移交 #43）；这个固定计数是唯一挡『静默删条目 / 改 repo』的机器判据")
        #expect(entries.filter { $0.repo == "storyui" && $0.kind == "semantic" }.isEmpty,
                "StoryUI 侧出现了 semantic 条目 —— J-2 在本仓无源码可核对，必须移交 #43 落地跨仓判据，不得靠裁决 (a) 的跳过静默放过")

        print("J-2 定义域 \(result.inspected.count) 条：\(result.inspected)")
        for (component, reason) in result.satisfied.sorted(by: { $0.key < $1.key }) {
            print("J-2 ✓ \(component)：\(reason)")
        }
        print("J-2 已知缺口 \(result.missing)（待补扩展点，移交后续任务）")
        print("⚠️ J-2 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条：CI 只 checkout 本仓，跨仓核对移交 #43。")
    }
}

// MARK: - J-3

@Suite("J-3 原生协议纯度")
struct NativeProtocolPurityGuard {

    /// **绿色正对照**的两个组件：它们的作用域里**必须**存在自有样式协议。
    ///
    /// ⚠️ **它挡的是「探针退化成恒空」，不是「主判据逻辑写坏」**：J-3 的真实输入只有
    /// `ProgressIndicator` 一条，主判据「作用域里没有自有协议 ⇒ 绿」在探针恒返回空集时
    /// **同样是绿**。把探针反向施加到这两个必然命中的组件上，探针一死，这里立刻红。
    /// ⚠️ **这条红能推到主判据身上，前提是 `judgeNativeProtocolPurity` 消费本探针**
    /// （Task 7 的结构约束，由规则层的 `j3JudgeConsumesTheProbe` 钉住）。判据若自带一份
    /// 内联副本，正对照红只证明副本之外那份死了——主判据可能照常工作，也可能早就写坏而无人
    /// 知晓。⇒ 改动 `customStyleProtocolsInScope` 或 `judgeNativeProtocolPurity` 的调用
    /// 关系前，先读 Task 8 的防线表。
    /// ⚠️ **两个正对照走的都是通道 (i)（作用域内声明）**：通道 (ii) 单独死掉时本条**不红**，
    /// 那一侧由规则层的 `j3MutationConformanceChannel` 与 Task 11 的端到端变异挡。
    static let positiveControls: [String: String] = [
        "Banner": "BannerStyle",
        "SegmentedControl": "SegmentedControlStyle",
    ]

    @Test("J-3：标注 nativeProtocol 的组件，作用域内不得出现自有样式协议")
    func nativeProtocolComponentsAreFreeOfCustomStyleProtocols() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeNativeProtocolPurity(entries: entries, scan: scan)

        // 防线 1：输入集合固定 —— AC 明令「对 nativeProtocol != null 的集合做了**实际
        // 源码扫描**且返回非零条数的检查记录」，不是「集合为空所以全绿」。
        #expect(result.inspected.count == 1,
                "J-3 定义域实测 1 条，实际 \(result.inspected.count) 条：\(result.inspected.keys.sorted())")
        #expect(result.inspected["ProgressIndicator"] != nil,
                "J-3 唯一的定义域成员应是 ProgressIndicator（本仓唯一 nativeProtocol 非空的条目）")

        // 防线 2：作用域真的解析出来了（扫到了非零个源码文件）。
        #expect(result.unresolvedScopes.isEmpty,
                "这些组件的声明文件定位不到 —— 判据没能运行，这不是『零违规』：\(result.unresolvedScopes)")
        #expect(result.inspected["ProgressIndicator"] == ["ProgressIndicator.swift"],
                "ProgressIndicator 的作用域文件实测为 ProgressIndicator.swift，实际 \(result.inspected["ProgressIndicator"] ?? [])")

        // 主判据（**无 withKnownIssue**：J-3 当前零违规，没有已知缺口要豁免）。
        #expect(result.violations.isEmpty,
                """
                这些标注了 nativeProtocol 的组件，作用域内出现了自有样式协议：
                \(result.violations.map { "\($0.component) ← \($0.symbol)（\($0.channel)，\($0.file)）" }.joined(separator: "\n"))
                """)

        // 防线 3：绿色正对照 —— 探针必须在必然命中的组件上命中。
        // ⚠️ 主判据消费的就是这个探针（Task 7 的结构约束）⇒ 这里红等于主判据的探测通路死了。
        for (component, expected) in Self.positiveControls.sorted(by: { $0.key < $1.key }) {
            let found = customStyleProtocolsInScope(of: component, scan: scan)
            #expect(found.contains { $0.symbol == expected },
                    """
                    正对照失效：\(component) 的作用域里应能探到 \(expected)，实际 \(found)。\
                    探针一旦恒返回空集，J-3 只有 1 条输入的主判据会静默全绿 —— 而主判据的违规逐字来自本探针，\
                    所以这条红同时意味着主判据已经失去发现违规的能力
                    """)
            #expect(found.contains { $0.symbol == expected && $0.channel == "作用域内声明" },
                    "正对照的两个组件都应走通道 (i)：\(component) 实际 \(found)")
        }
        // 反向对照：ProgressIndicator 上探到的必须是空集（与主判据同源，但换一个入口读，
        // 保证探针在「有命中」与「无命中」两侧都被使用过）。
        #expect(customStyleProtocolsInScope(of: "ProgressIndicator", scan: scan).isEmpty)

        // 跨仓裁决 (a)：显式报告 + 棘轮。
        #expect(result.skippedRepos == ["storyui": 25],
                "跨仓跳过计数变了：实际 \(result.skippedRepos)")
        #expect(entries.filter { $0.repo == "storyui" && $0.nativeProtocol != nil }.isEmpty,
                "StoryUI 侧出现了 nativeProtocol 非空的条目 —— 本仓读不到那边源码，必须移交 #43")

        print("J-3 定义域 \(result.inspected.count) 条：\(result.inspected.mapValues { $0.sorted() })")
        print("J-3 正对照：" + Self.positiveControls.keys.sorted().map {
            "\($0) → \(customStyleProtocolsInScope(of: $0, scan: scan).map { "\($0.symbol)(\($0.channel)@\($0.file))" })"
        }.joined(separator: "；"))
        print("⚠️ J-3 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条：CI 只 checkout 本仓，跨仓核对移交 #43。")
    }
}
