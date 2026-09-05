import SwiftUI
import Testing
@testable import CoreDesign

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - `Color.maskOpaque` 的 α = 1 契约（Issue #276）
//
// ## 它治什么
//
// `.mask { … }` 读的是遮罩内容的 **alpha 通道**。所以「拿一个色填出形状再遮上去」
// 这一族写法里，遮罩基色**唯一**承重的性质就是 `α = 1`——差一点，被遮的内容就整体
// 变淡一档，而且**不会报错、只会难看**。
//
// Issue #276 的实质损害正是这个：Effects 层四处遮罩全用 `Color.primary` 当基色，
// 注释宣称「`.primary` 恒为不透明 ⇒ 与写死 `.white` 等效，但它是语义色」。
//
// ⚠️⚠️ **`.primary` 的 α 是平台相关的，#276 正文没写这一条，本轮 iOS 腿实测出来的**：
//
//     平台                        light      dark
//     macOS 26 / AppKit labelColor 0.8471     0.8471
//     iOS 26 / UIKit  label        1.0000     1.0000
//
// ⇒ 那条注释在 **iOS 上恰好成立、在 macOS 上是错的**，而它写的是无条件形式
//（"恒为不透明"）。实际后果因此**只在 macOS 腿上可观测**：每处遮罩额外乘 0.847。
// ⚠️ **这不改变"必须修"的结论**——依赖一个未文档化、平台相关的 α 本身就是缺陷，
// 而 `CoreDesign` 是双平台库（`Package.swift` 同列 iOS 26 / macOS 26）；
// 但它确实改写了严重性描述：#276 说的「已发布组件里可见的 ghosting」在 iOS 上不成立。
//
// 既有的位图判据全是「a != b」/「!= blank」形态，**一条都抓不到**这枚偏差。
//
// ## 判据形态：性质，不是文本匹配
//
// ⚠️ 本文件**有意不去 grep `.primary`**：那样钉的是"上一版长什么样"，
// 而下一个人换成 `.contentPrimary`（同样映射到 `label`、macOS 上同样 0.8471）照样全绿。
// 这里钉的是**性质**——
//
// 1. `maskOpaqueIsFullyOpaqueInBothSchemes`：token 解析出来的 α 必须**恰好是 1**；
// 2. `fullMaskWithTheTokenIsAByteIdenticalNoOp`：拿它做**满遮罩**必须与"根本不遮"
//    **逐字节相同**——这是 α = 1 在渲染栈上的完整可观测形式，
//    而且同一条用例里带着一个**显式半透明**基色的反向对照（必须判不同），
//    ⇒ 它不可能因为"渲染塌成空图"这类退化而恒真。
//    ⚠️ 反向对照有意**不用 `.primary`**：它在 iOS 上 α = 1，拿它当对照会让本条
//    在 iOS 腿上因错误的原因判红——本轮实测就是这么发现平台差异的；
// 3. `maskIgnoresTheRGBChannel`：黑遮罩与白遮罩逐字节相同 ⇒ **RGB 通道不参与合成**
//    ——这一条是把「但它是语义色」那半句理由证伪的直接证据：语义色的价值在 RGB
//    随外观走，而 mask 根本不读 RGB。
//
// ⚠️ **本文件不覆盖"新加的遮罩点位有没有用对基色"**——那是
// `MaskSiteRegistryGuard`（点位台账，fail-closed）与各组件自己的量程判据
// （`AnimatedMeshGradientAlphaRangeTests.tintAlphaMaskSpansItsDeclaredRange` /
// `ProcessingSweepTests.maskStopsAreFullyOpaqueAtTheirPeak` /
// `BeforeAfterSliderTests.endpointRenderIsIndependentOfTheHiddenLayer`）的职责。
@Suite("Color.maskOpaque 的 α = 1 契约")
@MainActor
struct MaskOpaqueTokenTests {

    static let schemes: [(name: String, scheme: ColorScheme)] = [("light", .light), ("dark", .dark)]

