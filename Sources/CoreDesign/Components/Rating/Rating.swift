import SwiftUI

// MARK: - Rating

/// **材质层**: 内容. **表面角色**: 内容.
public struct Rating: View {
    @Binding var value: Double
    let count: Int
    let step: Double

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.layoutDirection) private var layoutDirection

    /// - Parameters:
    ///   - value: 当前评分，驱动方通过 `Binding<Double>` 双向绑定。
    ///   - count: 星数，默认 5。负数 clamp 到 0。
    ///   - step: 步进粒度，默认 `1.0`（整星）。传 `0.5` 即半星步进，手势与 VoiceOver
    ///     的 increment / decrement 都按它走。
    public init(
        value: Binding<Double>,
        count: Int = 5,
        step: Double = 1.0
    ) {
        self._value = value
        self.count = max(0, count)
        self.step = step > 0 && step.isFinite ? step : 1.0
    }

    // MARK: - Derived metrics

    @State private var measuredWidth: CGFloat = 0

    @Environment(\.ratingStyle) private var style

    // MARK: - Body

    public var body: some View {
        AnyView(self.style.makeBody(
            configuration: RatingStyleConfiguration(value: self.value, count: self.count)
        ))
        .frame(minHeight: CoreControlMetrics.height(for: self.controlSize))
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newValue in
            self.measuredWidth = newValue
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard self.measuredWidth > 0 else { return }
                    let x = self.layoutDirection == .rightToLeft
                        ? self.measuredWidth - drag.location.x
                        : drag.location.x
                    self.value = Self.steppedValue(
                        atRelativeX: x,
                        totalWidth: self.measuredWidth,
                        count: self.count,
                        step: self.step
                    )
                },
            isEnabled: self.isEnabled
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating", bundle: .module))
        .accessibilityValue(
            Text(verbatim: Self.accessibilityValueText(value: self.value, count: self.count))
        )
        .modifier(RatingAdjustableModifier(isEnabled: self.isEnabled) { direction in
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

    // MARK: - Pure logic (unit-testable via `@testable import`)

    static func fillFraction(value: Double, starIndex: Int) -> Double {
        min(max(value - Double(starIndex), 0), 1)
    }

    static func steppedValue(atRelativeX relativeX: CGFloat, totalWidth: CGFloat, count: Int, step: Double) -> Double {
        guard totalWidth > 0, count > 0, step > 0 else { return 0 }
        let clampedX = min(max(relativeX, 0), totalWidth)
        let rawValue = Double(clampedX / totalWidth) * Double(count)
        let stepped = (rawValue / step).rounded(.up) * step
        return min(max(stepped, 0), Double(count))
    }

    static func accessibilityValueText(value: Double, count: Int) -> String {
        String(localized: "\(value.formatted()) of \(Double(count).formatted())", bundle: .module)
    }
}

// MARK: - RatingStyleConfiguration

/// 传给 `RatingStyle.makeBody` 的上下文：**只描述外观所需的状态**。
public struct RatingStyleConfiguration {
    /// 当前评分（可含小数——半星 / 任意粒度都由它的小数部分表达）。
    public let value: Double
    /// 档位总数（星数）。
    public let count: Int
}

// MARK: - RatingStyle

/// `Rating` / `RatingDisplay` 视觉外观的扩展点，形态对齐 Apple `ButtonStyle` / `ToggleStyle`
/// 与本仓既有的 `BannerStyle` / `SegmentedControlStyle`。
public protocol RatingStyle {
    associatedtype Body: View

    @ViewBuilder
    @MainActor @preconcurrency
    func makeBody(configuration: Self.Configuration) -> Body

    typealias Configuration = RatingStyleConfiguration
}

// MARK: - StarRatingStyle

/// 默认评分外观：一排五角星，按 `value` 与星索引计算填充比例（整星 / 半星 / 空星三态），
/// 用 `.mask` 裁切实现半星视觉。
public struct StarRatingStyle: RatingStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StarRatingStyleBody(configuration: configuration)
    }
}

private struct StarRatingStyleBody: View {
    let configuration: RatingStyleConfiguration

    @Environment(\.controlSize) private var controlSize

    private var starSize: CGFloat {
        CoreControlMetrics.iconSize(for: self.controlSize) * 1.5
    }

    var body: some View {
        HStack(spacing: CoreSpacing.xs) {
            ForEach(0..<self.configuration.count, id: \.self) { index in
                self.star(at: index)
            }
        }
    }

    @ViewBuilder
    private func star(at index: Int) -> some View {
        let fraction = Rating.fillFraction(value: self.configuration.value, starIndex: index)
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
}

// MARK: - RatingStyle environment plumbing

extension EnvironmentValues {
    @Entry var ratingStyle: any RatingStyle = StarRatingStyle()
}

public extension View {
    /// 为子树中的所有 `Rating` / `RatingDisplay` 设置外观。
    ///
    /// - Parameter style: 任意符合 `RatingStyle` 协议的实现，内置的是 `StarRatingStyle`。
    func ratingStyle(_ style: some RatingStyle) -> some View {
        self.environment(\.ratingStyle, style)
    }
}

// MARK: - RatingAdjustableModifier

private struct RatingAdjustableModifier: ViewModifier {
    let isEnabled: Bool
    let action: (AccessibilityAdjustmentDirection) -> Void

    func body(content: Content) -> some View {
        if self.isEnabled {
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
                Rating(value: self.$halfStarValue, step: 0.5)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("只读展示（RatingDisplay）").coreFont(.footnote).foregroundStyle(.secondary)
                RatingDisplay(value: 3.5)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("禁用态（.disabled(true) —— 走原生变灰，与展示态不是一回事）")
                    .coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: .constant(3), step: 0.5)
                    .disabled(true)
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

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("自定义 RatingStyle（数字条）").coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: self.$wholeStarValue)
                    .ratingStyle(PreviewNumericRatingStyle())
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}

private struct PreviewNumericRatingStyle: RatingStyle {
    func makeBody(configuration: Configuration) -> some View {
        Text(verbatim: "\(configuration.value.formatted()) / \(Double(configuration.count).formatted())")
            .coreFont(.headline)
            .foregroundStyle(.tint)
    }
}
