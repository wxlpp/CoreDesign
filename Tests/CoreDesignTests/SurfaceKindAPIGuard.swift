@testable import CoreDesign

// 本类型**不是测试套件**——它是 SurfaceKind public API 的**编译期守卫**。
//
// 刻意不写成测试套件 / 测试方法：误删任一 public case 会让下面的 `apiGuard` 引用编译
// 失败，拦住破坏性 API 变更。`static let` 类型属性无 unused warning；不注册为测试套件
// （避免产生一个「叫 SurfaceKind 却啥都不测」的幽灵套件，误导后续 Issue 的覆盖自检），
// 也不进空断言自检——本文件刻意不出现测试标记宏的字面量，故覆盖自检的 grep 不会命中它。
//
// 原三个恒真的数组长度断言已删（断的是测试自写数组，与被测代码无关）；
// SurfaceKind 的 background / border / cornerRadius 映射是 private extension
// （`SurfaceModifier.swift`），`@testable` 够不到，Tests/ 内不可断言（改 Sources 违约 /
// ViewInspector 属 Out of Scope）。
enum SurfaceKindAPIGuard {
    private static let apiGuard: [SurfaceKind] = [
        .canvas, .content, .control, .floating, .overlay,
        .canvasSubtle, .panel, .sidebar, .card,
    ]
}
