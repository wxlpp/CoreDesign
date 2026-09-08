import OhMyDesign
import SwiftUI

/// `ScanningOverlay { }` —— 一道横向光束在内容上**上下往复扫描**，表示"正在识别 / 正在处理"。
public struct ScanningOverlay<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        self.content.overlay { ProcessingSweepDriver(kind: .scanning) }
    }
}

#Preview("ScanningOverlay") {
    ScanningOverlay {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 150)
            .overlay { Image(systemName: "doc.text.viewfinder").font(.system(size: 44)) }
    }
    .tint(.accent)
    .padding(40)
}
