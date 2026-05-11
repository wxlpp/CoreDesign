import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AvatarGroup")
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
}
