import Foundation
import Testing

// MARK: - 共享扫描入口 / Shared scan entry

/// 三条判据（J-2 / J-3 / FR-4）共用的源码扫描缓存。
///
/// 本仓 `Package.swift` 设了 `.defaultIsolation(MainActor.self)`，测试**串行**执行
/// ⇒ 这个可变静态量不需要额外同步（照 #38 `ComponentRegistryGuard` 的缓存成法；
/// 那个**属性**在 #38 时叫 `cachedCoreDesignScan`、它支撑的**函数**叫 `coreDesignScan`，
/// `#270` 之后现名分别是 `cachedComponentScan` 与 `componentScan`
/// ——⚠️ 四个都是历史 / 现名的**裸符号名，刻意不连点写成限定名**：
/// `JudgementReferenceGuard` 不区分活引用与撤回痕迹，连点写会被判成悬空引用）。
///
/// ⚠️ **只缓存「成功且非空」的结果**：`scanComponentJudgeInputs` 的失败路径（路径不存在 /
/// 无法枚举）返回空结果。若把空结果也缓存下来，第一条判据吃到失败、后两条却拿着缓存里的
/// 空集算差集 ⇒「零命中 ⇒ 零违规 ⇒ **绿**」——正是本 epic 反复栽的「测量工具制造自己的绿」。
enum ComponentJudgeSources {
    private static var cached: ComponentJudgeScanResult?

