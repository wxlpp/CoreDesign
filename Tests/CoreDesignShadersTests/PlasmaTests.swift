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
// ⚠️⚠️ **看 swiftbuild 腿的输出时不要只看最后一行**（第 4 轮终审 C-2 更正）。
//
// 包里有 4 个 test bundle，`swift test --build-system swiftbuild --filter
// CoreDesignShadersTests` 会打印**四行** "Test run with …"：本 bundle 的
// 「27 tests in 9 suites」（`Starfield` 随 #281 撤回后由 18 减 1 得 17；
// `#283` 的 `GlassOrb` / `Halftone` 两件各带一个 suite（9 条）+ 入口清单里
// 多一条「无时间形参」，合计 +10 条），
// 另外三个各一行「0 tests … passed」。
// 用 `tail` 取最后一行恰好取到那个 0 ⇒ 会误判成「一条都没跑」。
//
// ⚠️ 上一版据此在这里写下「`--filter` 在 swiftbuild 下恒返回 0 tests，
// 验证必须跑全量」——**那是错的，而且危险**：`ci.yml` 的 swiftbuild 步骤正是带
// `--filter` 的，删掉它会变成整腿 swiftbuild，而 `ci.yml` 与 `AGENTS.md` 明令禁止
//（会让 `ColorAssetGuardTests` 静默跳过，#258 踩过的坑）。
//
// ⚠️ 第 3 轮 I-4 的**另一半仍然成立**：`RenderProofTests` 整个文件包在
// `#if os(iOS)` 里 ⇒ macOS 腿的 17 条里**一条渲染证明都没有**，
// rim / 折射的机器守卫只在 iOS Simulator 腿上跑。
@Suite("CoreDesignShaders metallib 加载 —— fail-closed")
struct ShaderLibraryLoadTests {

    /// 全部 `[[stitchable]]` 入口。⚠️ 新增 shader 时**必须**加进来——
    /// 漏加不会有任何报错，那个 shader 的"函数名拼错 / 没编进 metallib"就无人守。
    static let entryPoints = [
        "coreDesignPlasma",
        "coreDesignDotGrid",
        "coreDesignFractalClouds",
        "coreDesignInkSmoke",
        "coreDesignLiquidChrome",
        "coreDesignRefractiveGlass",
        // ⚠️ `#283` 落地的两个内容层效果。**新增 shader 必须同时加进本表**——
        // 漏加不会有任何报错，那个 shader 的「函数名拼错 / 没编进 metallib」就无人守。
        "coreDesignGlassOrb",
        "coreDesignHalftone",
    ]

    @Test("bundle 里有 metallib，且八个入口全部解析得到")
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
