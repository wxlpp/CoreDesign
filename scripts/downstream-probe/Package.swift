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
    products: [.library(name: "DownstreamProbe", targets: ["DownstreamProbe"])],
    dependencies: [
        // 必须显式写 name:——SwiftPM 对 path 依赖的 identity 取目录 basename,
        // 而本仓库可能在 worktree 中检出(目录名如 issue-92-build-config)。
        .package(name: "CoreDesign", path: "../.."),
    ],
    targets: [
        .target(name: "DownstreamProbe", dependencies: [.product(name: "CoreDesign", package: "CoreDesign")]),
    ],
    swiftLanguageModes: [.v6]
)
