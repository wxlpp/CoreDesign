import SnapshottingTests
import XCTest

final class SnapshotTests: SnapshotTest {
    // 在测试运行时自动扫描 App target 中的 #Preview 宏并生成 PNG 快照。
    // PNG 文件生成至临时目录，不提交至仓库。
}
