import SnapshottingTests
import XCTest

final class SnapshotTests: SnapshotTest {
    // 默认收编 App target 中所有 #Preview 宏生成 PNG。
    // 如需排除特定 Preview，在数组中添加其名称。
    // 排除 CoreDesign package 内部的 modifier/token gallery Preview，
    // 仅保留 App/Previews.swift 中的组件文档快照。
    override class func excludedSnapshotPreviews() -> [String]? {
        [
            "Surface — Light",
            "Surface — Dark",
            "FocusRingModifier — iOS",
        ]
    }
}
