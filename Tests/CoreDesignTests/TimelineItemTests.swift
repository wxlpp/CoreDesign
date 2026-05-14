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

    @Test("timelineDepthKey defaults to 0")
    func defaultDepth() {
        #expect(TimelineDepthKey.defaultValue == 0)
    }
}
