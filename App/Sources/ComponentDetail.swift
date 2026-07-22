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

                    // Task #125：原为 HStack 并排——两栏各只有约 185pt 宽，一行 5 个 Badge
                    // 或稍长的 Tag 会被挤成「一字一行」的竖条，让组件在 demo 里看起来是坏的，
                    // 而组件本身没问题。改为上下堆叠，两种外观各占满整宽。
                    VStack(alignment: .leading, spacing: 0) {
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
                        // Task #125：这里**不能**用 `.preferredColorScheme`——它不是局部
                        // 作用域，会向上冒泡到整个 scene。两个兄弟视图各设一次时最后一个
                        // 赢，结果是整屏统一成同一外观、两栏渲染完全相同，而且还会**覆盖
                        // 掉真实的系统外观设置**（实测：模拟器设为深色，本页仍整屏浅色）。
                        // 用 `.environment(\.colorScheme,)` 才是真正只作用于该子树。
                        .environment(\.colorScheme, .light)

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
                        .environment(\.colorScheme, .dark)
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
