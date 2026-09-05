import CoreDesign
import CoreDesignEffects
import SwiftUI

// MARK: - 转场簇 B（3D 与弹性 6 种，Issue #267）的下游消费面
//
// ⚠️ **为什么单开一个文件，而不是照惯例分进 `EffectsNonisolatedUsage.swift`（守隔离）
// 与 `PublicVisibility.swift`（守可见性）**：本文件里有**第三类**契约——
// **名字解析**（`.move(edge:)` 与 `SwiftUICore.MoveTransition` 的重载 / 同名冲突）。
// 它既不是可见性也不是隔离，两边的文件头分流表都没有它的位置；而它与本簇的
// 值类型、入口点是同一个 API 单位的三个面，拆开三处反而看不出这是一件事。
// ⇒ 一个 API 单位一个文件，内部按 `nonisolated` / `@MainActor` 分节，
// 分流的**理由**仍旧是那两份文件头写的那条（下同）。
//
// ⚠️ 本簇的 12 个静态成员按 `Host.member` 去重算 **6 种** transition（#251 的计数单位）。

// MARK: - ⚠️⚠️ 命名冲突：本簇唯一**只有跨模块才看得见**的那条契约（#267 终审 C-4）
//
// `SwiftUICore` 已有 `public struct MoveTransition` 与
// `extension Transition where Self == MoveTransition { static func move(edge:) }`。
// 本仓的极坐标平移转场因此**不叫** `MoveTransition`、但静态成员**仍叫** `move`
// ——与系统那个构成**重载**（实参标签不同）而不是覆盖。
//
// ⚠️⚠️ **这条契约在库内结构上守不住，实测过两次**：
//
// ① `TransitionClusterTests.systemMoveEdgeStillResolvesToSwiftUI` 写的是
//    `let system: MoveTransition = .move(edge: .top)` —— **显式结果类型标注按返回类型
//    消歧了**。把回归注进去（给 `CoreDesignEffects` 加一条
//    `static func move(edge: Edge) -> PolarMoveTransition`）：
//    `swift build` ⇒ `Build complete!`、那条判据 ⇒ **绿**；
//    而真实外部消费者 ⇒ `error: ambiguous use of 'move(edge:)'`。
// ② 把本仓的类型改回叫 `MoveTransition`：库内 `swift build` 仍然**全绿**
//    （模块内 shadowing 盖过去了），下游 ⇒
//    `error: 'MoveTransition' is ambiguous for type lookup in this context`。
//
// ⇒ 两种失效各由下面一条守：**必须两条都有**，一条只覆盖一半。
// ⚠️ 两条都**不许**加显式类型标注以外的东西去"帮忙消歧"——那正是库内那条判据栽的坑。

/// 守**类型名**冲突（上面的失效 ②）：`MoveTransition` 出现在返回类型位置。
///
/// 若哪天本仓把 `PolarMoveTransition` 改名成 `MoveTransition`，这里的类型查找
/// 在**同时 import SwiftUI 与 CoreDesignEffects 的下游**变成歧义，本函数编译红。
@MainActor
func systemMoveEdgeKeepsResolvingToSwiftUI() -> MoveTransition {
    .move(edge: .top)
}

/// 守**实参标签**冲突（上面的失效 ①）：**没有任何类型标注**的真实调用点形态。
///
/// 这正是下游会写的那一行。若 `CoreDesignEffects` 哪天也提供了
/// `move(edge:)`，重载解析在这里无从消歧，本函数编译红
/// ——而库内那条带 `let system: MoveTransition =` 的判据照样绿。
@MainActor
func systemMoveEdgeIsUnambiguousWithoutAnyAnnotation() -> some View {
    Text(verbatim: "x").transition(.move(edge: .top))
}

/// 对照：我们自己那两个形态（无参 `.move` 与 `.move(angle:distance:)`）也必须
/// 在下游解析得到 —— 否则上面两条可以靠"把我们的 `move` 整个删掉"来满足。
@MainActor
func ourPolarMoveStillResolves() -> some View {
    VStack {
        Text(verbatim: "x").transition(.move)
        Text(verbatim: "x").transition(.move(angle: .degrees(-45), distance: 40))
    }
}

