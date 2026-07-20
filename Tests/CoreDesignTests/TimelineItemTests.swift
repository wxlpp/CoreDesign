import SwiftUI
import Testing
@testable import CoreDesign

@Suite("TimelineItem")
@MainActor
struct TimelineItemTests {
    @Test("init creates instance with default isLast")
    func initDefault() {
        let item = TimelineItem(icon: { Circle().fill(.blue).frame(width: 20, height: 20) }) {
            Text("content")
        }
        #expect(item.isLast == false)
        #expect(item.showsTopConnector == true)
    }

    @Test("init creates instance with explicit isLast")
    func initExplicit() {
        let item = TimelineItem(
            icon: { Circle().fill(.blue).frame(width: 20, height: 20) },
            showsTopConnector: false,
            isLast: true
        ) {
            Text("content")
        }
        #expect(item.isLast == true)
        #expect(item.showsTopConnector == false)
    }

    @Test("timelineDepth defaults to 0")
    func defaultDepth() {
        // Issue #97（B9b）把手写的 `TimelineDepthKey: EnvironmentKey` 换成了 `@Entry`，
        // 该类型不再存在——改为直接断言环境值的默认值。
        #expect(EnvironmentValues().timelineDepth == 0)
    }
}
