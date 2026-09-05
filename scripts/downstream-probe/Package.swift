// swift-tools-version: 6.3
// 下游消费者 probe：从 **nonisolated 上下文**使用 CoreDesign 的公开值类型。
//
// 存在理由：CoreDesign 的 target 启用了 `defaultIsolation(MainActor.self)`，
// 这会改变公开 API 的隔离契约——而库自身的四条验证命令全都跑在被隔离的
// target *内部*，结构上不可能发现「下游 nonisolated 代码用不了这些类型」。
// 本 probe 是唯一能看见该问题的地方。
//
// 跑法：cd scripts/downstream-probe && swift build
import PackageDescription

let package = Package(
    name: "DownstreamProbe",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "DownstreamProbe", targets: ["DownstreamProbe"]),
        .library(name: "CoreDesignOnlyProbe", targets: ["CoreDesignOnlyProbe"]),
    ],
    dependencies: [
        // 必须显式写 name:——SwiftPM 对 path 依赖的 identity 取目录 basename,
        // 而本仓库可能在 worktree 中检出(目录名如 issue-92-build-config)。
        .package(name: "CoreDesign", path: "../.."),
    ],
    targets: [
        // ⚠️ 三个 product 都要接（#247）：本 probe 验的是「下游从 **nonisolated 上下文**
        // 能不能用这些类型」，而 `.defaultIsolation(MainActor.self)` 是**逐 target** 生效的
        // ——只接 `CoreDesign` 的话，Effects / Charts 的隔离契约在结构上无人验证。
        //
        // ⚠️⚠️ **`CoreDesignShaders` 仍未接，但上一版给的理由已作废**（`#279` 更正）。
        // 原文逐字：「它**还不存在**（`shipswift-foundation` AD-A：该 target 归
        // `shipswift-shaders` 的 B-1 建，闸不过就不该留一个空 product）」——
        // **该前提已被 `#261` 推翻**：`Sources/CoreDesignShaders/` 与 `CoreDesignShaders`
        // product 都已落地，`#279` 还把它接进了 `GuardScanRoots.targetNames` 与登记表。
        // ⇒ 现在的理由只剩后半句：**manifest 接线与实质调用点都归 B-4**（本 probe 的价值
        // 全在**调用点**——只加一行 `.product(...)` 而没有任何 nonisolated 上下文里的实际
        // 调用，probe 对这个 module 依然什么都没验，那正是本文件下面
        // `CoreDesignOnlyProbe` 那段注释记的「变异实证现场抓到的」假绿形态）。
        // ⚠️ **如实记账**：在 B-4 落地之前，`CoreDesignShaders` 的
        // `.defaultIsolation(MainActor.self)` 隔离契约**在下游侧零验证**，
        // 且**没有任何判据会为此判红** —— 本 manifest 不受任何守卫覆盖
        // （`#279` 逐文件核过：`Tests/` 下提到 downstream-probe 的全部位置都是散文注释）。
        // 这条缝没有堵，写在这里而不是让它无声无息。
        .target(
            name: "DownstreamProbe",
            dependencies: [
                .product(name: "CoreDesign", package: "CoreDesign"),
                .product(name: "CoreDesignEffects", package: "CoreDesign"),
                .product(name: "CoreDesignCharts", package: "CoreDesign"),
            ]
        ),
        // ⚠️⚠️ **独立 target，只接 `CoreDesign` 一个 product——这是承重的，别给它加依赖。**
        //
        // 它证的是 #252 终审 S-2 下沉要换来的那句话：「**`import CoreDesign` 就够**」
        //（`shipswift-shaders` 的 B-2 不必为两个能耗键链上整个 Effects product）。
        //
        // ⚠️ **为什么必须是独立 target，而不是 `DownstreamProbe` 里一个"只写
        // `import CoreDesign`"的文件**——这条是**变异实证现场抓到的**，不是预防性设计：
        // 初版就是那个形态，而把两个键搬回 `CoreDesignEffects` 之后 probe **照样全绿**。
        // 原因是 Swift 对**扩展成员**的名字查找是**逐模块**而不是逐文件的：只要同一个
        // target 里**任何一个文件** `import CoreDesignEffects`，该模块在 `EnvironmentValues`
        // 上挂的成员在**同 target 的其它文件里也可见**，哪怕那个文件自己没 import 它。
        // ⇒ 文件级的 import 隔离对扩展成员**不成立**，只有 target 边界才成立。
        .target(
            name: "CoreDesignOnlyProbe",
            dependencies: [
                .product(name: "CoreDesign", package: "CoreDesign"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
