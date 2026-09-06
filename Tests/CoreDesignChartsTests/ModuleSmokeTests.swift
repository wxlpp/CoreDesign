import Testing

import CoreDesignCharts

@Suite("CoreDesignCharts 模块 smoke")
struct CoreDesignChartsModuleSmokeTests {
    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIdentity() {
        #expect(CoreDesignCharts.moduleName == "CoreDesignCharts")
    }
}
