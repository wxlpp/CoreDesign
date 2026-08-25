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
        // ⚠️ 判「失败」的信号是**四个桶全空**，不是「`textParams` 空」（PR #195 第 2 轮 review）：
        // 失败路径返回的是全空的 `ComponentJudgeScanResult()`，所以两种写法对**失败情形完全等价**；
        // 但只看 `textParams` 会把「扫描成功、恰好零文本参数」（例如 FR-4 定义域调整）也判成失败，
        // 于是缓存永远不写入、每个 suite 反复全盘解析源码。取全空作信号，两头都对。
        let allBucketsEmpty =
            result.textParams.isEmpty && result.styleProtocols.isEmpty
            && result.conformances.isEmpty && result.typeDeclFiles.isEmpty
        if !allBucketsEmpty { Self.cached = result }
        return result
    }
}

// MARK: - J-2

@Suite("J-2 样式扩展点")
struct ComponentExtensionPointGuard {

    /// J-2 的**已知缺口**：登记表判定法已给出「应该有扩展点」的结论，源码里的扩展点尚未落地。
    ///
    /// ⚠️ **这条是「待补的扩展点」，不是判据 bug**（`40.md` Technical Details 明令）：
    /// `Toast` 走判定法步骤 2（贴边胶囊 / 全宽横幅 / 居中 HUD 三种结构本身不同的替代形态），
    /// `customStyleProtocol` 仍是 `null`，源码里没有 `ToastStyle`。**正确处置是开后续任务
    /// 补扩展点**，不是回头改 J-2 的判据逻辑，也不是把 `needsExtensionPoint` 改回 `false`。
    ///
    /// ⚠️ **#41 已把 `Rating` 摘出去**：裁决 4c 补齐了 `RatingStyle`（协议 + `StarRatingStyle`
    /// + `EnvironmentValues.ratingStyle` + `View.ratingStyle(_:)`，且 `Rating.body` 真的经
    /// `style.makeBody(configuration:)` 渲染），登记表 `customStyleProtocol` 同轮填上
    /// ⇒ 它现在走 `satisfied` 分支。集合从 `{Rating, Toast}` 收缩到 `{Toast}` 是**判据能
    /// 逐条跟踪修复进度**的证据，不是一次性全绿——`Toast` 刻意留在红名单里（41-spec 第一节）。
    /// ⚠️ **#59 增补（判定法修订的到期通路，不是「改守卫迁就」）**：#59 裁定
    /// `D-53-17`（(A) 不成立 ⇒ 重跑步骤 2）后，按修订后的判据重判 `53-stress.md`
    /// 全部 17 条，落「出口 1（语义组件、需要扩展点）」的条目按方案 C 如实改
    /// `decidedBy: step2` / `kind: semantic` / `needsExtensionPoint: true`，扩展点
    /// 实现移交 **wxlpp/oh-my-story#60**。⇒ 与 `Toast` 完全同构：判定法结论已产出、
    /// 实现未跟上。按本集合下方注释的口径（「变小 ⇒ 已知缺口补上了，同步删除」），
    /// 该集合本就随判定结论增删 ⇒ 本轮增补。逐条取证见 oh-my-story
    /// `.claude/epics/component-contract/59-rejudge.md`。
    static let knownMissingExtensionPoints: Set<String> = ["SidebarUtilityRow", "Toast"]

    @Test("J-2：语义组件必须有样式扩展点（原生协议采纳 或 自有协议定义+使用）")
    func semanticComponentsHaveExtensionPoint() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeExtensionPoints(entries: entries, scan: scan)

        // ⚠️ **非空断言先行**（AC 原文点名）：若登记表里一个 semantic 组件都没有，
        // 「零输入 ⇒ 零违规 ⇒ 绿」会静默通过。判据必须能识别并报告这种异常。
        #expect(result.inspected.count == 11,
                "J-2 定义域实测 11 条（AvatarGroup/Banner/ProgressIndicator/Rating/RatingDisplay/SegmentedControl/SidebarUtilityRow/SpinningModifier/Steps/Timeline/Toast），实际 \(result.inspected.count) 条：\(result.inspected)")
        #expect(!result.satisfied.isEmpty,
                "没有任何语义组件被判为『扩展点存在』—— 扫描器失效时也会长这样，这不是零违规")
        // ⚠️ 扫描器承重自检：三条「已满足」的通路各自真的走通了，而不是集合恰好为空。
        #expect(result.satisfied["ProgressIndicator"]?.contains("ProgressViewStyle") == true,
                "nativeProtocol 通路未走通：\(result.satisfied["ProgressIndicator"] ?? "(缺)")")
        #expect(result.satisfied["Banner"]?.contains("BannerStyle") == true,
                "customStyleProtocol 通路未走通：\(result.satisfied["Banner"] ?? "(缺)")")
        #expect(result.satisfied["SegmentedControl"]?.contains("SegmentedControlStyle") == true,
                "customStyleProtocol 通路（第二例）未走通：\(result.satisfied["SegmentedControl"] ?? "(缺)")")
        #expect(result.satisfied["RatingDisplay"]?.contains("RatingStyle") == true,
                "customStyleProtocol 通路（#41 新增的第三例，与 Rating 复用同一个协议）未走通：\(result.satisfied["RatingDisplay"] ?? "(缺)")")

        // ⚠️ **主判据 —— `withKnownIssue` 只包住这一句**（#39 Task 8 变异实测：块里多包
        // 一句，新违规会被静默吞掉，只有块外的 canary 会红）。
        // ⚠️ 这条豁免的**到期是机器强制的**：`Toast` 补上扩展点之后块内不再
        // 记录 issue，Swift Testing 会主动判红，逼人回来删掉这段——这正是它优于
        // 「预置一个 expected 集合然后 `#expect(==)`」的地方（后者绿着，没人会回头看）。
        withKnownIssue(
            """
            J-2 已知缺口，剩 2 条：`Toast` 与 `SidebarUtilityRow` 的样式扩展点尚未落地。\
            ⚠️ **两条都不指向 #60** —— 别把它们读成「#60 待做」，#60 已 closed：\
            `SidebarUtilityRow` 被 60-form-decision.md §5 判为「建议退回重判，不在本轮开扩展点」\
            （三个候选跨槽/排布两类、判定自噬），须先重判形态才谈得上实现 ⇒ 承接
            **wxlpp/oh-my-story#64**；\
            `Toast` 从来不在 #60 范围内，是 #59 之前就存在的既有缺口 ⇒ 承接
            **wxlpp/oh-my-story#65**。\
            已摘除的：Steps / Timeline / AvatarGroup / SpinningModifier 由 wxlpp/oh-my-story#60 \
            以公约 §2 形态 D2「配置枚举」补齐（CoreDesign PR #206，已合并）；\
            Rating 由 #41 裁决 4c 补齐。\
            补齐后本块无 issue 记录 ⇒ Swift Testing 主动判红，届时删除本块。
            """
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
