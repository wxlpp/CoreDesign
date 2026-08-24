import Foundation

// MARK: - 合成输入工厂 / Synthetic entry factory

/// 造一条登记表条目，用于规则层的合成变异测试。
///
/// ⚠️ **规则层必须能用合成输入证伪**（#38 `compareRegistryToScan` / #39
/// `compareBoolHitsToExemptions` 的成法）：证伪「漏判」与「误判」两个方向不该依赖真的改
/// `docs/component-registry.json` 或真的改源码——那种证据是一次性 transcript，不可复现、
/// 也不在 CI 里常驻跑。本工厂 + 三个纯规则函数就是让变异证伪**常驻**的机制。
func makeTestEntry(
    component: String,
    repo: String = "coredesign",
    kind: String,
    decidedBy: String,
    nativeProtocol: String? = nil,
    customStyleProtocol: String? = nil,
    styleSlot: String? = nil,
    styleEnum: String? = nil,
    needsExtensionPoint: Bool,
    textParams: [ComponentRegistryGuard.TextParam] = [],
    notes: String = "合成条目，仅用于规则层单测"
) -> ComponentRegistryGuard.Entry {
    ComponentRegistryGuard.Entry(
        component: component, repo: repo, kind: kind, decidedBy: decidedBy,
        nativeProtocol: nativeProtocol, customStyleProtocol: customStyleProtocol,
        styleSlot: styleSlot, styleEnum: styleEnum,
        needsExtensionPoint: needsExtensionPoint, textParams: textParams, notes: notes
    )
}

// MARK: - J-2：语义组件必须有样式扩展点

struct J2Result: Sendable {
    /// 进入判据定义域的组件（`kind == semantic && needsExtensionPoint && repo == coredesign`），已排序。
    var inspected: [String] = []
    /// 组件 → 满足判据的扩展点说明（供报告打印，证明「绿」的理由具体是什么）。
    var satisfied: [String: String] = [:]
    /// 缺扩展点的组件，已排序。
    var missing: [String] = []
    /// 逐条违规明细（AC 要求「独立报告违规明细」）。
    var diagnostics: [String] = []
    /// 跨仓裁决 (a)：被跳过的非本仓条目按 repo 计数，**显式报告**，不静默略过。
    var skippedRepos: [String: Int] = [:]
}

