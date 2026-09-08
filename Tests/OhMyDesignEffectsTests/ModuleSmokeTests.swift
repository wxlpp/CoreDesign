import Testing

import OhMyDesignEffects

@Suite("OhMyDesignEffects 模块 smoke")
struct OhMyDesignEffectsModuleSmokeTests {
    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIdentity() {
        #expect(OhMyDesignEffects.moduleName == "OhMyDesignEffects")
    }
}
