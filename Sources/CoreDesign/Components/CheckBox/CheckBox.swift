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
struct CheckBoxToggleStyle: ToggleStyle {
    @MainActor @preconcurrency
    func makeBody(configuration: Configuration) -> some View {
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

// MARK: - CheckBox

/// 复选框 / CheckBox：`Toggle` + `CheckBoxToggleStyle` 的便利封装。
///
/// 使用场景：表单选项、协议同意框、列表多选等。Primer 概念上对应 `Checkbox` 表单控件，
/// 本组件仅暴露最小用法用于 `#Preview` 视觉冒烟，业务侧通常直接使用
/// `Toggle(...).toggleStyle(CheckBoxToggleStyle())` 自行控制 binding 与 label。
struct CheckBox: View {
    @State var isOn = false

    var body: some View {
        Toggle("哈哈哈哈哈", isOn: self.$isOn).toggleStyle(CheckBoxToggleStyle())
    }
}

#Preview {
    CheckBox()
}
