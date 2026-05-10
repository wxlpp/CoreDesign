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
                        .font(CoreTypography.titleMediumFont)
                        .foregroundStyle(Color.contentPrimary)
                    Text(component.description)
                        .font(CoreTypography.bodyLargeFont)
                        .foregroundStyle(Color.contentMuted)

                    if let demo = component.demoAction {
                        demo()
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
                    .overlay(
                        RoundedRectangle(cornerRadius: CoreRadius.medium)
                            .strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.thin)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium))
                }
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceCanvas)
        .navigationTitle(component.name)
    }
}

