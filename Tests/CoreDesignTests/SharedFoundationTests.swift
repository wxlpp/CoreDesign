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

    @Test("AvatarGroup 总数复数键：one/other 形态正确")
    func avatarGroupTotalPlural() {
        // ⚠️ `.countOnly`（`#60`）消费的键。**必须在这里断言**，不能在 `AvatarGroupTests`
        // 里用 `String(localized:)` 自比自 —— 那样左右两边走同一条 fallback，键注册与否
        // 结果一样绿（PR #206 第 2 轮 review 抓到的恒真测试）。本 suite 走
        // `Bundle.localizedString`，才真正区分「已注册」与「fallback」，见文件头注释。
        #expect(plural("%lld avatars", 1) == "1 avatar")
        #expect(plural("%lld avatars", 5) == "5 avatars")
    }

    @Test("Steps 步数复数键：one/other 形态正确")
    func stepsPlural() {
        #expect(plural("%lld steps", 1) == "1 step")
        #expect(plural("%lld steps", 4) == "4 steps")
    }

    // MARK: - 简单字符串键（.strings）

    @Test("Phase 0 预登记的 accessibility 字符串键已注册进资源 bundle")
    func accessibilityLabelKeysResolve() {
        // value: "\u{0}" 作哨兵——键缺失时 localizedString 返回哨兵值。断言「返回值 != 哨兵」
        // 即证「键已注册」，且**不**把「en 值恒等于 key」也捆进来（日后微调某个 en 值不该让本测试误红）。
        let keys = [
            "Rating", "Verification code",               // 组件标签
            // 注意："Add tag" 曾在 Phase 0 预登记，Phase 3（#173）收口时确认
            // TagInput 未消费（verbatim 渲染 placeholder，仿 SearchField 先例），
            // 已连同本条断言一并从 Localizable.strings 移除——不在此处保留死键。
            "Info", "Success", "Warning", "Error",       // Timeline 节点状态
            "%@ of %@",                                   // 通用位置/数值键
        ]
        for key in keys {
            #expect(Self.bundle.localizedString(forKey: key, value: "\u{0}", table: nil) != "\u{0}")
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
