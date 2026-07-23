//
//  CoreProgressViewStyle.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreProgressViewStyle

/// 系统 `ProgressView` 的 CoreDesign 视觉外观——**不重新实现控件本身**，只重绘
/// `makeBody(configuration:)` 交出的内容。`ProgressView` 的 `makeBody` 是公开
/// API，`.tint` 接入无障碍：本 style 的强调色全部经 `ShapeStyle.tint`（`.tint`）
/// 取值，不写死 `Color.accent`——对控件外加 `.tint(.red)` 会让填充条 / 环形指示器
/// 真的变红（见本文件 `#Preview` 与 `Tests/CoreDesignTests/CoreControlStyleTintTests.swift`
/// 的像素级验证）。
///
/// 分两种形态：
/// - **确定态**（`configuration.fractionCompleted != nil`）：水平轨道 + 填充条，
///   轨道底色 `Color.surfaceCanvasInset`、填充色 `.tint`，圆角经 `CoreShape.rounded`。
/// - **不确定态**（`fractionCompleted == nil`）：退回系统环形 spinner——显式
///   `.progressViewStyle(.circular)` 避免递归回本 style，同时仍继承外层
///   `.tint(_:)`（环境值正常向下传递，不受局部 style 切换影响）。
///
/// 两种形态都保留 `configuration.label` / `currentValueLabel`（若调用方提供），
/// 并通过 `accessibilityElement(children: .combine)` + `accessibilityValue`
/// 保留进度语义，供 VoiceOver 播报百分比。
public struct CoreProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        if let fractionCompleted = configuration.fractionCompleted {
            VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                if let label = configuration.label {
                    label
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        CoreShape.rounded(CoreRadius.small)
                            .fill(Color.surfaceCanvasInset)
                        CoreShape.rounded(CoreRadius.small)
                            // `.tint`（`TintShapeStyle`）——反映当前环境 tint，
                            // 而非固定写死的 `Color.accent`（FR-12 / ADR-3）。
                            .fill(.tint)
                            .frame(width: geometry.size.width * CGFloat(fractionCompleted))
                    }
                }
                .frame(height: CoreSpacing.xs)

                if let currentValueLabel = configuration.currentValueLabel {
                    currentValueLabel
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue("\(Int(fractionCompleted * 100))%")
        } else {
            // 不确定态：退回系统环形 spinner。显式指定 `.circular` 而不是省略，
            // 避免 SwiftUI 把当前环境的 `progressViewStyle`（即本 style 自身）
            // 再次套用到这个内层 `ProgressView()` 上造成无限递归。
            VStack(spacing: CoreSpacing.xs) {
                if let label = configuration.label {
                    label
                }
                ProgressView()
                    .progressViewStyle(.circular)
                if let currentValueLabel = configuration.currentValueLabel {
                    currentValueLabel
                        .coreFont(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - ProgressViewStyle extension

public extension ProgressViewStyle where Self == CoreProgressViewStyle {
    /// CoreDesign 的默认 `ProgressView` 外观。
    ///
    /// ```swift
    /// ProgressView(value: 0.6)
    ///     .progressViewStyle(.core)
    ///     .tint(.red) // 强调色随之改变，不恒取 Color.accent
    /// ```
    static var core: CoreProgressViewStyle { CoreProgressViewStyle() }
}

#Preview("CoreProgressViewStyle — Light") {
    CoreProgressViewStylePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("CoreProgressViewStyle — Dark") {
    CoreProgressViewStylePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CoreProgressViewStylePreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("默认 tint（继承 accent）").coreFont(.footnote).foregroundStyle(.secondary)
                ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
                    .progressViewStyle(.core)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(".tint(.red) 覆盖").coreFont(.footnote).foregroundStyle(.secondary)
                ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
                    .progressViewStyle(.core)
                    .tint(.red)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("不确定态 + .tint(.red)").coreFont(.footnote).foregroundStyle(.secondary)
                ProgressView()
                    .progressViewStyle(.core)
                    .tint(.red)
            }
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
