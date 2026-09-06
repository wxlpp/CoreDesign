import CoreDesign
import SwiftUI

/// `GlowSweep { }` —— 一段辉光**沿内容边框转圈**，表示"正在生成 / 正在思考"。
public struct GlowSweep<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        self.content.overlay { ProcessingSweepDriver(kind: .glow) }
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
