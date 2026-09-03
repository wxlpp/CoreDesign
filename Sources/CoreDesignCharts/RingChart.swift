//
//  RingChart.swift
//  CoreDesignCharts
//

import Accessibility
import CoreDesign
import SwiftUI

/// 活动环。多个同心进度环，每环一个指标的完成度。
///
/// ⚠️ Swift Charts 画不出来：`SectorMark` 是饼图/环形图（按占比切分**一个**环），
/// 活动环是**多个独立环各自表示完成度**——不是同一个概念。
public struct RingChart<Value: ChartValue>: View {

    private let values: [Value]
    private let goal: Double
    private let tint: Color
    private let title: LocalizedStringResource

    /// - Parameters:
    ///   - goal: 满环对应的值。⚠️ **不从数据里推**——活动环的语义是"完成度"，
    ///     目标是外部设定的，用数据最大值当目标会让"全部未达标"看起来像"有人满环"。
    public init(
        _ values: [Value],
        goal: Double,
        title: LocalizedStringResource? = nil,
        tint: Color = .accent
    ) {
        self.values = values
        self.goal = goal
        self.title = title ?? .chart("Activity rings")
        self.tint = tint
    }

    public var body: some View {
        if self.values.isEmpty {
            ChartEmptyState(message: .chart("No data"))
        } else if !self.goal.isFinite || self.goal <= 0 {
            // ⚠️ `goal == 0` 会让每个环的完成度除零。这是**调用方的输入错误**，
            // 但库不该 crash（FR-20 的同款原则）——给出可操作的提示。
            // ⚠️ `isFinite` 这半句是终审 C-4 补的：`NaN <= 0` 为**假**，
            // 原来的守卫放 `goal = .nan` 过关，然后在 `0...max(goal, 1)` 处
            // 让宿主 App trap（`max(NaN, 1) == NaN`）。
            ChartEmptyState(message: .chart("The goal must be greater than 0"))
        } else {
            self.rings
        }
    }

    /// 同心环的建议上限。**超出即截断**，与 `NetworkGraph` 同一条 FR-20 原则。
    ///
    /// ⚠️ **终审 I-6 抓到的**：初版一个上限都没有，而环宽有个 `max(…, 4)` 地板
    /// ⇒ 环数一多，`radius = outer - index * width * 1.5` 会变**负**
    ///（实测 side=200、20 个指标 ⇒ index 19 时 radius = -22 ⇒ `.frame(width: -44)`）。
    /// 6 是取「最内环仍有正半径」反推：`outer - 5 * width * 1.5 > 0` 在 `width`
    /// 走公式（非地板）时恒成立。
    /// ⚠️ 泛型类型不支持 static **存储**属性，故写成计算属性。
    public static var recommendedRingLimit: Int { 6 }

    /// ⚠️ **去重在截断之前**（第 2 轮终审 I-6）：`ForEach(id: \.element.id)` 拿到
    /// 重复 ID 是 SwiftUI 未定义行为——`NetworkGraph.layout` 已就同一件事去过重，
    /// 这里是同一论证的漏网。保留首次出现，与 `NetworkGraph` 同语义。
    /// ⚠️ **收够 6 个唯一值即停**（PR #263 Copilot 第 4 轮 S-3）：上一版
    /// `filter { … }.prefix(limit)` 会在截断之前把整个数组扫完，与「超限就截断」的
    /// 意图相悖。⚠️ 不能改写成 `values.lazy.filter { … }.prefix(6)` —— `[Value]` 是
    /// `Collection`，`prefix` 会让带副作用的谓词**求值两次**，实测直接 trap
    /// （`Range requires lowerBound <= upperBound`，推导见 `NetworkGraph.firstUnique`）；
    /// 显式循环才保证每个元素恰好求值一次。
    /// 取值 / 顺序由 `dedupeThenTruncateKeepsOrder` 钉住。
    private var effectiveValues: [Value] {
        var seen = Set<Value.ID>()
        var kept: [Value] = []
        kept.reserveCapacity(min(self.values.count, Self.recommendedRingLimit))
        for value in self.values where seen.insert(value.id).inserted {
            kept.append(value)
            if kept.count >= Self.recommendedRingLimit { break }
        }
        return kept
    }

    /// 把原始值折算成**画面上真正画出来的那个值** —— 与 `rings` 里
    /// `max(0, min(value / goal, 1))` 同一区间，供 descriptor 复用（S-6）。
    ///
    /// ⚠️ 非有限值单独走一档，因为**要对齐的是画面，不是公式**：
    /// `min(max(.nan, 0), goal)` 会把 `NaN` 原样透出，而渲染那侧走 `Comparable` 版
    /// `min` / `max`，对 `NaN` 的短路结果是 **0**；`+∞` 画满环、`-∞` 画空环。
    private static func drawnValue(_ value: Double, goal: Double) -> Double {
        guard value.isFinite else { return value > 0 ? goal : 0 }
        return min(max(value, 0), goal)
    }

    private var rings: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outer = side / 2 * 0.92
            let shown = self.effectiveValues
            let width = max(outer / Double(max(shown.count, 1)) * 0.52, 4)

