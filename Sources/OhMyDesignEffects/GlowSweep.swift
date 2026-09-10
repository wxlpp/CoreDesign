import OhMyDesign
import SwiftUI

/// `GlowSweep { }` —— 一段辉光**沿内容边框转圈**，表示"正在生成 / 正在思考"。
public struct GlowSweep<Content: View>: View {
    private let content: Content
    private let isActive: Bool
    private var ring: (() -> AnyView)?

    public init(isActive: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isActive = isActive
    }

    /// 沿指定形状的内边框绘制流光；停用时保留内容且不建立动画驱动。
    public init<S: InsettableShape>(
        in shape: S, isActive: Bool = true, @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isActive = isActive
        self.ring = {
            AnyView(shape.strokeBorder(.tint, lineWidth: ProcessingSweep.ringLineWidth))
        }
    }

    public var body: some View {
        self.content.overlay {
            if self.isActive {
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
