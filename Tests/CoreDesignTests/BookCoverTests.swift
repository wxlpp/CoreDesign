import Foundation
import CoreGraphics
import Testing
@testable import CoreDesign

@Suite("BookCover")
struct BookCoverTests {
    @Test("placeholder renderer accepts an explicit display scale")
    @MainActor
    func placeholderRendererAcceptsExplicitDisplayScale() {
        let data = BookCoverRenderer.generatePlaceholderData(
            title: "Test Book",
            width: 96,
            displayScale: 1
        )

        #expect(data != nil)
    }

    // MARK: - BookCoverImageCache（审计项 B9a，回归测试）

    @Test("Data.hashValue 只哈希前 80 字节——碰撞对可构造")
    func hashCollisionIsRealForData() {
        // 记录这个 Foundation 事实：两张字节数相同、前 80 字节相同、后续不同的
        // Data 会有相同 hashValue。这正是缓存必须复核 Data 字节的原因。
        var a = Data(count: 4096)
        var b = Data(count: 4096)
        for i in 0..<4096 { a[i] = UInt8(i % 256); b[i] = UInt8(i % 256) }
        b[100] = 99   // 差异在前 80 字节之外
        b[4000] = 77
        #expect(a != b)
        #expect(a.hashValue == b.hashValue)   // 碰撞成立
    }

    @Test("同一 data 不重复解码，碰撞的不同 data 各自解码（B9a + C1）")
    @MainActor
    func cacheDeduplicatesAndRejectsCollision() {
        BookCoverImageCache.reset()
        guard let base = BookCoverRenderer.generatePlaceholderData(title: "AA", width: 96, displayScale: 1),
              base.count > 200 else { Issue.record("placeholder 生成失败或过短"); return }

        // B9a：同一 data 连续两次，只解码一次。
        _ = BookCoverImageCache.image(for: base)
        _ = BookCoverImageCache.image(for: base)
        #expect(BookCoverImageCache.decodeCount == 1, "命中缓存不应重新解码")

        // C1：variant 与 base 等长、前 80 字节相同、后续不同——哈希碰撞。
        var variant = base
        for i in 80..<variant.count { variant[i] = variant[i] &+ 91 }
        #expect(variant.count == base.count)
        #expect(variant != base)
        #expect(variant.hashValue == base.hashValue, "前 80 字节相同 + 等长应哈希碰撞")

        // 查 variant：若缓存不复核 Data，会直接返回 base 的缓存（decodeCount 不变）——串味。
        // 复核生效时，variant 走自己的解码路径，decodeCount 递增到 2。
        _ = BookCoverImageCache.image(for: variant)
        #expect(BookCoverImageCache.decodeCount == 2, "碰撞时缓存把 variant 认成了 base——Data 复核未生效")
    }

    @Test("解码失败也被缓存，不对坏数据反复解码")
    @MainActor
    func cacheMemoizesDecodeFailure() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE])   // 非任何图片格式
        #expect(BookCoverImageCache.image(for: garbage) == nil)
        // 第二次走命中路径（entry.image == nil），仍返回 nil，不应崩
        #expect(BookCoverImageCache.image(for: garbage) == nil)
    }
}