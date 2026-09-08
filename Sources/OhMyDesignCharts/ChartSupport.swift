import OhMyDesign
import SwiftUI

// MARK: - ChartValue

/// 图表数据点的最小契约。
public protocol ChartValue: Identifiable, Sendable {
    /// 该点在图表上的显示名。由调用方的模型提供。
    var label: String { get }
    /// 该点的数值。
    var value: Double { get }
}

// MARK: - 另外两个数据契约

/// 热力图的一天。
public protocol HeatmapDay: Identifiable, Sendable {
    /// 该格对应的日期。⚠️ 归一化到哪一天由图表按注入的 `Calendar` 决定，调用方不必对齐。
    var date: Date { get }
    /// 该天的计数。
    var count: Int { get }
}

/// 网络图的一个节点。
public protocol GraphNode: Identifiable, Sendable where ID: Hashable & Sendable {
    /// 节点的显示名。
    var label: String { get }
}

/// 网络图的一条边。**以节点 `ID` 相连**，不持有节点本身。
public nonisolated struct GraphEdge<ID: Hashable & Sendable>: Sendable, Hashable {
    public let from: ID
    public let to: ID
    public init(from: ID, to: ID) {
        self.from = from
        self.to = to
    }
}

// MARK: - 退化输入

enum ChartDegeneracy: Equatable {
    case usable
    case empty
    case insufficientPoints(needed: Int)
    case flat
    case zeroTotal
    case nonFinite

    static func of(_ values: [Double], minimumCount: Int = 1) -> Self {
        guard !values.isEmpty else { return .empty }
        guard values.allSatisfy({ $0.isFinite }) else { return .nonFinite }
        if values.count < minimumCount { return .insufficientPoints(needed: minimumCount) }
        let total = values.reduce(0, +)
        if total == 0 { return .zeroTotal }
        if let first = values.first, values.allSatisfy({ $0 == first }) { return .flat }
        return .usable
    }
}

// MARK: - 本地化

extension LocalizedStringResource {
    static func chart(_ key: String.LocalizationValue) -> Self {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

func chartAXString(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

// MARK: - 空态

struct ChartEmptyState: View {
    let message: LocalizedStringResource

    var body: some View {
        Text(self.message)
            .coreFont(.footnote)
            .foregroundStyle(Color.contentTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(Text(self.message))
    }
}

// MARK: - 安全归一化

extension Collection where Element == Double {
    func normalizedSafely() -> [Double] {
        guard !self.isEmpty else { return [] }
        let finite = self.filter { $0.isFinite }
        guard let low = finite.min(), let high = finite.max() else {
            return self.map { _ in 0.5 }
        }
        let span = high - low
        guard span > 0 else { return self.map { $0.isFinite ? 0.5 : Self.clampNonFinite($0) } }
        return self.map { value in
            guard value.isFinite else { return Self.clampNonFinite(value) }
            return (value - low) / span
        }
    }

    private static func clampNonFinite(_ value: Double) -> Double {
        if value == .infinity { return 1 }
        if value == -.infinity { return 0 }
        return 0.5
    }
}

// MARK: - 区间构造

func safeRange(_ lower: Double, _ upper: Double) -> ClosedRange<Double> {
    let low = lower.isFinite ? lower : 0
    if upper.isFinite, upper > low { return low...upper }
    guard let high = strictlyAboveFinite(low) else {
        return low.nextDown...low
    }
    return low...high
}

private func strictlyAboveFinite(_ value: Double) -> Double? {
    let stepped = value + 1
    if stepped > value { return stepped }
    let bumped = value.nextUp
    return bumped.isFinite ? bumped : nil
}
