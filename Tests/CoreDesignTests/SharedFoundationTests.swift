import SwiftUI
import Testing
@testable import CoreDesign

// semi-mobile-components Phase 0（#161）——共享地基预登记项的回归测试。
// 覆盖 Phase 0 预登记的 accessibility 复数键 / 字符串键，以及骨架屏取色 token 的公开可见性。
// 不触碰共享 suite（TouchTargetTests / DynamicTypeLayoutTests）——这些留给 013。
@Suite("Shared Foundation — semi-mobile-components Phase 0")
struct SharedFoundationTests {
    // 直接对 CoreDesign 资源 bundle 做解析验证。
    //
    // 为什么不用 `String(localized:bundle:)`：在 macOS 的 `swift test` 腿上，`String(localized:)`
    // 不会对 SwiftPM 资源 bundle 里的 `.stringsdict` 套用 `one` 复数规则（只在 iOS 腿生效——
    // 属 CLAUDE.md 记载的「macOS swift test 对 iOS 行为假绿」盲区）。而底层
    // `Bundle.localizedString(forKey:value:table:)` + `String(format:)` 在两端都正确解析，
    // 因此用它来验证 Phase 0 的交付物「键已注册且 one/other 内容正确」。组件（Rating/Steps）
    // 在各自 Issue 里通过 `String(localized:)` 消费这些键，其运行时渲染由 iOS Simulator 腿验证。
    static let bundle = Bundle.module

    private func plural(_ key: String, _ n: Int) -> String {
        String(format: Self.bundle.localizedString(forKey: key, value: nil, table: nil), n)
    }

    // MARK: - 复数键（.stringsdict）

    @Test("Rating 星数复数键：one/other 形态正确")
    func ratingStarsPlural() {
        #expect(plural("%lld stars", 1) == "1 star")
        #expect(plural("%lld stars", 3) == "3 stars")
    }

    @Test("Steps 步数复数键：one/other 形态正确")
    func stepsPlural() {
        #expect(plural("%lld steps", 1) == "1 step")
        #expect(plural("%lld steps", 4) == "4 steps")
    }

    // MARK: - 简单字符串键（.strings）

    @Test("Phase 0 预登记的 accessibility 字符串键已注册进资源 bundle")
    func accessibilityLabelKeysResolve() {
        // value: "\u{0}" 作哨兵——键存在时返回登记值，缺失时返回哨兵而非 key 自身，
        // 从而真正验证「键已注册」（而非 fallback 到 key 造成的假通过）。
        let keys = [
            "Rating", "Verification code", "Add tag",   // 组件标签
            "Info", "Success", "Warning", "Error",       // Timeline 节点状态
            "%@ of %@",                                   // 通用位置/数值键
        ]
        for key in keys {
            #expect(Self.bundle.localizedString(forKey: key, value: "\u{0}", table: nil) == key)
        }
    }

    // MARK: - 骨架屏取色 token（可引用性 · 非 colorset 派生）

    @Test("Skeleton 取色 token 可引用且编译可用")
    @MainActor
    func skeletonColorTokensAreUsable() {
        // 注意：`@testable import` 下 internal 符号一样可解析，本测试**只**证明
        // 「token 存在且编译可用」，不构成真正的 public 可见性护栏——后者由
        // `scripts/downstream-probe` 从外部包 `consumeSkeletonColorTokens()` 守。
        let base = Color.skeletonBase
        let highlight = Color.skeletonHighlight
        _ = base
        _ = highlight
        #expect(Bool(true))
    }
}
