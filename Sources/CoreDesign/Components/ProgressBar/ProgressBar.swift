import SwiftUI

// MARK: - ProgressBar

/// **材质层**: 内容. **表面角色**: 内容.
@available(*, deprecated, message: "改用 ProgressView(value:).progressViewStyle(.core)——.core 响应环境 .tint，走系统控件。见 docs/components/core-control-styles.md")
public struct ProgressBar: View {
    let value: Double
    let tint: Color?
    let label: String?

    public init(value: Double, tint: Color? = nil, label: String? = nil) {
        let sanitized = value.isFinite ? value : 0
        self.value = min(max(sanitized, 0), 1)
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            if let label = self.label {
                Text(label)
                    .coreFont(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    CoreShape.rounded(CoreRadius.small)
                        .fill(Color.surfaceCanvasInset)
                    CoreShape.rounded(CoreRadius.small)
                        .fill(self.tint ?? Color.accent)
                        .frame(width: geometry.size.width * CGFloat(self.value))
                }
            }
            .frame(height: CoreSpacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.label.map(Text.init(verbatim:)) ?? Text("Progress", bundle: .module))
        .accessibilityValue(Self.percentValue(self.value))
    }

    static func percentValue(_ value: Double) -> String {
        let pct = "\(Int(value * 100))%"
        return String(localized: "\(pct) complete", bundle: .module)
    }
}
