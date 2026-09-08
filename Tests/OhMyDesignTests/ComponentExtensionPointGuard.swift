import Foundation
import Testing

// MARK: - 共享扫描入口 / Shared scan entry

enum ComponentJudgeSources {
    private static var cached: ComponentJudgeScanResult?

    static func scan() throws -> ComponentJudgeScanResult {
        if let cached = Self.cached { return cached }
        let result = try scanComponentJudgeInputs(roots: ComponentRegistryGuard.componentScanRoots)
        if !result.isEmpty { Self.cached = result }
        return result
    }
}

// MARK: - J-2

@Suite("J-2 样式扩展点")
struct ComponentExtensionPointGuard {
    static let knownMissingExtensionPoints: Set<String> = [
        "ActivityHeatmap", "BeforeAfterSlider", "RadarChart", "RingChart",
    ]

    static let extensionPointFollowUpIssue = "#312"

    @Test("J-2：语义组件必须有样式扩展点（原生协议采纳 或 自有协议定义+使用）")
    func semanticComponentsHaveExtensionPoint() throws {
        let entries = try ComponentRegistryGuard.loadRegistry()
        let scan = try ComponentJudgeSources.scan()
        let result = judgeExtensionPoints(entries: entries, scan: scan)

        #expect(result.inspected.count == 16,
                "J-2 定义域实测 16 条（ActivityHeatmap/AvatarGroup/Banner/BeforeAfterSlider/NetworkGraph/ProgressIndicator/RadarChart/Rating/RatingDisplay/RingChart/SegmentedControl/SidebarUtilityRow/SpinningModifier/Steps/Timeline/Toast），实际 \(result.inspected.count) 条：\(result.inspected)")
        #expect(!result.satisfied.isEmpty,
                "没有任何语义组件被判为『扩展点存在』—— 扫描器失效时也会长这样，这不是零违规")
        #expect(result.satisfied["ProgressIndicator"]?.contains("ProgressViewStyle") == true,
                "nativeProtocol 通路未走通：\(result.satisfied["ProgressIndicator"] ?? "(缺)")")
        #expect(result.satisfied["Banner"]?.contains("BannerStyle") == true,
                "customStyleProtocol 通路未走通：\(result.satisfied["Banner"] ?? "(缺)")")
        #expect(result.satisfied["SegmentedControl"]?.contains("SegmentedControlStyle") == true,
                "customStyleProtocol 通路（第二例）未走通：\(result.satisfied["SegmentedControl"] ?? "(缺)")")
        #expect(result.satisfied["RatingDisplay"]?.contains("RatingStyle") == true,
                "customStyleProtocol 通路（#41 新增的第三例，与 Rating 复用同一个协议）未走通：\(result.satisfied["RatingDisplay"] ?? "(缺)")")

        withKnownIssue("4 条待补的扩展点，移交 #312（#299 重判落出口 1，实现未跟上）") {
            #expect(result.missing.isEmpty, "这些语义组件缺样式扩展点：\n\(result.diagnostics.joined(separator: "\n"))")
        }

        #expect(Set(result.missing) == Self.knownMissingExtensionPoints,
                """
                J-2 违规集合变了：实际 \(result.missing.sorted())，已知 \(Self.knownMissingExtensionPoints.sorted())。\
                ⚠️ 已知集合现为 4 条（`#299` 重判落出口 1、实现移交 `#312`）；`#65` 收口后它曾是空集。\
                ⚠️ `NetworkGraph` 已由 `#312` 以形态 D2 补上 `NetworkGraphLayout`，从本集合移出。\
                红了意味着新增了缺扩展点的语义组件 ⇒ 要么补扩展点，要么在公约 §2 走一次判定\
                （允许得出形态 C「承认差异存在、本轮不开扩展点」，须在 notes 写明理由）。\
                ⚠️ **不要**为了让它变绿而把新条目塞回 knownMissingExtensionPoints —— 那个集合的\
                存在意义是「有承接 issue 的已知缺口」，不是消音器
                """)

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

        let missingFollowUp = Self.knownMissingExtensionPoints
            .filter { component in
                guard let entry = entries.first(where: { $0.component == component }) else { return false }
                return !entry.notes.contains(Self.extensionPointFollowUpIssue)
            }
            .sorted()
        #expect(missingFollowUp.isEmpty, """
        这些条目在 knownMissingExtensionPoints 里，但 notes 没写承接 issue 号 \(Self.extensionPointFollowUpIssue)：\
        \(missingFollowUp)。缺口没有落点等于永久缺口，也正是「把新条目塞回红名单让判据闭嘴」的形态。\
        正确处置是补扩展点（然后从本集合删名字），或在 notes 里写明承接 issue。
        """)

        let bothProtocolFields = entries.filter {
            $0.repo == "ohmydesign" && $0.nativeProtocol != nil && $0.customStyleProtocol != nil
        }
        #expect(bothProtocolFields.isEmpty,
                """
                这些条目 nativeProtocol 与 customStyleProtocol 同时非空：\(bothProtocolFields.map(\.component))。\
                judgeExtensionPoints 会按 customStyleProtocol 优先裁决、静默略过 native 侧 —— \
                请回 #38 确认两字段是否应互斥，或把判据改成两侧都核对（并同步删掉本断言）
                """)

        #expect(result.skippedRepos == ["storyui": 25],
                "跨仓跳过计数变了：实际 \(result.skippedRepos)。CI 只 checkout 本仓，StoryUI 侧无源码可核对（移交 #43）；这个固定计数是唯一挡『静默删条目 / 改 repo』的机器判据")
        #expect(entries.filter { $0.repo == "storyui" && $0.kind == "semantic" }.isEmpty,
                "StoryUI 侧出现了 semantic 条目 —— J-2 在本仓无源码可核对，必须移交 #43 落地跨仓判据，不得靠裁决 (a) 的跳过静默放过")

        print("J-2 定义域 \(result.inspected.count) 条：\(result.inspected)")
        for (component, reason) in result.satisfied.sorted(by: { $0.key < $1.key }) {
            print("J-2 ✓ \(component)：\(reason)")
        }
        print("J-2 已知缺口 \(result.missing)"
              + (result.missing.isEmpty
                 ? "（**空集** —— 扩展点缺口已全部收口）"
                 : "（待补扩展点，承接 issue \(Self.extensionPointFollowUpIssue)）"))
        print("⚠️ J-2 跳过 storyui \(result.skippedRepos["storyui"] ?? 0) 条：CI 只 checkout 本仓，跨仓核对移交 #43。")
    }
}
