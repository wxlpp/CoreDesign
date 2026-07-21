//
//  CheckBox.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/2.
//

import SwiftUI

// MARK: - CheckBoxToggleStyle

/// 复选框样式 / CheckBox toggle style：把 SwiftUI `Toggle` 渲染为左侧方框 +
/// 右侧 label 的复选框形态。
///
/// 使用方式：`Toggle("...", isOn: $value).toggleStyle(CheckBoxToggleStyle())`
///
/// 视觉规格：
/// - 与 Apple `ToggleStyle` 协议形态对齐（`makeBody(configuration:)` + `Configuration` 类型别名）。
/// - icon 字号 `CoreControlMetrics.iconSize(for: .regular)`（16pt），与 `bodyMedium` 默认 UI 文字视觉等重。
/// - icon ↔ label 间距 `CoreSpacing.sm`（8pt）。
/// - 选中态 `checkmark.square.fill` 用 `Color.contentPrimary`、未选中 `square` 用 `Color.gray`。
/// - light / dark 行为：`Color.contentPrimary` / `Color.gray` 自动适配系统外观。
///
///   > 此处原写 `Color.primary`。第 4 层曾定义同名别名而遮蔽了 SwiftUI 内建成员，
///   > 使该图标实际渲染成品牌色而非系统 label 色——与本注释原先的描述相反。
///   > Issue #93 删除了那组别名，这里改用语义层的 `contentPrimary` 明确表达意图。
public struct CheckBoxToggleStyle: ToggleStyle {
    /// 无参构造 / Memberwise-free init：显式声明才能让下游可达
    /// （Swift 默认合成的 memberwise init 是 internal）。
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: CoreSpacing.sm) {
            if configuration.isOn {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentPrimary)
            } else {
                Image(systemName: "square")
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.gray)
            }
            configuration.label
        }
        .animation(.easeOut(duration: 0.25), value: configuration.isOn)
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

// MARK: - Preview

// 演示用法 / Demo usage：本包不再导出便利封装——原 `CheckBox` 视图硬编码 label
// 且用 `@State` 而非 `@Binding`，唯一使用者就是本 Preview，已于 Issue #94 内联。
// （用 `//` 而非 `///`：doc 注释挂在 `#Preview` 这种独立宏展开上不会被 DocC /
// Quick Help 呈现，写成 doc 注释是自欺。面向下游的说明在 `CheckBoxToggleStyle`
// 自己的 doc block 里。）
#Preview {
    @Previewable @State var isOn = false

    Toggle("同意用户协议 / Accept terms", isOn: $isOn)
        .toggleStyle(CheckBoxToggleStyle())
        .padding()
}
