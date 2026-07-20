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

// MARK: - Shared helpers

/// 统一书名兜底逻辑 / Unified title fallback.
///
/// `BookCover` 与 `BookCoverPlaceholder` 共用同一份 a11y label 兜底语义：
/// 空标题朗读为 "未命名"。集中在此避免双处分叉。
private func bookCoverDisplayTitle(_ title: String) -> String {
    title.isEmpty ? "未命名" : title
}

// MARK: - BookCover

/// Native Primer book cover.
///
/// Content visual. Image-first presentation with a restrained border and a
/// small shadow — explicitly **not** glass. Aspect ratio and corner radius
/// match a print-cover read; the component stays a quiet object inside
/// content rows / grids.
///
/// **Material layer**: content. **Surface role**: content.
///
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
/// - 边框颜色走 `Color.borderMuted`（基于 `.separator.opacity(0.42)`），随系统外观自适应。
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
            if let image = self.decodedImage {
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
        .accessibilityLabel(Text(bookCoverDisplayTitle(self.title)))
        .accessibilityAddTraits(.isImage)
    }

    private let data: Data?
    private let title: String

    /// 解码后的封面图 / Decoded cover image（审计项 B9a）。
    ///
    /// 走**进程级缓存查表**而非 `@State` + `.task`：后者在首帧之后才执行，会让每个
    /// cell 先闪一下占位彩块、且 `data` 切换时有一个 runloop 渲染上一本书的封面。
    /// 缓存查表是同步的——首帧就有正确的图，重复解码也照样被消除（真正的目标）。
    private var decodedImage: Image? {
        guard let data = self.data else { return nil }
        return BookCoverImageCache.image(for: data)
    }

    fileprivate static func decode(_ data: Data) -> Image? {
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
        let displayTitle = bookCoverDisplayTitle(self.title)
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
        .accessibilityLabel(Text(displayTitle))
    }

    private let title: String
}

// MARK: - BookCoverRenderer

@MainActor
public enum BookCoverRenderer {
    public static func generatePlaceholderData(
        title: String,
        width: CGFloat = 320,
        displayScale: CGFloat = 2
    ) -> Data? {
        let size = CGSize(width: width, height: width / BookCover.aspectRatio)
        let content = BookCoverPlaceholder(title: title)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        #if canImport(UIKit)
            renderer.scale = displayScale
            return renderer.uiImage?.pngData()
        #elseif canImport(AppKit)
            renderer.scale = displayScale
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

// MARK: - BookCoverImageCache（审计项 B9a）

/// 封面解码的进程级缓存 / Process-wide cover decode cache.
///
/// `BookCover.body` 原先每次求值都调 `UIImage(data:)`，列表滚动时对整张封面反复解码
/// （审计项 B9a）。改法有两条路：
///
/// 1. `@State` + `.task(id: data)` —— **不用**。`.task` 在首帧**之后**才执行，于是每个
///    cell 都要先闪一下占位彩块；且 `data` 切换时 state 仍持有旧图，会有一个 runloop
///    渲染上一本书的封面配新书的 a11y label。用「优化滚动」的名义换来滚动时闪烁，方向反了。
/// 2. **同步缓存查表**（本实现）—— 首帧即命中，重复解码同样被消除。
///
/// 用 `NSCache` 而非字典：内存压力下自动清理（尽力而为，非硬上限），配合
/// `totalCostLimit` 给一个字节预算，避免长列表把解码结果堆到 OOM。
///
/// > **key 不能只用 `data.hashValue`**：`Foundation.Data.hash(into:)` 只哈希 `count`
/// > 加**前 80 字节**，不遍历全部字节。两张字节数相同、前 80 字节相同的封面
/// > （同一编码管线的 JPEG 头部 + DQT 表往往逐字节相同）会命中同一 key，永久返回
/// > 错图。故命中后**必须用完整 `Data` 复核**（`Data.==` 先比 `count` 再 memcmp，
/// > 只对同尺寸候选跑，成本远低于一次解码）。
enum BookCoverImageCache {
    private static let cache: NSCache<NSNumber, Entry> = {
        let cache = NSCache<NSNumber, Entry>()
        cache.countLimit = 64
        // 约 64MB 字节预算：`cost` 用源 `Data` 的字节数近似（解码后的位图更大，
        // 但源字节数与之单调相关，够做逐出排序）。
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    /// `NSCache` 只接受 class 类型。同时存源 `Data`（命中复核）与解码结果
    /// （`nil` = 解码失败，也缓存下来避免对坏数据反复解码——I2）。
    private final class Entry {
        let data: Data
        let image: Image?
        init(data: Data, image: Image?) {
            self.data = data
            self.image = image
        }
    }

    /// 真解码次数 / Number of actual decode calls（测试探针，直接量化 B9a
    /// 「不重复解码」：命中缓存不应递增它）。
    static private(set) var decodeCount = 0

    /// 清空缓存与计数 / Reset — 仅供测试隔离。
    static func reset() {
        self.cache.removeAllObjects()
        self.decodeCount = 0
    }

    /// 解析封面图 / Resolve the cover image，带同步缓存。
    ///
    /// `@MainActor`：唯一调用点是 `BookCover.body`（MainActor），且 AppKit 的
    /// `NSImage(data:)` 未文档化为线程安全——钉在主 actor 上消除歧义。
    @MainActor
    static func image(for data: Data) -> Image? {
        let key = NSNumber(value: data.hashValue)
        if let entry = self.cache.object(forKey: key), entry.data == data {
            return entry.image   // 命中且字节完全一致——包括缓存过的解码失败（image == nil）
        }
        // 未命中，或哈希碰撞（同 key 不同字节）：解码并覆盖。
        self.decodeCount += 1
        let decoded = BookCover.decode(data)
        self.cache.setObject(Entry(data: data, image: decoded), forKey: key, cost: data.count)
        return decoded
    }
}
