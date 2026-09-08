import SwiftUI

// MARK: - MenuIconView

private struct MenuIconView: View, @MainActor Animatable {
    var progress: Double

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    var body: some View {
        Canvas { context, canvasSize in
            let centerX = canvasSize.width / 2
            let centerY = canvasSize.height / 2
            let halfLength = canvasSize.width * 0.42
            let lineGap = canvasSize.height * 0.28
            let progressValue = CGFloat(progress)
            let angle = Double.pi / 4 * Double(progressValue)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

            func segment(centerX: CGFloat, centerY: CGFloat, angle: Double) -> Path {
                let cosine = CGFloat(cos(angle))
                let sine = CGFloat(sin(angle))
                var path = Path()
                path.move(to: CGPoint(x: centerX - halfLength * cosine, y: centerY - halfLength * sine))
                path.addLine(to: CGPoint(x: centerX + halfLength * cosine, y: centerY + halfLength * sine))
                return path
            }

            context.stroke(
                segment(centerX: centerX, centerY: centerY - lineGap * (1 - progressValue), angle: angle),
                with: .foreground, style: style
            )

            context.opacity = 1 - Double(progressValue)
            context.stroke(
                segment(centerX: centerX, centerY: centerY, angle: 0),
                with: .foreground, style: style
            )
            context.opacity = 1

            context.stroke(
                segment(centerX: centerX, centerY: centerY + lineGap * (1 - progressValue), angle: -angle),
                with: .foreground, style: style
            )
        }
        .frame(width: self.size, height: self.size)
    }

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = CoreControlMetrics.iconSize(for: .large)

    private var lineWidth: CGFloat {
        self.size / 12
    }
}

// MARK: - CoreMenuButtonStyle

enum CoreMenuButtonStyle: Sendable, Equatable {
    case labeled
    case circular
}

// MARK: - CoreMenuButtonStyleModifier

private struct CoreMenuButtonStyleModifier: ViewModifier {
    let style: CoreMenuButtonStyle

    func body(content: Content) -> some View {
        switch self.style {
        case .labeled:
            content
                .padding(.horizontal, CoreSpacing.sm)
                .frame(minHeight: self.controlSize)
                .contentShape(Capsule())
                .modifier(TelegramGlassButtonModifier(
                    shape: Capsule(),
                    isPressed: false,
                    border: .borderSubtle,
                    pressFeedback: false
                ))
        case .circular:
            content
                .frame(width: self.controlSize, height: self.controlSize)
                .contentShape(Circle())
                .modifier(TelegramGlassButtonModifier(
                    shape: Circle(),
                    isPressed: false,
                    border: .borderSubtle,
                    pressFeedback: false
                ))
        }
    }

    private let controlSize: CGFloat = CoreControlMetrics.height(for: .large)
}

// MARK: - CoreMenuButton

struct CoreMenuButton: View {
    @Binding var isExpanded: Bool

    var style: CoreMenuButtonStyle = .labeled

    var body: some View {
        let icon = MenuIconView(progress: self.isExpanded ? 1.0 : 0.0)

        let inner = HStack(spacing: CoreSpacing.sm) {
            icon
            if self.style == .labeled {
                Text("Menu", bundle: .module)
            }
        }

        inner
            .modifier(CoreMenuButtonStyleModifier(style: self.style))
            .foregroundStyle(.white)
            .scaleEffect(self.isLongPressing ? CoreButtonMetrics.pressedScale : 1.0)
            .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 10, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.isLongPressing = pressing
                }
                if !pressing && self.longPressTriggered {
                    withAnimation(.spring(duration: 0.3)) {
                        self.isExpanded.toggle()
                    }
                    triggerMenuFeedback()
                    self.longPressTriggered = false
                }
            }, perform: {
                self.longPressTriggered = true
            })
            .onTapGesture {
                withAnimation(.spring(duration: 0.3)) {
                    self.isExpanded.toggle()
                }
                triggerMenuFeedback()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Menu", bundle: .module))
            .accessibilityAddTraits(.isButton)
    }

    @State private var isLongPressing = false
    @State private var longPressTriggered = false
}

@MainActor
private func triggerMenuFeedback() {
    #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    #endif
}

#Preview {
    VStack(spacing: 16) {
        CoreMenuButton(isExpanded: .constant(true), style: .labeled)
            .font(.headline)
            .backgroundStyle(.red)

        CoreMenuButton(isExpanded: .constant(false), style: .circular)
            .font(.headline)
            .backgroundStyle(.red)
    }
}
