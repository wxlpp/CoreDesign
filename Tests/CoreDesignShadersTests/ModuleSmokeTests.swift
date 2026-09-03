import Testing

@testable import CoreDesignShaders

/// ⚠️ 本 target 唯一在**原生 `swift test` 腿**也能跑的模块级冒烟点
///（`RenderProofTests` 有意在原生腿判红——那里没有编好的 metallib）。
/// `CoreDesignEffects` / `CoreDesignCharts` 都有同名文件，唯独这里漏了（终审 S-6）。
@Suite("CoreDesignShaders 模块冒烟")
struct ModuleSmokeTests {

    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIsLinked() {
        #expect(CoreDesignShaders.moduleName == "CoreDesignShaders")
    }
}
