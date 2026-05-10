import SwiftUI
import CoreDesign

struct ComponentDetail: View {
    let component: ComponentMeta

    @Environment(\.toastHost) private var toast

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text(component.name)
                        .font(CoreTypography.titleMediumFont)
                        .foregroundStyle(Color.contentPrimary)
                    Text(component.description)
                        .font(CoreTypography.bodyLargeFont)
                        .foregroundStyle(Color.contentMuted)

                    if component.id == "toast" {
                        Button("Show Demo Toast") {
                            self.toast?.show("Toast message", level: .info)
                        }
                        .buttonStyle(.solidButton(role: .primary))
                    }
                }

                // Light + Dark side-by-side
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Preview")
                        .font(CoreTypography.titleSmallFont)
                        .foregroundStyle(Color.contentPrimary)

                    HStack(alignment: .top, spacing: 0) {
                        // Light
                        VStack(spacing: 0) {
                            Text("Light")
                                .font(CoreTypography.captionFont)
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
                                .font(CoreTypography.captionFont)
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
                    .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: CoreRadius.medium)
                            .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
                    )
                }
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceCanvas)
        .navigationTitle(component.name)
        .toastHost(edge: .top)
    }
}
