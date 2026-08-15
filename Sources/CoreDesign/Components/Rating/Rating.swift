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
/// 手势：拖拽 / 点按更新 `value`，按 `step`（public init 参数，默认 `1.0`）取整后写回，
/// clamp 在 `0...count`；`isReadOnly` 或外层 `.disabled(true)` 时手势整体不挂载。
///
/// Accessibility：`.accessibilityAdjustableAction` 让 VoiceOver 的 increment / decrement
/// 手势按 `step` 调整 `value`；label 用 Phase 0 预登记键 `"Rating"`，value 用位置键
/// `"%@ of %@"`（`String(localized:bundle:)`，`bundle: .module` 必传——见
/// `.claude/epics/semi-mobile-components/phase0-decisions.md` §2），半星精确播报
/// （`Double.formatted()`，不取整）。
public struct Rating: View {
    // 非 `private`：`count` / `step` / `isReadOnly` / `value` 需要在
    // `@testable import` 的单测里直接断言构造参数是否原样保留（见 RatingTests）。
    // 这不扩大 public API 表面——外部下游仍只能通过 `init` 设置，读不到这些字段。
    @Binding var value: Double
    let count: Int
    let step: Double
    let isReadOnly: Bool

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.layoutDirection) private var layoutDirection

    /// - Parameters:
    ///   - value: 当前评分，驱动方通过 `Binding<Double>` 双向绑定。
    ///   - count: 星数，默认 5。负数 clamp 到 0。
    ///   - step: 步进粒度，默认 `1.0`（整星）。传 `0.5` 即半星步进，手势与 VoiceOver
    ///     的 increment / decrement 都按它走。
    ///
    ///     ⚠️ **#41 破坏性变更**：本参数取代了原来的 `allowsHalfStar: Bool`
    ///     （公约第 3 节替代路径 3.1「把压扁的取值域还原成真实取值域」——`step` 从来
    ///     就不是二值的，`0.5` / `1.0` 只是它最常用的两个取值）。
    ///     迁移：`allowsHalfStar: true` → `step: 0.5`；`allowsHalfStar: false` → 省略。
    ///
    ///     ⚠️ **非正值 clamp 回 `1.0`，不 `precondition`**：`steppedValue` 里的
    ///     `guard ... step > 0 else { return 0 }` 决定了 `step <= 0` 的失效形态是
    ///     **整个组件恒返回 0 分**（静默），不是崩溃。clamp 把这个静默失效换成一个
    ///     可用的默认值，且与仓内惯例一致（`count` 的 `max(0, count)`、
    ///     `AvatarGroup.max`、`Separator.Inset.leading`），还能被单测直接断言。
    ///
    ///     ⚠️ **刻意不设上界**：`count == 0` 是合法入参（`max(0, count)` +
    ///     `RatingTests.negativeCountClampsToZero`），任何 `step <= Double(count)` 形态的
    ///     上界在 `count == 0` 时与 `step > 0` 联立无解，会把既有合法调用打成非法；
    ///     而 `step > count` 本身不是失效形态——`steppedValue` 会把结果 clamp 回
    ///     `0...count`，得到粗粒度但可用的控件。
    ///   - isReadOnly: 只读模式——`true` 时不挂载手势 / accessibility adjust action。
    public init(
        value: Binding<Double>,
        count: Int = 5,
        step: Double = 1.0,
        isReadOnly: Bool = false
    ) {
        self._value = value
        self.count = max(0, count)
        self.step = step > 0 ? step : 1.0
        self.isReadOnly = isReadOnly
    }

    // MARK: - Derived metrics

    /// 手势坐标换算用的控件实测宽度，由 `.onGeometryChange` 写入。
    ///
    /// ⚠️ **#41 起改为「量」而不是「算」**：原实现用 `starSize × count + 间距` 独立再算
    /// 一遍总宽，它自己的文档就写着「两处独立算，改一处务必同步改另一处，否则拖拽手势的
    /// 取值会与星形的真实渲染位置错位（无测试能抓到这类几何失步）」。裁决 4c 把渲染权交给
    /// `RatingStyle` 之后，那条隐患从「可能失步」升级成「任何自定义 style 都必然失步」
    /// ——数字条 / 表情 / 纯文本样式的宽度与星形公式毫无关系。量真实宽度是唯一正确解。
    ///
    /// ⚠️ **已知的一帧窗口**：首帧渲染完成、`.onGeometryChange` 回调到达之前该值是 `0`。
    /// `DragGesture.onChanged` 里对 `self.value` 是**无条件写回**——`steppedValue` 在
    /// `totalWidth == 0` 时返回 `0`（见 `:182` 的 `guard totalWidth > 0 else { return 0 }`），
    /// 若不做兜底，恰好落在这一帧内的拖拽会把 `value` **清成 0 分**（毁值写入，不是
    /// no-op）。因此 `.onChanged` 开头有一条 `guard self.measuredWidth > 0 else { return }`
    /// ——真正的 no-op guard，不引入任何几何计算，失效方向因此才是「不动」而不是「乱跳」或
    /// 「清零」。**这与「加一个 `if measuredWidth == 0 { 用旧公式 }`」不是同一件事**：后者
    /// 会把刚删掉的第二份几何公式请回来，前者只是拒绝在没有测量结果时写值。
    @State private var measuredWidth: CGFloat = 0

    @Environment(\.ratingStyle) private var style

    /// 手势 / accessibility adjust action 是否生效——只读或外层 `.disabled(true)` 时关闭。
    /// 提取为静态纯函数（见下方 `Rating.isInteractive(isReadOnly:isEnabled:)`），
    /// 让「只读模式下手势不生效」这条受控逻辑可以脱离 SwiftUI 渲染上下文直接单测。
    private var isInteractive: Bool {
        Self.isInteractive(isReadOnly: self.isReadOnly, isEnabled: self.isEnabled)
    }

    // MARK: - Body

    public var body: some View {
        // ⚠️ **渲染权交给 `RatingStyle`**（裁决 4c）：与 `Banner.body` 逐字同形。
        // 只声明协议、登记表填上名字而组件自己照旧硬渲染，能骗过 J-2 的
        // `customStyleProtocol` 通路（它只查「协议已声明 + 至少一个类型采纳」，
        // #40 移交清单第 1 条已把这条精度上限写在明处）——那正是本 epic 一直在打的
        // 「绿得理由不对」。这里不踩那个上限。
        AnyView(self.style.makeBody(
            configuration: RatingStyleConfiguration(value: self.value, count: self.count)
        ))
        // `frame(minHeight:)` 在 `contentShape` 之前施加——地板，不裁切，与
        // `TouchTargetTests.swift` 记录的「可信断言」前提一致（`contentShape` 挂在
        // 撑高之后的最外层）。星形视觉尺寸在多数 `controlSize` 档位下小于 44pt 的 HIG
        // 命中区下限，这里补足纵向命中区而不放大星形本身——多出的空间由 HStack 居中吸收，
        // 视觉不变。
        .frame(minHeight: CoreControlMetrics.height(for: self.controlSize))
        .contentShape(Rectangle())
        // 手势坐标换算的分母：量真实宽度，见 `measuredWidth` 的文档。
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newValue in
            self.measuredWidth = newValue
        }
        // `minimumDistance: 0`——保留精确点按语义（AC 要求「拖拽或点按」都能设值）。
        // 已知取舍：与原生 `Slider` 一样，把 Rating 嵌进纵向 `ScrollView` / `List`
        // 时，起手落在星形上的纵向滑动会被本手势而非祖先滚动手势捕获（SwiftUI 对
        // 后代视图的 `.gesture` 默认优先于祖先容器的滚动手势）。收窄手势识别范围
        // 需要引入方向判定 / UIKit 手势代理协作，超出本组件当前范围；集成方若需要
        // Rating 与纵向滚动共存，建议参考 `rating.md`「手势与取值」一节的说明。
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    // 首帧窗口兜底：`measuredWidth` 在 `.onGeometryChange` 回调到达前是
                    // `0`，若不 guard，下面对 `self.value` 的无条件写回会被
                    // `steppedValue` 的 `totalWidth > 0` 前置条件短路成 0 分（毁值）。
                    // 见 `measuredWidth` 声明处的文档。
                    guard self.measuredWidth > 0 else { return }
                    // RTL 镜像：`drag.location.x` 是视图本地物理坐标（不随 layoutDirection
                    // 镜像），而星序与半星 `.mask` 在 RTL 下都镜像。故 RTL 时把 x 沿
                    // 宽度翻折，保证「点视觉上的第 k 颗星」在两种方向下都得到 k 分。
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
            isEnabled: self.isInteractive
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating", bundle: .module))
        .accessibilityValue(
            Text(verbatim: Self.accessibilityValueText(value: self.value, count: self.count))
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

    // MARK: - Pure logic (unit-testable via `@testable import`)

    /// 单颗星的填充比例（0 空星 / 1 整星 / (0,1) 半星），由 `value` 与星索引推导。
    static func fillFraction(value: Double, starIndex: Int) -> Double {
        min(max(value - Double(starIndex), 0), 1)
    }

    /// 根据触摸 / 拖拽在评分控件宽度上的相对 x 坐标计算新的评分值：按 `step` **向上取整**
    /// （ceiling），clamp 到 `0...count`。真实手势无法在 Swift Testing 里直接模拟，提取成
    /// 纯函数让取值 / 边界逻辑可单测。
    ///
    /// **为何 ceiling 而非就近取整**：rating 控件的惯例是「点第 k 颗星 → k 分」（半星模式下
    /// 星 k 左半 → k−0.5、右半 → k）。就近取整会让星 k 的左半区落回 k−1——点第一颗星的左
    /// 大半区反而清零，严重违反直觉。ceiling 保证落在星 k 上（rawValue ∈ (k−1, k]）的任何
    /// 点按都至少给到 k（半星模式细分到 k−0.5 / k）。rawValue==0（最左缘）仍得 0，即清空。
    static func steppedValue(atRelativeX relativeX: CGFloat, totalWidth: CGFloat, count: Int, step: Double) -> Double {
        guard totalWidth > 0, count > 0, step > 0 else { return 0 }
        let clampedX = min(max(relativeX, 0), totalWidth)
        let rawValue = Double(clampedX / totalWidth) * Double(count)
        let stepped = (rawValue / step).rounded(.up) * step
        return min(max(stepped, 0), Double(count))
    }

    /// 手势 / accessibility adjust action 的启用条件：只读模式与外层 `.disabled(true)`
    /// 任一为真即关闭交互。
    static func isInteractive(isReadOnly: Bool, isEnabled: Bool) -> Bool {
        !isReadOnly && isEnabled
    }

    /// `accessibilityValue` 文案组装：Phase 0 位置键 `"%@ of %@"`
    /// （`.claude/epics/semi-mobile-components/phase0-decisions.md` §2），两端均为
    /// `Double.formatted()`，半星精确播报（不取整）。抽成静态纯函数——与
    /// `fillFraction` / `steppedValue` / `isInteractive` 同样的理由：`bundle:
    /// .module` 漏传或插值形状跑偏都是静默 fallback（英文环境下输出恰好不变，
    /// 直到非英文本地化才暴露），需要能被单测锁定，而不是只靠人工审查一次性确认。
    static func accessibilityValueText(value: Double, count: Int) -> String {
        String(localized: "\(value.formatted()) of \(Double(count).formatted())", bundle: .module)
    }
}