// MARK: - 隔离契约（`nonisolated`）：本簇的公开值类型与静态常量
//
// 分流理由见 `EffectsNonisolatedUsage.swift` 的文件头：值类型 / 配置类型是调用方在
// **自己模型层**构造的东西，被 `MainActor` 隔离会让下游在后台线程准备参数时用不了
// ——**这只有本 probe 看得见**。
//
// ⚠️⚠️ `FlipTransition.swift` 里逐字写着「**`nonisolated` 是必需的、不是装饰**」，
// 而 `#267` 落地时**没有**在 probe 里补调用点（#253 / #254 各自补过，#267 悄悄破了
// 这个惯例，#267 终审 I-2）。实测把 `nonisolated` 从 `TransitionTravel` /
// `TransitionAxis3D` 上删掉：
//
// · 库的 `swift build -Xswiftc -warnings-as-errors` ⇒ **`Build complete!`**
// · 库的全量 `swift test` ⇒ **754 tests / 110 suites passed**
// · 本 probe ⇒ **两条硬 error**（不是 warning）：
//     TransitionClusterProbe.swift:  error: cannot form key path to main actor-isolated property 'points'
//     TransitionClusterProbe.swift:  error: main actor-isolated conformance of 'TransitionAxis3D'
//                                           to 'Equatable' cannot be used in nonisolated context
//
// ⚠️ **两条各自的"硬"来自不同机制，别把它们合并成一条**：`points` 那条硬在
// **key path**（`\.points` 对隔离属性直接不成立），`TransitionAxis3D` 那条硬在
// **isolated conformance**（`==` 要的 `Equatable` 一致性被隔离了）。
// 若哪天把 `readTransitionTravelPoints` 里的 `map(\.points)` 改写成 `map { $0.points }`，
// 那条就退化成 warning、在 `swift build` 下静默放行 —— **别改**。

nonisolated func readTransitionTravelPoints() -> [CGFloat] {
    TransitionTravel.allCases.map(\.points)
}

/// ⚠️ `TransitionAxis3D.vector` 是 internal（只给绘制层用）⇒ 下游能碰的只有 case 本身
/// 与 `CaseIterable` / `Equatable` 一致性。本函数覆盖的正是这些。
nonisolated func readTransitionAxes() -> [Bool] {
    TransitionAxis3D.allCases.map { $0 == .tilted }
}

/// 三个 `public nonisolated static let` —— 它们被 `public` 签名当**默认实参**用
/// （Swift 不允许默认实参引用 internal 符号），所以是真正的公开面。
///
/// ⚠️ **这三个的 `nonisolated` 本 probe 只报 warning，不是它守住的**（实测）：
/// 拿掉 `FlipTransition.quarterTurn` 的 `nonisolated`，**库自己**的
/// `swift build -Xswiftc -warnings-as-errors` 当场硬红
/// （`FlipTransition.swift:174: error: main actor-isolated static property 'quarterTurn'
/// can not be referenced from a nonisolated context` —— 因为 `nonisolated enum Flip`
/// 就在同一个文件里读它）。本函数是**下游视角的留痕**，不重复声称守卫作用。
/// 真正只有本 probe 看得见的那两条在上面。
nonisolated func readTransitionClusterDefaults() -> [Double] {
    [
        FlipTransition.quarterTurn,
        Rotate3DTransition.defaultDegrees,
        PolarMoveTransition.defaultDegrees,
    ]
}

// MARK: - 可见性契约（`@MainActor`）：12 个静态入口点
//
// 分流理由见 `PublicVisibility.swift` 的文件头：`Transition` 的静态成员经
// `.transition(_:)` 触达，而本包开了 `.defaultIsolation(MainActor.self)`
// ⇒ 这些调用点天然是 MainActor 隔离的。
//
// ⚠️ 拆成两个函数只是因为 `ViewBuilder` 一次最多接 10 个子视图。

@MainActor
func consumeTransitionClusterEntryPointsA() -> some View {
    VStack {
        Text(verbatim: "x").transition(.flip)
        Text(verbatim: "x").transition(.flip(axis: .vertical))
        Text(verbatim: "x").transition(.rotate3D)
        Text(verbatim: "x").transition(.rotate3D(angle: .degrees(120), axis: .depth))
        Text(verbatim: "x").transition(.swoosh)
        Text(verbatim: "x").transition(.swoosh(edge: .top, travel: .long))
    }
}

@MainActor
func consumeTransitionClusterEntryPointsB() -> some View {
    VStack {
        Text(verbatim: "x").transition(.boing)
        Text(verbatim: "x").transition(.boing(strength: .pronounced))
        Text(verbatim: "x").transition(.skid)
        Text(verbatim: "x").transition(.skid(edge: .bottom, travel: .short))
        Text(verbatim: "x").transition(.move)
        Text(verbatim: "x").transition(.move(angle: .degrees(-45), distance: 40))
    }
}

/// 六个层 1 类型的 `public init` 与存储属性也是公开面（漏 `public` 只有下游看得见）。
///
/// ⚠️ 走 `@MainActor`：本包 `.defaultIsolation(MainActor.self)` ⇒ 这些 `init`
/// 天然是隔离的（与上面那三个 `nonisolated static let` 的分工，见两份文件头的分流表）。
@MainActor
func constructTransitionClusterTypes() -> [Double] {
    [
        FlipTransition(axis: .depth).axis == .depth ? 1 : 0,
        Rotate3DTransition(angle: .degrees(30), axis: .vertical).angle.degrees,
        Double(SwooshTransition(edge: .top, travel: .long).travel.points),
        BoingTransition(strength: .subtle).strength == .subtle ? 1 : 0,
        Double(SkidTransition(edge: .bottom, travel: .short).travel.points),
        Double(PolarMoveTransition(angle: .degrees(10), distance: 33).distance),
    ]
}
