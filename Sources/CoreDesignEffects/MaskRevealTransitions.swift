import CoreDesign
import SwiftUI

// MARK: - 转场本体

/// `iris` / `wipe` / `blinds` / `clock` / `glare` / `dissolve` 六种「揭示型」转场。
public struct MaskRevealTransition: Transition {
    let kind: MaskRevealKind

    init(_ kind: MaskRevealKind) {
        self.kind = kind
    }

    /// 默认百叶条数。
    public nonisolated static let defaultBlindCount: Int = 8

    /// 默认格边长（pt）。同上，`public` 是默认实参的要求、`nonisolated` 是下游的要求。
    public nonisolated static let defaultCellSize: CGFloat = 24

    /// `wipe` 的默认方向：左 → 右。
    public nonisolated static let defaultWipeAngle: Angle = .degrees(0)

    /// `glare` 的默认方向：左上 → 右下的斜掠。
    public nonisolated static let defaultGlareAngle: Angle = .degrees(35)

    /// 保留框架在 Reduce Motion 下的 opacity 替换（`hasMotion` 取 `true`）。
    public nonisolated static let properties: TransitionProperties = TransitionProperties(hasMotion: true)

    /// 把相位与几何族交给 `MaskRevealChrome` 渲染——六个公开入口点的唯一路径。
    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(
            MaskRevealChrome(progress: MaskReveal.progress(phase: phase), kind: self.kind)
        )
    }
}

// MARK: - 公开入口点（`Transition` 的静态成员）

public extension Transition where Self == MaskRevealTransition {
    /// 圆形光圈从中心向外张开。
    static var iris: MaskRevealTransition { MaskRevealTransition(.iris(anchor: .center)) }

    /// 圆形光圈从 `anchor` 向外张开。
    ///
    /// - Parameter anchor: 光圈中心，内容 bounds 的单位坐标。半径自动取到最远角，
    ///   因此任何 anchor（含四角）在完全揭示时都铺满内容。
    static func iris(anchor: UnitPoint = .center) -> MaskRevealTransition {
        MaskRevealTransition(.iris(anchor: anchor))
    }

    /// 一条直边沿默认方向（左 → 右）扫过。
    static var wipe: MaskRevealTransition {
        MaskRevealTransition(.wipe(radians: MaskRevealTransition.defaultWipeAngle.radians))
    }

    /// 一条直边沿指定方向扫过。
    ///
    /// - Parameter angle: 扫过方向。`0°` 左 → 右，`90°` 上 → 下（SwiftUI 的 y 轴向下），
    ///   `180°` 右 → 左。任意角度都合法，边始终与该方向垂直。
    static func wipe(angle: Angle = MaskRevealTransition.defaultWipeAngle) -> MaskRevealTransition {
        MaskRevealTransition(.wipe(radians: angle.radians))
    }

    /// 若干条横向百叶各自从自己的中线向上下张开。
    static var blinds: MaskRevealTransition {
        MaskRevealTransition(.blinds(count: MaskRevealTransition.defaultBlindCount))
    }

    /// 指定条数的横向百叶。
    ///
    /// - Parameter count: 百叶条数。`0` 与负数会被钳到 1——否则整条转场退化成
    ///   "什么都不揭示"，而那是一个不会报错的死转场。
    static func blinds(count: Int = MaskRevealTransition.defaultBlindCount) -> MaskRevealTransition {
        MaskRevealTransition(.blinds(count: count))
    }

    /// 扇形扫针从 12 点方向顺时针扫一圈。
    static var clock: MaskRevealTransition { MaskRevealTransition(.clock(sign: 1)) }

    /// 扇形扫针，方向可选。
    ///
    /// - Parameter direction: 扫针方向。⚠️ 用语义枚举而不是 `clockwise: Bool`
    ///   ——`true` 在调用处读不出含义（J-1 禁未豁免 Bool 参数，`SpinDirection`
    ///   记着同一条裁决）。
    static func clock(direction: SpinDirection = .clockwise) -> MaskRevealTransition {
        MaskRevealTransition(.clock(sign: direction == .clockwise ? 1 : -1))
    }

    /// 斜掠的直边扫过，揭示边上骑一条柔光带。
    static var glare: MaskRevealTransition {
        MaskRevealTransition(.glare(radians: MaskRevealTransition.defaultGlareAngle.radians))
    }

    /// 指定方向的掠光揭示。
    static func glare(angle: Angle = MaskRevealTransition.defaultGlareAngle) -> MaskRevealTransition {
        MaskRevealTransition(.glare(radians: angle.radians))
    }

    /// 网格逐格随机浮现。
    static var dissolve: MaskRevealTransition {
        MaskRevealTransition(.dissolve(cellSize: MaskRevealTransition.defaultCellSize))
    }

    /// 指定格边长的逐格浮现。
    ///
    /// - Parameter cellSize: 格边长（pt）。⚠️ 过小的值会被自动放大到让格数落在
    ///   `MaskReveal.dissolveMaximumCells` 以内——否则全屏内容配 `0.5` 会是百万级
    ///   子路径逐帧重建。`0` / 负数 / 非有限值一律回落到默认值。
    static func dissolve(cellSize: CGFloat = MaskRevealTransition.defaultCellSize) -> MaskRevealTransition {
        MaskRevealTransition(.dissolve(cellSize: cellSize))
    }
}

#Preview("mask reveal 六种") {
    @Previewable @State var shown = true
    @Previewable @State var index = 0

    let cases: [(String, MaskRevealTransition)] = [
        ("iris", .iris), ("wipe", .wipe), ("blinds", .blinds),
        ("clock", .clock), ("glare", .glare), ("dissolve", .dissolve),
    ]
    let current = cases[index % cases.count]

    return VStack(spacing: CoreSpacing.xxl) {
        Text(current.0).font(.headline)

        ZStack {
            if shown {
                Text("PRO")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, CoreSpacing.xxl)
                    .padding(.vertical, CoreSpacing.md)
                    .background(Color.accent, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(Color.contentOnAccent)
                    .transition(current.1)
            }
        }
        .frame(height: 140)

        HStack(spacing: CoreSpacing.lg) {
            Button("切换") { withAnimation(.easeInOut(duration: 0.9)) { shown.toggle() } }
            Button("换一种") { index += 1; shown = true }
        }
    }
    .padding(CoreSpacing.huge)
}

#Preview("含参重载") {
    @Previewable @State var shown = true

    return VStack(spacing: CoreSpacing.xxl) {
        HStack(spacing: CoreSpacing.xxl) {
            ForEach(Array(previewParameterisedCases.enumerated()), id: \.offset) { pair in
                VStack(spacing: CoreSpacing.sm) {
                    ZStack {
                        if shown {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accent)
                                .frame(width: 84, height: 84)
                                .transition(pair.element.1)
                        }
                    }
                    .frame(width: 84, height: 84)
                    Text(pair.element.0).font(.caption)
                }
            }
        }
        Button("切换") { withAnimation(.easeInOut(duration: 1.2)) { shown.toggle() } }
    }
    .padding(CoreSpacing.huge)
}

private let previewParameterisedCases: [(String, MaskRevealTransition)] = [
    ("iris(.topLeading)", .iris(anchor: .topLeading)),
    ("wipe(90°)", .wipe(angle: .degrees(90))),
    ("blinds(3)", .blinds(count: 3)),
    ("clock(逆)", .clock(direction: .counterClockwise)),
    ("glare(-20°)", .glare(angle: .degrees(-20))),
    ("dissolve(12)", .dissolve(cellSize: 12)),
]