/// J-2：登记表标为语义组件且 `needsExtensionPoint` 的，源码中必须有对应扩展点。
///
/// **判据的两条通路，与登记表的两个字段一一对应（裁决 D3：分开读，不合并）**：
/// - `customStyleProtocol != nil` ⇒ 本仓必须**声明**了这个协议（结构性识别，见
///   `StyleProtocolDecl`）**且**至少有一个类型采纳它。两个条件缺一不可——AC 原文是
///   「自定义样式协议定义 **+ 使用**」；只查声明的话，把 `PlainBannerStyle` /
///   `BorderedBannerStyle` 整个删掉，判据照绿。
/// - `nativeProtocol != nil` ⇒ 本仓必须有类型采纳这个 Apple 原生协议。
///   ⚠️ **这里不要求「组件自己采纳」**：`ProgressIndicator` 的扩展点是
///   `CoreProgressViewStyle: ProgressViewStyle`（`Components/Style/`，另一个文件），
///   登记表 `notes` 原文把它写成可实现性证明（「`Style/CoreProgressViewStyle.swift:37`
///   的 makeBody 就是可实现性证明」）。⇒ 判据按**全仓存在性**判，与登记表口径一致。
///   ⚠️ **这是已知的精度上限，不是「全覆盖」**：全仓存在一个 `ProgressViewStyle` 实现，
///   不等于**这个组件**真的把定制权交出去了。收紧需要「组件是否消费该 style」的语义
///   判断，超出本任务「纯符号级核对」的边界 ⇒ 留痕，移交 #41。
/// - 两者都为 `nil` ⇒ 语义组件却没有任何扩展点符号可核对 ⇒ 违规。
///
/// ⚠️ **跨仓裁决 (a)**：只对 `repo == "coredesign"` 跑，其余按 repo 计数进
/// `skippedRepos`，由调用方**显式报告 + 棘轮断言**。理由见 plan 顶部 Global Constraints。
func judgeExtensionPoints(
    entries: [ComponentRegistryGuard.Entry], scan: ComponentJudgeScanResult
) -> J2Result {
    var result = J2Result()
    for entry in entries where entry.repo != "coredesign" {
        result.skippedRepos[entry.repo, default: 0] += 1
    }
    for entry in entries
    where entry.repo == "coredesign" && entry.kind == "semantic" && entry.needsExtensionPoint {
        result.inspected.append(entry.component)
        // ⚠️ **不留静默分支**：下面是 `if let custom … else if let native …`，
        // `customStyleProtocol` 排在前面 ⇒ 两字段**同时非空**时 native 侧会被静默略过，
        // 判据「绿」而 native 那条通路从未被核对过。实测今日登记表零此形态
        // （`两字段皆非空 == []`），但「今日为零」不是结构保证 —— 先在这里留一行 diagnostics，
        // 再由 `ComponentExtensionPointGuard` 的互斥棘轮把「今日为零」变成机器判据。
        if let native = entry.nativeProtocol, let custom = entry.customStyleProtocol {
            result.diagnostics.append(
                "\(entry.component)：登记表 nativeProtocol=\(native) 与 customStyleProtocol=\(custom)"
                + " **同时非空** —— 本判据按 customStyleProtocol 优先裁决，native 侧未被核对。"
                + "请回 #38 确认两字段是否应互斥（裁决 D3 只说了『分开读』，没说过可以同时填）"
            )
        }
        if let custom = entry.customStyleProtocol {
            let declared = scan.styleProtocolNames.contains(custom)
            let implementations = scan.conformers(of: custom)
            if declared && !implementations.isEmpty {
                result.satisfied[entry.component] =
                    "自有协议 \(custom)（已声明；实现：\(implementations.sorted().joined(separator: ", "))）"
            } else {
                result.missing.append(entry.component)
                result.diagnostics.append(
                    "\(entry.component)：登记表 customStyleProtocol=\(custom)，但源码里"
                    + (declared ? "无实现类型（协议已声明，零 conformance）" : "无该协议声明")
                )
            }
        } else if let native = entry.nativeProtocol {
            let implementations = scan.conformers(of: native)
            if implementations.isEmpty {
                result.missing.append(entry.component)
                result.diagnostics.append(
                    "\(entry.component)：登记表 nativeProtocol=\(native)，但本仓无任何类型采纳该原生协议"
                )
            } else {
                result.satisfied[entry.component] =
                    "原生协议 \(native)（实现：\(implementations.sorted().joined(separator: ", "))）"
            }
        } else if let slot = entry.styleSlot {
            // 形态 D1「外观槽」（公约 §2，由 `D-59-1` 裁定）。
            // ⚠️ **必须核源码真的有这个槽** —— 只看字段非空就判绿，等于「填个字符串就过」，
            // 那是本 epic 反复抓到的「测量工具制造自己的绿」。
            if scan.styleSlotKeys.contains(slot) {
                result.satisfied[entry.component] = "外观槽 \(slot)（形态 D1）"
            } else {
                result.missing.append(entry.component)
                result.diagnostics.append(
                    "\(entry.component)：登记表 styleSlot=\(slot)，但源码里无该公开 @ViewBuilder init 参数"
                    + "（采集口径：**只认公开 init 参数**，私有 body 里的 @ViewBuilder 计算属性调用方够不着、不算扩展点）"
                )
            }
        } else if let styleEnum = entry.styleEnum {
            // 形态 D2「配置枚举」。同样必须核源码，且**两道**：声明存在 + 真的接进公开 init。
            //
            // ⚠️ 只核声明存在是不够的（PR #206 第 2 轮 review 抓到）：`styleEnumNames` 是
            // `Sources/CoreDesign` 下**任意**公开 enum 的名字集合，于是登记表填一个本仓
            // 早就有的枚举名，组件代码一行不写也判绿。相邻的 D1 臂用 `类型名.参数名` 作键、
            // 本来就核到了接线，D2 这条漏了。
            //
            // ⚠️ **本判据的限度（必须写明，不写就会被当成比实际更强的保证）**：它能核
            // 「这个公开枚举真的接在了某个组件的公开 `init` 上」，**核不了**「这个枚举承载的
            // 是不是真正的形态候选」。`Steps` 的 `StepsAxis`（排列方向）同样是公开枚举、
            // 同样接在 `Steps.init` 上 —— 把登记表指向它照样绿。「枚举承载的是形态候选」
            // 属公约 §2 的**人工判定**，与 D1 的 `styleSlot` 可以被填成内容槽同源。
            // 机器守的是「没接线就不算」，不是「填对了才算」。
            let hosts = scan.styleEnumHosts[styleEnum] ?? []
            if !scan.styleEnumNames.contains(styleEnum) {
                result.missing.append(entry.component)
                result.diagnostics.append(
                    "\(entry.component)：登记表 styleEnum=\(styleEnum)，但源码里无该公开 enum 声明"
                )
            } else if hosts.isEmpty {
                result.missing.append(entry.component)
                result.diagnostics.append(
                    "\(entry.component)：登记表 styleEnum=\(styleEnum) 的公开 enum 声明存在，"
                    + "但它**没有出现在任何公开 `init` 的参数类型**里 —— 声明了没接线，调用方够不着，"
                    + "不构成扩展点（采集口径：只认公开 init 参数，与 D1 外观槽同源）"
                )
            } else if !hosts.contains(entry.component) {
                // ⚠️ **宿主必须是本条目自己**（PR #206 第 3 轮 review 抓到）：只判 `hosts` 非空的话，
                // 「组件代码一行不写也判绿」并没关死，只是从「借一个本仓已有的枚举名」变成
                // 「借**另一个组件**的形态枚举」。实测（当时）：把 `AvatarGroup` 的 styleEnum
                // 指向 `StepsPresentation` ⇒ hosts = {Steps} 非空 ⇒ 判绿 ⇒ 407 全绿，而且这类
                // 条目**从不进 `missing`**，`ComponentExtensionPointGuard` 的棘轮结构上也抓不到。
                result.missing.append(entry.component)
                result.diagnostics.append(
                    "\(entry.component)：登记表 styleEnum=\(styleEnum) 接线于 "
                    + "\(hosts.sorted().joined(separator: ", "))，**不含本条目 \(entry.component)** —— "
                    + "借了别的组件的枚举，本组件自己的公开 init 上没有这个扩展点"
                )
            } else {
                result.satisfied[entry.component] =
                    "配置枚举 \(styleEnum)（形态 D2，接线于 \(hosts.sorted().joined(separator: ", "))）"
            }
            // ⚠️ **判据到此为止的真实保证**：「这个公开枚举确实接在了**本条目对应类型**的公开
            // `init` 上」。仍**核不了**「枚举承载的是不是真正的形态候选」—— 见
            // `j2StyleEnumWiringCannotJudgeSemantics`，那条限度是不可机器化的，与本条不同源。
        } else {
            result.missing.append(entry.component)
            result.diagnostics.append(
                "\(entry.component)：登记表 nativeProtocol / customStyleProtocol / styleSlot / styleEnum 四者皆空"
                + " —— 语义组件必须有扩展点（这是**待补的扩展点**，不是判据 bug：判定法结论已产出、实现未跟上）"
            )
        }
    }
    result.inspected.sort()
    result.missing.sort()
    result.diagnostics.sort()
    return result
}

