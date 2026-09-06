import Foundation

// MARK: - 合成输入工厂 / Synthetic entry factory

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

// MARK: - 条目名 → 合法宿主标识的别名表（`#65`）

enum ComponentHostAliases {
    static let table: [String: Set<String>] = [
        "Toast": ["toastHost"],
    ]

    static func acceptedHosts(for component: String) -> Set<String> {
        self.table[component] ?? [component]
    }
}

// MARK: - J-2：语义组件必须有样式扩展点

struct J2Result: Sendable {
    var inspected: [String] = []
    var satisfied: [String: String] = [:]
    var missing: [String] = []
    var diagnostics: [String] = []
    var skippedRepos: [String: Int] = [:]
}

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
                    + "但它**没有出现在任何公开入口的参数类型**里 —— 声明了没接线，调用方够不着，不构成扩展点。"
                    + "（采集口径**两条通路**：公开 `init` 的参数；以及公开 `extension View` 上返回 "
                    + "`some View` 的 modifier 方法的参数 —— 后者是 `#65` 为 `Toast` 这类"
                    + "「唯一公开入口是 modifier 方法」的组件加的。⚠️ D1 外观槽**不适用**第二条通路，"
                    + "它仍只认公开 `init` 的 @ViewBuilder 参数。）"
                )
            } else if hosts.isDisjoint(with: ComponentHostAliases.acceptedHosts(for: entry.component)) {
                result.missing.append(entry.component)
                result.diagnostics.append(
                    "\(entry.component)：登记表 styleEnum=\(styleEnum) 接线于 "
                    + "\(hosts.sorted().joined(separator: ", "))，**不含本条目可接受的宿主 "
                    + "\(ComponentHostAliases.acceptedHosts(for: entry.component).sorted().joined(separator: ", "))** —— "
                    + "借了别的组件的枚举，本组件自己的公开入口上没有这个扩展点"
                )
            } else {
                result.satisfied[entry.component] =
                    "配置枚举 \(styleEnum)（形态 D2，接线于 \(hosts.sorted().joined(separator: ", "))）"
            }
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

struct ScopedStyleProtocolHit: Hashable, Comparable, Sendable {
    let symbol: String
    let channel: String
    let file: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.symbol, lhs.channel, lhs.file) < (rhs.symbol, rhs.channel, rhs.file)
    }
}

func customStyleProtocolsInScope(
    of component: String, scan: ComponentJudgeScanResult
) -> [ScopedStyleProtocolHit] {
    let names = scan.styleProtocolNames
    var found: [ScopedStyleProtocolHit] = []
    let files = scan.typeDeclFiles[component] ?? []
    for declaration in scan.styleProtocols where files.contains(declaration.file) {
        found.append(
            ScopedStyleProtocolHit(
                symbol: declaration.name, channel: "作用域内声明", file: declaration.file
            )
        )
    }
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
    let symbol: String
    let channel: String
    let file: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.component, lhs.symbol, lhs.channel, lhs.file)
            < (rhs.component, rhs.symbol, rhs.channel, rhs.file)
    }
}

struct J3Result: Sendable {
    var inspected: [String: Set<String>] = [:]
    var unresolvedScopes: [String] = []
    var violations: [J3Violation] = []
    var skippedRepos: [String: Int] = [:]
}

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
            result.unresolvedScopes.append(entry.component)
        }
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
    var covered: [String: String] = [:]
    var violations: [String] = []
    var diagnostics: [String] = []
    var exemptedByRegistryNotes: [String] = []
    var exemptedByExcludedKind: [String] = []
    var unmappedOwners: [String] = []
    var ghostRegistryParams: [String] = []
    var localizedByType: [String] = []
    var carrying: [String] = []
    var functionSideBareText: [String] = []
    var skippedRepos: [String: Int] = [:]
}

func textParamCandidateNames(owner: String, parameter: String) -> [String] {
    let simpleOwner = owner.split(separator: ".").last.map(String.init) ?? owner
    var names = [parameter, "\(owner).\(parameter)"]
    if simpleOwner != owner { names.append("\(simpleOwner).\(parameter)") }
    return names
}

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

    func resolve(_ hit: TextParamHit) -> (entry: ComponentRegistryGuard.Entry, matched: String?)? {
        let component = ownerAliases[hit.owner] ?? hit.owner
        guard let entry = byComponent[component] else { return nil }
        let candidates = textParamCandidateNames(owner: hit.owner, parameter: hit.parameter)
        let matched = entry.textParams.first {
            candidates.contains($0.name) && !$0.category.isEmpty
        }?.name
        return (entry, matched)
    }

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
            result.functionSideBareText.append(hit.key)
            continue
        }
        guard let resolved = resolve(hit) else {
            result.unmappedOwners.append(hit.key)
            continue
        }
        if resolved.entry.kind == "excluded" {
            result.exemptedByExcludedKind.append(hit.key)
            continue
        }
        if let matched = resolved.matched {
            result.covered[hit.key] = "\(resolved.entry.component).\(matched)"
            continue
        }
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

    func sortedUnique(_ keys: [String]) -> [String] { Array(Set(keys)).sorted() }
    result.violations = sortedUnique(result.violations)
    result.diagnostics.sort()
    result.exemptedByRegistryNotes = sortedUnique(result.exemptedByRegistryNotes)
    result.exemptedByExcludedKind = sortedUnique(result.exemptedByExcludedKind)
    result.unmappedOwners = sortedUnique(result.unmappedOwners)
    result.ghostRegistryParams = sortedUnique(result.ghostRegistryParams)
    result.localizedByType = sortedUnique(result.localizedByType)
    result.carrying = sortedUnique(result.carrying)
    result.functionSideBareText = sortedUnique(result.functionSideBareText)
    return result
}
