import Testing
@testable import CoreDesign

@Suite("SurfaceKind")
struct SurfaceKindTests {
    // 编译期 public API 守卫：误删任一 public case 会让本引用编译失败，
    // 拦住破坏性变更。故意写成普通存储属性、不是测试方法——本文件因此
    // 不含任何测试方法，逃过 Task 5 的空断言自检；恒真的数组长度断言已删。
    // token 映射是 private，Tests/ 内无法断言（改 Sources 违约 / ViewInspector Out of Scope）。
    private static let apiGuard: [SurfaceKind] = [
        .canvas, .content, .control, .floating, .overlay,
        .canvasSubtle, .panel, .sidebar, .card,
    ]
}
