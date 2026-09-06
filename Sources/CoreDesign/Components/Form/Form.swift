import SwiftUI

// MARK: - LabelIcon

/// 表单 / 列表行 leading 位置使用的方形 app-tile 风格图标。
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
            .accessibilityHidden(true)
    }

    private let systemName: String
    private let backgroundStyle: AnyShapeStyle
    private let variableValue: Double?
}

// MARK: - ChevronRightIcon

/// 列表行 trailing 的「可进入下一级」指示符，用 `chevron.forward` 以在 RTL 下自动镜像。
public struct ChevronRightIcon: View {
    /// 创建一个默认配置的 chevron 指示符。
    public init() {}

    /// 渲染 `chevron.forward` symbol（LTR=right / RTL=left），颜色 / 尺寸由父容器决定。
    public var body: some View {
        Image(systemName: "chevron.forward")
            .accessibilityHidden(true)
    }
}

// MARK: - DangerIcon

/// 列表行 trailing 位置的危险 / 错误状态指示符（实心感叹号圆形）。
public struct DangerIcon: View {
    /// 创建一个默认配置的危险指示符。
    public init() {}

    /// 渲染 `exclamationmark.circle.fill`，foreground 锁定为 `statusDangerForeground`。
    public var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(Color.statusDangerForeground)
            .accessibilityLabel(Text("Alert", bundle: .module))
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
