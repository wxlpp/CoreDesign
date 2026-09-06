import SwiftUI

// MARK: - ProgressIndicator

/// **材质层**: 内容. **表面角色**: 内容.
public struct ProgressIndicator: View {
    let text: Text?

    let tint: Color

    /// 创建无文案的进度指示器。
    public init(tint: Color = .accent) {
        self.text = nil
        self.tint = tint
    }

    /// 静态文案——字面量在 `Bundle.main` 本地化（对 App 调用方即其自身 bundle），
    /// 渲染于 spinner 下方。
    public init(text: LocalizedStringKey, tint: Color = .accent) {
        self.text = Text(text)
        self.tint = tint
    }

    /// 运行期字符串文案，verbatim 显示、不走本地化查表。
    @_disfavoredOverload
    public init<S: StringProtocol>(text: S, tint: Color = .accent) {
        self.text = Text(text)
        self.tint = tint
    }

    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(self.tint)
                .controlSize(self.controlSize)
                .accessibilityLabel(self.text ?? Text("Loading", bundle: .module))

            if let text = self.text {
                text
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview("ProgressIndicator — Light") {
    ProgressIndicatorPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("ProgressIndicator — Dark") {
    ProgressIndicatorPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct ProgressIndicatorPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.xl) {
            VStack(spacing: CoreSpacing.lg) {
                ProgressIndicator()
                    .controlSize(.small)
                ProgressIndicator()
                    .controlSize(.regular)
                ProgressIndicator()
                    .controlSize(.large)
            }
            ProgressIndicator(text: "Loading…")
                .controlSize(.large)
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
