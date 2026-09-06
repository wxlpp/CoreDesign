import SwiftUI

// MARK: - RadioOption

/// 单选组的一个可选项 / A single selectable option in a `RadioGroup`。
public struct RadioOption<SelectionValue: Hashable & Sendable>: Identifiable, Sendable {
    public var id: SelectionValue { self.value }

    /// 该选项代表的选中值。
    public let value: SelectionValue

    /// 选项标题，运行期字符串，直接展示，不经本地化表。
    public let title: String

    public init(value: SelectionValue, title: String) {
        self.value = value
        self.title = title
    }
}

// MARK: - RadioGroup

/// `Binding<SelectionValue>` 驱动的互斥选择组，与 `CheckBoxToggleStyle` 同套 token、方框换圆点。
public struct RadioGroup<SelectionValue: Hashable & Sendable>: View {
    @Binding private var selection: SelectionValue
    private let options: [RadioOption<SelectionValue>]
    private let axis: Axis
    private let spacing: CGFloat

    /// - Parameters:
    ///   - selection: 当前选中值的双向绑定。
    ///   - options: 全部候选项，按传入顺序渲染。
    ///   - axis: 排列方向，`.vertical`（默认）纵向堆叠，`.horizontal` 横向排列。
    ///   - spacing: 选项间距，默认 `CoreSpacing.sm`。
    public init(
        selection: Binding<SelectionValue>,
        options: [RadioOption<SelectionValue>],
        axis: Axis = .vertical,
        spacing: CGFloat = CoreSpacing.sm
    ) {
        self._selection = selection
        self.options = options
        self.axis = axis
        self.spacing = spacing
    }

    public var body: some View {
        Group {
            if self.axis == .horizontal {
                HStack(spacing: self.spacing) {
                    ForEach(self.options) { option in
                        self.row(for: option)
                    }
                }
            } else {
                VStack(spacing: self.spacing) {
                    ForEach(self.options) { option in
                        self.row(for: option)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for option: RadioOption<SelectionValue>) -> some View {
        let selected = Self.isSelected(option, in: self.selection)
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            Image(systemName: selected ? "circle.inset.filled" : "circle")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(selected ? Color.contentPrimary : Color.contentSecondary)
                .accessibilityHidden(true)
            Text(option.title)
        }
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.25), value: selected)
        .onTapGesture {
            self.selection = option.value
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    static func isSelected(_ option: RadioOption<SelectionValue>, in selection: SelectionValue) -> Bool {
        option.value == selection
    }
}

// MARK: - Preview

#Preview("垂直 / Vertical") {
    @Previewable @State var verticalSelection = "basic"

    RadioGroup(
        selection: $verticalSelection,
        options: [
            RadioOption(value: "basic", title: "基础版 / Basic"),
            RadioOption(value: "pro", title: "专业版 / Pro"),
            RadioOption(value: "enterprise", title: "企业版 / Enterprise"),
        ]
    )
    .padding()
}

#Preview("水平 / Horizontal") {
    @Previewable @State var horizontalSelection = 1

    RadioGroup(
        selection: $horizontalSelection,
        options: [
            RadioOption(value: 1, title: "小 / S"),
            RadioOption(value: 2, title: "中 / M"),
            RadioOption(value: 3, title: "大 / L"),
        ],
        axis: .horizontal
    )
    .padding()
}

#Preview("垂直 / Vertical — Dark") {
    @Previewable @State var verticalSelection = "pro"

    RadioGroup(
        selection: $verticalSelection,
        options: [
            RadioOption(value: "basic", title: "基础版 / Basic"),
            RadioOption(value: "pro", title: "专业版 / Pro"),
            RadioOption(value: "enterprise", title: "企业版 / Enterprise"),
        ]
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("水平 / Horizontal — Dark") {
    @Previewable @State var horizontalSelection = 2

    RadioGroup(
        selection: $horizontalSelection,
        options: [
            RadioOption(value: 1, title: "小 / S"),
            RadioOption(value: 2, title: "中 / M"),
            RadioOption(value: 3, title: "大 / L"),
        ],
        axis: .horizontal
    )
    .padding()
    .preferredColorScheme(.dark)
}
