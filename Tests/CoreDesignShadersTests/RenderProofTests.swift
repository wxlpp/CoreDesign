#if os(iOS)
import SwiftUI
import Testing
import UIKit

@testable import CoreDesignShaders

// ⚠️ **本 suite 守的是「能画」，不是「能加载」——两者是不同的失败面。**
//
// `assertShaderLibraryLoadable` 只证明 metallib 在 bundle 里、函数名解析得到；
// 它**证不了** `.colorEffect(...)` / `.layerEffect(...)` 的实参与 `[[stitchable]]`
// 形参的**位次与类型对得上**。签名不匹配时 SwiftUI **不报错、只是不渲染**
// ——这是本 target 最坏的失败形态。
//
// ⚠️ 本 suite 还守着一个只在真渲染时暴露的坑：`Plasma` 落地时曾出现
// **每个像素完全相同**，而编译、metallib 加载、签名绑定全绿。根因是把
// `timeIntervalSinceReferenceDate`（~8.1e8）喂进 `Float`，在该量级上精度约 16 个单位，
// 空间项被整个舍入吃掉。⇒ **删掉本 suite 等于把那个坑重新放回去。**
@Suite("渲染证明 —— shader 真的执行且输出随位置变化")
@MainActor
struct RenderProofTests {

    /// ⚠️ 用枚举而不是 `AnyView` 作参数化实参——`AnyView` **不是 `Sendable`**，
    /// 直接当 `arguments:` 会编译失败（`conformance of 'AnyView' to 'Sendable' is unavailable`）。
    enum Background: String, CaseIterable, Sendable {
        case plasma, dotGrid, fractalClouds, inkSmoke, liquidChrome

        @MainActor
        @ViewBuilder var view: some View {
            switch self {
            case .plasma: Plasma(tint: .blue, density: .dense)
            case .dotGrid: DotGrid(tint: .blue, spacing: .tight)
            case .fractalClouds: FractalClouds(tint: .blue, density: .turbulent)
            case .inkSmoke: InkSmoke(tint: .blue, density: .heavy)
            case .liquidChrome: LiquidChrome(tint: .blue, density: .fine)
            }
        }
    }

