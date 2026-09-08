import SwiftUI
import Testing
@testable import OhMyDesign

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - `Color.maskOpaque` 的 α = 1 契约（Issue #276）

@Suite("Color.maskOpaque 的 α = 1 契约")
@MainActor
struct MaskOpaqueTokenTests {
    static let schemes: [(name: String, scheme: ColorScheme)] = [("light", .light), ("dark", .dark)]

    static func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var env = EnvironmentValues()
        env.colorScheme = scheme
        return env
    }

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

    @Test("mask 只吃 alpha：黑遮罩与白遮罩逐字节相同")
    func maskIgnoresTheRGBChannel() {
        let byWhite = Self.rgbaPixels(Self.subject(masked: .white))
        let byBlack = Self.rgbaPixels(Self.subject(masked: .black))
        let bare = Self.rgbaPixels(Self.subject(masked: nil))
        expectBitmapsEqual(bare, byWhite, "白遮罩不是 no-op —— 下面的相等断言会失去意义")
        expectBitmapsEqual(byWhite, byBlack, """
        黑遮罩与白遮罩渲出了**不同**的图 —— 那意味着 `.mask` 读了 RGB。
        `MaskColors.swift` 的整段论证（"遮罩基色唯一承重的性质是 α = 1，
        写白还是写黑没有可观测差别"）建立在本条之上，需要一并重估。
        """)
    }
}
