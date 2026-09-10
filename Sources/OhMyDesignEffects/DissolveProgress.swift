import OhMyDesign
import SwiftUI

public extension View {
    /// 可控进度的消散：1 为完整内容，0 为完全隐藏；布局占位保持不变。
    func dissolve(progress: Double, cellSize: CGFloat = 24) -> some View {
        modifier(DissolveProgressModifier(progress: progress, cellSize: cellSize))
    }
}

struct DissolveProgressModifier: ViewModifier, Animatable {
    var progress: Double
    let cellSize: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let amount = min(1, max(0, progress))
        content.mask {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let path = reduceMotion ? Path(rect)
                    : MaskReveal.dissolvePath(cellSize: cellSize, progress: amount, in: rect)
                context.fill(path, with: .color(Color.maskOpaque.opacity(reduceMotion ? amount : 1)))
            }
        }
    }
}