// MARK: - J-3：标注 nativeProtocol 的组件，作用域内不得有自有样式协议

/// 探针的一处命中：**哪个符号、经哪条通道、出处在哪个文件**。
///
/// ⚠️ **为什么不是 `Set<String>`（只回符号名）**：`judgeNativeProtocolPurity` 要填的
/// `J3Violation` 需要 `channel` 与 `file`。探针若只回名字，判据就得自己再走一遍两条通道
/// 才能补齐这两个字段 —— 于是同一套逻辑存在两份，Task 8「绿色正对照」的推理链当场断掉
/// （详见 `customStyleProtocolsInScope` 的文档）。三元组是让判据**无需重走通道**的最小信息量。
struct ScopedStyleProtocolHit: Hashable, Comparable, Sendable {
    /// 命中的自有样式协议名。
    let symbol: String
    /// `作用域内声明` 或 `组件采纳`。
    let channel: String
    /// 命中的出处文件：通道 (i) 是协议声明所在文件，通道 (ii) 是 conformance 所在文件。
    let file: String

    /// ⚠️ 三个字段全参与排序：`Array.sort()` **不保证稳定**，只比 `symbol` 时「同符号、
    /// 两条通道」的相对次序不确定，`j3JudgeConsumesTheProbe` 的逐位比对会间歇性红。
    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.symbol, lhs.channel, lhs.file) < (rhs.symbol, rhs.channel, rhs.file)
    }
}

