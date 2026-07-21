//
//  Form.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/9.
//

import SwiftUI

// MARK: - LabelIcon

/// 表单 / 列表行 leading 位置使用的方形 app-tile 风格图标。
///
/// 视觉形态：底层 `app.fill` glyph 提供圆角方块背景（按 `backgroundStyle` 上色），
/// 上层叠加目标 SF Symbol（`Color.contentInverse` 反白）。常见于 `Settings` 风格
/// 的 `LabeledContent { ... } label: { Label { Text(...) } icon: { LabelIcon(...) } }`
/// 组合。
///
/// ## Token 化
///
/// - 底层 tile 边长：`CoreControlMetrics.iconSize(for: .extraLarge)` (24pt)
/// - 上层 glyph 边长：`CoreControlMetrics.iconSize(for: .regular)` (16pt)
/// - 反白色：`Color.contentInverse`
///
/// `iconSize(for:)` 是控件内联 icon 的标准 token，比起 `CoreSpacing.*`
/// 在语义上更贴合"几何尺寸 vs. 布局间距"的边界。
public struct LabelIcon: View {
    /// 以单一 `Color` 着色。便利 init，等价于 `init(systemName:backgroundStyle:variableValue:)`
    /// 包裹一层 `AnyShapeStyle`。
    ///
    /// - Parameters:
    ///   - systemName: 上层叠加的 SF Symbol 名称。
    ///   - backgroundColor: 底层 tile 颜色。
    ///   - variableValue: SF Symbol variable color / variable value（如 `bell.badge.fill`
    ///     的填充强度），可选。
    public init(systemName: String, backgroundColor: Color, variableValue: Double? = nil) {
        self.systemName = systemName
        self.backgroundStyle = AnyShapeStyle(backgroundColor)
        self.variableValue = variableValue
    }

    /// 以任意 `ShapeStyle`（gradient / material / hierarchical）着色。
    ///
    /// - Parameters:
    ///   - systemName: 上层叠加的 SF Symbol 名称。
    ///   - backgroundStyle: 底层 tile 着色样式，可为 `LinearGradient` / `Material` 等。
    ///   - variableValue: SF Symbol variable color / variable value，可选。
    public init(systemName: String, backgroundStyle: some ShapeStyle, variableValue: Double? = nil) {
        self.systemName = systemName
        self.backgroundStyle = AnyShapeStyle(backgroundStyle)
        self.variableValue = variableValue
    }

    /// 渲染叠合 tile：底层 `app.fill` (24pt) + 上层 SF Symbol (16pt, `contentInverse`)。
    public var body: some View {
        Image(systemName: "app.fill")
            .font(.system(size: CoreControlMetrics.iconSize(for: .extraLarge)))
            .foregroundStyle(self.backgroundStyle)
            .overlay(alignment: .center) {
                Image(systemName: self.systemName, variableValue: self.variableValue)
                    .font(.system(size: CoreControlMetrics.iconSize(for: .regular)))
                    .foregroundStyle(Color.contentInverse)
            }
            // LabelIcon 是 `Label { Text(...) } icon: { LabelIcon(...) }` 的 icon 槽：
            // 该用法下 SwiftUI 的 `Label` 已把 icon+text 合成单一元素、由 Text 播报，
            // 本 hidden 与之一致（冗余保险）。**不承诺**外层 `.accessibilityHidden(false)`
            // 能恢复——SwiftUI 内层 hidden 剪掉子树后外层 unhide 不可靠。standalone 需要
            // 图标被播报时，调用方应组合自带 label 的图标视图，而非依赖 unhide。
            .accessibilityHidden(true)
    }

    private let systemName: String
    private let backgroundStyle: AnyShapeStyle
    private let variableValue: Double?
}

// MARK: - ChevronRightIcon

/// 列表行 trailing 位置的"可进入下一级"指示符（系统 `chevron.right`）。
///
/// 配色与字号继承父容器（一般是 `LabeledContent` 的 detail 槽位，由 SwiftUI
/// `Form` / `List` 自动应用 secondary tint）。如未来需要自定义尺寸，可以加
/// 默认参数走 `CoreControlMetrics.iconSize(for:)`。
public struct ChevronRightIcon: View {
    /// 创建一个默认配置的 chevron 指示符。
    public init() {}

    /// 渲染 `chevron.right` symbol，颜色 / 尺寸由父容器决定。
    public var body: some View {
        Image(systemName: "chevron.right")
            // 永远是「进入下一级」的 disclosure 指示符，任何语境下都装饰——对齐
            // Sidebar 对 chevron 的处理，无歧义，隐藏它安全。
            .accessibilityHidden(true)
    }
}

// MARK: - DangerIcon

/// 列表行 trailing 位置的危险 / 错误状态指示符（实心感叹号圆形）。
///
/// 颜色固定为 `Color.statusDangerForeground`（语义 token），尺寸继承父容器字号。
/// 常见用法是与 `ChevronRightIcon` 并排出现于 `LabeledContent` 的 detail 槽位，
/// 提示该项需要用户注意（例如未读告警 / 待修复设置）。
public struct DangerIcon: View {
    /// 创建一个默认配置的危险指示符。
    public init() {}

    /// 渲染 `exclamationmark.circle.fill`，foreground 锁定为 `statusDangerForeground`。
    public var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(Color.statusDangerForeground)
            // 承载语义（危险/需注意本身是信息），补 label 而非隐藏。用 "Alert" 而非
            // "Warning"——warning(橙) 与 danger(红) 在本库是两个不同的状态语义，念 "Warning"
            // 会让屏读用户把 danger 误听成 warning、无法区分本该能区分的两个状态。
            .accessibilityLabel("Alert")
    }
}

#Preview {
    @Previewable @State var isSaveDataTraffic = false
    Form {
        Section {
            LabeledContent {
                ChevronRightIcon()
            } label: {
                Label {
                    Text("主页")
                } icon: {
                    LabelIcon(systemName: "person.circle.fill", backgroundColor: .red4)
                }
            }
        }

        Section {
            LabeledContent {
                Text("扫描二维码")
                ChevronRightIcon()
            } label: {
                Label {
                    Text("设备")
                } icon: {
                    LabelIcon(systemName: "ipad.case.and.iphone.case", backgroundColor: .yellow4)
                }
            }
            LabeledContent {
                DangerIcon()
                ChevronRightIcon()
            } label: {
                Label {
                    Text("通知")
                } icon: {
                    LabelIcon(systemName: "bell.badge.fill", backgroundColor: .danger)
                }
            }
            Toggle("节省流量", isOn: $isSaveDataTraffic)
        }
    }
}
