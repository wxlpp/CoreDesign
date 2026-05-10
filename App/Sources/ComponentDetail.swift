import SwiftUI
import CoreDesign

struct ComponentDetail: View {
    let component: ComponentMeta

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text(component.name)
                        .font(.title)
                        .foregroundStyle(Color.contentPrimary)
                    Text(component.description)
                        .font(.body)
                        .foregroundStyle(Color.contentMuted)

                    if component.id == "toast" {
                        ToastDemoButton()
                    }
                }

                // Light + Dark side-by-side
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundStyle(Color.contentPrimary)

                    let roundedRect = RoundedRectangle(cornerRadius: CoreRadius.medium)

                    HStack(alignment: .top, spacing: 0) {
                        // Light
                        VStack(spacing: 0) {
                            Text("Light")
                                .font(.caption)
                                .foregroundStyle(Color.contentMuted)
                                .padding(.vertical, CoreSpacing.xs)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfaceCanvasSubtle)

                            component.preview()
                                .padding(CoreSpacing.md)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfaceCanvas)
                        }
                        .preferredColorScheme(.light)

                        Divider()

                        // Dark
                        VStack(spacing: 0) {
                            Text("Dark")
                                .font(.caption)
                                .foregroundStyle(Color.contentMuted)
                                .padding(.vertical, CoreSpacing.xs)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfaceCanvasSubtle)

                            component.preview()
                                .padding(CoreSpacing.md)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfaceCanvas)
                        }
                        .preferredColorScheme(.dark)
                    }
                    .overlay(
                        roundedRect
                            .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
                    )
                    .clipShape(roundedRect)
                }
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceCanvas)
        .navigationTitle(component.name)
    }
}

// MARK: - ToastDemoButton

/// 子视图，确保在 `.toastHost(edge:)` 生效的环境中读取 `\.toastHost`。
private struct ToastDemoButton: View {
    @Environment(\.toastHost) private var toast

    var body: some View {
        Button("Show Demo Toast") {
            self.toast?.show("Toast message", level: .info)
        }
        .buttonStyle(.solidButton(role: .primary))
    }
}