// MARK: - RatingStyleConfiguration

/// 传给 `RatingStyle.makeBody` 的上下文：**只描述外观所需的状态**。
///
/// ⚠️ **刻意不带 `step`、不带 `isInteractive`**（公约第 2 节**边界条款**：样式协议的
/// `Configuration` 不得携带行为）：
/// - `step` 是手势与 VoiceOver 的调整粒度 —— 行为。样式实现要画半星只需 `value`
///   （`Rating.fillFraction(value:starIndex:)` 按小数部分算填充比例），不需要知道粒度。
/// - `isInteractive` 是可交互性 —— 行为；而且它是 `Bool`，放进一个 public 表面会当场
///   触发 J-1（`BoolExemptionGuard`）。
///
/// ⚠️ **memberwise init 刻意保持 internal**（Swift 默认）：`Rating` / `RatingDisplay`
/// 同模块可构造，下游实现自定义 style 时只需**读**这两个字段。这同时让本类型不出现在
/// J-1 的 public init 扫描面里。
public struct RatingStyleConfiguration {
    /// 当前评分（可含小数——半星 / 任意粒度都由它的小数部分表达）。
    public let value: Double
    /// 档位总数（星数）。
    public let count: Int
}

// MARK: - RatingStyle

/// `Rating` / `RatingDisplay` 视觉外观的扩展点，形态对齐 Apple `ButtonStyle` / `ToggleStyle`
/// 与本仓既有的 `BannerStyle` / `SegmentedControlStyle`。
///
/// ⚠️ **为什么是自有协议而不是 Apple 原生协议**（#41 裁决 4c，行使公约第 1 节头号规则的
/// 「A 不适用 ⇒ 才准走 B」方向，理由必须写死否则下一个人会以为漏查了）：形态最近的候选是
/// `ProgressViewStyle`（一个 0…1 的进度量 + 自定义 `makeBody`），但它的 `Configuration`
/// 只暴露 `fractionCompleted: Double?` 与 `label` / `currentValueLabel`，**没有离散档位数
/// （`count`）与步进粒度（`step`）**——而评分控件的手势语义全建立在这两者上
/// （见 `Rating.steppedValue(atRelativeX:totalWidth:count:step:)`）。改写成
/// `ProgressView + 自定义 style` 会丢掉手势取整与 accessibility adjust action
/// ⇒ 按公约第 1 节步骤 1 的操作化判据「写不出『可改写且不丢功能』的声明 ⇒ 视为无」，
/// 判 **无** ⇒ 走形态 B。本仓形态 A 的既有先例是 `ProgressIndicator` ↔ `ProgressViewStyle`。
///
/// 实现该协议以提供新的评分外观（数字条 / 表情 / 纯数字文本等——正是登记表判定法步骤 2
/// 举出的那几种结构本身不同的替代形态），通过 `View.ratingStyle(_:)` 注入到子树。
/// 内置实现见 `StarRatingStyle`（默认）。新实现应继续走设计 token
/// （`CoreSpacing.*` / `CoreControlMetrics.*`）与 `.tint`，避免引入魔法数字与写死的强调色。
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
///
/// 星形复用 `Shape/StarShape.swift`（不重新实现五角星路径）。选中态填充色经 `.tint`
/// （`TintShapeStyle`）取值——不写死 `Color.accent`，调用方外加 `.tint(_:)` 会让选中星
/// 真的变色；未选中态走 `Color.tertiaryFill`（第 3 层中性色）。
public struct StarRatingStyle: RatingStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StarRatingStyleBody(configuration: configuration)
    }
}

