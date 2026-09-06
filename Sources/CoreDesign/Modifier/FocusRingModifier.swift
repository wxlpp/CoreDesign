import SwiftUI

// MARK: - FocusRingModifier

struct FocusRingModifier: ViewModifier {
    var visible: Bool
    var color: Color
    var width: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                CoreShape.rounded(self.cornerRadius)
                    .stroke(
                        self.visible ? self.color : .clear,
                        lineWidth: self.width
                    )
            )
    }
}

// MARK: - View.focusRing

public extension View {
    /// 给视图添加一个焦点环。
    ///
    /// - Parameters:
    ///   - visible: 是否显示焦点环；通常由 `@FocusState` 或外部状态绑定 / Whether
    ///     the ring is shown; typically driven by `@FocusState` or external state.
    ///   - color: 描边色，默认 `.borderFocus` / Stroke color, defaults to `.borderFocus`.
    ///   - width: 描边宽度，默认 `CoreBorderWidth.thick` (2pt) / Stroke width.
    ///   - cornerRadius: 圆角，默认 `CoreRadius.medium` (6pt) / Corner radius.
    /// - Returns: 套上了焦点环 overlay 的视图 / The view wrapped with the focus-ring overlay.
    func focusRing(
        visible: Bool = true,
        color: Color = .borderFocus,
        width: CGFloat = CoreBorderWidth.thick,
        cornerRadius: CGFloat = CoreRadius.medium
    ) -> some View {
        return self.modifier(
            FocusRingModifier(
                visible: visible,
                color: color,
                width: width,
                cornerRadius: cornerRadius
            )
        )
    }
}

// MARK: - Preview

#if DEBUG && canImport(UIKit)
private struct FocusRingPreviewHost: View {
    @FocusState private var focusedField: Field?
    @State private var emailText: String = ""
    @State private var nameText: String = ""

    private enum Field: Hashable {
        case email
        case name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Text("FocusRingModifier — iOS Preview")
                .font(.headline)

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Email (focused → ring visible)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("you@example.com", text: self.$emailText)
                    .textFieldStyle(.plain)
                    .padding(CoreSpacing.sm)
                    .focused(self.$focusedField, equals: .email)
                    .focusRing(visible: self.focusedField == .email)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("Name (focused → ring visible)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Your name", text: self.$nameText)
                    .textFieldStyle(.plain)
                    .padding(CoreSpacing.sm)
                    .focused(self.$focusedField, equals: .name)
                    .focusRing(visible: self.focusedField == .name)
            }

            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                Text("visible: false → 透明且不占布局 / transparent, layout-neutral")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Static label")
                    .padding(CoreSpacing.sm)
                    .focusRing(visible: false)
            }

            Spacer()
        }
        .padding(CoreSpacing.lg)
    }
}

#Preview("FocusRingModifier — iOS") {
    FocusRingPreviewHost()
}
#endif
