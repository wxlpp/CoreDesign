import Testing

@testable import CoreDesignCharts

// Smoke 测试 —— 理由同 `CoreDesignEffectsTests`：区分「scheme 纳入了新 test target」
// 与「纳入了但没有测试可跑」这两种在 CI 输出上无法分辨的状态。
@Suite("CoreDesignCharts 模块 smoke")
struct CoreDesignChartsModuleSmokeTests {

    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIdentity() {
        #expect(CoreDesignCharts.moduleName == "CoreDesignCharts")
    }
}
