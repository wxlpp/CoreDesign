import Testing

// ⚠️ 用 `@testable` 而非普通 `import`（与 #245 那两个 smoke 测试相反）：
// 下方 `Density.field` / `Motion.speed` **有意是 `internal`**——它们是"语义档位展开成
// shader 数值"的实现细节，公开面只该有档位本身。要断言档位之间的单调关系就得看进去。
// ⚠️ 而 `assertShaderLibraryLoadable` 是**公开 API**，那条测试不依赖 `@testable`。
@testable import CoreDesignShaders

// ⚠️ **本 suite 在原生 `swift test` 下会判红，这是有意的。**
// 原生 SwiftPM 不编译 `.metal`（#248 spike 实测），bundle 里没有 metallib，
// 而 `assertShaderLibraryLoadable` 是 **fail-closed** 的——它不会"查不到就算了"。
// CI 把本 target 从原生腿显式 `--skip` 掉，另起一步用
// `swift test --build-system swiftbuild --filter CoreDesignShadersTests` 跑它。
//
// ⚠️ **不要**为了让原生腿变绿而给它加 `.enabled(if:)` 之类的条件——
// 那会把"metallib 没编出来"变成静默跳过，正是本仓反复堵的假绿病型
// （对照 `ColorAssetGuardTests` 在 swiftbuild 下静默失守那个案例，#258）。
@Suite("CoreDesignShaders metallib 加载 —— fail-closed")
struct ShaderLibraryLoadTests {

    @Test("bundle 里有 metallib，且含 coreDesignPlasma")
    func libraryLoads() throws {
        try CoreDesignShaders.assertShaderLibraryLoadable(
            functions: ["coreDesignPlasma"]
        )
    }
}

@Suite("Plasma 语义档位")
struct PlasmaDensityTests {

    // ⚠️ 断言的是**档位之间的关系**，不是具体数值——数值是可调的实现细节，
    // 而"更密 ⇒ 频率更高、叠加更多"是这个枚举的语义承诺。
    @Test("Density 单调：subtle < regular < dense（频率与叠加层数同向递增）")
    func densityIsMonotonic() {
        let subtle = Plasma.Density.subtle.field
        let regular = Plasma.Density.regular.field
        let dense = Plasma.Density.dense.field

        #expect(subtle.frequency < regular.frequency)
        #expect(regular.frequency < dense.frequency)
        #expect(subtle.octaves <= regular.octaves)
        #expect(regular.octaves <= dense.octaves)
    }

    @Test("Motion 单调：calm < regular < lively")
    func motionIsMonotonic() {
        #expect(Plasma.Motion.calm.speed < Plasma.Motion.regular.speed)
        #expect(Plasma.Motion.regular.speed < Plasma.Motion.lively.speed)
    }

    @Test("octaves 至少 1 —— 0 会让 shader 的除法退化")
    func octavesAreAtLeastOne() {
        for density in Plasma.Density.allCases {
            #expect(density.field.octaves >= 1)
        }
    }
}