    static func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var env = EnvironmentValues()
        env.colorScheme = scheme
        return env
    }

    /// 渲染成**解码后的 RGBA8 缓冲**（不是 PNG / TIFF 字节）。
    ///
    /// ⚠️ 走 `cgImage` + 自建 `CGContext` 而不是 `pngData()` / `tiffRepresentation`：
    /// 后两者会把色彩配置与压缩元数据一起带进比较，`SidebarLeadingSlotRenderTests`
    /// 的 `pixels(_:)` 文档已就同一件事记过账（"正确修法是比较解码后的像素缓冲"）。
    static func rgbaPixels(_ view: some View, side: CGFloat = 24) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: side, height: side))
        renderer.scale = 1
        guard let cg = renderer.cgImage, cg.width > 0, cg.height > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let context = buffer.withUnsafeMutableBytes { raw -> CGContext? in
            CGContext(
                data: raw.baseAddress,
                width: cg.width,
                height: cg.height,
                bitsPerComponent: 8,
                bytesPerRow: cg.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        guard let context else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return Data(buffer)
    }

    /// 被遮的内容。**用 `Color.accent`**（宿主 App 的强调色，实测 α = 1）：
    /// ⚠️ 有意**不用** `ColorGrade` 资源色——它们在 macOS `swift test` 下可能解析为
    /// 透明（#275），那会让下面每一条相等断言在"两张空图"上恒真。
    static func subject(masked: Color?) -> some View {
        let base = Rectangle().fill(Color.accent)
        return ZStack {
            Color.surfaceCanvas
            if let masked {
                base.mask { masked }
            } else {
                base
            }
        }
    }

    // MARK: - 1. token 自身的契约

    @Test("Color.maskOpaque 在明暗两端都恰好 α = 1")
    func maskOpaqueIsFullyOpaqueInBothSchemes() {
        for (name, scheme) in Self.schemes {
            let resolved = Color.maskOpaque.resolve(in: Self.environment(scheme))
            #expect(resolved.opacity == 1, """
            \(name)：`Color.maskOpaque` 解析出 α = \(resolved.opacity)，不是 1。
            本 token 的**唯一**契约就是"满不透明"——它存在的理由是给 `.mask { … }`
            当基色，而 `mask` 吃的正是 alpha。α < 1 ⇒ 每一处用它的遮罩都整体变淡，
            且渲染上不会报错（Issue #276 的原始形态就是这样溜过去的）。
            """)
        }
    }

    /// ⚠️⚠️ **本条是上一条的"探测器非真空"证据，不是在给 Apple 立规矩**。
    ///
    /// 上一条断言的是"某个 `Color` 解析出来 α == 1"。如果 `resolve(in:).opacity`
    /// 在本平台上恒返回 1（或渲染栈把一切都当不透明），它就是一条恒真判据。
    /// ⇒ 这里拿一个**显式半透明**的色当反例：`Color.maskOpaque.opacity(0.5)`
    /// 必须解析成 0.5。两条一起才说明"α 这个量在这里真的可分辨"。
    ///
    /// ⚠️ **有意不用 `Color.primary` 当反例**（本轮 iOS 腿实测出来的教训）：
    /// 它的 α 是**平台相关**的——macOS/AppKit 0.8471、iOS/UIKit **1.0**
    /// ⇒ 拿它当反例，本条会在 iOS 腿上因错误的原因判红。
    /// `.primary` 的平台差异改由下一条**如实登记**，不参与非真空论证。
    @Test("非真空：显式半透明色必须解析成 α = 0.5（α 这个量在本平台可分辨）")
    func theAlphaProbeIsNotVacuous() {
        for (name, scheme) in Self.schemes {
            let resolved = Color.maskOpaque.opacity(0.5).resolve(in: Self.environment(scheme))
            #expect(abs(Double(resolved.opacity) - 0.5) < 0.005, """
            \(name)：`Color.maskOpaque.opacity(0.5)` 解析出 α = \(resolved.opacity)，不是 0.5。
            ⇒ 本平台上 `resolve(in:).opacity` 分辨不出半透明，
            `maskOpaqueIsFullyOpaqueInBothSchemes` 因此是一条恒真判据，不得当作通过。
            """)
        }
    }

    /// ⚠️⚠️ **如实登记：`Color.primary` 的 α 是平台相关的**（#276 正文没写这一条，
    /// 本轮 iOS 腿实测出来的）。
    ///
    ///     平台                         light      dark
    ///     macOS 26 / AppKit labelColor  0.8471     0.8471
    ///     iOS 26 / UIKit  label         1.0000     1.0000
    ///
    /// ⇒ 那条被复制了五份的注释（「`.primary` 恒为不透明 ⇒ 与写死 `.white` 等效」）
    /// **在 iOS 上恰好成立、在 macOS 上是错的**，而它写的是无条件形式。
    /// #276 描述的「已发布组件里可见的 ghosting」因此**只在 macOS 腿上成立**。
    ///
    /// ⚠️ **这不改变"必须修"的结论**：依赖一个未文档化、平台相关的 α 本身就是缺陷，
    /// 而 `CoreDesign` 是双平台库（`Package.swift` 同列 iOS 26 / macOS 26）。
    /// ⚠️ 本条哪天判红**不一定是回归**——它钉的是外部平台行为。真判红时请连同
    /// `Sources/CoreDesign/Colors/MaskColors.swift` 的整段账一起重估，而不是顺手放宽。
    @Test("登记：Color.primary 的 α 是平台相关的（macOS 0.8471 / iOS 1.0）")
    func primaryAlphaIsPlatformDependent() {
        #if canImport(UIKit)
        let expected = 1.0
        let platform = "iOS / UIKit label"
        #else
        let expected = 0.8471
        let platform = "macOS / AppKit labelColor"
        #endif
        for (name, scheme) in Self.schemes {
            let alpha = Double(Color.primary.resolve(in: Self.environment(scheme)).opacity)
            #expect(abs(alpha - expected) < 0.001, """
            \(platform) \(name)：`Color.primary` 的 α 是 \(alpha)，登记值是 \(expected)。
            #276 的整段记账建立在这个数上 —— 平台行为变了就要重写记账，不要改判据了事。
            """)
        }
    }

    // MARK: - 2. α = 1 在渲染栈上的完整可观测形式

    /// ⚠️⚠️ **承重**：满遮罩必须是 **no-op**。
    ///
    /// 「α = 1」在 `resolve(in:)` 上是一个数，在渲染栈上就是这一条：
    /// `X.mask { 满不透明色 }` 与 `X` 逐字节相同。
    /// 同一条用例里带着一个**显式半透明**基色的反向对照——它必须判**不同**
    /// ⇒ 本条不可能因为"两侧都渲成空图"而恒真。
    ///
    /// ⚠️ 反向对照**不用 `.primary`**：它在 iOS 上 α = 1（见
    /// `primaryAlphaIsPlatformDependent`），本轮 iOS 腿上正是这一条因此判红过。
    @Test("满遮罩是 no-op：mask(.maskOpaque) 与不遮逐字节相同，半透明遮罩必须不同")
    func fullMaskWithTheTokenIsAByteIdenticalNoOp() {
        let bare = Self.rgbaPixels(Self.subject(masked: nil))
        let byToken = Self.rgbaPixels(Self.subject(masked: .maskOpaque))
        let byTranslucent = Self.rgbaPixels(Self.subject(masked: Color.maskOpaque.opacity(0.5)))

        expectBitmapsEqual(bare, byToken, """
        `X.mask { Color.maskOpaque }` 与不加遮罩渲出了**不同**的图 ——
        满不透明的遮罩本该是 no-op。差异只可能来自遮罩基色的 α < 1。
        """)
        expectBitmapsDiffer(bare, byTranslucent, """
        `X.mask { α = 0.5 }` 与不加遮罩渲成了**同一张**图 —— 这说明上面那条
        相等断言此刻分辨不出 α 的差别（渲染塌缩），它因此是恒真的，不得当作通过。
        """)
    }

    /// ⚠️ 把「但它是语义色」那半句理由**证伪**：`mask` 不读 RGB。
    ///
    /// 两个 α 都 = 1 但 RGB 相反的色（黑 / 白）当遮罩，结果必须逐字节相同。
    /// ⇒ 语义色"RGB 随外观走"的那份好处，在遮罩位置上**落在一个不参与合成的通道里**。
    /// 这就是 #276 里"结论错、理由也空"的那一半。
    @Test("mask 只吃 alpha：黑遮罩与白遮罩逐字节相同")
    func maskIgnoresTheRGBChannel() {
        let byWhite = Self.rgbaPixels(Self.subject(masked: .white))
        let byBlack = Self.rgbaPixels(Self.subject(masked: .black))
        let bare = Self.rgbaPixels(Self.subject(masked: nil))
        // 非退化前置：两张都不是空图（与"不遮"相同即证明确实画出了东西）。
        expectBitmapsEqual(bare, byWhite, "白遮罩不是 no-op —— 下面的相等断言会失去意义")
        expectBitmapsEqual(byWhite, byBlack, """
        黑遮罩与白遮罩渲出了**不同**的图 —— 那意味着 `.mask` 读了 RGB。
        `MaskColors.swift` 的整段论证（"遮罩基色唯一承重的性质是 α = 1，
        写白还是写黑没有可观测差别"）建立在本条之上，需要一并重估。
        """)
    }
}