    static func scan() throws -> ComponentJudgeScanResult {
        if let cached = Self.cached { return cached }
        let result = try scanComponentJudgeInputs(roots: ComponentRegistryGuard.componentScanRoots)
        // ⚠️ 判「失败」的信号是**四个桶全空**，不是「`textParams` 空」（PR #195 第 2 轮 review）：
        // 失败路径返回的是全空的 `ComponentJudgeScanResult()`，所以两种写法对**失败情形完全等价**；
        // 但只看 `textParams` 会把「扫描成功、恰好零文本参数」（例如 FR-4 定义域调整）也判成失败，
        // 于是缓存永远不写入、每个 suite 反复全盘解析源码。取全空作信号，两头都对。
        // ⚠️ 判据本体已抽成 `ComponentJudgeScanResult.isEmpty`（PR #297 终审 S-3）——
        // `scanComponentJudgeInputs(roots:)` 的**逐根**非空断言用的是同一份定义，
        // 两处各写一份必然漂。
        if !result.isEmpty { Self.cached = result }
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
    /// ⚠️ **上句是当时的记录。现状（`#65`）：`Toast` 已补齐，集合再收缩到空集** ——
    /// 「逐条跟踪修复进度」这个论点由 `{Rating,Toast}` → `{Toast}` → `{}` 三段完整走完。
    /// ⚠️ **#59 增补（判定法修订的到期通路，不是「改守卫迁就」）**：#59 裁定
    /// `D-53-17`（(A) 不成立 ⇒ 重跑步骤 2）后，按修订后的判据重判 `53-stress.md`
    /// 全部 17 条，落「出口 1（语义组件、需要扩展点）」的条目按方案 C 如实改
    /// `decidedBy: step2` / `kind: semantic` / `needsExtensionPoint: true`，扩展点
    /// 实现移交 **wxlpp/oh-my-story#60**。⇒ 与 `Toast` 完全同构：判定法结论已产出、
    /// 实现未跟上。按本集合下方注释的口径（「变小 ⇒ 已知缺口补上了，同步删除」），
    /// 该集合本就随判定结论增删 ⇒ 本轮增补。逐条取证见 oh-my-story
    /// `.claude/epics/component-contract/59-rejudge.md`。
    /// ⚠️ **空集**：J-2 的扩展点缺口已全部收口（`Toast` 由 `wxlpp/oh-my-story#65`
    /// 以形态 D2 补齐，是最后一条）。
    ///
    /// ⚠️ 空集时下面的棘轮断言 `Set(result.missing) == knownMissingExtensionPoints`
    /// 退化为「`missing` 必须为空」—— **语义更强、不是更弱**：此后任何新增的语义组件
    /// 若没有扩展点，会直接判红，不再有「已知缺口」这个缓冲。
    ///
    /// ⚠️ **`#299` 增补 5 条，集合由空集变回非空**（上面两段是 `#65` 当时的记录，不改写）。
    /// 成因与 `#59` 那次**完全同构**，逐条对齐：
    /// · `#299` 对 `#270` 留下的 6 条 `decidedBy: pendingStep2` 条目补做了公约步骤 2 的
    ///   候选枚举与来源核验，其中 **5 条落出口 1**（`RadarChart` / `RingChart` /
    ///   `ActivityHeatmap` / `NetworkGraph` / `BeforeAfterSlider`），按公约如实改
    ///   `decidedBy: step2` / `kind: semantic` / `needsExtensionPoint: true`；
    /// · 判定法结论**已产出**，扩展点**实现未跟上** —— 与 `Toast` 当年一字不差；
    /// · 扩展点实现移交 **`#312`**（形态 A/B/D 四选一的设计须在那边单独走一次，
    ///   `D-59-1` 裁定后优先考虑形态 D：槽 / 枚举可演进，public 协议不可撤）。
    ///
    /// ⚠️⚠️ **这不是「为了让判据变绿把新条目塞回红名单」**（下方 canary 的失败文案逐字
    /// 禁止那件事）。两者的区别是**可核验的**，不是措辞之争：
    /// · 消音器 = 名字进表、**没有承接 issue**、判定理由停留在「反正判据红了」；
    /// · 本次 = 每一条的 `notes` 里写着**逐条枚举出的候选 + 可点开的来源 URL + 三分法归类
    ///   + 作用域三条件的逐条核验**，落点是公约的出口 1，承接 issue 是 `#312`。
    /// 红名单自身的成文语义就是「**有承接 issue 的**已知缺口」——本次正是它设计要装的东西。
    ///
    /// ⚠️ **第 6 条 `OrbitingLogos` 没进来**：它本轮落**步骤 4**（`tiebreaker`，`kind`
    /// 仍 `prescriptive`）⇒ 不进 J-2 定义域。⇒ 这批的落点**不是一边倒**，也就不是
    /// 「一律判成 semantic 好把问题推走」。
    static let knownMissingExtensionPoints: Set<String> = [
        "ActivityHeatmap", "BeforeAfterSlider", "NetworkGraph", "RadarChart", "RingChart",
    ]

    /// J-2 侧的承接 issue 号。**写成常量并被下面的断言引用**，而不是只出现在散文里。
    ///
    /// ⚠️ **`#315` 终审 I-5**：红名单的成文语义逐字是「**有承接 issue 的**已知缺口」，
    /// 而在此之前这句只活在本文件的注释与失败文案里 —— **没有任何断言**要求
    /// `knownMissingExtensionPoints` 的成员真的在 `notes` 里写着承接 issue 号。
    /// 对照组：`pendingStep2` 侧**有**这条判据（`ComponentRegistryGuard` 里
    /// `for e in entries where e.decidedBy == "pendingStep2" { #expect(e.notes.contains(...)) }`），
    /// 但那个集合本轮已收口为空 ⇒ 那条判据当前**空转**。⇒ 把同一条照抄到 J-2 侧，
    /// 让「名字进表但没有承接点」（也就是把红名单当消音器用）当场判红。
    /// ⚠️ 5 条 `notes` 实测都写了 `#312`，但在本条之前**没有东西挡下一个人不写**。
    ///
    /// ⚠️⚠️ **`#315` 第 2 轮终审 F-3：本常量重新引入了 I-6 刚移除掉的那个缺陷族。**
    /// 下面那条聚合断言只核「`notes` 里有没有这个号」，**没有任何判据核对 `#312` 是否仍 OPEN**
    /// —— 若 `#312` 在 5 条扩展点落地前被关闭，判据**照绿**，并继续指着一个关掉的号
    /// （`pendingStep2FollowUpIssue` 那一侧正是因为这个才在 I-6 被改成 `nil`）。
    /// ⇒ **关闭 `#312` 之前必须满足下列之一**（已登记进 `#312` 正文的同名小节）：
    /// · `knownMissingExtensionPoints` 已收缩为空集 ⇒ 本常量与下面那条断言一并删除；
    /// · 红名单仍非空 ⇒ **先**把本常量改指一个尚未关闭的新承接 issue、并同步 5 条 `notes`，
    ///   **再**关闭 `#312`。
    static let extensionPointFollowUpIssue = "#312"

    @Test("J-2：语义组件必须有样式扩展点（原生协议采纳 或 自有协议定义+使用）")
    func semanticComponentsHaveExtensionPoint() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeExtensionPoints(entries: entries, scan: scan)

        // ⚠️ **非空断言先行**（AC 原文点名）：若登记表里一个 semantic 组件都没有，
        // 「零输入 ⇒ 零违规 ⇒ 绿」会静默通过。判据必须能识别并报告这种异常。
        // ⚠️ **`#299` 由 11 改 16**：`RadarChart` / `RingChart` / `ActivityHeatmap` /
        // `NetworkGraph` / `BeforeAfterSlider` 五条重判落出口 1 ⇒ `kind: semantic` ⇒
        // 进 J-2 定义域。⚠️ 这正是公约 AD-4《下游连锁一》**预判过**的那条链
        // （`step1/2 ⇒ semantic ⇒ 硬断言 needsExtensionPoint ⇒ 进 J-2 定义域 ⇒
        // `inspected.count` 变红`）—— `#270` 当时因 15 条全落 prescriptive 而没触发，
        // `#299` 触发了。
        #expect(result.inspected.count == 16,
                "J-2 定义域实测 16 条（ActivityHeatmap/AvatarGroup/Banner/BeforeAfterSlider/NetworkGraph/ProgressIndicator/RadarChart/Rating/RatingDisplay/RingChart/SegmentedControl/SidebarUtilityRow/SpinningModifier/Steps/Timeline/Toast），实际 \(result.inspected.count) 条：\(result.inspected)")
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

