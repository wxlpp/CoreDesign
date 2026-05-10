import SnapshottingTests
import XCTest

final class SnapshotTests: SnapshotTest {
    // 默认收编 App target 中所有 #Preview 宏生成 PNG。
    // 如需排除特定 Preview，在数组中添加其名称。
    override class func excludedSnapshotPreviews() -> [String]? {
        nil
    }
}
