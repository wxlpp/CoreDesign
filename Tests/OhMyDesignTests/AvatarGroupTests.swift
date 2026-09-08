import SwiftUI
import Testing
@testable import OhMyDesign

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
        let group = AvatarGroup(max: 7, layout: .countOnly) { Circle() }
        #expect(group.max == 7, ".countOnly 下 max 仍应原样保留")
        #expect(group.layout == .countOnly)
    }

    @Test("AvatarGroup：四种排布都能构造且 body 可求值（不 crash）")
    func avatarGroupAllLayoutsRender() {
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
        #expect(
            AvatarGroupAccessibility.totalLabel(for: 5)
                != AvatarGroupAccessibility.overflowLabel(for: 5),
            "两个标签语义不同，文案不该相同"
        )
    }

    @Test("AvatarGroupAccessibility：totalLabel 走 %lld avatars 复数键，不自造字面键")
    func avatarGroupTotalLabelUsesRegisteredPluralKey() {
        #expect(AvatarGroupAccessibility.totalLabel(for: 1)
                != AvatarGroupAccessibility.totalLabel(for: 5),
                "totalLabel 必须消费 count")
        #expect(AvatarGroupAccessibility.totalLabel(for: 5).contains("5"))
    }
}
