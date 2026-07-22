import SwiftUI
import CoreDesign

struct ComponentDetail: View {
    let component: ComponentMeta

    private var previewBorder: RoundedRectangle {
        RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoreSpacing.md) {
                // Header
                VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                    Text(component.name)
                        .font(CoreTypography.Token.title2.font)
                        .foregroundStyle(Color.contentPrimary)
                    Text(component.description)
                        .font(CoreTypography.Token.callout.font)
                        .foregroundStyle(Color.contentMuted)

                    if let demo = component.demoAction {
                        demo()
                    }
                }

                // Light + Dark side-by-side
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Preview")
                        .font(CoreTypography.Token.headline.font)
                        .foregroundStyle(Color.contentPrimary)

                    HStack(alignment: .top, spacing: 0) {
                        // Light
                        VStack(spacing: 0) {
                            Text("Light")
                                .font(CoreTypography.Token.caption.font)
                                .foregroundStyle(Color.contentMuted)
                                .padding(.vertical, CoreSpacing.xs)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfacePanel)

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
                                .font(CoreTypography.Token.caption.font)
                                .foregroundStyle(Color.contentMuted)
                                .padding(.vertical, CoreSpacing.xs)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfacePanel)

                            component.preview()
                                .padding(CoreSpacing.md)
                                .frame(maxWidth: .infinity)
                                .background(Color.surfaceCanvas)
                        }
                        .preferredColorScheme(.dark)
                    }
                    .background(Color.surfacePanel)
                    .overlay(self.previewBorder.strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.hairline))
                    .clipShape(self.previewBorder)
                }
            }
            .padding(CoreSpacing.lg)
        }
        .background(Color.surfaceCanvas)
        .navigationTitle(component.name)
    }
}
