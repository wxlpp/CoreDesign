//
//  ProgressIndicator.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressIndicator

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 通用圆形加载指示器。
///
/// 实用可读性优先于装饰：**无玻璃、无装饰性材质**。用于页内加载态；
/// 需要浮层反馈请改用 `ToastHost`；需要为任意内容整体叠加加载遮罩请改用
/// `View.spinning(_:text:)`（`Modifier/SpinningModifier.swift`）。
///
/// 封装系统 `ProgressView`，使用 `Color.accent` 作为 tint，自动响应
/// `@Environment(\.controlSize)` 调整尺寸。可选传入文案，渲染于 spinner 下方
/// （Issue #172）。
///
/// ```swift
/// ProgressIndicator()                    // 无文案
/// ProgressIndicator(text: "Loading…")    // 带静态文案
/// ProgressIndicator(text: statusString)  // 带运行期字符串文案
/// ```
public struct ProgressIndicator: View {
    // 不标 `private`——`Tests/CoreDesignTests/ProgressIndicatorTests.swift` 经
    // `@testable import` 断言文案存储正确性（AC「新 init 的文案存储正确性」）。
    let text: Text?

    /// 原有形态：无文案，签名不变（NFR-6 无破坏）。
    public init() {
        self.text = nil
    }

    /// 静态文案——字面量在 `Bundle.main` 本地化（对 App 调用方即其自身 bundle），
    /// 渲染于 spinner 下方。
    public init(text: LocalizedStringKey) {
        self.text = Text(text)
    }

    /// 运行期字符串文案（数据来的进度说明等），verbatim 显示、不走本地化查表。
    /// `@_disfavoredOverload` 避免与 `LocalizedStringKey` 重载产生调用方歧义，
    /// 参照 `InsetGroupedSection` 的 `header`/`footer` 双 init 模式。
    @_disfavoredOverload
    public init<S: StringProtocol>(text: S) {
        self.text = Text(text)
    }

    @Environment(\.controlSize) private var controlSize

    public var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                // FR-3a 例外（Issue #172，唯一例外，见 172.md Technical Details）：
                // 显式 `Color.accent`——避免在 `tint(_:)` 多个 ShapeStyle 重载之间
                // 解析到 SwiftUI 自带的环境 accent，而不是 CoreDesign 的 `Color.accent`。
                // SC-5「无字面 Color.accent」的静态核对对本文件豁免；新增 init
                // 重载延续这一写法，不改为 `.tint` 环境取色。
                .tint(Color.accent)
                .controlSize(self.controlSize)
                .accessibilityLabel(Text("Loading", bundle: .module))

            if let text = self.text {
                text
                    .coreFont(.footnote)
                    .foregroundStyle(Color.contentSecondary)
                    // VoiceOver 语义复用上方 ProgressView 既有的 "Loading" label
                    // （不重复定义）——这段可视文案只是补充说明，隐藏避免双重播报，
                    // 与 `CoreProgressViewStyle.currentValueLabel` 同款处理。
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview("ProgressIndicator — Light") {
    ProgressIndicatorPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("ProgressIndicator — Dark") {
    ProgressIndicatorPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct ProgressIndicatorPreviewGallery: View {
    var body: some View {
        VStack(spacing: CoreSpacing.xl) {
            VStack(spacing: CoreSpacing.lg) {
                ProgressIndicator()
                    .controlSize(.small)
                ProgressIndicator()
                    .controlSize(.regular)
                ProgressIndicator()
                    .controlSize(.large)
            }
            ProgressIndicator(text: "Loading…")
                .controlSize(.large)
        }
        .padding()
        .background(Color.surfaceCanvas)
    }
}
