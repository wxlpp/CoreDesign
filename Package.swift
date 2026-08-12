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
        .testTarget(
            name: "CoreDesignTests",
            dependencies: [
                "CoreDesign",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
