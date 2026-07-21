//
//  FloatingGlassModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - FloatingGlassModifier

public struct FloatingGlassModifier<S: InsettableShape>: ViewModifier {
    public let shape: S
    public let isInteractive: Bool

    public init(shape: S, isInteractive: Bool = false) {
        self.shape = shape
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        let glass = self.isInteractive ? Glass.regular.interactive() : Glass.regular

        content
            .background(
                self.shape
                    .inset(by: CoreButtonMetrics.glassInset)
                    .fill(.background.opacity(0.64))
                    .glassEffect(glass, in: self.shape)
            )
            .overlay(
                self.shape.strokeBorder(
                    Color.borderSubtle,
                    lineWidth: CoreBorderWidth.hairline
                )
            )
    }
}

public extension View {
    func floatingGlass(
        in shape: some InsettableShape = Capsule(style: .continuous),
        isInteractive: Bool = false
    ) -> some View {
        self.modifier(FloatingGlassModifier(shape: shape, isInteractive: isInteractive))
    }
}

#Preview {
    VStack(spacing: CoreSpacing.xl) {
        Text("floatingGlass · Capsule (default)")
            .padding()
            .floatingGlass()

        Text("floatingGlass · RoundedRect (interactive)")
            .padding()
            .floatingGlass(in: RoundedRectangle(cornerRadius: CoreRadius.large), isInteractive: true)
    }
    .padding(CoreSpacing.xxxl)
    .background(Color.surfaceCanvas)
}
