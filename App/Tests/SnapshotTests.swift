import SnapshottingTests
import XCTest

final class SnapshotTests: SnapshotTest {
    // 默认收编 App target 中所有 #Preview 宏生成 PNG。
    // 按 module 包含：仅保留 App/Previews.swift 中的组件文档快照，
    // 排除 CoreDesign package 内部的 modifier/token gallery Preview。
    override class func snapshotPreviewModules() -> [String]? {
        ["CoreDesignPreview"]
    }
}