        // ⚠️ **主判据。原本这里有一个 `withKnownIssue` 块包着它**（`Toast` 是最后一条
        // 已知缺口）—— `wxlpp/oh-my-story#65` 以形态 D2 补齐后，块内不再记录 issue，
        // Swift Testing 主动判红，**逼人回来删掉那段**。本次删除就是那条机制的兑现。
        //
        // ⇒ 这正是它优于「预置一个 expected 集合然后 `#expect(==)`」的地方：后者补齐后
        // 仍然绿着，没人会回头看。⚠️ 将来若又出现已知缺口，**照原样重建 `withKnownIssue`
        // 块（只包住下面这一句）**，别改成宽松断言 —— #39 Task 8 变异实测过：块里多包一句，
        // 新违规会被静默吞掉，只有块外的 canary 会红。
        // ⚠️ **`#299` 按上面那段注释自己的指令重建了 `withKnownIssue` 块**
        // （逐字：「将来若又出现已知缺口，**照原样重建 `withKnownIssue` 块（只包住下面这一句）**，
        // 别改成宽松断言」）—— 「只包住一句」的理由与变异证据见上一段，此处不再复述
        // （`#315` 终审 S-7：上一版把那两句逐字重复了一遍）。
        // ⚠️ `#312` 把 5 条扩展点补齐后，块内不再有 issue 记录 ⇒ Swift Testing 主动判红，
        // **逼人回来删掉这个块**。这就是它优于「预置 expected 集合然后 `#expect(==)`」的地方。
        withKnownIssue("5 条待补的扩展点，移交 #312（#299 重判落出口 1，实现未跟上）") {
            #expect(result.missing.isEmpty, "这些语义组件缺样式扩展点：\n\(result.diagnostics.joined(separator: "\n"))")
        }

