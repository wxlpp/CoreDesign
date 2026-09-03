import Testing

@testable import CoreDesignShaders

/// ⚠️ 本 target 唯一在**原生 `swift test` 腿**也能跑的模块级冒烟点
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