/// `StarRatingStyle` 的真实视图主体。
///
/// ⚠️ **必须是一个独立的 `View`，不能把 `@Environment` 挂在 `StarRatingStyle` 上**：
/// 样式实例是被存进 `EnvironmentValues` 的普通值，SwiftUI 不会给它安装环境；只有真正
/// 进入视图树的 `View` 才拿得到 `\.controlSize`。本仓 `BannerStyle` 的两个实现走的是
/// 同一条路（把公共主体抽成 `bannerBody(configuration:bordered:)` 自由函数）。
private struct StarRatingStyleBody: View {
    let configuration: RatingStyleConfiguration

    @Environment(\.controlSize) private var controlSize

    /// 星形边长：跟随 `\.controlSize`，不随 Dynamic Type 缩放（现状记录见
    /// `DynamicTypeLayoutTests` 里那条「星形边长走固定 iconSize」的说明）。
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

    // 每颗星固定 `.frame(width: starSize)`——这个宽度与 `HStack(spacing: CoreSpacing.xs)`
    // 的间距共同决定控件总宽。⚠️ #41 之前 `Rating` 用同一套公式**独立再算一遍**
    // `totalWidth` 供手势换算，两处几何若不同步会静默错位；交出渲染权之后那条隐患会从
    // 「可能失步」升级成「任何自定义 style 都必然失步」⇒ `Rating` 现在改用
    // `.onGeometryChange` 量真实宽度，这里不再需要对外暴露任何几何量。
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
    /// 当前生效的 `RatingStyle`，默认 `StarRatingStyle`。
    ///
    /// 通过 `View.ratingStyle(_:)` 注入到子树；`Rating` 与 `RatingDisplay` 在 `body` 中
    /// 读取该值并调用 `style.makeBody(configuration:)` 渲染。两个组件共用同一个协议与
    /// 同一个环境入口——评分的外观语汇只有一套，control / indicator 的差别在交互而不在长相。
    @Entry var ratingStyle: any RatingStyle = StarRatingStyle()
}

