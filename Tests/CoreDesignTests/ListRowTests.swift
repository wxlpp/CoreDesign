import SwiftUI
import Testing
@testable import CoreDesign

@Suite("ListRow")
struct ListRowTests {
    @MainActor
    @Test("list row constructs with label only")
    func listRowConstructsWithLabelOnly() {
        let row = ListRow(label: { Text("Item") })
        #expect(type(of: row) == ListRow<EmptyView, EmptyView, Text>.self)
    }

    @MainActor
    @Test("list row constructs with leading and trailing")
    func listRowConstructsWithLeadingAndTrailing() {
        // 三个槽位用三种不同 View 类型（Image / Circle / Text）——让 concrete-type
        // 断言能区分 Leading / Trailing / Label 三个泛型位置，若 init 参数顺序或
        // 泛型 slot 顺序回退，本断言会立刻失败。
        let row = ListRow(
            leading: { Image(systemName: "doc") },
            label: { Text("Item") },
            trailing: { Circle() }
        )
        #expect(type(of: row) == ListRow<Image, Circle, Text>.self)
    }
}
