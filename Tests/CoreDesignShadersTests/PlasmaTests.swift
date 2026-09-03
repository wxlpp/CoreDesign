import Testing

// ⚠️ 用 `@testable` 而非普通 `import`：下方的 `field` / `metrics` / `speed` 等
// **有意是 `internal`**——它们是"语义档位展开成 shader 数值"的实现细节，
// 公开面只该有档位本身。要断言档位之间的单调关系就得看进去。
// ⚠️ 而 `assertShaderLibraryLoadable` 是**公开 API**，那条测试不依赖 `@testable`。
@testable import CoreDesignShaders

// ⚠️ **本 suite 在原生 `swift test` 下会判红，这是有意的。**
// 原生 SwiftPM 不编译 `.metal`（#248 spike 实测），bundle 里没有 metallib，
// 而 `assertShaderLibraryLoadable` 是 **fail-closed** 的。
// CI 把本 target 从原生腿显式 `--skip` 掉，另起一步用 swiftbuild 跑它。
//
// ⚠️ **不要**为了让原生腿变绿而加 `.enabled(if:)`——那会把"metallib 没编出来"变成
// 静默跳过，正是本仓反复堵的假绿病型（对照 #258 发现的 `ColorAssetGuardTests`
// 在 swiftbuild 下静默失守）。
@Suite("CoreDesignShaders metallib 加载 —— fail-closed")
struct ShaderLibraryLoadTests {

    /// 全部 `[[stitchable]]` 入口。⚠️ 新增 shader 时**必须**加进来——
    /// 漏加不会有任何报错，那个 shader 的"函数名拼错 / 没编进 metallib"就无人守。
    static let entryPoints = [
        "coreDesignPlasma",
        "coreDesignStarfield",
        "coreDesignDotGrid",
        "coreDesignFractalClouds",
        "coreDesignInkSmoke",
        "coreDesignLiquidChrome",
        "coreDesignRefractiveGlass",
    ]

    @Test("bundle 里有 metallib，且七个入口全部解析得到")
    func libraryLoads() throws {
        try CoreDesignShaders.assertShaderLibraryLoadable(functions: Self.entryPoints)
    }
}

@Suite("语义档位单调性")
struct SemanticStopTests {

    // ⚠️ 断言的是**档位之间的关系**，不是具体数值——数值是可调的实现细节，
    // 而"更密 ⇒ 频率更高"这类是枚举的语义承诺。

    @Test("ShaderMotion：still < calm < regular < lively")
    func motion() {
        #expect(ShaderMotion.still.speed == 0)
        #expect(ShaderMotion.still.speed < ShaderMotion.calm.speed)
        #expect(ShaderMotion.calm.speed < ShaderMotion.regular.speed)
        #expect(ShaderMotion.regular.speed < ShaderMotion.lively.speed)
    }

    @Test("Plasma.Density 单调，且 octaves ≥ 1（0 会让 shader 的除法退化）")
    func plasma() {
        let stops = Plasma.Density.allCases.map(\.field)
        #expect(zip(stops, stops.dropFirst()).allSatisfy { $0.frequency < $1.frequency })
        #expect(zip(stops, stops.dropFirst()).allSatisfy { $0.octaves <= $1.octaves })
        #expect(stops.allSatisfy { $0.octaves >= 1 })
    }

    @Test("Starfield.Density 单调递增")
    func starfield() {
        let cells = Starfield.Density.allCases.map(\.cells)
        #expect(zip(cells, cells.dropFirst()).allSatisfy(<))
    }

    @Test("DotGrid.Spacing：格数递增，半径不减")
    func dotGrid() {
        let m = DotGrid.Spacing.allCases.map(\.metrics)
        #expect(zip(m, m.dropFirst()).allSatisfy { $0.spacing < $1.spacing })
        #expect(zip(m, m.dropFirst()).allSatisfy { $0.radius <= $1.radius })
    }

    @Test("FractalClouds / InkSmoke：scale、octaves、扭曲强度同向递增，octaves ≥ 1")
    func noiseDerived() {
        let clouds = FractalClouds.Density.allCases.map(\.field)
        #expect(zip(clouds, clouds.dropFirst()).allSatisfy { $0.scale < $1.scale })
        #expect(zip(clouds, clouds.dropFirst()).allSatisfy { $0.warp < $1.warp })
        #expect(clouds.allSatisfy { $0.octaves >= 1 })

        let smoke = InkSmoke.Density.allCases.map(\.field)
        #expect(zip(smoke, smoke.dropFirst()).allSatisfy { $0.scale < $1.scale })
        #expect(zip(smoke, smoke.dropFirst()).allSatisfy { $0.wisp < $1.wisp })
        #expect(smoke.allSatisfy { $0.octaves >= 1 })
    }

    @Test("LiquidChrome.Density：带数递增")
    func liquidChrome() {
        let f = LiquidChrome.Density.allCases.map(\.field)
        #expect(zip(f, f.dropFirst()).allSatisfy { $0.bands < $1.bands })
    }

    @Test("RefractiveGlassStrength：折射与色散同向递增，subtle 档色散为 0")
    func glassStrength() {
        let all = RefractiveGlassStrength.allCases
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.refraction < $1.refraction })
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.dispersion <= $1.dispersion })
        // 弱折射配色散会显脏——这条是设计决定，不是巧合。
        #expect(RefractiveGlassStrength.subtle.dispersion == 0)
    }
}
