import SnapshottingTests
import XCTest

final class SnapshotTests: SnapshotTest {
    // 默认收编 App target 中所有 #Preview 宏生成 PNG。
    override class func excludedSnapshotPreviews() -> [String]? {
        ["ContentView_Preview"]
    }
}