            ZStack {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, value in
                    // ⚠️ 半径夹到 ≥ 1：`max(…, 4)` 那道宽度地板在极小容器里仍能把
                    // 半径推负，而负 frame 是 SwiftUI 运行期告警（终审 I-6）。
                    let radius = max(outer - Double(index) * width * 1.5, 1)
                    // ⚠️ 完成度可以 > 1（超额完成），环画满即止；但**不夹到 0 以下**，
                    // 负值当 0 处理而不是反向画。
                    let progress = max(0, min(value.value / self.goal, 1))

                    ZStack {
                        Circle()
                            .stroke(self.tint.opacity(0.18), lineWidth: width)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                // ⚠️ 透明度夹一道 0.1 地板（PR #263 Copilot 第 1 轮）。
                                // 先说事实：`recommendedRingLimit == 6` ⇒ `index ≤ 5`
                                // ⇒ 本式最小为 `1.0 - 5 × 0.18 = 0.1`，**现状下取不到负值**
                                // ——评论说的「环数多了变负」在截断存在时不可达。
                                // 仍加地板是因为上限是一个 public 计算属性、改它只需一行，
                                // 而 7 环起本式就 ≤ -0.08（`opacity` 对负值无定义）。
                                // 地板取 0.1 而不是 0：夹到 0 同样是「看不见」，与「最内环仍可辨」
                                // 的层级意图相反。最外层（index == 0）仍为 1.0，视觉层级不变。
                                self.tint.opacity(max(1.0 - Double(index) * 0.18, 0.1)),
                                style: StrokeStyle(lineWidth: width, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: radius * 2, height: radius * 2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(self.title))
        .accessibilityChartDescriptor(self)
    }
}

extension RingChart: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        let category = AXCategoricalDataAxisDescriptor(
            // ⚠️⚠️ **必须用截断后的集合**（第 2 轮终审 C-1，这是我修 I-6 时引入的真 bug）：
            // 渲染走 `effectiveValues`（最多 6 环），descriptor 却走 `self.values`
            // ⇒ 喂 20 个指标时 **VoiceOver 播报 20 个、屏幕上只有 6 个环**。
            // `NetworkGraph` 在同一件事上是对的（用 `effectiveNodes`），两个兄弟组件走反了。
            title: chartAXString("Metric"), categoryOrder: self.effectiveValues.map(\.label)
        )
        // ⚠️ `safeRange` 与 `denominator` 都是终审 C-4 的产物：descriptor 是
        // VoiceOver 主动拉取的，**渲染没崩不代表这里不崩**。
        let denominator = self.goal.isFinite && self.goal > 0 ? self.goal : 1
        let axis = AXNumericDataAxisDescriptor(
            title: chartAXString("Completion"),
            range: safeRange(0, denominator), gridlinePositions: []
        // ⚠️ **scale 是 `100 / goal`，不是 `1 / goal`**（PR #263 Copilot 第 1 轮判它
        // 「`.percent` 自带 ×100 ⇒ 会放大 100 倍」——**实测为假**）。真相是
        // `.scale(_:)` **替换**掉 `Percent` 那个隐式的 ×100，而不是与它相乘：
        // `(2.0).formatted(.percent) == "200%"`，但 `(2.0).formatted(.percent.scale(1)) == "2%"`。
        // ⇒ 现式把 `goal` 读成 `100%`；改成 `1 / goal` 反而会读成 `1%`。
        // 该语义由 `AccessibilityDescriptorTests.ringAxisReadsPercent` 钉住。
        ) { "\($0.formatted(.percent.scale(100 / denominator)))" }
        // ⚠️⚠️ **y 必须与画面走同一道夹取**（PR #263 Copilot 第 4 轮 S-6）：渲染那侧写的是
        // `max(0, min(value / goal, 1))`——超额完成画满即止、负值当 0；descriptor 这侧
        // 却报**原始 `value`** ⇒ 喂 750（goal = 500）时屏幕是满环、VoiceOver 念「150%」，
        // 喂 -100 时屏幕是空环、VoiceOver 念「-20%」：**视障用户听到的与视力用户看到的
        // 不是同一张图**。这些 y 还落在上面 `safeRange(0, denominator)` 声明的量程之外。
        // ⚠️ 与第 1 轮驳回的 `.scale(100 / goal)` 是**两件事**：那条讲格式化倍率
        // （实测误报，见下方注释与 `ringAxisReadsPercent`），这条讲**取值域**。
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: false,
            dataPoints: self.effectiveValues.map {
                AXDataPoint(x: $0.label, y: Self.drawnValue($0.value, goal: denominator))
            }
        )
        return AXChartDescriptor(
            title: String(localized: self.title), summary: nil,
            xAxis: category, yAxis: axis, additionalAxes: [], series: [series]
        )
    }
}

private nonisolated struct Ring: ChartValue {
    let id = UUID()
    let label: String
    let value: Double
}

#Preview("RingChart") {
    VStack(spacing: 24) {
        RingChart([
            Ring(label: "活动", value: 420),
            Ring(label: "锻炼", value: 28),
            Ring(label: "站立", value: 9),
        ], goal: 500)
        .frame(height: 200)

        // 退化：目标为 0
        RingChart([Ring(label: "x", value: 1)], goal: 0).frame(height: 60)
    }
    .padding()
}
