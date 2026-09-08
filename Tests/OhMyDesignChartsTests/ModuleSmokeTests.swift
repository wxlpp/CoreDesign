import Testing

import OhMyDesignCharts

@Suite("OhMyDesignCharts 模块 smoke")
struct OhMyDesignChartsModuleSmokeTests {
    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIdentity() {
        #expect(OhMyDesignCharts.moduleName == "OhMyDesignCharts")
    }
}
