//
//  Rating.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Rating

/// **材质层**: 内容. **表面角色**: 内容.
///
/// `Binding<Double>` 驱动的星级评分组件 / Star rating control driven by a `Binding<Double>`。
///
/// 星形复用 `Shape/StarShape.swift`（不重新实现五角星路径），按 `value` 与每颗星的索引
/// 计算填充比例（整星 / 半星 / 空星三态），用 `.mask` 裁切实现半星视觉。选中态填充色经
/// `.tint`（`TintShapeStyle`）取值——不写死 `Color.accent`，调用方外加 `.tint(_:)` 会让
/// 选中星真的变色；未选中态走 `Color.tertiaryFill`（第 3 层中性色）。
///
/// 手势：拖拽 / 点按更新 `value`，按 `step`（`allowsHalfStar ? 0.5 : 1.0`）取整后写回，
/// clamp 在 `0...count`；`isReadOnly` 或外层 `.disabled(true)` 时手势整体不挂载。
///
/// Accessibility：`.accessibilityAdjustableAction` 让 VoiceOver 的 increment / decrement
/// 手势按 `step` 调整 `value`；label 用 Phase 0 预登记键 `"Rating"`，value 用位置键
/// `"%@ of %@"`（`String(localized:bundle:)`，`bundle: .module` 必传——见
/// `.claude/epics/semi-mobile-components/phase0-decisions.md` §2），半星精确播报
/// （`Double.formatted()`，不取整）。
public struct Rating: View {
    // 非 `private`：`count` / `allowsHalfStar` / `isReadOnly` / `value` 需要在
    // `@testable import` 的单测里直接断言构造参数是否原样保留（见 RatingTests）。
    // 这不扩大 public API 表面——外部下游仍只能通过 `init` 设置，读不到这些字段。
    @Binding var value: Double
    let count: Int
    let allowsHalfStar: Bool
    let isReadOnly: Bool

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    /// - Parameters:
    ///   - value: 当前评分，驱动方通过 `Binding<Double>` 双向绑定。
    ///   - count: 星数，默认 5。
    ///   - allowsHalfStar: 是否允许半星步进（`true` 时手势按 0.5 递增/递减，否则按 1.0）。
    ///   - isReadOnly: 只读模式——`true` 时不挂载手势 / accessibility adjust action。
    public init(
        value: Binding<Double>,
        count: Int = 5,
        allowsHalfStar: Bool = false,
        isReadOnly: Bool = false
    ) {
        self._value = value
        self.count = max(0, count)
        self.allowsHalfStar = allowsHalfStar
        self.isReadOnly = isReadOnly
    }

    // MARK: - Derived metrics

    private var step: Double {
        self.allowsHalfStar ? 0.5 : 1.0
    }

    private var starSize: CGFloat {
        CoreControlMetrics.iconSize(for: self.controlSize) * 1.5
    }

    private var totalWidth: CGFloat {
        guard self.count > 0 else { return 0 }
        return CGFloat(self.count) * self.starSize + CGFloat(self.count - 1) * CoreSpacing.xs
    }

    /// 手势 / accessibility adjust action 是否生效——只读或外层 `.disabled(true)` 时关闭。
    /// 提取为静态纯函数（见下方 `Rating.isInteractive(isReadOnly:isEnabled:)`），
    /// 让「只读模式下手势不生效」这条受控逻辑可以脱离 SwiftUI 渲染上下文直接单测。
    private var isInteractive: Bool {
        Self.isInteractive(isReadOnly: self.isReadOnly, isEnabled: self.isEnabled)
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            ForEach(0..<self.count, id: \.self) { index in
                self.star(at: index)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    self.value = Self.steppedValue(
                        atRelativeX: drag.location.x,
                        totalWidth: self.totalWidth,
                        count: self.count,
                        step: self.step
                    )
                },
            isEnabled: self.isInteractive
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating", bundle: .module))
        .accessibilityValue(
            Text(verbatim: String(
                localized: "\(self.value.formatted()) of \(Double(self.count).formatted())",
                bundle: .module
            ))
        )
        .modifier(RatingAdjustableModifier(isInteractive: self.isInteractive) { direction in
            switch direction {
            case .increment:
                self.value = min(self.value + self.step, Double(self.count))
            case .decrement:
                self.value = max(self.value - self.step, 0)
            @unknown default:
                break
            }
        })
    }

    // MARK: - Star rendering

    @ViewBuilder
    private func star(at index: Int) -> some View {
        let fraction = Self.fillFraction(value: self.value, starIndex: index)
        ZStack(alignment: .leading) {
            StarShape()
                .fill(Color.tertiaryFill)
            StarShape()
                .fill(.tint)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: self.starSize * fraction, height: self.starSize)
                }
        }
        .frame(width: self.starSize, height: self.starSize)
    }

    // MARK: - Pure logic (unit-testable via `@testable import`)

    /// 单颗星的填充比例（0 空星 / 1 整星 / (0,1) 半星），由 `value` 与星索引推导。
    static func fillFraction(value: Double, starIndex: Int) -> Double {
        min(max(value - Double(starIndex), 0), 1)
    }

    /// 根据触摸 / 拖拽在评分控件宽度上的相对 x 坐标计算新的评分值：按 `step` 取整、
    /// clamp 到 `0...count`。真实手势无法在 Swift Testing 里直接模拟，提取成纯函数
    /// 让手势背后的取整 / 边界逻辑可单测。
    static func steppedValue(atRelativeX relativeX: CGFloat, totalWidth: CGFloat, count: Int, step: Double) -> Double {
        guard totalWidth > 0, count > 0, step > 0 else { return 0 }
        let clampedX = min(max(relativeX, 0), totalWidth)
        let rawValue = Double(clampedX / totalWidth) * Double(count)
        let stepped = (rawValue / step).rounded() * step
        return min(max(stepped, 0), Double(count))
    }

    /// 手势 / accessibility adjust action 的启用条件：只读模式与外层 `.disabled(true)`
    /// 任一为真即关闭交互。
    static func isInteractive(isReadOnly: Bool, isEnabled: Bool) -> Bool {
        !isReadOnly && isEnabled
    }
}

// MARK: - RatingAdjustableModifier

/// `.accessibilityAdjustableAction` 只读模式下不挂载——用独立 `ViewModifier` 承载条件分支，
/// 避免在 `Rating.body` 里对同一视图重复书写 if/else 两条平行内容。
private struct RatingAdjustableModifier: ViewModifier {
    let isInteractive: Bool
    let action: (AccessibilityAdjustmentDirection) -> Void

    func body(content: Content) -> some View {
        if self.isInteractive {
            content.accessibilityAdjustableAction(self.action)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("Rating — Light") {
    RatingPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Rating — Dark") {
    RatingPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct RatingPreviewGallery: View {
    @State private var wholeStarValue: Double = 3
    @State private var halfStarValue: Double = 2.5
    @State private var customCountValue: Double = 4

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.xl) {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("默认（整星步进）").coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: self.$wholeStarValue)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("半星步进").coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: self.$halfStarValue, allowsHalfStar: true)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("只读").coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: .constant(3.5), allowsHalfStar: true, isReadOnly: true)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("自定义星数（3 星）").coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: self.$customCountValue, count: 3)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text(".tint(.red) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: .constant(2), count: 5)
                    .tint(.red)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
