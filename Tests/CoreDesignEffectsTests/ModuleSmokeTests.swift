import Testing

// ⚠️ 用普通 `import` 而非 `@testable`：本测试只访问 public 成员，
// 普通 import 更贴近「从**外部视角**证明 target 被编进测试」的意图，
// 也不引入 `-enable-testing` 依赖。
import CoreDesignEffects

// Smoke 测试 —— 存在的唯一理由是**证明这个 test target 真的在跑**。
//
// ⚠️ 不要因为「只断言一个字符串、看起来没价值」就删掉它（#245 的验收项之一）：
// 空的 test target 下 `xcodebuild test -scheme CoreDesign-Package` 会照常绿，
// 但跑的仍然只是 `CoreDesignTests`——新 target 有没有被 scheme 纳入，
// 在没有任何测试的情况下**无法与「纳入了但没测试可跑」区分**。
// 这一条断言就是那个区分点。
@Suite("CoreDesignEffects 模块 smoke")
struct CoreDesignEffectsModuleSmokeTests {

    @Test("模块标识可读，且 target 确实被编译进测试")
    func moduleIdentity() {
        #expect(CoreDesignEffects.moduleName == "CoreDesignEffects")
    }
}
