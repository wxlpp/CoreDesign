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
            // 本 target 的 chrome 文案要有自己的 `Bundle.module` 才能被翻译
            // （PR #263 终审 C-5：初版连资源目录都没有，文案只能落到宿主 App 的
            // `Bundle.main`，本包永远无法为自己提供翻译）。
            //
            // ⚠️ **上一版这里写「`resources:` 不是可选的，没有它 SwiftPM 不合成
            // `Bundle.module`」——实测为假**：本包设了 `defaultLocalization: "en"`，
            // SwiftPM 会**自动**把 `*.lproj` 目录当本地化资源处理；把这一行删掉后
            // `swift package clean && swift build` 照样生成
            // `CoreDesign_CoreDesignCharts.bundle`（内含 `en.lproj`）。
            // ⇒ 这一行是**显式声明**，不是必需品。保留它是为了将来放非 `.lproj`
            // 资源时不必再想一次，但**不要再照抄那句错的理由**。
            resources: [.process("Resources")],
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
    ],
    swiftLanguageModes: [.v6]
)
