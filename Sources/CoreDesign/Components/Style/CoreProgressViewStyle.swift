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
///
/// > 无障碍假设：`currentValueLabel` 的**可视文本**被 `.accessibilityHidden` 掉
/// > 以避免与 `accessibilityValue` 的百分数双重播报——这假定它就是百分比重复
/// > （如 "60%"）。若调用方在 `currentValueLabel` 里放的是**非百分比**信息
/// > （如 "3 of 5 files"），该信息对 VoiceOver 不可达，只会播报 `fractionCompleted`
/// > 的百分数。需要播报非百分比进度时，改用系统默认 `ProgressView` 语义或自行
/// > 在 `label` 中承载。
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
                        // 百分比已由下方 `.accessibilityValue` 播报；若让 `.combine`
                        // 把这段可视文本（调用方常传 "60%"）也并进元素，VoiceOver
                        // 会连播两遍。可视保留、无障碍隐藏，避免重复。
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            // 本地化百分数（`.percent` 会 ×100 并按 locale 格式化），
            // 而非硬编码 `%` + `Int(...)` 截断（0.999 会显示成 "99%"）。
            .accessibilityValue(Text(fractionCompleted, format: .percent))
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
            // 与确定态分支保持一致：把 label / spinner / currentValueLabel 合成
            // 单个无障碍元素（不确定态无百分比，故不叠加 accessibilityValue）。
            .accessibilityElement(children: .combine)
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
