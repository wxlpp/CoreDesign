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
    needsExtensionPoint: Bool,
    textParams: [ComponentRegistryGuard.TextParam] = [],
    notes: String = "合成条目，仅用于规则层单测"
) -> ComponentRegistryGuard.Entry {
    ComponentRegistryGuard.Entry(
        component: component, repo: repo, kind: kind, decidedBy: decidedBy,
        nativeProtocol: nativeProtocol, customStyleProtocol: customStyleProtocol,
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
        } else {
            result.missing.append(entry.component)
            result.diagnostics.append(
                "\(entry.component)：登记表既无 nativeProtocol 也无 customStyleProtocol"
                + " —— 语义组件必须有扩展点（这是**待补的扩展点**，不是判据 bug：判定法结论已产出、实现未跟上）"
            )
        }
    }
    result.inspected.sort()
    result.missing.sort()
    result.diagnostics.sort()
    return result
}
