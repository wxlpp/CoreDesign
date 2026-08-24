import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AvatarGroup")
@MainActor
struct AvatarGroupTests {
    @Test("init with max parameter stores value")
    func initMaxParam() {
        let group = AvatarGroup(max: 5) {
            Circle().fill(.blue).frame(width: 32, height: 32)
            Circle().fill(.red).frame(width: 32, height: 32)
        }
        #expect(group.max == 5)
    }

    @Test("default max is 3")
    func defaultMax() {
        let group = AvatarGroup {
            Circle().fill(.blue).frame(width: 32, height: 32)
        }
        #expect(group.max == 3)
    }

    @Test("overflow accessibility label includes avatar context")
    func overflowAccessibilityLabel() {
        #expect(AvatarGroupAccessibility.overflowLabel(for: 2) == "2 more avatars")
    }
    // MARK: - AvatarGroupLayout（`#60` 形态 D2）

    @Test("AvatarGroup：layout 默认 .overlapped —— 现有调用方零影响")
    func avatarGroupLayoutDefaultsToOverlapped() {
        // ⚠️ 破坏性变更的防线：新参数带默认值（源码兼容）+ 默认值 == 现状（行为兼容）。
        let group = AvatarGroup { Circle() }
        #expect(group.layout == .overlapped)
    }

    @Test("AvatarGroup：layout 原样保留")
    func avatarGroupStoresLayout() {
        for layout in [AvatarGroupLayout.overlapped, .spaced, .grid, .countOnly] {
            let group = AvatarGroup(layout: layout) { Circle() }
            #expect(group.layout == layout)
        }
    }

    @Test("AvatarGroupLayout：四个 case 互不相等（Equatable 不是恒真）")
    func avatarGroupLayoutEquatableIsNotDegenerate() {
        let all: [AvatarGroupLayout] = [.overlapped, .spaced, .grid, .countOnly]
        for (i, lhs) in all.enumerated() {
            for (j, rhs) in all.enumerated() where i != j {
                #expect(lhs != rhs, "\(lhs) 与 \(rhs) 不应相等")
            }
        }
    }

    @Test("AvatarGroup：.countOnly 下 max 仍被原样保留（不生效 ≠ 被改写）")
    func avatarGroupCountOnlyPreservesMax() {
        // ⚠️ 正交性约定：.countOnly 不渲染头像 ⇒ max 不生效，但存储层仍保留它。
        // 改写掉会让调用方切回 .overlapped 时丢配置。
        let group = AvatarGroup(max: 7, layout: .countOnly) { Circle() }
        #expect(group.max == 7, ".countOnly 下 max 仍应原样保留")
        #expect(group.layout == .countOnly)
    }

    @Test("AvatarGroup：四种排布都能构造且 body 可求值（不 crash）")
    func avatarGroupAllLayoutsRender() {
        // ⚠️ 只证「不 crash」，不证渲染正确 —— 视觉正确性靠 #Preview 人工抽查。
        for layout in [AvatarGroupLayout.overlapped, .spaced, .grid, .countOnly] {
            let group = AvatarGroup(max: 2, layout: layout) {
                Circle()
                Circle()
                Circle()
                Circle()
            }
            _ = group.body
        }
    }

    @Test("AvatarGroupAccessibility：totalLabel 与 overflowLabel 语义不同、文案不同")
    func avatarGroupTotalLabelDiffersFromOverflow() {
        // ⚠️ 前者「一共 N 个」、后者「还有 N 个没显示」。若误复用 overflowLabel，
        // VoiceOver 会让用户以为还有更多头像被折叠。
        #expect(
            AvatarGroupAccessibility.totalLabel(for: 5)
                != AvatarGroupAccessibility.overflowLabel(for: 5),
            "两个标签语义不同，文案不该相同"
        )
    }

    @Test("AvatarGroupAccessibility：totalLabel 走 %lld avatars 复数键，不自造字面键")
    func avatarGroupTotalLabelUsesRegisteredPluralKey() {
        // ⚠️ **单复数形态本身在 `SharedFoundationTests.avatarGroupTotalPlural` 断言**，
        // 不在这里 —— 本 suite 用 `String(localized:)`，它在 macOS 的 `swift test` 腿上
        // 不对 SwiftPM 资源 bundle 的 `.stringsdict` 套用 `one` 规则（CLAUDE.md 记载的
        // 「macOS 对 iOS 行为假绿」盲区），拿它断言「1 avatar」会左右两边一起 fallback、
        // 恒真（PR #206 第 2 轮 review 抓到）。那条断言必须走 `Bundle.localizedString`。
        //
        // 这里只锁本函数的**契约面**：产出跟随 count 变化、且与 overflowLabel 语义不同。
        #expect(AvatarGroupAccessibility.totalLabel(for: 1)
                != AvatarGroupAccessibility.totalLabel(for: 5),
                "totalLabel 必须消费 count")
        #expect(AvatarGroupAccessibility.totalLabel(for: 5).contains("5"))
    }
}