public extension View {
    /// 为子树中的所有 `Rating` / `RatingDisplay` 设置外观。
    ///
    /// 对应 Apple `View.buttonStyle(_:)` 的注入模式：在父视图调用一次即可影响下游所有实例，
    /// 无需逐个指定。
    ///
    /// ```swift
    /// VStack {
    ///     Rating(value: $score)
    ///     RatingDisplay(value: 4.5)
    /// }
    /// .ratingStyle(StarRatingStyle())
    /// ```
    ///
    /// - Parameter style: 任意符合 `RatingStyle` 协议的实现，内置的是 `StarRatingStyle`。
    func ratingStyle(_ style: some RatingStyle) -> some View {
        self.environment(\.ratingStyle, style)
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
                Rating(value: self.$halfStarValue, step: 0.5)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("只读").coreFont(.footnote).foregroundStyle(.secondary)
                Rating(value: .constant(3.5), step: 0.5, isReadOnly: true)
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

/// 仅供 `#Preview` 使用的替代样式——证明 `RatingStyle` 真的换得掉默认星形。
private struct PreviewNumericRatingStyle: RatingStyle {
    func makeBody(configuration: Configuration) -> some View {
        Text(verbatim: "\(configuration.value.formatted()) / \(Double(configuration.count).formatted())")
            .coreFont(.headline)
            .foregroundStyle(.tint)
    }
}
