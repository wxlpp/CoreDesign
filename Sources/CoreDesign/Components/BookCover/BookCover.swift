//
//  BookCover.swift
//  CoreDesign
//
//  Created by AnyWriter on 2026/4/14.
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

// MARK: - BookCover

/// 书籍封面容器视图 / Book cover container.
///
/// **使用场景**：在书架、阅读列表、推荐位等需要展示一本书可视外观的位置；
/// 当 `data` 为有效图片字节时渲染图片，否则降级到 `BookCoverPlaceholder`
/// 自动生成一张带书名的封面替身。
///
/// **关键参数**：
/// - `data`：封面图原始字节（PNG / JPEG 等 `UIImage` / `NSImage` 可解析格式）；
///   `nil` 或解码失败时走 placeholder 分支。
/// - `title`：书名；同时作为 placeholder 的文字内容与算法生成色的种子。
///
/// **Primer 对应**：Primer 库无对应"书籍封面"概念，本组件是 CoreDesign 自有抽象，
/// 复用 v2 容器 token（`CoreRadius.medium` 圆角 + `CoreBorderWidth.hairline` 边框 +
/// 通过 `.coreShadow(.medium)` (CoreElevation.Level.medium) 提供阴影）落地视觉。
///
/// **Light / Dark 行为**：
/// - 边框颜色走 `Color.borderMuted`（基于 `.separator.opacity(0.5)`），随系统外观自适应。
/// - 阴影走 `.coreShadow(.medium)`，由 shadow-medium colorset
///   提供 light / dark 双取值，dark 模式下浓度自动加深以补偿 elevation 视觉。
///
/// **比例约束**：`aspectRatio = 2.0 / 3.0` 是书籍封面行业标准比例，不可配置。
public struct BookCover: View {
    public init(data: Data?, title: String) {
        self.data = data
        self.title = title
    }

    /// 书籍封面行业标准宽高比（2:3）。非 magic number——这是行业约定的比例，
    /// 与 Amazon / Goodreads / 各大电子书店一致。
    public static let aspectRatio: CGFloat = 2.0 / 3.0

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
        // strokeBorder 内描边（路径在形状内部），避免 stroke 居中描边的外侧一半被
        // 后续 clipShape 裁掉导致 hairline 半像素丢失/模糊。clipShape 必须在 overlay
        // 之后，与 SurfaceModifier 模式保持一致。
        return Group {
            if let data, let image = Self.image(from: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                BookCoverPlaceholder(title: self.title)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .overlay(shape.strokeBorder(Color.borderMuted, lineWidth: CoreBorderWidth.hairline))
        .clipShape(shape)
        .coreShadow(.medium)
        // a11y: 让 VoiceOver 朗读书名而非默认 unlabeled 容器；isImage trait 反映"封面是一张图"语义。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(self.title))
        .accessibilityAddTraits(.isImage)
    }

    private let data: Data?
    private let title: String

    private static func image(from data: Data) -> Image? {
        #if canImport(UIKit)
            if let ui = UIImage(data: data) {
                return Image(uiImage: ui)
            }
        #elseif canImport(AppKit)
            if let ns = NSImage(data: data) {
                return Image(nsImage: ns)
            }
        #endif
        return nil
    }
}

// MARK: - BookCoverPlaceholder

/// 书籍封面占位视图 / Book cover placeholder.
///
/// **使用场景**：`BookCover` 在拿不到有效封面图片时的降级渲染；也可独立用于
/// 书籍数据尚未加载完成的骨架屏 / 占位场景。
///
/// **关键参数**：
/// - `title`：书名；空字符串时显示 "未命名"。书名同时是渐变背景色的算法种子
///   （见 `Color(text:)` 在 `Utils/ColorExtension.swift`）——同一书名总是得到
///   同一颜色，跨设备 / 跨会话保持一致。
///
/// **Primer 对应**：无；占位封面的 "彩色块 + 居中标题" 视觉为本仓自有约定。
///
/// **Light / Dark 行为**：
/// - 占位背景从一组固定色 (.red/.green/.blue/...) 中根据文字哈希取色。
/// - 文字固定使用 `Color.contentOnEmphasis`（白色）——彩色饱和背景上的对比文本，
///   语义对齐 Primer `fgColor.onEmphasis`。
///
/// **比例约束**：与 `BookCover.aspectRatio` 共用 2:3 比例，独立使用时同样保持。
///
/// **几何缩放**：字号 / 水平 padding 与 `proxy.size.width` 成比例（13% / 12%），
/// 这是响应式视觉缩放逻辑，不是 magic number。字号下限走 `CoreSpacing.md` (12pt) 作为
/// 极小尺寸下的可读性兜底。
public struct BookCoverPlaceholder: View {
    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        let displayTitle = self.title.isEmpty ? "未命名" : self.title
        GeometryReader { proxy in
            let base = Color(text: displayTitle)
            ZStack {
                LinearGradient(
                    colors: [base, base.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack {
                    Spacer(minLength: CoreSpacing.none)
                    // MARK: - Typography metrics (借用 spacing token)
                    // 暂借 CoreSpacing tokens 作为字号下限与 lineSpacing 数值；本 epic 不新增 token (ADR #8)。
                    // 后续 epic 引入 CoreTypography.{minFontSize,lineSpacing} CGFloats 后替换。
                    Text(displayTitle)
                        .font(.system(size: max(proxy.size.width * 0.13, CoreSpacing.md), weight: .bold))
                        .foregroundStyle(Color.contentOnEmphasis)
                        .multilineTextAlignment(.center)
                        .lineSpacing(CoreSpacing.xxs)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, proxy.size.width * 0.12)
                    Spacer(minLength: CoreSpacing.none)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(BookCover.aspectRatio, contentMode: .fit)
        // a11y: 占位封面是文本视觉，朗读标题即可；不加 isImage trait（占位本质是 text-based 渲染）。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(self.title.isEmpty ? "未命名" : self.title))
    }

    private let title: String
}

// MARK: - BookCoverRenderer

@MainActor
public enum BookCoverRenderer {
    public static func generatePlaceholderData(title: String, width: CGFloat = 320) -> Data? {
        let size = CGSize(width: width, height: width / BookCover.aspectRatio)
        let content = BookCoverPlaceholder(title: title)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        #if canImport(UIKit)
            return renderer.uiImage?.pngData()
        #elseif canImport(AppKit)
            guard let cg = renderer.cgImage else {
                return nil
            }
            let rep = NSBitmapImageRep(cgImage: cg)
            return rep.representation(using: .png, properties: [:])
        #else
            return nil
        #endif
    }
}

#Preview {
    HStack(spacing: 16) {
        BookCover(data: nil, title: "万历十五年")
            .frame(width: 120)
        BookCover(data: nil, title: "A Short Title")
            .frame(width: 120)
        BookCover(data: nil, title: "三体：黑暗森林")
            .frame(width: 120)
    }
    .padding()
}
