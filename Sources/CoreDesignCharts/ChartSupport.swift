//
//  ChartSupport.swift
//  CoreDesignCharts
//
//  四个图表的公共约定 / Shared conventions for the four charts.
//

import Accessibility
import CoreDesign
import SwiftUI

// MARK: - ⚠️ 本 target 的三条硬约束（写新图表前必读）

// 1. **不 `import Charts`**。本 target 只收容 Swift Charts **原生画不出来**的四类：
//    雷达图 / 活动环 / 贡献热力图 / 力导向网络图。line / bar / area / point / sector
//    原生已支持，重造它们的换皮是本 target 明确的 Non-Goal。
//
// 2. **退化输入是一等契约，不是边角**（FR-19）。力导向布局节点重合会 NaN、雷达图轴值
//    全等会除零——这是图表类组件最常见的 crash 源。每个图表都必须对空数组、单点、
//    以及自己特有的退化形态有**定义好的行为**（渲染空态 / 忽略该点），并有测试。
//
// 3. **超限行为固定为「截断 + 降级 + 文档」，不得抛断言**（FR-20）。
//    库代码对数据规模 `precondition` / `fatalError` 就是让宿主 App crash。

// MARK: - ChartValue

/// 图表数据点的最小契约。
///
/// ⚠️ **调用方传入的标签是「内容」不是「UI 文案」**——不强制 `LocalizedStringResource`
/// （FR-7 的边界声明）。轴标题这类**组件自带**的 chrome 文案才走本地化类型。
///
/// ⚠️ **`Sendable` 的实际代价（本仓第三次撞到，写在这里免得第四次）**：
/// 在**同样设了 `defaultIsolation(MainActor)` 的模块**里声明遵从类型，会拿到
/// MainActor 隔离的 `Identifiable` conformance，满足不了 `Sendable`，报
/// `main actor-isolated conformance ... cannot satisfy conformance requirement
/// for a 'Sendable' type parameter`。
/// ⇒ **解法是给该类型标 `nonisolated`**（提到文件作用域不够——该设置作用于整个 target）。
/// ⚠️ **下游 App 通常不设 `defaultIsolation`**，那里的普通 `struct` 天然满足 `Sendable`
/// ⇒ 这道摩擦主要落在本包自己的 Preview / 测试类型上。
///
/// ⚠️ **为什么仍然要 `Sendable`**：图表的数据入参是**调用方在自己模型层构造的值类型**，
/// 若被 `MainActor` 隔离，下游在后台线程准备数据时就用不了——而那正是
/// `scripts/downstream-probe` 存在的理由。这条约束是**有意的**，不是顺手加的。
public protocol ChartValue: Identifiable, Sendable {
    /// 该点在图表上的显示名。由调用方的模型提供。
    var label: String { get }
    /// 该点的数值。
    var value: Double { get }
}

// MARK: - 退化输入

/// 一组数据点的退化形态。**每个图表在渲染前都要过这一关。**
enum ChartDegeneracy: Equatable {
    /// 数据可用。
    case usable
    /// 空数组 —— 渲染空态。
    case empty
    /// 只有一个数据点 —— 多数图表（雷达/网络图）需要 ≥3 才有意义。
    case singlePoint
    /// 所有值相等 —— 归一化会除零。
    case flat
    /// 总和为 0 —— 占比类图表（活动环）会除零。
    case zeroTotal

    /// ⚠️ **判定顺序有意为之**：空 > 单点 > 零总和 > 全等。
    /// `[0]` 同时是"单点"与"零总和"，报单点更有信息量（调用方更可能是漏了数据）。
    static func of(_ values: [Double], minimumCount: Int = 1) -> Self {
        guard !values.isEmpty else { return .empty }
        guard values.count >= max(minimumCount, 2) || minimumCount <= 1 else {
            return .singlePoint
        }
        if values.count < minimumCount { return .singlePoint }
        let total = values.reduce(0, +)
        if total == 0 { return .zeroTotal }
        if let first = values.first, values.allSatisfy({ $0 == first }) { return .flat }
        return .usable
    }
}

// MARK: - 空态

/// 所有图表共用的空态。⚠️ 文案是**组件自带的 chrome**，走 `LocalizedStringKey`（FR-7）。
struct ChartEmptyState: View {
    let message: LocalizedStringKey

    var body: some View {
        Text(self.message)
            .font(.footnote)
            .foregroundStyle(Color.contentTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(self.message)
    }
}

// MARK: - 安全归一化

extension Collection where Element == Double {

    /// 把一组值归一化到 [0, 1]。
    ///
    /// ⚠️ **全等时返回全 0.5 而不是除零**——雷达图轴值全相等是常见输入
    /// （所有维度同分），不是错误，不该 NaN 也不该崩。
    func normalizedSafely() -> [Double] {
        guard let low = self.min(), let high = self.max() else { return [] }
        let span = high - low
        guard span > 0 else { return self.map { _ in 0.5 } }
        return self.map { ($0 - low) / span }
    }
}
