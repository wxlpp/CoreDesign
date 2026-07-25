//
//  Radio.swift
//  CoreDesign
//

import SwiftUI

// MARK: - RadioOption

/// 单选组的一个可选项 / A single selectable option in a `RadioGroup`。
///
/// 纯数据结构：`id` 直接取 `value`（`Identifiable` 契约），`title` 由调用方提供、
/// 未经 `Localizable.strings`——与 `Tag` / `CheckBoxToggleStyle` 一致，标签文案本地化
/// 由调用方自负责。
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

/// Semi 风格单选组 / Semi-style radio group：`Binding<SelectionValue>` 驱动的互斥选择控件，
/// 视觉上与既有 `Components/CheckBox/`（`CheckBoxToggleStyle`）成对——同一套 token
/// （`Color.contentPrimary` / `Color.gray`、`CoreControlMetrics.iconSize(for: .regular)`、
/// `CoreSpacing.sm`、44pt 命中区手法），只是把方框换成圆点。
///
/// 未采用 macOS 原生 `.pickerStyle(.radioGroup)`：Apple 原生更推荐该 style，但本仓库
/// Semi 组件集里 Radio 与 CheckBox 是并列的表单控件，为保持跨端视觉一致与既有 CheckBox
/// 语汇延续，复刻 `CheckBoxToggleStyle` 的手写实现而非借用平台 picker style。
///
/// 使用方式：
///
/// ```swift
/// RadioGroup(
///     selection: $selectedPlan,
///     options: [
///         RadioOption(value: .basic, title: "基础版"),
///         RadioOption(value: .pro, title: "专业版"),
///     ]
/// )
/// ```
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
        HStack(spacing: CoreSpacing.sm) {
            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                .foregroundStyle(selected ? Color.contentPrimary : Color.gray)
            Text(option.title)
        }
        // 与 CheckBoxToggleStyle 同一手法：无 minHeight/contentShape 时命中区域会
        // 退化为 icon + label 的 intrinsic 高度，远低于 44pt 地板。补上
        // `frame(minHeight:)` + `contentShape(Rectangle())` 把整行命中区撑到
        // 44pt（内部相对布局不变，行高本身确有增加，属可接受的无障碍取舍）。
        .frame(minHeight: CoreControlMetrics.height(for: .regular))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.25), value: selected)
        .onTapGesture {
            self.selection = option.value
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// 纯函数 / Pure function：判断某选项在给定 `selection` 下是否为选中态。
    /// 抽出为可单测的静态函数，而非只能通过渲染验证。
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