/// J-3 的**探针**：一个组件的作用域里出现的自有样式协议。
///
/// **「组件作用域」的机械定义（两条通道，都不做名字匹配）**：
/// - 通道 (i) **作用域内声明**：`typeDeclFiles[component]` 里的任一文件里声明了自有样式
///   协议。⚠️ 用**文件**而不是「嵌套在该类型内部」作粒度，是因为本仓两个真实扩展点都写在
///   文件顶层、与组件并排（`Banner.swift:77` 的 `BannerStyle`、`SegmentedControl.swift:66`
///   的 `SegmentedControlStyle`）——按「嵌套」判会对这两例零命中，等于判据从未真的运行过。
/// - 通道 (ii) **组件采纳**：组件类型自身或其 `extension` 的继承子句里出现自有样式协议。
///
/// ⚠️ **本函数是 J-3 的唯一探测实现，`judgeNativeProtocolPurity` 必须调用它**（不许把
/// 两条通道再内联重写一遍）。理由是 Task 8 的「绿色正对照」全靠这个结构才成立：J-3 的真实
/// 输入只有 **1 条**（`ProgressIndicator`），探针一旦退化成恒返回空集，主判据静默全绿。
/// 正对照把探针**反向**施加到两个**必须命中**的组件（`Banner` / `SegmentedControl`）上，
/// 于是得到一条不依赖样本量的活性检查——**但它只有在主判据与探针是同一段代码时才承重**：
/// 若判据自带一份副本，正对照红了只说明副本之外那份死了，主判据可能照常工作，也可能早就
/// 写坏了而无人知晓。规则层的 `j3JudgeConsumesTheProbe` 把这条结构约束钉成机器判据。
///
/// ⚠️ **已知精度上限（留痕）**：同一个文件里放两个组件时，通道 (i) 会把协议算到两个组件
/// 头上（多报）。本仓一组件一文件，实测零多报；方向是 fail-closed（多报要人来解释，
/// 不是漏网）。
func customStyleProtocolsInScope(
    of component: String, scan: ComponentJudgeScanResult
) -> [ScopedStyleProtocolHit] {
    let names = scan.styleProtocolNames
    var found: [ScopedStyleProtocolHit] = []
    let files = scan.typeDeclFiles[component] ?? []
    // 通道 (i)：组件的作用域文件里声明了自有样式协议。
    for declaration in scan.styleProtocols where files.contains(declaration.file) {
        found.append(
            ScopedStyleProtocolHit(
                symbol: declaration.name, channel: "作用域内声明", file: declaration.file
            )
        )
    }
    // 通道 (ii)：组件类型自身或其 extension 采纳了自有样式协议。
    for record in scan.conformances where record.typeName == component {
        for adopted in Set(record.inheritedNames).intersection(names).sorted() {
            found.append(
                ScopedStyleProtocolHit(symbol: adopted, channel: "组件采纳", file: record.file)
            )
        }
    }
    found.sort()
    return found
}

struct J3Violation: Hashable, Comparable, Sendable {
    let component: String
    /// 命中的自有样式协议名。
    let symbol: String
    /// `作用域内声明` 或 `组件采纳`。
    let channel: String
    let file: String

    /// ⚠️ 四个字段全参与排序（不是只比 `(component, symbol)`）：`Array.sort()` **不保证
    /// 稳定**，只比前两个字段时「同组件同符号、两条通道」的相对次序不确定，
    /// `j3JudgeConsumesTheProbe` 里与探针的逐位比对就会间歇性红。
    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.component, lhs.symbol, lhs.channel, lhs.file)
            < (rhs.component, rhs.symbol, rhs.channel, rhs.file)
    }
}

struct J3Result: Sendable {
    /// 组件 → 实际扫到的作用域文件集合。**空集合会同时进 `unresolvedScopes`**。
    var inspected: [String: Set<String>] = [:]
    /// 作用域解析不出来的组件：这不是「没违规」，是「判据没能运行」。
    var unresolvedScopes: [String] = []
    var violations: [J3Violation] = []
    var skippedRepos: [String: Int] = [:]
}

