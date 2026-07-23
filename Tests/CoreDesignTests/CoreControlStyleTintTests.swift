import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - `.tint` 真实响应的像素级证据（Issue #143 / FR-12 / ADR-3）
//
// 光靠读源码「没有 `Color.accent` 字面量」不足以证明 `.tint` 真的接入了——
// `.foregroundStyle(.tint)` / `.fill(.tint)` 这类写法本身就可能被误用成
// 恒定颜色（例如不小心用了 `ShapeStyle.tint` 之外的固定 token）。这里用
// `ImageRenderer` 把三个 style 的关键着色元素实际渲染成位图，分别在
// `.tint(.red)` 与 `.tint(.blue)` 下取像素平均色，断言两者色相确实不同
// 且分别偏红/偏蓝——直接证据，而不是「看起来应该会生效」的推断。
//
// 与仓库既有的 `AccentDerivationTests` / `SurfaceContrastTests` 不同：那些测的是
// `Color` 值本身（`.resolve(in:)` 不需要渲染），本文件测的是**渲染结果**——因为
// `.tint` 是 `ShapeStyle`，不是 `Color`，没有等价的 `.resolve(in:)` 直接取值路径，
// 只能经渲染管线验证「环境 tint 确实传导到了最终像素」。

private func averageColor(of content: some View, size: CGSize) -> (r: Double, g: Double, b: Double)? {
    let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
    renderer.scale = 1

    guard let cgImage = renderer.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    // 用己方构造的 CGContext 重新绘制一遍，锁定像素格式（8-bit RGBA，
    // premultiplied，big-endian）——不依赖 `cgImage` 原生格式（可能因平台/
    // 版本而异），避免误读字节序导致颜色断言假阳性/假阴性。
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var totalR = 0.0, totalG = 0.0, totalB = 0.0
    var count = 0.0
    for index in stride(from: 0, to: pixels.count, by: 4) {
        let alpha = pixels[index + 3]
        guard alpha > 0 else { continue } // 跳过完全透明像素（背景/间隙）
        totalR += Double(pixels[index])
        totalG += Double(pixels[index + 1])
        totalB += Double(pixels[index + 2])
        count += 1
    }
    guard count > 0 else { return nil }
    return (totalR / count, totalG / count, totalB / count)
}

@Suite("`.tint` 真实响应（像素级）")
@MainActor
struct CoreControlStyleTintTests {
    @Test("CoreProgressViewStyle 的填充条随 .tint 变色，而非恒取 accent")
    func progressViewStyleRespondsToTint() throws {
        let redBar = ProgressView(value: 1.0)
            .progressViewStyle(.core)
            .tint(.red)
        let blueBar = ProgressView(value: 1.0)
            .progressViewStyle(.core)
            .tint(.blue)

        let redAvg = try #require(averageColor(of: redBar, size: CGSize(width: 80, height: 16)), "渲染失败——无法取得 cgImage")
        let blueAvg = try #require(averageColor(of: blueBar, size: CGSize(width: 80, height: 16)), "渲染失败——无法取得 cgImage")

        #expect(redAvg.r > redAvg.b, ".tint(.red) 下填充条红通道应显著高于蓝通道，实测 r=\(redAvg.r) b=\(redAvg.b)")
        #expect(blueAvg.b > blueAvg.r, ".tint(.blue) 下填充条蓝通道应显著高于红通道，实测 r=\(blueAvg.r) b=\(blueAvg.b)")
    }

    @Test("CoreLabelStyle 的 icon 随 .tint 变色，而非恒取 accent")
    func labelStyleRespondsToTint() throws {
        let redLabel = Label("", systemImage: "star.fill")
            .labelStyle(.core)
            .tint(.red)
        let blueLabel = Label("", systemImage: "star.fill")
            .labelStyle(.core)
            .tint(.blue)

        let redAvg = try #require(averageColor(of: redLabel, size: CGSize(width: 40, height: 40)), "渲染失败——无法取得 cgImage")
        let blueAvg = try #require(averageColor(of: blueLabel, size: CGSize(width: 40, height: 40)), "渲染失败——无法取得 cgImage")

        #expect(redAvg.r > redAvg.b, ".tint(.red) 下 icon 红通道应显著高于蓝通道，实测 r=\(redAvg.r) b=\(redAvg.b)")
        #expect(blueAvg.b > blueAvg.r, ".tint(.blue) 下 icon 蓝通道应显著高于红通道，实测 r=\(blueAvg.r) b=\(blueAvg.b)")
    }

    @Test("CoreDisclosureGroupStyle 的 chevron 随 .tint 变色，而非恒取 accent")
    func disclosureGroupStyleRespondsToTint() throws {
        let redGroup = DisclosureGroup(isExpanded: .constant(false)) {
            Text("content")
        } label: {
            Text("")
        }
        .disclosureGroupStyle(.core)
        .tint(.red)

        let blueGroup = DisclosureGroup(isExpanded: .constant(false)) {
            Text("content")
        } label: {
            Text("")
        }
        .disclosureGroupStyle(.core)
        .tint(.blue)

        let redAvg = try #require(averageColor(of: redGroup, size: CGSize(width: 40, height: 24)), "渲染失败——无法取得 cgImage")
        let blueAvg = try #require(averageColor(of: blueGroup, size: CGSize(width: 40, height: 24)), "渲染失败——无法取得 cgImage")

        #expect(redAvg.r > redAvg.b, ".tint(.red) 下 chevron 红通道应显著高于蓝通道，实测 r=\(redAvg.r) b=\(redAvg.b)")
        #expect(blueAvg.b > blueAvg.r, ".tint(.blue) 下 chevron 蓝通道应显著高于红通道，实测 r=\(blueAvg.r) b=\(blueAvg.b)")
    }
}
