import OhMyDesign
import SwiftUI

// MARK: - 强度档位

/// 微交互的强度。**所有**微交互共用这一个枚举。
public nonisolated enum MicroInteractionStrength: Sendable, CaseIterable {
    case subtle, regular, pronounced

    var displacement: CGFloat {
        switch self {
        case .subtle: 4
        case .regular: 9
        case .pronounced: 16
        }
    }

    var scaleDelta: CGFloat {
        switch self {
        case .subtle: 0.06
        case .regular: 0.14
        case .pronounced: 0.24
        }
    }

    var particleCount: Int {
        switch self {
        case .subtle: 6
        case .regular: 12
        case .pronounced: 22
        }
    }
}

// MARK: - TriggerRelay

struct TriggerRelay<T: Equatable, Core: ViewModifier>: ViewModifier {
    let trigger: T
    let makeCore: (Int) -> Core

    @State private var fire = 0

    func body(content: Content) -> some View {
        content
            .modifier(self.makeCore(self.fire))
            .onChange(of: self.trigger) { self.fire &+= 1 }
    }
}

// MARK: - Reduce Motion 降级

extension View {
    @ViewBuilder
    func reduceMotionFallback(active: Bool, trigger: Int) -> some View {
        if active {
            self.modifier(OpacityPulse(trigger: trigger))
        } else {
            self
        }
    }
}

private struct OpacityPulse: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.phaseAnimator([1.0, 0.45, 1.0], trigger: self.trigger) { view, opacity in
            view.opacity(opacity)
        } animation: { _ in
            .easeInOut(duration: 0.12)
        }
    }
}