/// J-3：登记表标注了 `nativeProtocol` 的组件，其源码作用域内不得出现自有样式协议符号。
///
/// ⚠️ **只在 `nativeProtocol != nil` 时触发**（裁决 D3）：`customStyleProtocol` 非空、
/// `nativeProtocol` 为 `null` 的组件（`SegmentedControl` / `Banner`）**不进定义域**——
/// 合并两个字段会让它们被自己发布的协议判红。
///
/// ⚠️ **跨仓裁决 (a)**：只对 `repo == "coredesign"` 跑，其余进 `skippedRepos`。
///
/// ⚠️ **本函数只做三件事：定义域过滤、作用域解析留痕、把探针命中装配成 `J3Violation`。**
/// 两条通道的探测逻辑**一行都不在这里**——它全在 `customStyleProtocolsInScope` 里。
/// 这不是分层洁癖：Task 8 的「绿色正对照」证明的是**探针**还活着，只有当主判据的违规逐字
/// 来自探针时，这条证明才能推到主判据身上。若这里再抄一份通道逻辑，正对照就退化成
/// 「两段不相干的代码碰巧都还在跑」，而 Task 1 抽取剥离层的立论（两份实现必然漂移）
/// 也在同一份 plan 里被自己推翻。
func judgeNativeProtocolPurity(
    entries: [ComponentRegistryGuard.Entry], scan: ComponentJudgeScanResult
) -> J3Result {
    var result = J3Result()
    for entry in entries where entry.repo != "coredesign" {
        result.skippedRepos[entry.repo, default: 0] += 1
    }
    for entry in entries where entry.repo == "coredesign" && entry.nativeProtocol != nil {
        let files = scan.typeDeclFiles[entry.component] ?? []
        result.inspected[entry.component] = files
        if files.isEmpty {
            // ⚠️ **零输出不是绿**：扫描器定位不到组件的声明文件时，「作用域里没有自有
            // 协议」这句话没有信息量，必须单独报出来而不是并进「无违规」。
            result.unresolvedScopes.append(entry.component)
        }
        // 唯一的探测入口。装配 = 给探针命中补上 `component` 字段，不做任何再判定。
        for hit in customStyleProtocolsInScope(of: entry.component, scan: scan) {
            result.violations.append(
                J3Violation(
                    component: entry.component, symbol: hit.symbol,
                    channel: hit.channel, file: hit.file
                )
            )
        }
    }
    result.unresolvedScopes.sort()
    result.violations.sort()
    return result
}

// MARK: - FR-4：public init 的文本型参数必须有分类条目

struct FR4Result: Sendable {
    /// 扫描键 → 覆盖它的登记表条目（`"Component.name"`）。
    var covered: [String: String] = [:]
    /// FR-4 的红：裸文本参数无分类条目、登记表 `notes` 也没点名它。
    var violations: [String] = []
    var diagnostics: [String] = []
    /// 登记表 `notes` 原文点名了参数名 ⇒ #38 已经人工裁决过「不计入 textParams」。
    var exemptedByRegistryNotes: [String] = []
    /// 组件 `kind == "excluded"`：公约弃用条款「不分类」，整体豁免 FR-4 扫描。
    var exemptedByExcludedKind: [String] = []
    /// 宿主类型不对应任何登记表条目 ⇒ 判据定义域之外。
    var unmappedOwners: [String] = []
    /// 反向差集：登记表有条目、源码里扫不到（`"Component.name"`）。
    var ghostRegistryParams: [String] = []
    /// 类型已是 LSK/LSR ⇒ 由类型直接判定，不要求登记表条目（公约 §4）。
    var localizedByType: [String] = []
    /// `Binding<String>` / 回调等：清点、打印、不进判据。
    var carrying: [String] = []
    /// `func`（非 `init`）上的裸文本参数：AC 只点名 `init`，这里只留痕。
    var functionSideBareText: [String] = []
    var skippedRepos: [String: Int] = [:]
}

