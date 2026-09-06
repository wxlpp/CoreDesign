import SwiftUI

// MARK: - DisclosureChevron

private struct DisclosureChevron: View {
    let isExpanded: Bool

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Image(systemName: "chevron.forward")
            .foregroundStyle(.tint)
            .rotationEffect(.degrees(self.rotation))
    }

    private var rotation: Double {
        guard self.isExpanded else { return 0 }
        return self.layoutDirection == .rightToLeft ? -90 : 90
    }
}

// MARK: - CoreDisclosureGroupStyle

/// 系统 `DisclosureGroup` 的 CoreDesign 视觉外观——**不重新实现控件本身**，只重排
/// `makeBody(configuration:)` 交出的 `label` / `content`，展开状态仍由系统
/// 通过 `configuration.$isExpanded`（`Binding<Bool>`）驱动。`DisclosureGroupStyle.makeBody`
/// 是公开 API，`.tint` 接入无障碍。
public struct CoreDisclosureGroupStyle: DisclosureGroupStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Button {
                withAnimation(.snappy) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack {
                    configuration.label
                    Spacer()
                    DisclosureChevron(isExpanded: configuration.isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                configuration.isExpanded
                    ? Text("Expanded", bundle: .module)
                    : Text("Collapsed", bundle: .module)
            )

            if configuration.isExpanded {
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, CoreSpacing.md)
            }
        }
    }
}

// MARK: - DisclosureGroupStyle extension

public extension DisclosureGroupStyle where Self == CoreDisclosureGroupStyle {
    /// CoreDesign 的默认 `DisclosureGroup` 外观：chevron 走 `.tint`，展开内容
    /// 作 leading 缩进（贴近原生，不加卡片）。
    static var core: CoreDisclosureGroupStyle { CoreDisclosureGroupStyle() }
}

#Preview("CoreDisclosureGroupStyle — Light") {
    CoreDisclosureGroupStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("CoreDisclosureGroupStyle — Dark") {
    CoreDisclosureGroupStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CoreDisclosureGroupStylePreviewGallery: View {
    @State private var expandedA = true
    @State private var expandedB = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("默认 tint（继承 accent）").coreFont(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("Details", isExpanded: self.$expandedA) {
                    Text("Additional information goes here.")
                }
                .disclosureGroupStyle(.core)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(".tint(.red) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("Details", isExpanded: self.$expandedB) {
                    Text("Additional information goes here.")
                }
                .disclosureGroupStyle(.core)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