        // ⚠️ **块外 canary：新违规不能被上面的 knownIssue 吞掉**。
        // 这条与上面那条不是重复——上面那条负责「已知缺口到期」，这条负责「集合不许变大」。
        #expect(Set(result.missing) == Self.knownMissingExtensionPoints,
                """
                J-2 违规集合变了：实际 \(result.missing.sorted())，已知 \(Self.knownMissingExtensionPoints.sorted())。\
                ⚠️ 已知集合现为 5 条（`#299` 重判落出口 1、实现移交 `#312`）；`#65` 收口后它曾是空集。\
                红了意味着新增了缺扩展点的语义组件 ⇒ 要么补扩展点，要么在公约 §2 走一次判定\
                （允许得出形态 C「承认差异存在、本轮不开扩展点」，须在 notes 写明理由）。\
                ⚠️ **不要**为了让它变绿而把新条目塞回 knownMissingExtensionPoints —— 那个集合的\
                存在意义是「有承接 issue 的已知缺口」，不是消音器
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

        // ⚠️ **承接指针要承重**（`#315` 终审 I-5，形态照抄 `ComponentRegistryGuard` 的
        // `pendingStep2` 侧那条 `notes.contains(pendingStep2FollowUpIssue)`）：红名单的成文
        // 语义逐字是「**有承接 issue 的**已知缺口」，而在此之前这句只活在注释与失败文案里，
        // **没有任何断言**核对它 ⇒「名字进表、没有承接点」就是一条纯消音器，判据照绿。
        // ⚠️ **写成聚合断言而不是循环内逐条 `#expect`**。
        // ⚠️⚠️ **`#315` 第 2 轮终审 F-1：上一版把成因写错了，而且写成了一条永久规则。**
        // 上一版逐字是「循环体里的 `#expect` 判红时 console reporter 不打印那一条的 issue
        // 行」——**「循环体」不是成因**，而本仓循环体内的 `#expect` / `#require` 有**四百多处**、
        // 分布在**五十多个**测试文件里（`TransitionClusterTests` / `MaskRevealTests` /
        // `FilterTransitionTests` / `CrossPlatformTests` / `ComponentRegistryGuard` 是大户），
        // 照那条规则去改是纯负收益，还会漏掉真正的坑。
        //
        // **真因是「不要把大字符串塞进 `#expect` 的展开」。** 本轮在**同一个循环、同一位置**
        // 做隔离变异实证（两侧各连跑多轮、跨两批独立取样，结果稳定分开）：
        // · 小展开 `#expect(component == "NOPE_TINY_EXPANSION")` —— 记录 5 条真 issue，
        //   **5 条 issue 行全部打印**（两批取样的每一遍都是 5，无一例外）；
        // · 巨串展开 `#expect(entry.notes.contains("NOPE_HUGE_EXPANSION"))`（`notes` 是**数 KB
        //   量级**的长字符串）—— 同样记录 5 条真 issue（汇总行**每次**都是
        //   `6 issues (including 1 known issue)`），但 issue 行会被**静默丢掉，丢多少不稳定**。
        //   ⚠️⚠️ **这里不写具体区间**（`#315` 第 3 轮终审 C-2：上一版写「只打印 3–4 条
        //   （4 次实测 3 / 4 / 3 / 3）」，被后续两批各连跑 6 遍的取样直接证伪 —— 两批都出现过
        //   **0 条**，即一行都不打印）。**丢行数量不是一个可复现的常量**，任何「只打印 N–M 条」
        //   的写法都会被下一次取样推翻；这条注释的上一段正是在批评「用一次观测代替规律」。
        // ⇒ 丢行是**静默**的，只有**汇总计数**可靠；人看不到是哪一条、为什么。
        //
        // ⚠️ **同族先例**：`FilterTransitionTests` 的 `noRawBitmapComparisonsInThisFile`
        // 早就把「不得把 `Data` 直接塞进 `#expect`，否则一次失败产出几百 KB」立成了机器判据。
        // **本次这个形态更危险**：那条的后果是**产出几百 KB**（吵，但线索还在），
        // 本条的后果是**一行都不产出**（或少产出几行且不告诉你少了哪几条）。
        // 聚合成一条顶层断言后，展开只剩一个**小数组**，失败文案正常打印，且一次列全所有缺号的条目。
        let missingFollowUp = Self.knownMissingExtensionPoints
            .filter { component in
                // ⚠️ **本分支是 fail-open**（`#315` 第 2 轮终审 F-6）：条目在登记表里找不到时
                // 返回 `false` ⇒ 该名字不算「缺承接 issue」⇒ 本条断言对它静默放行。
                // **这不是漏洞，因为有两条判据兜着它**——⚠️ 是**冗余**不是合取：
                // **两条各自单独就能接住**（`#315` 第 3 轮终审 S-1 更正了上一版的「缺一不可」）：
                // · 上方的**块外 canary**（`Set(result.missing) == knownMissingExtensionPoints`）
                //   —— 红名单里的名字若不在 `missing` 里，那里当场判红；
                // · 紧接其后的**承重核对循环**（`for component in Self.knownMissingExtensionPoints`）
                //   —— 同一个 `entries.first(where:)` 查不到时走 `Issue.record` 判红
                //   （fail-closed），不是 `return false`。
                // ⚠️ **这里有意不写行号**（`#315` 第 3 轮终审 C-3：上一版写的 `:154` / `:167` 在
                // **同一个 commit** 里被上方新插入的 9 行注释顶掉，两处恰好各差 9 行、双双落到无关行上；
                // 而 `JudgementReferenceGuard` 只认「类型.成员」形式的引用，**裸行号没有任何机器判据
                // 兜底**）。⇒ 引用块内的判据一律用**名字与相对位置**描述，不用行号。
                // ⚠️ 将来若那**两条同时**被改动，**必须回头把这里改成 fail-closed**，否则本条会静默失守。
                guard let entry = entries.first(where: { $0.component == component }) else { return false }
                return !entry.notes.contains(Self.extensionPointFollowUpIssue)
            }
            .sorted()
        #expect(missingFollowUp.isEmpty, """
        这些条目在 knownMissingExtensionPoints 里，但 notes 没写承接 issue 号 \(Self.extensionPointFollowUpIssue)：\
        \(missingFollowUp)。缺口没有落点等于永久缺口，也正是「把新条目塞回红名单让判据闭嘴」的形态。\
        正确处置是补扩展点（然后从本集合删名字），或在 notes 里写明承接 issue。
        """)

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
        // ⚠️ `#315` 终审 S-8：空集分支原写「`#65` 是最后一条」，`#299` 之后已过期
        // （现在的最后一条是移交 `#312` 的那 5 条）⇒ 改成不带具体 issue 号的说法。
        print("J-2 已知缺口 \(result.missing)"
              + (result.missing.isEmpty
                 ? "（**空集** —— 扩展点缺口已全部收口）"
                 : "（待补扩展点，承接 issue \(Self.extensionPointFollowUpIssue)）"))
        print("⚠️ J-2 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条：CI 只 checkout 本仓，跨仓核对移交 #43。")
    }

}
