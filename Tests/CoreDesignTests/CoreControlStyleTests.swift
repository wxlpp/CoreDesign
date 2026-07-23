import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 系统控件 .core style 套件（Issue #143）
//
// 结构性断言：`.core` 静态成员确实产出对应的 CoreDesign style 类型，
// 编译期即验证了 SwiftUI 惯例形态（`XxxStyle where Self == CoreXxxStyle`）
// 与 `public` 表面完整——若签名或可见性有误，本文件本身就无法编译。
//
// 真正的 `.tint` 响应证据（不是恒取 accent）见同目录
// `CoreControlStyleTintTests.swift` 的像素级渲染断言。

@Suite("系统控件 .core style 静态成员")
@MainActor
struct CoreControlStyleStaticMemberTests {
    @Test(".progressViewStyle(.core) 产出 CoreProgressViewStyle")
    func progressViewStyleCore() {
        let style: CoreProgressViewStyle = .core
        _ = style // 类型即断言：签名不对齐这里就编译不过
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
