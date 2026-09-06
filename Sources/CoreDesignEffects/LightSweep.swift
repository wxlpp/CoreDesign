import CoreDesign
import SwiftUI

/// `LightSweep { }` —— 一道斜向光带在内容**表面左右掠过**，表示"正在等待 / 正在传输"。
public struct LightSweep<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        self.content.overlay { ProcessingSweepDriver(kind: .light) }
    }
}

#Preview("LightSweep") {
    LightSweep {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 90)
            .overlay { Image(systemName: "arrow.trianglehead.2.clockwise").font(.system(size: 34)) }
    }
    .tint(.accent)
    .padding(40)
}
