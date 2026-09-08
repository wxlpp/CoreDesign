import SwiftUI
import Testing
@testable import OhMyDesign

// MARK: - 系统控件 .core style 套件（Issue #143）

@Suite("系统控件 .core style 静态成员")
@MainActor
struct CoreControlStyleStaticMemberTests {
    @Test(".progressViewStyle(.core) 产出 CoreProgressViewStyle")
    func progressViewStyleCore() {
        let style: CoreProgressViewStyle = .core
        _ = style
    }

    @Test(".labelStyle(.core) 产出 CoreLabelStyle")
    func labelStyleCore() {
        let style: CoreLabelStyle = .core
        _ = style
    }

    @Test(".disclosureGroupStyle(.core) 产出 CoreDisclosureGroupStyle")
    func disclosureGroupStyleCore() {
        let style: CoreDisclosureGroupStyle = .core
        _ = style
    }
}
