import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - Descriptions

@Suite("Descriptions")
@MainActor
struct DescriptionsTests {
    // MARK: .labeledContentStyle(.core) 静态成员

    @Test(".labeledContentStyle(.core) 产出 CoreLabeledContentStyle")
    func labeledContentStyleCore() {
        let style: CoreLabeledContentStyle = .core
        _ = style // 类型即断言：签名不对齐这里就编译不过
    }

    // MARK: DescriptionsLayout.effectiveColumns —— 大字号强制单列

    @Test(
        "非可访问性档位：effectiveColumns 原样返回调用方偏好",
        arguments: [
            DynamicTypeSize.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        ]
    )
    func effectiveColumnsPassesThroughAtRegularSizes(_ size: DynamicTypeSize) {
        #expect(DescriptionsLayout.effectiveColumns(.two, dynamicTypeSize: size) == .two)
        #expect(DescriptionsLayout.effectiveColumns(.one, dynamicTypeSize: size) == .one)
    }

    @Test(
        "可访问性档位：effectiveColumns 无论调用方传入什么都强制单列",
        arguments: [
            DynamicTypeSize.accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
        ]
    )
    func effectiveColumnsForcesOneAtAccessibilitySizes(_ size: DynamicTypeSize) {
        #expect(DescriptionsLayout.effectiveColumns(.two, dynamicTypeSize: size) == .one)
        #expect(DescriptionsLayout.effectiveColumns(.one, dynamicTypeSize: size) == .one)
    }

    // MARK: DescriptionsLayout.rowGroups —— 列切分纯函数

    @Test("rowCount 为 0 时不产出任何组（.one / .two 均同）")
    func rowGroupsEmptyWhenNoRows() {
        #expect(DescriptionsLayout.rowGroups(rowCount: 0, columns: .one).isEmpty)
        #expect(DescriptionsLayout.rowGroups(rowCount: 0, columns: .two).isEmpty)
    }

    @Test(
        ".one 列：每行单独成组，组数恒等于行数",
        arguments: [1, 2, 3, 4, 5]
    )
    func rowGroupsOneColumnIsOnePerRow(_ rowCount: Int) {
        let groups = DescriptionsLayout.rowGroups(rowCount: rowCount, columns: .one)
        #expect(groups.count == rowCount)
        #expect(groups.allSatisfy { $0.count == 1 })
        #expect(groups.map(\.self) == (0..<rowCount).map { [$0] })
    }

    @Test(".two 列 + 偶数行数：全部两两配对，无落单组")
    func rowGroupsTwoColumnsEvenRowCountPairsCompletely() {
        let groups = DescriptionsLayout.rowGroups(rowCount: 4, columns: .two)
        #expect(groups == [[0, 1], [2, 3]])
        #expect(groups.allSatisfy { $0.count == 2 })
    }

    @Test(".two 列 + 奇数行数：最后一组只含 1 个索引（占满整行）")
    func rowGroupsTwoColumnsOddRowCountLastGroupIsSingle() {
        let groups = DescriptionsLayout.rowGroups(rowCount: 5, columns: .two)
        #expect(groups == [[0, 1], [2, 3], [4]])
        #expect(groups.last?.count == 1)
    }

    @Test(".two 列 + 单行：唯一一组只含 1 个索引")
    func rowGroupsTwoColumnsSingleRow() {
        let groups = DescriptionsLayout.rowGroups(rowCount: 1, columns: .two)
        #expect(groups == [[0]])
    }

    @Test(".two 列：切分覆盖每个索引恰好一次，且保持原始顺序")
    func rowGroupsTwoColumnsCoversEveryIndexExactlyOnceInOrder() {
        let rowCount = 7
        let groups = DescriptionsLayout.rowGroups(rowCount: rowCount, columns: .two)
        let flattened = groups.flatMap(\.self)
        #expect(flattened == Array(0..<rowCount))
    }

    // MARK: 受控行为（columns / dividerDensity 参数存储）

    @Test("DescriptionsColumns 两个枚举值互不相等")
    func descriptionsColumnsCasesAreDistinct() {
        // 编译期即可判断相等性——枚举无关联值，Equatable 由编译器合成。
        let one: DescriptionsColumns = .one
        let two: DescriptionsColumns = .two
        #expect(DescriptionsLayout.effectiveColumns(one, dynamicTypeSize: .large) != DescriptionsLayout.effectiveColumns(two, dynamicTypeSize: .large))
    }
}
