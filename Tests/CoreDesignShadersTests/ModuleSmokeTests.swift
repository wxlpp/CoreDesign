import Testing

@testable import CoreDesignShaders

/// 本 target 的模块级冒烟点。**本文件不依赖 Metal**，在本地原生 `swift test` 下即可
/// 编译并通过。
///
/// ⚠️ **但 CI 的 native SwiftPM job 会整体 skip 该 target**——`.github/workflows/ci.yml`
/// 的 `Test` 步骤跑的是 `swift test --skip CoreDesignShadersTests`，所以本冒烟在那条腿上
/// **一次都不会执行**。别把"能在原生腿跑"读成"CI 的原生腿覆盖了它"。
/// 本 target 在 CI 上的覆盖只有两处：`Test (swiftbuild) — CoreDesignShaders` 步骤
///（`swift test --build-system swiftbuild --filter CoreDesignShadersTests`）与 iOS Simulator 腿。
///
/// ⚠️ 那个 `--skip` 是必需的：同 target 的 `ShaderLibraryLoadTests`（在 `PlasmaTests.swift`）
/// 在原生腿上**有意 fail-closed** —— 原生 SwiftPM 不编译 `.metal`，bundle 里没有 metallib，
/// `assertShaderLibraryLoadable` 会 `throw`。
///（⚠️ 上一版这里写「`RenderProofTests` 有意在原生腿判红」——**那是错的**：
/// 它整包在 `#if os(iOS)` 里，macOS 腿**根本不编译它、不可能红**。
/// 原生腿有意判红的是 `ShaderLibraryLoadTests`。第 5 轮终审 S 抓到）。
/// `CoreDesignEffects` / `CoreDesignCharts` 都有同名文件，唯独这里漏了（终审 S-6）。
@Suite("CoreDesignShaders 模块冒烟")
struct ModuleSmokeTests {

    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIsLinked() {
        #expect(CoreDesignShaders.moduleName == "CoreDesignShaders")
    }
}