    @Test("五个程序化背景各自渲染出非纯色结果", arguments: Background.allCases)
    func backgroundsRender(_ background: Background) throws {
        let samples = try Self.render(background.view.frame(width: 64, height: 64))
        #expect(
            Set(samples).count > 1,
            """
            \(background.rawValue)：所有采样点颜色相同 ⇒ shader 没有执行，或输出与位置无关。
            ⚠️ 先查这两条再改测试：① `.colorEffect` 实参位次/类型是否与 `[[stitchable]]`
            形参一致（不匹配 = 静默无渲染）；② 是否把绝对纪元时间喂进了 `Float`
            （见 `ProceduralBackground.origin` 的注释）。
            """
        )
    }

    /// ⚠️ **抓「shader 完全忽略 `time`」** —— 单帧比较抓不到它：一个把 `time` 形参
    /// 收下却不用的 shader，空间上照样变化，上一条测试照样通过（#261 终审 I-3）。
    /// 同类型形参**换序**也是同理——`.float(t), .float(frequency), .float(octaves)`
    /// 三个都是 `float`，换序照样编译；本条能抓到其中把 `time` 换走的那些排列。
    @Test("动画背景在两个时刻的输出不同 —— shader 真的吃了 time")
    func timeActuallyAdvances() throws {
        // 同一个 shader、同一尺寸，只有时间原点不同。
        let now = Date()
        let ramp = ShaderRamp(tint: .blue, reduceTransparency: false)
        let library = ShaderLibrary.bundle(.module)

        func frame(secondsAgo: TimeInterval) throws -> [UInt32] {
            try Self.render(
                ProceduralBackground(
                    base: ramp.low,
                    motion: .lively,
                    originOverride: now.addingTimeInterval(-secondsAgo)
                ) { size, t in
                    library.coreDesignPlasma(
                        .float2(size), .float(t), .float(11), .float(3),
                        .color(ramp.low), .color(ramp.mid), .color(ramp.high)
                    )
                }
                .frame(width: 64, height: 64)
            )
        }

        #expect(
            try frame(secondsAgo: 0) != frame(secondsAgo: 30),
            """
            两个时刻渲染结果完全相同 ⇒ shader 没有真正使用 `time` 形参。
            ⚠️ 常见原因：`.float(...)` 实参顺序与 `[[stitchable]]` 形参不匹配
            （同为 `float` 时换序照样编译）；或时间被 `Float` 精度吃掉
            （见 `ProceduralBackground.origin`）。
            """
        )
    }

    @Test("refractiveGlass 改变了内容层的像素")
    func glassRefracts() throws {
        let content = LinearGradient(
            colors: [.blue, .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 64, height: 64)

        let plain = try Self.render(content)
        let glassed = try Self.render(
            content.refractiveGlass(corner: 12, strength: .pronounced)
        )

        #expect(plain.count == glassed.count)
        #expect(
            plain != glassed,
            "施加 refractiveGlass 前后像素完全一致 ⇒ layerEffect 没有生效"
        )
    }

    /// ⚠️⚠️ **rim 那一行改过三次，前两次都错，而它一直是零回归覆盖**
    ///（第 4 轮终审 I-2）。`glassRefracts` 用的是**不透明** `LinearGradient`
    /// ⇒ 第 2 版「`sample.a == 0` 时 rim 整条消失」在那里**不可能暴露**；
    /// 且 `render(_:)` 只取 RGB 三通道、**从不采样 alpha** ⇒ 第 1 版的
    /// 「边缘 25% 透明环」对它也天然不可见。三个版本它都放行。
    ///
    /// ⇒ 本条以**透明内容**为被折射层，并**采样 alpha**：圆角边界一圈必须出现
    ///   `alpha > 0` 的 rim 像素。
    /// ⚠️ **测试名与注释曾宣称「前两版都会在这条上判红」——那句话只对第 2 版成立**
    /// （第 5 轮终审 I-1）。推演第 1 版 `mix(sample, rim, rimBand * rim.a)`：
    /// 测试传不透明的 `rim: .accent`（`rim.a = 1`）⇒ 透明处
    /// `out.a = 0·(1-k) + 1·k = rimBand > 0` ⇒ **本条对第 1 版判绿**。
    /// 第 1 版的真实失效形态是**不透明内容的边缘被打出透明环**，
    /// 由下面 `rimDoesNotPunchHolesInOpaqueContent` 覆盖。
    @Test("rim 高光在透明内容上仍然显影（覆盖第 2 版的失效形态）")
    func rimShowsOnTransparentContent() throws {
        // SF Symbol 四周 alpha = 0，正是第 2 版失效的那类内容。
        let content = Image(systemName: "bolt.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)

        // ⚠️⚠️ **对照必须隔离 rim**：拿「加不加 glass」比是**错的**——折射本身会把
        // 不透明像素位移进原本透明的区域，不透明像素数从 209 涨到 740（实测），
        // 这个变化**完全淹没** rim 的贡献。我的第一版断言正是这么写的，
        // 而它对第 2 版的 rim bug **判绿**（变异实测），检出力为零。
        // ⇒ 正确对照：**同样的折射、只有 rim 不同**（`.clear` vs 有色）。
        let noRim = try Self.renderAlpha(
            content.refractiveGlass(corner: 12, strength: .pronounced, rim: .clear)
        )
        let withRim = try Self.renderAlpha(
            content.refractiveGlass(corner: 12, strength: .pronounced, rim: .accent)
        )
        #expect(noRim.count == withRim.count)

        // 第 2 版 `mix(sample, half4(rim.rgb, sample.a), k)` 保住了 `sample.a`
        // ⇒ 透明处 alpha 恒为 0 ⇒ 两者的 alpha 分布**完全相同** ⇒ 本条判红。
        // 第 3 版的预乘 source-over 会在边界一圈抬高 alpha ⇒ 两者不同。
        let opaqueWithout = noRim.filter { $0 > 8 }.count
        let opaqueWith = withRim.filter { $0 > 8 }.count
        #expect(opaqueWith > opaqueWithout,
                "rim 在透明内容上没有抬高任何 alpha（\(opaqueWithout) → \(opaqueWith)）—— 这正是第 2 版的失效形态")
    }

    /// ⚠️ **覆盖第 1 版的失效形态**（第 5 轮终审 I-1）：
    /// `mix(sample, rim, k)` 会把 alpha 一起插值 ⇒ 用默认 `rim: .accent.opacity(0.55)`
    /// 时贴边处 `out.a = 1 - 0.2475·rimBand` ⇒ **不透明内容的边缘被打出约 25% 的透明环**。
    /// 上一版补的是透明内容那一侧，这一条补不透明那一侧——两条各挡一个版本。
    @Test("rim 不在不透明内容上打洞（覆盖第 1 版的失效形态）")
    func rimDoesNotPunchHolesInOpaqueContent() throws {
        let content = LinearGradient(colors: [.blue, .white],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: 64, height: 64)
        let alphas = try Self.renderAlpha(
            content.refractiveGlass(corner: 12, strength: .pronounced)
        )
        #expect(!alphas.isEmpty)
        let minAlpha = alphas.min() ?? 0
        #expect(minAlpha >= 250, "不透明内容被 rim 打出透明环：min alpha = \(minAlpha)")
    }

    // MARK: - #283：两个内容层效果的渲染证明

    /// ⚠️ **本组断言一律先把比较归约成 `Bool` 再进 `#expect`**（#293 的纪律）：
    /// 大 `Collection` 直接写进 `#expect(a == b)` 时，判红不是判红而是**挂住**
    /// （swift-testing 会去求 `CollectionDifference`，本仓实测 200 秒 SIGALRM）。
    /// ⚠️⚠️ **对照组不是"不加 glassOrb"，这是本条最重要的一句。**
    ///
    /// 我的第一版写的是「加 vs 不加 `.glassOrb()`，位图必须不同」。**变异实测：它是假判据**
    /// —— 把 `coreDesignGlassOrb` 的函数体整个换成 `return layer.sample(position);`
    /// （整层被绕过）之后，那一版**照样绿**。原因是 `layerEffect` 本身会强制光栅化，
    /// 「加了 layerEffect」与「没加」的位图**本来就不同**，跟 shader 做了什么无关。
    /// ⇒ 那正是本仓反复栽的「判定通过而东西不工作」。
    ///
    /// ⇒ 改成**同一条公开 API、只换一个档位**：两侧都经过 `.glassOrb(...)`、都光栅化，
    /// 差异只能来自"倍率实参真的到了 shader"。同一枚变异下本条**当场判红**（实证见 PR 正文）。
    @Test("glassOrb 的倍率档位经公开 API 真的到达了 shader")
    func glassOrbMagnificationReachesTheShader() throws {
        let content = LinearGradient(
            colors: [.blue, .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 64, height: 64)

        // `.large` 档半径 72pt > 画布 ⇒ 整幅都在镜内，两档的差异铺满全图。
        let strong = try Self.render(content.glassOrb(size: .large, magnification: .strong))
        let gentle = try Self.render(content.glassOrb(size: .large, magnification: .gentle))

        #expect(strong.count == gentle.count)
        let magnificationMatters = strong != gentle
        #expect(magnificationMatters, """
        `.strong` 与 `.gentle` 两档渲出**逐字节相同**的结果 ⇒ 倍率实参没有到达 shader。
        先查 `.float(...)` 的实参位次是否与 `coreDesignGlassOrb` 的形参对得上
        （同为 `float` 时换序照样编译、照样不渲染），再查 `GlassOrbMagnification.factor`。
        """)
    }

    /// ⚠️⚠️ **两个「策略函数不是摆设」的证明，缺一不可。**
    ///
    /// `GlassOrbModifier` 的两个 `static` 纯函数（`focusPoint` / `softness`）各有一条
    /// 值级断言（在 `ContentEffectStopTests` 里），但**值算对了不等于 shader 真的用了它**
    /// ——`.float2(...)` / `.float(...)` 的实参位次一旦与 `[[stitchable]]` 形参错位，
    /// SwiftUI **不报错、只是不渲染**（本文件顶部注释里的那个失败面）。
    /// ⇒ 这里直接调 shader，把两个输入各自单独变一次，位图必须跟着变。
    ///
    /// ⚠️ **为什么不用 `.environment(\.accessibilityReduceMotion, …)` 走公开 API 那条路**
    /// （初版就是那么写的）：`accessibilityReduceMotion` / `accessibilityReduceTransparency`
    /// 在 `EnvironmentValues` 上**只有 getter**，`.environment(_:_:)` 要 `WritableKeyPath`
    /// ⇒ **编译不过**（实测 `error: cannot convert value of type 'any KeyPath<EnvironmentValues, Bool>
    /// & Sendable' to expected argument type 'WritableKeyPath<…>'`）。
    /// 本仓对 a11y 偏好的既有覆盖手法也正是「把判定抽成纯函数 + 单独证明 shader 吃了那个值」
    /// （`ProceduralBackground.elapsed` 是同一条）。
    @Test("glassOrb 的 focus 与 softness 都真的被 shader 吃进去了")
    func glassOrbConsumesFocusAndSoftness() throws {
        let atCentre = try Self.render(Self.smallOrb(focus: CGPoint(x: 32, y: 32), softness: 1))
        let atCorner = try Self.render(Self.smallOrb(focus: CGPoint(x: 8, y: 8), softness: 1))
        let focusMatters = atCentre != atCorner
        #expect(focusMatters, """
        换一个放大中心，位图一个像素都没变 ⇒ shader 没有吃 `focus`。\
        先查 `.float2(...)` 的实参位次是否与 `coreDesignGlassOrb` 的形参对得上\
        （同为 `float2` 时换序照样编译、照样不渲染）。
        """)

        let soft = try Self.render(Self.smallOrb(focus: CGPoint(x: 32, y: 32), softness: 1))
        let hard = try Self.render(Self.smallOrb(focus: CGPoint(x: 32, y: 32), softness: 0))
        let softnessMatters = soft != hard
        #expect(softnessMatters, """
        `softness` 从 1 改成 0，位图一个像素都没变 ⇒ Reduce Transparency 那条降级\
        （玻璃珠 → 均匀放大镜）在渲染上**什么都没发生**，\
        `GlassOrbModifier.softness(reduceTransparency:)` 的值级断言因此证明不了任何事。
        """)
    }

    /// ⚠️ **钉住「亮度 → 点半径」的方向，两条各挡一侧**：
    /// · 纯白必须**一个点都不落**（曾经的失效形态：`radius == 0` 时
    ///   `smoothstep(-aa, +aa, 0)` 在格心那一像素仍返回 0 ⇒ 覆盖度 1
    ///   ⇒ **白底上每格一个 1px 墨点**。抗锯齿把不存在的点画了出来）；
    /// · 纯黑必须**落满点**。
    /// 方向反过来（`mix(0, dotScale, lum)`）时两条同时判红。
    @Test("halftone：白处留白、黑处落墨")
    func halftoneInksDarkAndSparesLight() throws {
        let canvas = CGSize(width: 64, height: 64)

        let white = Color.white.frame(width: canvas.width, height: canvas.height)
        let black = Color.black.frame(width: canvas.width, height: canvas.height)

        // 对照：把纸色换成一个显然不同的颜色，证明 shader **真的在跑**。
        // 没有这一条，「白底上一种颜色」与「shader 静默没执行」不可分辨。
        let tinted = try Self.renderDense(white.halftone(dot: .coarse, ink: .black, paper: .green))
        let tintedTones = Set(tinted)
        #expect(tintedTones.count == 1, "纸色没有铺满：出现了 \(tintedTones.count) 种颜色")
        let paperWasApplied = tintedTones.first != Set(try Self.renderDense(white)).first
        #expect(paperWasApplied, "对照组与白底不可分辨 ⇒ halftone 可能根本没执行，下面两条都证明不了事")

        let printedWhite = Set(try Self.renderDense(white.halftone(dot: .coarse, ink: .black, paper: .white)))
        #expect(printedWhite.count == 1, """
        纯白内容上出现了 \(printedWhite.count) 种颜色 —— 半径为 0 的点被抗锯齿画了出来，\
        白底每格一个 1px 墨点。
        """)

        // ⚠️⚠️ **黑那一侧不能只问"有没有出现第二种颜色"** —— 变异实测（把
        // `mix(max(dotScale,0), 0, luminance)` 反写成 `mix(0, max(dotScale,0), luminance)`）
        // 时那种写法**照样绿**：`ImageRenderer` 在 64×64 色块的**边界**会渲出抗锯齿的
        // 半透明像素，它们的亮度不是 0，方向反过来之后正好在那一圈落点 ⇒ 「出现了第二种颜色」
        // 由边界像素平凡满足，与画面主体是否落墨无关。
        // ⇒ 改问**落墨面积占比**：黑底必须大面积落墨，白底必须一点都没有。
        let blackInk = Self.darkFraction(try Self.renderDense(
            black.halftone(dot: .coarse, ink: .black, paper: .white)
        ))
        #expect(blackInk > 0.25, """
        纯黑内容的落墨面积只有 \(blackInk) —— 亮度到点半径的映射方向反了\
        （黑处应当落满点）。
        """)

        let whiteInk = Self.darkFraction(try Self.renderDense(
            white.halftone(dot: .coarse, ink: .black, paper: .white)
        ))
        #expect(whiteInk == 0, "纯白内容上落了 \(whiteInk) 的墨 —— 白处应当一点都不落")
    }

    /// ⚠️⚠️ **本条守的是「柔化真的消除了硬边」，不是「柔化到达了 shader」。**
    ///
    /// 两者差一整个失效面，而本 PR 的第一版只有后者
    /// （`glassOrbConsumesFocusAndSoftness` 证明 `softness` 从 1 改成 0 位图会变）：
    /// **变异实测** —— 把 `coreDesignGlassOrb` 里的衰减项写成上游 Inferno 的
    /// `+= smoothstep(...) * 0.5`（那个 `0.5` 与它自己 `zoomFactor: 2` 的默认值配套，
    /// 而本仓的三档是 1.6 / 2.4 / 4.0，**没有一档是 2**）之后，
    /// 三档在边界处各留一道 4.5 / 6 / 15 px 的源位移接缝
    /// （gentle 档甚至**反向缩小**），而**当时全套 35 条判据一条都没红**。
    ///
    /// ⇒ 判据形态：沿**过焦点的水平射线**读边界内外相邻像素。
    /// · `softness == 1`（默认）：边界内侧必须与**未变形的原图**几乎逐像素重合，
    ///   且跨边界的灰阶跳变不得比原图自身在同一位置的跳变大多少 —— 那才叫"没有硬边"。
    /// · `softness == 0`（Reduce Transparency 档）：**反过来断言接缝存在**
    ///   —— 那一档要的正是"硬边镜片"。⚠️ 这一半同时是 Reduce Transparency 降级的
    ///   **行为判据**：没有它，`softness(reduceTransparency:)` 的值级断言只说明
    ///   "算出了 0"，说明不了"0 在画面上意味着什么"。
    ///
    /// ⚠️ 用 `.regular` 档（半径 44）+ 200×200 画布是刻意的：焦点默认落在正中 (100, 100)
    /// ⇒ 边界恰好在 **x = 144**，内外两侧都留足了背景。
    @Test("glassOrb：softness == 1 时边界无缝、softness == 0 时边界是硬边",
          arguments: GlassOrbMagnification.allCases)
    func glassOrbSofteningClosesTheSeam(_ magnification: GlassOrbMagnification) throws {
        // 数组下标 0 → x = 140；边界内侧最后一像素 x = 143 是下标 3，外侧第一像素 x = 144 是下标 4。
        let xs = 140...148
        let plain = try Self.greyRow(Self.seamProbe, y: 100, xs: xs)

        // ① 默认（softness == 1）走**公开 API**：`.regular` 档半径就是 44，
        //    手势未发生 ⇒ 焦点是画布正中，与下面裸调 shader 的那一组参数完全同构。
        let softened = try Self.greyRow(
            Self.seamProbe.glassOrb(size: .regular, magnification: magnification),
            y: 100, xs: xs
        )
        #expect(plain.count == softened.count)

        // 边界内侧紧邻的三像素：柔化档在这里必须已经衰减回"原样透过"。
        let innerDrift = (1...3).map { abs(softened[$0] - plain[$0]) }.max() ?? 0
        #expect(innerDrift <= 3, """
        \(magnification) 档在边界内侧仍偏离原图 \(innerDrift) 个灰阶（本底斜率约 1.3 灰阶/px）\
        ⇒ 变焦没有在边界处衰减回 1，圆的内外接不上。
        实测行 x=140…148：原图 \(plain) / 加镜 \(softened)。
        ⚠️ 先查 `coreDesignGlassOrb` 的衰减项是不是被写回了上游的 `+= smoothstep(...) * 0.5`\
        —— 那个常数只在 `magnification == 2.0` 时成立，本仓一档都不是 2。
        """)

        // 跨边界的跳变：必须与原图自身在同一位置的跳变相当。
        let seam = abs(softened[4] - softened[3])
        let baseline = abs(plain[4] - plain[3])
        #expect(abs(seam - baseline) <= 2, """
        \(magnification) 档跨边界跳变 \(seam) 灰阶，而原图同处只跳 \(baseline) 灰阶 ⇒ 出现硬边。
        实测行 x=140…148：原图 \(plain) / 加镜 \(softened)。
        """)

        // ② 反恒真对照 + Reduce Transparency 档的行为判据：softness == 0 时接缝**必须存在**。
        let hard = try Self.greyRow(
            Self.rawOrb(
                Self.seamProbe,
                focus: CGPoint(x: 100, y: 100),
                radius: GlassOrbSize.regular.radius,
                magnification: magnification.factor,
                softness: 0
            ),
            y: 100, xs: xs
        )
        let hardDrift = (1...3).map { abs(hard[$0] - plain[$0]) }.max() ?? 0
        #expect(hardDrift >= 10, """
        `softness == 0` 时边界内侧只偏离原图 \(hardDrift) 个灰阶 ⇒ "取消柔化"在画面上什么都没发生，\
        上面那条"无缝"断言因此可能是恒真的（例如放大整个没生效）。
        实测行 x=140…148：原图 \(plain) / 硬边档 \(hard)。
        """)
    }

    /// ⚠️⚠️ **`halftone` 的三个 `float` 实参此前零渲染证明。**
    ///
    /// **变异实测**：把 `Halftone.swift` 里的 `.float(cell)` 与 `.float(angle)` **互换**
    /// ⇒ `cellSize = max(π/4, 1) = 1`（网格塌成 1pt）、`angle = 4 / 8 / 16 rad`
    /// （45° 网屏角完全消失）⇒ 效果被摧毁，而**当时全套 35 条判据一条都没红**。
    /// 原因：`halftoneInksDarkAndSparesLight` 的四条断言（含 `paperWasApplied` 对照）
    /// **在任何格宽 / 角度下都成立**，而 `HalftoneStopTests` 三条全是纯值级断言，
    /// 结构上看不见"值有没有到 shader"。
    ///
    /// ⇒ 本条与 `glassOrbMagnificationReachesTheShader` **同形**：同一条公开 API、只换档位。
    /// ⚠️ 判据取**最长墨条**而不是落墨面积占比——后者 `≈ π · (dotScale · (1 - lum))²`
    /// **与 `cell` 无关**，把格宽打成常数时它一点都不动（那正是上面那枚变异逃掉的路径）。
    @Test("halftone 的格宽档位经公开 API 真的到达了 shader")
    func halftoneCellSizeReachesTheShader() throws {
        let runs = try HalftoneDot.allCases.map { dot in
            try Self.maxInkRun(Self.midGrey.halftone(dot: dot, ink: .black, paper: .white))
        }
        #expect(runs.count == 3, "档位数变了（实际 \(runs.count)）—— 下面的关系断言要跟着复核")
        #expect(zip(runs, runs.dropFirst()).allSatisfy { $0 < $1 }, """
        三档的最长墨条不再随格宽递增：\(runs) ⇒ `cell` 没有到达 shader，或位次与
        `coreDesignHalftone` 的形参对不上（`cell` / `angle` / `dotScale` 同为 `float`，换序照样编译）。
        """)

        // 几何：中性灰下 `.coarse` 的墨点直径 = 2 · 0.64 · (1 - 0.5) · 16 ≈ 10.2pt。
        // ⚠️ 阈值取 8 而不是"大于 `.fine`"：单调性挡不住"三档一起塌成 1pt 网格"那种变异
        // （实测那时三档是 2 / 4 / 3 —— 单调性确实红了，但只是巧合地红，
        //  换一组档位就可能仍然递增）。这一条钉的是**绝对尺度**。
        let coarse = runs.last ?? 0
        #expect(coarse >= 8, """
        `.coarse`（格宽 16pt）的最长墨条只有 \(coarse)px，几何上应当约 10px ⇒ 网格塌了。
        三档实测：\(runs)。
        """)
    }

    /// ⚠️ **网屏角在渲染层面此前完全无覆盖**：`ContentEffectStopTests.screenAngleIsFortyFiveDegrees`
    /// 断言 `HalftoneModifier.screenAngle == .pi / 4`，而 `screenAngle` **就定义成 `.pi / 4`**
    /// ⇒ 它是纯变更探测器，证不了 45° 起了作用。
    ///
    /// ⇒ 本条两半：
    /// · **角度真的进了 shader**：同一组几何参数下 0 rad 与 π/4 的位图必须不同；
    /// · **modifier 传下去的就是 π/4**：公开 API 的位图必须与裸调 π/4 **逐字节相同**。
    /// ⚠️ 后一半是上面那枚"互换 `cell` 与 `angle`"变异的直接判据。
    /// ⚠️ 裸调那一侧的角度写**字面量** `.pi / 4` 而不是 `HalftoneModifier.screenAngle`
    /// —— 引用后者会让两侧一起漂移，判据对"角度被改掉"失明。
    @Test("halftone 的 45° 网屏角真的被 modifier 传了下去")
    func halftoneScreenAngleReachesTheShader() throws {
        let cell = HalftoneDot.coarse.cell
        let dotScale = HalftoneDot.coarse.dotScale

        let viaPublicAPI = try Self.renderDense(
            Self.midGrey.halftone(dot: .coarse, ink: .black, paper: .white)
        )
        let atFortyFive = try Self.renderDense(
            Self.rawHalftone(Self.midGrey, cell: cell, angle: .pi / 4, dotScale: dotScale)
        )
        let atZero = try Self.renderDense(
            Self.rawHalftone(Self.midGrey, cell: cell, angle: 0, dotScale: dotScale)
        )
        #expect(viaPublicAPI.count == atFortyFive.count)
        #expect(viaPublicAPI.count == atZero.count)

        let angleMatters = atFortyFive != atZero
        #expect(angleMatters, """
        0 rad 与 π/4 渲出**逐字节相同**的结果 ⇒ `angle` 实参没有到达 shader，
        下面那条"modifier 传的就是 π/4"因此是恒真的。
        """)

        let modifierPassesFortyFive = viaPublicAPI == atFortyFive
        #expect(modifierPassesFortyFive, """
        `View.halftone(dot: .coarse)` 的位图与"格宽 16 / 角度 π/4 / 点半径 0.64"的裸调**不一致**
        ⇒ `HalftoneModifier` 传下去的三个 `float` 里至少有一个不是它声称的那个值。
        先查 `.float(cell)` / `.float(angle)` / `.float(dotScale)` 的**位次**
        （三个同为 `float`，换序照样编译、照样不报错）。
        """)
    }

    // MARK: - Helpers

    /// 直接以给定的 `focus` / `radius` / `magnification` / `softness` 调 `coreDesignGlassOrb`，
    /// 绕开 `@State` 手势与只读的 a11y 环境。
    ///
    /// ⚠️ 与 `timeActuallyAdvances` 里直接调 `library.coreDesignPlasma` 是同一手法：
    /// 公开 API 那条路上，这两个输入一个来自私有 `@State`、一个来自只读的 a11y 环境，
    /// **都注入不了**；不绕过去的话这两条契约就是零覆盖。
    @MainActor
    private static func rawOrb(
        _ content: some View,
        focus: CGPoint,
        radius: CGFloat,
        magnification: Float,
        softness: Float
    ) -> some View {
        let library = ShaderLibrary.bundle(.module)
        return content.visualEffect { view, proxy in
            view.layerEffect(
                library.coreDesignGlassOrb(
                    .float2(proxy.size),
                    .float2(focus),
                    .float(radius),
                    .float(magnification),
                    .float(softness)
                ),
                maxSampleOffset: CGSize(width: radius, height: radius)
            )
        }
    }

    /// 直接以给定的 `cell` / `angle` / `dotScale` 调 `coreDesignHalftone`。
    ///
    /// ⚠️ **`angle` 在公开面上不可调**（`HalftoneModifier.screenAngle` 是 `static let`）
    /// ⇒ 「网屏角真的进了 shader」这条只能这样绕过去证。
    @MainActor
    private static func rawHalftone(
        _ content: some View,
        cell: CGFloat,
        angle: Float,
        dotScale: Float
    ) -> some View {
        let library = ShaderLibrary.bundle(.module)
        return content.visualEffect { view, proxy in
            view.layerEffect(
                library.coreDesignHalftone(
                    .float2(proxy.size),
                    .float(Float(cell)),
                    .float(angle),
                    .float(dotScale),
                    .color(.black),
                    .color(.white)
                ),
                maxSampleOffset: CGSize(width: cell, height: cell)
            )
        }
    }

    /// 200×200 的黑→白**水平**线性渐变。⚠️ 选它是因为像素值直接**编码「采样到的源 x」**
    /// （实测本底斜率约 1.3 灰阶/px）⇒ 「采样点被搬了多远」可以逐像素读出来，
    /// 而 `.blue → .white` 那种对角渐变读不出方向。
    @MainActor
    private static var seamProbe: some View {
        LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
            .frame(width: 200, height: 200)
    }

    /// 中性灰。⚠️ 半调的点半径 `= dotScale · (1 - luminance)`，取 0.5 让三档的点都**恰好半开**
    /// —— 纯黑会让点互相咬住、纯白一个点都不落，两端都量不出「格子有多大」。
    @MainActor
    private static var midGrey: some View {
        Color(white: 0.5).frame(width: 64, height: 64)
    }

    /// 取一条扫描线上指定 x 区间的**红通道**值（灰度内容上三通道等值）。
    private static func greyRow(_ view: some View, y: Int, xs: ClosedRange<Int>) throws -> [Int] {
        let (pixels, width, _) = try Self.rgbaPixels(view)
        return xs.map { Int(pixels[(y * width + $0) * 4]) }
    }

    /// 全图**水平**方向上最长的一段连续落墨像素。
    ///
    /// ⚠️ 这是「格子有多大」的直接量度：中性灰下每格落一个直径
    /// `2 · dotScale · (1 - lum) · cell` 点的墨点，⇒ 最长墨条 ≈ 该直径。
    /// ⚠️ **不能用落墨面积占比代替**：面积占比 `≈ π · (dotScale · (1 - lum))²`
    /// 只含 `dotScale`、**与 `cell` 无关** ⇒ 把 `cell` 打成常数时它一点都不动。
    private static func maxInkRun(_ view: some View) throws -> Int {
        let (pixels, width, height) = try Self.rgbaPixels(view)
        var longest = 0
        for y in 0..<height {
            var run = 0
            for x in 0..<width {
                if pixels[(y * width + x) * 4] < 128 {
                    run += 1
                    longest = max(longest, run)
                } else {
                    run = 0
                }
            }
        }
        return longest
    }

    /// `glassOrbConsumesFocusAndSoftness` 用的那一组固定参数（64×64 对角渐变、
    /// `.small` 半径、`.strong` 倍率）。⚠️ 数值与本条改写前逐字一致。
    @MainActor
    private static func smallOrb(focus: CGPoint, softness: Float) -> some View {
        Self.rawOrb(
            LinearGradient(colors: [.blue, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 64, height: 64),
            focus: focus,
            radius: GlassOrbSize.small.radius,
            magnification: GlassOrbMagnification.strong.factor,
            softness: softness
        )
    }

    /// 「落墨」的像素占比：红通道 < 128 即算落了墨。
    ///
    /// ⚠️ 取红通道而不是三通道平均是有意的——本判据只用在**灰度**内容上
    /// （黑 / 白 + 黑墨白纸），三个通道等值，取一个就够；换成彩色内容时本函数不适用。
    private static func darkFraction(_ packedRGB: [UInt32]) -> Double {
        guard !packedRGB.isEmpty else { return 0 }
        let dark = packedRGB.filter { (($0 >> 16) & 0xFF) < 128 }.count
        return Double(dark) / Double(packedRGB.count)
    }

    /// **逐像素**全扫描。⚠️ 与 `render(_:)`（每 4 像素取一个）分开是必需的：
    /// `#283` 要挡的失效形态是「每格中心一个 **1px** 墨点」，
    /// 隔 4 像素取样会整片错过它 —— 那正是本仓「判据看不见被测对象」那一族。
    private static func renderDense(_ view: some View) throws -> [UInt32] {
        let (bytes, width, height) = try Self.rgbaPixels(view)
        var out: [UInt32] = []
        out.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let o = (y * width + x) * 4
                out.append(
                    (UInt32(bytes[o]) << 16) | (UInt32(bytes[o + 1]) << 8) | UInt32(bytes[o + 2])
                )
            }
        }
        return out
    }

    /// 渲染并**锁定像素格式**后的位图：8-bit RGBA、premultipliedLast、device RGB、
    /// `bytesPerRow == width * 4`。
    ///
    /// ⚠️ **不要直接读 `cgImage` 的原生字节**（#261 第 1 轮 review）：`ImageRenderer`
    /// 产出的 `bitmapInfo` 随系统/设备而异（BGRA / ARGB / 灰度 / 16-bit 都可能），
    /// 按固定偏移取通道会误读甚至越界，测试因此变得偶发脆弱。仓库既有先例
    /// （`CoreControlStyleTintTests.averageColor`）的做法是先重绘到己方构造的
    /// `CGContext` 把格式钉死，再做采样——这里沿用同一写法，不另立平行模式。
    private static func rgbaPixels(_ view: some View) throws -> (pixels: [UInt8], width: Int, height: Int) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let cgImage = try #require(renderer.cgImage, "ImageRenderer 未产出图像")
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { throw RenderProbeError.noPixelData }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RenderProbeError.noPixelData
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels, width, height)
    }

    /// 只取 alpha 通道的全图网格扫描。⚠️ 与 `render(_:)` 分开是有意的：
    /// 后者取 RGB，对「alpha 被改坏」这一类缺陷天然不可见。
    private static func renderAlpha(_ view: some View) throws -> [UInt8] {
        // alpha 落在每像素第 4 个字节，是 `rgbaPixels` 里 `premultipliedLast` 钉死的，
        // 不再是对 `cgImage` 原生布局的假设。
        let (pixels, width, height) = try Self.rgbaPixels(view)
        var out: [UInt8] = []
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                out.append(pixels[(y * width + x) * 4 + 3])
            }
        }
        return out
    }

    /// ⚠️ **全图网格扫描，不是几个固定采样点**：初版用 6 个固定点会判红。
    /// ⚠️ 当时的触发者是 `Starfield`（**已随 #281 撤回**，别再去 grep 这个类型）
    /// ——而那不是 shader 的问题，是**星星按设计就稀疏**（只有一部分格子有星），
    /// 6 个点全落在空天区。任何稀疏效果都需要足够的采样密度才谈得上"输出随位置变化"，
    /// 所以这条设计**不随该件撤回而失效**。
    /// ⚠️ 修法是**加密采样**而不是放宽断言——放宽会让这条守卫对真正的"静默无渲染"失灵。
    private static func render(_ view: some View) throws -> [UInt32] {
        let (pixels, width, height) = try Self.rgbaPixels(view)
        var out: [UInt32] = []
        out.reserveCapacity(256)
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let o = (y * width + x) * 4
                out.append(
                    (UInt32(pixels[o]) << 16) | (UInt32(pixels[o + 1]) << 8) | UInt32(pixels[o + 2])
                )
            }
        }
        return out
    }

    private enum RenderProbeError: Error { case noPixelData }
}
#endif
