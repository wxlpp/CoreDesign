import Testing

import CoreDesignEffects

@Suite("CoreDesignEffects 模块 smoke")
struct CoreDesignEffectsModuleSmokeTests {
    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIdentity() {
        #expect(CoreDesignEffects.moduleName == "CoreDesignEffects")
    }
}
