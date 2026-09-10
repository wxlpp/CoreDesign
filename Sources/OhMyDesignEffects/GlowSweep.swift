import OhMyDesign
import SwiftUI

/// 流光装饰的生命周期，不改变内容的可用性。
public nonisolated enum GlowSweepActivity: Sendable {
    case active, inactive
}

/// `GlowSweep { }` —— 一段辉光**沿内容边框转圈**，表示"正在生成 / 正在思考"。
public struct GlowSweep<Content: View>: View {
    private let content: Content
    private let activity: GlowSweepActivity
    private var ring: ((CGFloat) -> AnyView)?

    public init(activity: GlowSweepActivity = .active, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.activity = activity
    }

    /// 沿指定形状的内边框绘制流光；停用时保留内容且不建立动画驱动。
    public init<S: InsettableShape>(
        in shape: S, activity: GlowSweepActivity = .active, @ViewBuilder content: () -> Content
    ) {
        self.init(in: shape, stroke: .tint, activity: activity, content: content)
    }

    /// 沿指定形状绘制自定义颜色或渐变的流光。
    public init<S: InsettableShape, Stroke: ShapeStyle>(
        in shape: S, stroke: Stroke, activity: GlowSweepActivity = .active,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.activity = activity
        self.ring = { phase in
            AnyView(shape.strokeBorder(stroke, lineWidth: ProcessingSweep.ringLineWidth)
                .mask { PerimeterGlowTrail(shape: shape, phase: phase) })
        }
    }

    public var body: some View {
        self.content.overlay {
            if self.activity == .active {
                ProcessingSweepDriver(kind: .glow, ring: self.ring)
            }
        }
    }
}

#Preview("GlowSweep") {
    GlowSweep {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 120)
            .overlay { Image(systemName: "sparkles").font(.system(size: 40)) }
    }
    .tint(.accent)
    .padding(40)
}
