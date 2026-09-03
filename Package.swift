// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreDesign",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CoreDesign",
            targets: ["CoreDesign"]
        ),
        // ⚠️ 表达性视觉层与图表层是**独立 product**，不并进 CoreDesign
        //（`shipswift-harvest` PRD / epic `shipswift-foundation` AD-A）：
        // · 只想要系统原生观感的消费者不必背上动效与图表；
        // · Metal shader 那一层（`CoreDesignShaders`）另有非默认构建系统依赖，
        //   由 `shipswift-shaders` 在两闸通过后单独引入——**此处有意不预留它**，
        //   闸不过时仓库里不该留下一个空 product。
        .library(
            name: "CoreDesignEffects",
            targets: ["CoreDesignEffects"]
        ),
        .library(
            name: "CoreDesignCharts",
            targets: ["CoreDesignCharts"]
        ),
        // ⚠️ 与 Effects / Charts 分开的理由不只是"内容不同"：本 target 含 `.metal` 源，
        // 而**原生 `swift build` 不编译 `.metal`**（#248 spike 实测）。把它并进 Effects
        // 会让"只想要 `.shake(trigger:)`"的消费者也背上构建系统约束。
        .library(
            name: "CoreDesignShaders",
            targets: ["CoreDesignShaders"]
        ),
    ],
    dependencies: [
        // ⚠️ 版本约束刻意写成 `.upToNextMinor` 而不是 `from:` 或 `.exact`
        // （PR #193 Copilot 第 1 轮）：
        // · `from: "603.0.0"` 允许整个 603.x —— manifest 里读不出项目实测的是哪版；
        // · `.exact` 又过紧 —— 连补丁更新都挡掉，而 swift-syntax 的 6xx 主版本本身
        //   就绑定工具链世代（603 ↔ Swift 6.3），同世代内的补丁是兼容的。
        // ⇒ `.upToNextMinor(from: "603.0.2")`：manifest 明写实测版本，同时放行 603.0.x 补丁。
        // 另有两道既有防线：`Package.resolved` 已提交并钉住 603.0.2；扫描器的
        // `tree.hasError` 检查会在 parser 与工具链主版本不配套时判红（见
        // `Tests/CoreDesignTests/ComponentRegistryGuard.swift` 的 `scanTypes`）。
        .package(url: "https://github.com/swiftlang/swift-syntax.git", .upToNextMinor(from: "603.0.2")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CoreDesign",
            resources: [.process("Resources")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "CoreDesignEffects",
            dependencies: ["CoreDesign"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "CoreDesignCharts",
            dependencies: ["CoreDesign"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "CoreDesignShaders",
            dependencies: ["CoreDesign"],
            // ⚠️ `.metal` **必须**声明为资源，这是 α 路径的强制项而非可选（#248 spike）：
            // · 不声明 ⇒ 原生 `swift build` 报 `unhandled file`，且 **`Bundle.module`
            //   根本不被合成** ⇒ `downstream-probe` 与下游直接编译失败；
            // · 声明后：swiftbuild / xcodebuild 会真编成 `default.metallib`（bundle 里
            //   **只有** metallib，`.metal` 源不会被同时拷进去）；原生 `swift build`
            //   则只是把 `.metal` 源拷进 bundle，**不产生 metallib**。
            resources: [.process("CoreDesignShaders.metal")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "CoreDesignTests",
            dependencies: [
                "CoreDesign",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // ⚠️ 新 target 各建**独立** test target，**不并进 `CoreDesignTests`**
        //（epic `shipswift-foundation` AD-D）：并进去需要
        // `@testable import CoreDesignEffects`，会让 `CoreDesignTests` 的依赖图
        // 包含新 target，判红本 issue 立下的隔离判据——
        // `swift package describe --type json | jq '.targets[]
        //   | select(.name=="CoreDesignTests") | .target_dependencies'`
        // 必须恰为 `["CoreDesign"]`。
        .testTarget(
            name: "CoreDesignEffectsTests",
            dependencies: ["CoreDesignEffects"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "CoreDesignChartsTests",
            dependencies: ["CoreDesignCharts"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // ⚠️ 本 test target **在原生 `swift test` 下会判红**，这是**有意的**：
        // 原生构建不产生 metallib，而 `assertShaderLibraryLoadable` 是 fail-closed 的。
        // CI 因此把它从原生腿显式 `--skip` 掉，另起一步用 swiftbuild 跑它
        // ——**显式跳过 + 留痕**，不是静默放过（见 `.github/workflows/ci.yml`）。
        .testTarget(
            name: "CoreDesignShadersTests",
            dependencies: ["CoreDesignShaders"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
