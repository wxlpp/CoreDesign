import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - `.tint` 真实响应的像素级证据（Issue #143 / FR-12 / ADR-3）

private func averageColor(of content: some View, size: CGSize) -> (r: Double, g: Double, b: Double)? {
    let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
    renderer.scale = 1

    guard let cgImage = renderer.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

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
        guard alpha > 0 else { continue }
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