/// 一处扫描命中在登记表里可能对应的条目名。
///
/// ⚠️ **三种拼法都要认**：登记表的 `name` 有时是**参数名**（`Tag.text`），有时是
/// **限定名**（`RadioGroup` 条目下的 `RadioOption.title`、`Steps` 条目下的
/// `StepItem.title`）——因为一个组件的文案入口可能开在它的辅助数据类型上。
/// 第三种（简单宿主名 + 参数名）覆盖点分宿主
/// （`SegmentedControlStyleConfiguration.Segment` → `Segment.title`）。
func textParamCandidateNames(owner: String, parameter: String) -> [String] {
    let simpleOwner = owner.split(separator: ".").last.map(String.init) ?? owner
    var names = [parameter, "\(owner).\(parameter)"]
    if simpleOwner != owner { names.append("\(simpleOwner).\(parameter)") }
    return names
}

/// FR-4：每个 public `init` 的裸文本参数必须在登记表 `textParams[]` 里有分类条目。
///
/// **正向**（源码 → 登记表）是主判据；**反向**（登记表 → 源码）产出 `ghostRegistryParams`，
/// 是第二道防线：把 `title: String` 改写成扫描器看不见的形态（`typealias` 洗白、
/// `where T == String` 泛型洗白），正向会漏判，反向会把那条登记表条目抓成幽灵。
/// ⚠️ **这不等于「两个方向都穷尽」**：**新增且从未登记**的参数用同样的手法仍能逃逸，
/// 见 `classifyTextParameterType` 文档的「已知盲区」。写「已覆盖两个方向的这些形态」，
/// 不写「已覆盖全部」。
///
/// ⚠️ **`by-type` 与 A 类不进正向要求**：公约 §4 明确 `LocalizedStringKey` /
/// `LocalizedStringResource` 由类型直接判定；A 类「文案写在组件源码里」按定义不是 public
/// 参数，实测 `textParams[]` 中 A 计数恒为 0。⇒ 正向只要求**裸文本**有条目。
///
/// ⚠️ **跨仓裁决 (a)**：只对 `repo == "coredesign"` 的条目建索引、只判本仓组件；其余进
/// `skippedRepos`。
func judgeTextParamCoverage(
    entries: [ComponentRegistryGuard.Entry],
    scan: ComponentJudgeScanResult,
    ownerAliases: [String: String]
) -> FR4Result {
    var result = FR4Result()
    for entry in entries where entry.repo != "coredesign" {
        result.skippedRepos[entry.repo, default: 0] += 1
    }
    let byComponent = Dictionary(
        entries.filter { $0.repo == "coredesign" }.map { ($0.component, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// 正向 + 反向共用的解析：命中 → (组件条目, 命中的登记表条目名)。
    func resolve(_ hit: TextParamHit) -> (entry: ComponentRegistryGuard.Entry, matched: String?)? {
        let component = ownerAliases[hit.owner] ?? hit.owner
        guard let entry = byComponent[component] else { return nil }
        let candidates = textParamCandidateNames(owner: hit.owner, parameter: hit.parameter)
        let matched = entry.textParams.first {
            candidates.contains($0.name) && !$0.category.isEmpty
        }?.name
        return (entry, matched)
    }

    // ---- 正向：源码 → 登记表 ----
    for hit in scan.textParams.sorted() {
        switch hit.kind {
        case .textCarrying:
            result.carrying.append(hit.key)
            continue
        case .notText:
            continue
        case .localizedText:
            result.localizedByType.append(hit.key)
            continue
        case .bareText:
            break
        }
        guard hit.isInitializer else {
            // AC 只点名 `init`。`func` 侧同样是真实的 public 文案入口，但登记表的登记单位
            // 是「组件的 public 表面」而不是「每个函数」⇒ 只留痕，由调用方固定集合断言钉住。
            result.functionSideBareText.append(hit.key)
            continue
        }
        guard let resolved = resolve(hit) else {
            result.unmappedOwners.append(hit.key)
            continue
        }
        if resolved.entry.kind == "excluded" {
            // 公约弃用条款「不分类」：`ProgressBar.textParams` 留空是刻意的，不是遗漏。
            result.exemptedByExcludedKind.append(hit.key)
            continue
        }
        if let matched = resolved.matched {
            result.covered[hit.key] = "\(resolved.entry.component).\(matched)"
            continue
        }
        // ⚠️ **唯一的语义豁免通道，授权者是登记表而不是判据作者**：#38 在 `notes` 里
        // 点名写过这个参数名（例：`LabelIcon` 的「systemName 是符号标识符不是展示文案，
        // 不计入 textParams」）⇒ 视为已裁决。没点名 ⇒ 判红，处置是回 #38 补一句 notes，
        // 不是在判据里硬编码特例。
        // ⚠️ **豁免要求参数名与 `textParams` 同句共现，不是全文子串命中**（#59 Task 6 实测
        // 暴露：旧写法 `notes.contains(hit.parameter)` 会被 `SidebarUtilityRow` 的 notes
        // 误伤——该 notes 在论证候选形态时提到「systemImage 是必填无默认值的公开参数」，
        // 这只是论证过程中顺带提及参数名，从未裁决它算不算 textParams，却被子串匹配错记成
        // 「已豁免」。「把未裁决写成已裁决」正是本 epic 反复在抓的错误方向，故收紧为：按
        // `。`/`；`/换行断句，只有同一句里参数名与 `textParams` 同时出现才算裁决语——如
        // `LabelIcon` 例句「systemName 是符号标识符不是展示文案，不计入 textParams。」）。
        let isNotedAsDecided = resolved.entry.notes
            .split(whereSeparator: { $0 == "。" || $0 == "；" || $0.isNewline })
            .contains { sentence in
                sentence.contains(hit.parameter) && sentence.contains("textParams")
            }
        if isNotedAsDecided {
            result.exemptedByRegistryNotes.append(hit.key)
            continue
        }
        result.violations.append(hit.key)
        result.diagnostics.append(
            "\(hit.key)（\(hit.file):\(hit.line)）：裸文本参数，登记表条目 \(resolved.entry.component)"
            + " 的 textParams 里没有 \(textParamCandidateNames(owner: hit.owner, parameter: hit.parameter))"
            + " 中任何一个，notes 也没点名它"
        )
    }

    // ---- 反向：登记表 → 源码 ----
    var reachable: Set<String> = []
    for hit in scan.textParams where hit.kind == .bareText || hit.kind == .localizedText {
        let component = ownerAliases[hit.owner] ?? hit.owner
        for candidate in textParamCandidateNames(owner: hit.owner, parameter: hit.parameter) {
            reachable.insert("\(component).\(candidate)")
        }
    }
    for entry in entries where entry.repo == "coredesign" {
        for textParam in entry.textParams
        where !reachable.contains("\(entry.component).\(textParam.name)") {
            result.ghostRegistryParams.append("\(entry.component).\(textParam.name)")
        }
    }

    // ⚠️ **按键去重，不是简单排序**：`scan.textParams` 的单位是**命中**，一个参数名可以被
    // 多个 `init` 重载各命中一次（实测：`SettingsRow` 有多个重载都带 `title:
    // LocalizedStringKey`，`LabelIcon` 有两个重载都带 `systemName`）；而这几个桶的语义单位
    // 是**扫描键**（`Owner.decl#param`）——`covered` 是以扫描键为主键的字典、`violations` /
    // `unmappedOwners` 等在判据里一律按 `Set` 比较，都天然去重。只有两个**按计数**断言的
    // 留痕桶会把这个差异暴露出来：不去重时 `localizedByType` 是 14（命中数），
    // 去重后是 11（键数，与 Task 3 冒烟打印的 `localizedTextKeys.count` 同口径）。
    // ⇒ 这正是 plan 在 `covered` 那里警告过的「两者计数单位不同」，只是漏在了这两个桶上。
    // 统一取**键**作单位：重载数不是 FR-4 关心的量，参数身份才是。
    func sortedUnique(_ keys: [String]) -> [String] { Array(Set(keys)).sorted() }
    result.violations = sortedUnique(result.violations)
    result.diagnostics.sort()   // ⚠️ 不去重：同名参数的两个重载在不同行，明细要各报一条
    result.exemptedByRegistryNotes = sortedUnique(result.exemptedByRegistryNotes)
    result.exemptedByExcludedKind = sortedUnique(result.exemptedByExcludedKind)
    result.unmappedOwners = sortedUnique(result.unmappedOwners)
    result.ghostRegistryParams = sortedUnique(result.ghostRegistryParams)
    result.localizedByType = sortedUnique(result.localizedByType)
    result.carrying = sortedUnique(result.carrying)
    result.functionSideBareText = sortedUnique(result.functionSideBareText)
    return result
}
