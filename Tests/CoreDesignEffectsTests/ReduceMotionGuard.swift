import Foundation
import Testing

// ⚠️ **这条守卫是 #262 终审 I-4 的产物。**
//
// 我在任务记账里写过「环境注入 + 渲染断言在 macOS 单测里不可观测」，据此把两条 AC
// 记为"结构性做不到"。**那个理由不成立**——本仓的主流测试形态本来就是**源码扫描**
//（`BoolParameterScanner` 68 KB、`BoolExemptionGuard` 55 KB、`ComponentRegistryGuard`
// 60 KB…七条以上 SwiftSyntax 守卫），完全在 macOS 射程内。
//
// ⚠️⚠️ **上一版的头注释写「这条守卫若早就存在，第 1 轮的 Jump / Spray / Shine 三条
// 缺陷会被机器当场逮到」——第 3 轮终审 C-3 实测证伪了其中 Jump 那条。**
// 评审把第 1 轮的源码取出来逐字复现判据：Jump 的缺陷是「`offset` 门控了、
// `scaleEffect` 没门控」，而文件里 `accessibilityReduceMotion` 在、
// `reduceMotionFallback(` 也在 ⇒ **上一版守卫全绿放行**。
// 逮到的只有 Spray / Shine / Ping 三条（完全没有降级的那一类）。
//
// ⇒ 本版补上第三条判据 `everyMotionCallIsGated` 直取那个盲区：
//   **不走早退的文件，每一行运动变换都必须自带门控**。它对第 1 轮的 Jump 判红。
//
// ⚠️ 真正不可观测的只是**动画中间帧**（`ImageRenderer` 拍的是静态帧，本仓
// `ToastPresentationRenderTests` 已写死这条限度）。

@Suite("Reduce Motion 降级守卫")
struct MicroInteractionReduceMotionGuard {

    /// 会产生**运动**的 SwiftUI 变换。带 `(` 是为了避免匹配到注释里的裸词。
    ///
    /// ⚠️ 第 3 轮终审 I-5 补齐：上一版缺 `.symbolEffect(` / `position(` /
    /// `transformEffect(` / `matchedGeometryEffect(`——其中 `symbolEffect` 最可能被撞上
    /// （`Spray` 整篇在用 SF Symbol，`.bounce` 就是运动）。
    static let motionCalls = [
        "offset(", "rotationEffect(", "scaleEffect(", "rotation3DEffect(",
        "symbolEffect(", "position(", "transformEffect(", "matchedGeometryEffect(",
        // 第 5 轮终审 I5-1 补：这四个是"关键字看不见的运动"的入口。
        "Canvas(", "TimelineView(", "visualEffect(", "projectionEffect(",
    ]

    /// 走**降级形态 2**（保留淡入淡出 + 静止位移，不叠脉冲）的文件。
    ///
    /// ⚠️ **集中名单，不用文件内自证标记**（第 3 轮终审 I-5）：上一版只认文件里的
    /// `// RM-FORM-2:` 注释——任何人加一行注释即可放行，且那行长在**被审对象自己
    /// 文件里**，评审时没有集中位置能看见「谁又新领了一张豁免」。
    /// 本仓对同类问题的成法是集中豁免名单（`BoolExemptionGuard`）。
    /// 现在两边**双向差集**：新领一张豁免必须改本文件 ⇒ 在 diff 里必然可见。
    /// ⚠️ **`#252` 起本名单从 1 个变成 3 个**，形态 2 的定义随之被**明确**（而不是被放宽）：
    /// 「保留这个效果**长什么样**、只把运动去掉，且**不再叠透明度脉冲**」。
    /// · `Rise.swift` —— 保留淡入淡出，位移换成静止位移；
    /// · `Confetti.swift` —— 不放粒子，降级为**一次淡入淡出的静态庆祝层**（`#252` AC 逐字）。
    ///   它本身就是一次淡入淡出，再叠脉冲就是两次反馈；
    /// · `ProcessingSweep.swift` —— 三个常驻"处理中"效果把相位钉在
    ///   `ProcessingSweep.restingPhase` 上静止呈现。它们没有 trigger，
    ///   而 `OpacityPulse` 是 trigger 驱动的一次性反馈，形态上根本对不上。
    /// ⚠️ **`#253` 起本名单从 3 个变成 5 个**，形态 2 的定义仍是那两句（保留呈现、
    /// 去掉运动、不叠脉冲）：
    /// · `AnimatedMeshGradient.swift` —— 网格点钉在 `MeshDrift.restingPhase` 上**冻结**，
    ///   整层照常绘制（AC 逐字「冻结在某一帧」）。它是一块**背景面**，
    ///   叠透明度脉冲等于让底色一闪，形态上对不上；
    /// · `ParticleTransition.swift` —— 不放粒子、不缩放，**只留内容自身的淡入淡出**。
    ///   它本身就是一次淡入淡出，再叠 `OpacityPulse` 就是两次；且 `OpacityPulse`
    ///   吃的是 `TriggerRelay` 的计数，转场根本没有那个 trigger。
    /// ⚠️ **`#254` 新增两条**，两者都是"整块常驻呈现"、抹掉它等于把界面的一部分拿走：
    /// · `SphereSurface.swift` —— `DotSphere` / `CharSphere` 共用的驱动与绘制：
    ///   球照常画，只把自转相位与色波钉死在 `SphereField.restingPhase` /
    ///   `SphereField.restingWave(paletteCount:)` 上（与 `AnimatedMeshGradient`
    ///   的"冻结在某一帧"逐字同形）；
    /// · `OrbitingLogos.swift` —— 环、点、logo 与中心视图照常画，只把自转
    ///   （`OrbitRing.restingPhase`）与轮播（`OrbitRing.restingFeature` ⇒
    ///   `popScale == 1`，谁都不放大）钉死。
    /// 两者都不叠 `OpacityPulse`：它是 trigger 驱动的一次性反馈，而这两件没有 trigger。
    static let approvedFormTwo: Set<String> = [
        "Rise.swift", "Confetti.swift", "ProcessingSweep.swift",
        "AnimatedMeshGradient.swift", "ParticleTransition.swift",
        "SphereSurface.swift", "OrbitingLogos.swift",
    ]

    /// 走**早退**（RM 下整个装饰层不构建）的文件。
    ///
    /// ⚠️ **同样必须是集中名单**（第 4 轮终审 C4-2）：上一版只认文件里出现
    /// `guard !isReduced` 这个字符串——**那和我在同一个 commit 里刚铲掉的
    /// `// RM-FORM-2:` 自证标记是同一形态，只是伪装成了代码**。
    /// 任何人在文件任意位置写下一句 `guard !isReduced`（哪怕只包住一个局部函数），
    /// 整个文件的**每一处**运动调用就全部被豁免。评审实测过这枚变异：绿。
    static let approvedEarlyExit: Set<String> = [
        "Ping.swift", "Spray.swift", "Shine.swift",
        // `#252`：两者都在 Reduce Motion 下**换一整套呈现**（静态庆祝层 / 静止相位），
        // 而不是在原路径上逐处门控 ⇒ 走早退。
        "Confetti.swift", "ProcessingSweep.swift",
        // `#253`：两者都在 Reduce Motion 下**换一整套呈现**，而不是逐处门控。
        // · `AnimatedMeshGradient` 走 `switch presentation {`（与 `Confetti` 同一个
        //   共享裁决点：先能耗闸、再 RM 闸）；
        // · `ParticleTransition` 走 `guard !isReduced`（与 `Ping` / `Spray` / `Shine` 同形态）。
        "AnimatedMeshGradient.swift", "ParticleTransition.swift",
        // `#254`：两者都在 Reduce Motion 下**换一整套呈现**（静止相位），走
        // 与 `AnimatedMeshGradient` 同一个共享裁决点 `switch presentation {`
        //（先能耗闸、再 RM 闸）。
        "SphereSurface.swift", "OrbitingLogos.swift",
    ]

    /// 「整段换一套呈现」的三种写法。**文件必须同时在 `approvedEarlyExit` 名单上**
    /// ——单有标记不放行（第 4 轮终审 C4-2 立的规矩）。
    ///
    /// ⚠️ **第三种是 `#252` PR #269 第 2 轮终审 C-1 加的**：`Confetti.swift` 不再能写
    /// `guard !isReduced else { return AnyView(…) }`——那个形态给 `body` 造出了**两个**
    /// `AnyView` 出口，而出口选择依赖 `scenePhase` ⇒ 每次后台往返调用方内容子树换身份、
    /// 且 Reduce Motion 下的庆祝会重放。单出口的写法把两道闸的结论物化成
    /// `EffectsPresentation` 再 `switch`，**语义与早退等价**（整段换一套呈现、不逐处门控），
    /// 只是决策点从 `guard` 挪进了 `switch`。
    /// ⇒ 标记的**射程与 `guard` 一样窄**：`switch presentation {` 之后的代码才被豁免，
    /// 而三个 `switch` 分支本身仍在射程内（判据实测：往 `.resting` 分支加一处
    /// `.offset(x: 20)` 会被 `everyMotionCallIsGated` 判红）。
    static let earlyExitMarkers = [
        "guard !isReduced", "guard !self.reduceMotion", "switch presentation {",
    ]

    /// **确认不含运动**的文件。
    ///
    /// ⚠️⚠️ **分类必须 fail-closed**（第 5 轮终审 I5-1，评审有变异实证）：
    /// 上一版靠 8 个关键字**命中才算运动文件**，而 `Canvas` / `TimelineView` 里的
    /// 运动一个都不命中 ⇒ 用它们实现的效果**根本不进运动文件集合** ⇒ 三条 RM 判据
    /// 全部跳过它。评审建了一个 `TimelineView(.animation)` + `Canvas` 的摆动效果、
    /// **完全不读 `accessibilityReduceMotion`**：只有文件计数判红，改一个整数就全绿。
    /// ⚠️ 这不是假想——`250.md` 自己写着上游用 `KeyframeAnimator` / `PhaseAnimator` /
    /// `sensoryFeedback` / **`Canvas`**，而 #251–#255 还有 5 个效果 issue 排在这道护栏后面。
    /// ⇒ 反过来：**每个文件要么进运动集合、要么进本名单**，两者双向差集。
    static let approvedNoMotion: Set<String> = [
        "CoreDesignEffects.swift",      // 模块标识
        "MicroInteractionSupport.swift", // 档位枚举 + TriggerRelay + 降级基线
        "Haptic.swift",                  // 只有 sensoryFeedback，无视觉运动
        // `#252` 新增。
        // ⚠️ 两个可注入环境键**已不在本文件**：`#252` PR #269 把 `\.lowPowerModeOverride` /
        // `\.scenePhaseOverride` 下沉到 `CoreDesign/Environment/EnergySignalEnvironment.swift`
        //（终审 S-2）。本文件现在只剩 Effects 侧的语义档位与策略枚举。
        "EffectsEnergy.swift",           // NFR-7 的能耗档位 + 纯策略/呈现枚举，无绘制
        // ⚠️ 下面三个是**薄封装**：`body` 只有一行 `content.overlay { ProcessingSweepDriver(...) }`，
        // 运动全部在 `ProcessingSweep.swift` 里（那份在早退名单 + 形态 2 名单上）。
        // "文件里没有运动关键字"这一条在这里**不是**逃逸位——
        // `ProcessingSweepTests.containersDelegateToDriver` 逐个断言这三个文件里
        // 既出现 `ProcessingSweepDriver(`、又不出现任何自建动画/绘制调用，
        // 两条判据合起来才堵住"容器自建一套、绕过降级"这个洞。
        "ScanningOverlay.swift",
        "GlowSweep.swift",
        "LightSweep.swift",
        // `#253` 新增。
        // ⚠️ `TypewriterText.swift` —— 逐字揭示**确实不含**位移 / 旋转 / 缩放：
        // 它只是把 `Text` 的内容从前缀换成更长的前缀（全文层 `opacity(0)` 做尺寸底稿，
        // 布局不动）。FR-11 约束的是运动，这里没有。它的 RM 降级（直接显示完整文本）
        // 由纯函数 `TypewriterReveal.plan(total:typed:reduceMotion:)` +
        // `TypewriterTextTests.reduceMotionIsOnlyConsumedByTheRevealGate`（调用点逐次计数）
        // + `TypewriterTextTests.planIsTheOnlyThingBodyHandsDown`（闸的两个**出口**）
        // 三条判据接管——与本守卫 `reduceMotionIsOnlyConsumedByTheSharedGate` 同形态。
        // ⚠️ **上一版这里写的是 `revealedCount(total:typed:reduceMotion:)`，那个符号已不存在**
        //（#253 PR #273 终审 S-1）：它正是被本 PR 的 M2 那次修复改名成 `plan(...)` 的
        // ⇒ 一条豁免的理由指向了一个 grep 不到的符号。豁免理由必须指向活着的符号。
        // ⚠️ 上一版只列两条判据，也漏了「闸的输出」那一半——终审 I-1 实测：把
        // `revealed: plan.revealed` 改成 `revealed: total`，打字机效果整个消失而 7/7 全绿。
        //
        // ⚠️⚠️ `BeforeAfterSlider.swift` —— **这一条不是「它不动」**，必须读清楚：
        // 入场摆动会让分隔线滑过去。它进本名单的理由与上面三个薄封装**同型**——
        // 本文件里一个 `motionCalls` 关键字都不出现（揭示宽度与把手位置全部由
        // **布局宽度**给出，见 `BeforeAfterSliderBody` 的类型文档：分隔线位置是
        // FR-12 逐字要求保留的「用户手势驱动的空间输入」，给它加 `isReduced` 三元
        // 在语义上是错的，真分支填什么都不对）。
        // ⇒ 「文件里没有运动关键字」在这里**不是**逃逸位，由两条判据合起来堵：
        // · `BeforeAfterSliderTests.sliderPositionsByLayoutNotByTransform`
        //   —— 逐个断言本文件不含任何 `motionCalls` 关键字（本豁免的前提本身）；
        // · `BeforeAfterSliderTests.reduceMotionIsOnlyConsumedByTheSweepGate`
        //   —— `reduceMotion` 只许喂给 `BeforeAfterSweep.introSweep(reduceMotion:)`。
        // 哪天有人往里加一处 `offset(`，第一条当场判红，逼人回来重新分类。
        "TypewriterText.swift",
        "BeforeAfterSlider.swift",
        // `#254` 新增。分两类，理由各不相同：
        //
        // ① **纯几何 / 纯裁决**，一行 SwiftUI 都没有：
        "SphereField.swift",             // Vogel 螺旋 + 透视投影 + 色波，纯算术
        "OrbitRing.swift",               // 同心环几何 + 解析挤压位移场，纯算术
        "FullScreenTransitionPlan.swift", // 两个 Bool 进、一个枚举出的裁决函数
        //
        // ② **薄封装**：`body` 只有一句 `SphereSurface(mark:…)`，运动全部在
        //    `SphereSurface.swift` 里（那份同时在早退名单与形态 2 名单上）。
        //    ⚠️ 「文件里没有运动关键字」在这里**不是**逃逸位——
        //    `CrossPlatformRenderTests.spheresDelegateToSharedSurface` 逐个断言这两个
        //    文件里既出现 `SphereSurface(`、又不出现任何自建动画 / 绘制 / 能耗闸调用，
        //    两条判据合起来才堵住"薄封装自建一套、绕过降级"这个洞（形态同
        //    `ProcessingSweepTests.containersDelegateToDriver`）。
        "DotSphere.swift",
        "CharSphere.swift",
        //
        // ③ ⚠️⚠️ `FullScreenButton.swift` —— **这一条不是「它不动」**，必须读清楚：
        //    点开时卡片会几何匹配地放大成整屏，那当然是运动。它进本名单的理由是
        //    **那次运动整个发生在系统的导航转场里**：本文件一个 `motionCalls` 关键字
        //    都不出现（放大由 `.navigationTransition(.zoom(sourceID:in:))` 驱动，
        //    位移 / 缩放没有一处写在本仓代码里），因此三条 RM 判据对它无话可说。
        //    ⇒ 「文件里没有运动关键字」在这里同样**不是**逃逸位，由两条判据合起来堵：
        //    · `PlatformSupportGuard.reduceMotionIsOnlyConsumedByTheTransitionPlan`
        //      —— `reduceMotion` 只许喂给 `FullScreenTransitionPlan.resolve(...)`；
        //    · `PlatformSupportGuard.zoomIsFencedToIOS`
        //      —— `.zoom(` 只许出现在 `#if os(iOS)` 里，且必须由 `plan` 门控。
        //    哪天有人往里加一处 `offset(`，`everyFileIsClassified` 与
        //    `motionFilesReadReduceMotion` 当场判红，逼人回来重新分类。
        "FullScreenButton.swift",
    ]

    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/CoreDesignEffectsTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // 仓库根
            .appendingPathComponent("Sources/CoreDesignEffects")
    }

    /// ⚠️ **递归枚举**（第 3 轮终审 I-5）：上一版用 `contentsOfDirectory` 不递归，
    /// 把任一效果文件挪进子目录（本仓 `Sources/CoreDesign/Components/*/` 就是这么组织的）
    /// 它就不再被扫描，而计数阈值仍然通过 ⇒ 静默逃逸。
    static func swiftFiles() throws -> [URL] {
        let root = Self.sourceRoot
        // ⚠️ **fail-closed**：目录不存在时必须判红，不能"零文件 ⇒ 零违规 ⇒ 绿"。
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory)
        #expect(exists && isDirectory.boolValue,
                "扫描根不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
        guard exists, let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return [] }
        return e.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 去掉 `//` 行注释，避免注释里的示例代码被当成真调用。
    ///
    /// ⚠️ **已知：不处理 `/* */` 块注释与字符串字面量**。方向是 **fail-closed**
    /// （块注释里的 `offset(` 只会造成误报，不会漏报），故不修；写在这里免得
    /// 下一个人以为它处理了。实测本 target 当前无块注释。
    static func stripComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let r = line.range(of: "//") else { return String(line) }
                return String(line[line.startIndex..<r.lowerBound])
            }
            .joined(separator: "\n")
    }

    static func motionFiles() throws -> [(URL, String)] {
        try Self.swiftFiles().compactMap { url in
            let code = Self.stripComments(try String(contentsOf: url, encoding: .utf8))
            return Self.motionCalls.contains(where: { code.contains($0) }) ? (url, code) : nil
        }
    }

    @Test("凡产生运动的效果文件，都必须读 accessibilityReduceMotion")
    func motionFilesReadReduceMotion() throws {
        let offenders = try Self.motionFiles()
            .filter { !$0.1.contains("accessibilityReduceMotion") }
            .map(\.0.lastPathComponent)
        #expect(offenders.isEmpty, "这些文件有运动变换却没读 Reduce Motion：\(offenders)")
    }

    @Test("凡产生运动的效果文件，都必须走两种被批准的降级形态之一")
    func motionFilesDegradeConsistently() throws {
        let offenders = try Self.motionFiles()
            .filter { !$0.1.contains("reduceMotionFallback(")
                      && !Self.approvedFormTwo.contains($0.0.lastPathComponent) }
            .map(\.0.lastPathComponent)
        #expect(offenders.isEmpty,
                "这些文件有运动却既不调 reduceMotionFallback、也不在形态 2 名单里：\(offenders)")
    }

    /// ⚠️⚠️ **直取上一版的盲区：部分门控**（第 3 轮终审 C-3）。
    ///
    /// 「有 `accessibilityReduceMotion`、也有 `reduceMotionFallback(`」不代表**每一处**
    /// 运动都被门控——第 1 轮的 Jump 正是「`offset` 门控了、`scaleEffect` 没门控」，
    /// 上一版守卫对它全绿。这是本 issue 已经真实发生过一次、也最可能再次发生的形态。
    ///
    /// 判据：**不走早退**（没有 `guard !isReduced`）的文件，每一行含运动变换的代码
    /// 都必须自带门控标记（`isReduced` / `reduceMotion`）。走早退的文件整段已被挡在
    /// RM 之外，逐行门控没有意义。
    @Test("不走早退的文件，每一处运动变换都必须自带门控")
    func everyMotionCallIsGated() throws {
        var offenders: [String] = []
        for (url, code) in try Self.motionFiles() {
            // ⚠️ **早退只豁免 `guard` 之后的代码**（第 4 轮终审 C4-3）：
            // 上一版 `continue` 掉整个文件 ⇒ 把运动加进 **RM 降级分支内部**
            //（`guard` 的 `else { }` 块里）三条判据无一命中。评审实测：往 Shine 的
            // 降级分支加 `.rotationEffect(15°).offset(x: 20)` ⇒ 绿。
            // 那是在 Reduce Motion **开启**的路径上加运动，FR-11 的正面违反，
            // 也正是本 issue 前三轮反复出问题的方向。
            let name = url.lastPathComponent
            let guardEnd: Int? = Self.approvedEarlyExit.contains(name)
                ? Self.earlyExitBodyStart(in: code)
                : nil
            for (call, args, line) in Self.motionCallArguments(in: code) {
                // 只有落在早退 `guard` **之后**的调用才被豁免。
                if let end = guardEnd, Self.offset(ofLine: line, in: code) > end { continue }
                // ⚠️ **只看该调用自己的实参**（配对括号提取），不看行、也不看窗口。
                // 逐行会把跨行调用误判（`.scaleEffect(` 的门控写在后续实参行上）；
                // 而窗口会被**紧邻的另一个已门控调用**骗过——第 1 轮的 Jump 正是
                // `.scaleEffect(未门控)` 紧接着 `.offset(y: isReduced ? …)`，
                // 6 行窗口把后者的门控算给了前者 ⇒ 放行。实测过这两种失败。
                guard args.contains("isReduced") || args.contains("reduceMotion") else {
                    offenders.append("\(url.lastPathComponent):\(line) \(call)… [无门控]")
                    continue
                }
                // ⚠️⚠️ **还要看极性**（第 5 轮终审 I5-2，评审有变异实证）：
                // 上一版只查「关键字在场」⇒ 把 `isReduced ? phase.offsetY * d : 0`
                //（**只有 Reduce Motion 开启时才有位移**，FR-11 的字面反面）判绿。
                // ⇒ 三元的**真分支**必须是恒等字面量。
                if let q = args.firstIndex(of: "?"), let c = args[q...].firstIndex(of: ":") {
                    let trueBranch = args[args.index(after: q)..<c]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    // ⚠️ 判据是「**不引用动画状态**」而不是「必须是恒等字面量」——
                    // 后者会把**形态 2** 的静止位移误判（`Rise` 的
                    // `isReduced ? -reach * 0.5 : state.lift`，真分支有意是常量位移
                    // 而非 0）。实测过一次误红才定下这个写法。
                    // 本判据同时覆盖三种情况：恒等值 ✓、静止位移 ✓、
                    // 「门控成了另一个动画值」✗（第 5 轮终审 I5-2 与 S-1 的盲区一并堵上）。
                    let animationRefs = ["state.", "phase.", "progress", "turns"]
                    if let bad = animationRefs.first(where: { trueBranch.contains($0) }) {
                        offenders.append("\(url.lastPathComponent):\(line) \(call)… "
                                         + "[Reduce Motion 分支引用了动画状态 `\(bad)`："
                                         + "`\(trueBranch)` —— 极性反了或门控成了另一个动画值]")
                    }
                }
            }
        }
        #expect(offenders.isEmpty, "这些运动变换没有被 Reduce Motion 门控：\n\(offenders.joined(separator: "\n"))")
    }

    /// 早退 `guard` 语句**结束**（其 `else { }` 块闭合）后的字符偏移。
    /// 返回 `nil` 表示文件里没有早退。
    static func earlyExitBodyStart(in code: String) -> Int? {
        let chars = Array(code)
        for marker in Self.earlyExitMarkers {
            guard let r = code.range(of: marker) else { continue }
            var k = code.distance(from: code.startIndex, to: r.lowerBound)
            // 走到 `else {` 的那个 `{`，再配对到它的 `}`。
            while k < chars.count, chars[k] != "{" { k += 1 }
            var depth = 0
            while k < chars.count {
                if chars[k] == "{" { depth += 1 }
                else if chars[k] == "}" {
                    depth -= 1
                    if depth == 0 { return k }
                }
                k += 1
            }
        }
        return nil
    }

    /// 1-based 行号 → 字符偏移。
    static func offset(ofLine line: Int, in code: String) -> Int {
        var offset = 0, current = 1
        for ch in code {
            if current >= line { break }
            offset += 1
            if ch == "\n" { current += 1 }
        }
        return offset
    }

    /// 提取每个运动调用**自身的实参文本**（配对括号），连同起始行号。
    static func motionCallArguments(in code: String) -> [(call: String, args: String, line: Int)] {
        let chars = Array(code)
        var result: [(String, String, Int)] = []
        for call in Self.motionCalls {
            var searchStart = code.startIndex
            while let r = code.range(of: call, range: searchStart..<code.endIndex) {
                let openIndex = code.index(before: r.upperBound)   // 指向 "("
                let openOffset = code.distance(from: code.startIndex, to: openIndex)
                var depth = 0
                var k = openOffset
                while k < chars.count {
                    if chars[k] == "(" { depth += 1 }
                    else if chars[k] == ")" {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    k += 1
                }
                let args = String(chars[openOffset...min(k, chars.count - 1)])
                let line = code[code.startIndex..<r.lowerBound].filter { $0 == "\n" }.count + 1
                result.append((call, args, line))
                searchStart = r.upperBound
            }
        }
        return result
    }

    /// 走 NFR-7 能耗闸的文件（**双向差集**，新增一个必须改本文件）。
    ///
    /// 判据见 `reduceMotionIsOnlyConsumedByTheSharedGate`。
    ///
    /// ## 当前规则（下一个件照这条判，后面的《沿革》只是它怎么来的）
    ///
    /// 1. **进不进名单只看一件事：有没有可停的常驻装饰层**（`TimelineView` /
    ///    常驻调度器持续驱相位的那一层）。有 ⇒ 进；没有 ⇒ 不进，进来只会白挨一道闸。
    /// 2. **`.none` 的语义是「一个*装饰*像素都不画」**。一个件若同时画装饰与
    ///    **调用方的内容**，`.none` 分支摘掉的是装饰层与调度器，**内容层静态留下**
    ///    （`OrbitingLogos` 走 `OrbitLayers.contentOnly`）——把调用方的内容藏掉
    ///    不是停摆、是 bug。
    /// 3. ⚠️ **「画内容」不是排除在名单外的理由**（第 2 轮终审 I-E）：收窄之后它
    ///    **不再蕴含**「排除在闸外」，`OrbitingLogos` 就是反例（画内容且**在**名单里）。
    ///
    /// 当前名单：`Confetti` / `ProcessingSweep` / `AnimatedMeshGradient` /
    /// `SphereSurface`（`DotSphere` / `CharSphere` 共用）/ `OrbitingLogos`。
    /// 有意**不在**名单里的：`TypewriterText`（有限时长的一次性揭示）、
    /// `BeforeAfterSlider`（入场摆动一次性，其余是静止图 + 手势）、
    /// `ParticleTransition`（转场由 SwiftUI 驱动，瞬态）、
    /// `FullScreenButton`（一次性导航转场，无常驻调度器）——四件的共同点是**规则 1**：
    /// 全文件无 `TimelineView`、无常驻调度器，**没有可停的装饰层**。
    /// 判据：`CrossPlatformRenderTests.pausedKeepsCallerContentInOrbitingLogos`
    /// + `orbitPresentationBranchesAreWiredCorrectly` ①
    /// + `accessibilityHiddenStaysOnTheDecorationLayer`。
    ///
    /// ## 沿革（历史，读到这里就够了；下面只解释规则怎么变成现在这样）
    ///
    /// ⚠️⚠️ **登记一条本守卫看不见的方向**（#252 PR #269 第 4 轮终审 S2-3）：
    /// 扫描根固定为 `Sources/CoreDesignEffects`（`sourceRoot`）⇒ 若把一个**常驻渲染件**
    /// 落在 `Sources/CoreDesign`，它走不走能耗闸本守卫一概看不见。这不是本轮能修的
    /// ——它是 issue #271 那条残余（NFR-7 的通用策略表仍在 `CoreDesignEffects`，
    /// `shipswift-shaders` 的 B-2 只能在"import 整个 Effects product"与"自己再派生
    /// 一份"之间二选一）的**判据侧**同一枚硬币：只要策略表没下沉，
    /// `CoreDesign` 侧的常驻渲染件就既不共用那张表、也不进这个扫描根。
    /// ⇒ **B-2 落件时与 #271 一并裁决**：策略表下沉到哪一层，扫描根就跟到哪一层。
    /// 本轮只留痕，不改扫描根（现在 `CoreDesign` 里没有常驻渲染件，改了也只是空跑）。
    /// ⚠️ **`#253` 加入 `AnimatedMeshGradient.swift`**：它是本 target 第三个
    /// **常驻渲染件**（`TimelineView` 持续驱相位），与 `ScanningOverlay` / `Confetti` 同类。
    /// 另外三个新件**有意不在这里**，理由逐条写在各自的类型文档里：
    /// · `TypewriterText` —— 有限时长的一次性揭示，打完就没有调度器；
    /// · `BeforeAfterSlider` —— 入场摆动是一次性的，其余时间是静止图 + 手势；
    /// · `ParticleTransition` —— 转场由 SwiftUI 驱动，瞬态。
    /// 后两者还有同一条硬理由：能耗闸的 `.none` 语义是「一个像素都不画」，
    /// 而它们画的是**内容**，把内容隐藏不是停摆、是 bug。
    /// ⚠️ **上面这句已于下一段（`#254`）收窄，别再照它判新件**：收窄之后「画内容」
    /// 不再蕴含「排除在闸外」，那两件现在的理由是"没有可停的常驻装饰层"。
    /// 现行规则见本文档开头的《当前规则》。
    ///
    /// ⚠️⚠️ **上面这条规则在 `#254` 的 `OrbitingLogos` 上被收窄了一次，记在这里**
    ///（PR #274 终审 C-1）：`OrbitingLogos` **同时**画装饰（四圈点环，常驻渲染，该停）
    /// 与**调用方的内容**（`logo(item)` / `center`，两者有意不 `accessibilityHidden`）。
    /// 「进名单 ⇒ 整层不建」与「画内容 ⇒ 不许藏」在它身上正面撞车，而当时选的是前者
    /// ⇒ macOS 上一失焦（`.inactive`，**窗口完全可见**）宿主 App 的品牌 logo 与全部
    /// 合作方 logo 就从窗口里消失。
    /// ⇒ 规则收窄为：**`.none` 的语义是「一个*装饰*像素都不画」**。一个既画装饰又画
    /// 内容的件仍然进名单（装饰该停），但它的 `.none` 分支摘掉的是装饰层与调度器，
    /// 内容层静态留下（`OrbitingLogos` 走 `OrbitLayers.contentOnly`）。
    /// 纯内容件（`BeforeAfterSlider` / `ParticleTransition`）仍然整个不进名单——
    /// 它们没有可停的常驻装饰层，进来只会白挨一道闸。
    /// 判据：`CrossPlatformRenderTests.pausedKeepsCallerContentInOrbitingLogos`
    /// + `orbitPresentationBranchesAreWiredCorrectly` ①。
    /// ⚠️ **`#254` 加入两条**：`SphereSurface`（`DotSphere` / `CharSphere` 共用）与
    /// `OrbitingLogos` 都是**常驻渲染件**（`TimelineView` 持续驱相位），与
    /// `AnimatedMeshGradient` 同类。
    /// ⚠️ 第四件 `FullScreenButton` **有意不在这里**：它是一次性的导航转场（点一下才发生），
    /// 没有任何常驻调度器；它的 Reduce Motion 降级由纯函数
    /// `FullScreenTransitionPlan.resolve(reduceMotion:platformSupportsZoom:)` +
    /// `PlatformSupportGuard.reduceMotionIsOnlyConsumedByTheTransitionPlan`
    ///（调用点逐次计数，与本条 ② ③ 同形态）两条判据接管。
    static let energyGatedFiles: Set<String> = [
        "Confetti.swift", "ProcessingSweep.swift", "AnimatedMeshGradient.swift",
        "SphereSurface.swift", "OrbitingLogos.swift",
    ]

    /// ⚠️⚠️ **第 2 轮终审 I-A 的判据**（#252 PR #269）。
    ///
    /// `EffectsEnergyStateTests.energyGateOutranksReduceMotion` 是**纯函数判据**，钉的是
    /// `presentation(reduceMotion:)` **函数体内**的顺序。**调用点是否真的用这个结论**
    /// 是另一条链，而它此前**零覆盖**——终审逐条实测过：
    /// · 位图路不可能覆盖：`\.accessibilityReduceMotion` 不可注入，测试里恒为 `false`，
    ///   `presentation == .resting` 与 `self.reduceMotion` 两种写法渲染**逐字节相同**；
    /// · 三条字符串守卫（`timelineOnlyExistsDuringBurst` /
    ///   `reduceMotionFallsBackToStaticCelebration` / 本 suite 原有三条）在变异后**全绿**。
    /// ⇒ 把 `Confetti` 的 `let isReduced = presentation == .resting` 改回
    /// `let isReduced = self.reduceMotion`，**I-1 原封不动回来而全套测试仍绿**。
    ///
    /// ⇒ 本条直接守调用点：**凡走能耗闸的文件，读到的 `\.accessibilityReduceMotion`
    /// 只许喂给 `EffectsEnergyState.presentation(reduceMotion:)` 这一个裁决点**，
    /// 一次都不许另作他用。任何"自己再拿它判一次"的写法（`let isReduced = self.reduceMotion`、
    /// `self.reduceMotion ? .resting : .animated`、`guard !self.reduceMotion`…）
    /// 都会让 `self.reduceMotion` 的出现次数多于喂给纯函数的次数 ⇒ 判红。
    ///
    /// ⚠️ **射程只到走能耗闸的文件**：`Ping` / `Spray` / `Jump` 这些 trigger 驱动的一次性
    /// 微交互**没有**能耗闸（它们不是常驻渲染件），`let isReduced = self.reduceMotion`
    /// 在那边是正确写法。这也正是那句"让它不可能被重新引入"要收窄的地方——
    /// 纯函数判据只管函数体内，调用点这一环由本条接管。
    @Test("走能耗闸的文件：reduceMotion 只许喂给 presentation(reduceMotion:) 这一个裁决点")
    func reduceMotionIsOnlyConsumedByTheSharedGate() throws {
        let scanned = try Self.swiftFiles().map { url -> (String, String) in
            (url.lastPathComponent, Self.stripComments(try String(contentsOf: url, encoding: .utf8)))
        }
        // ① 名单与实际**双向差集**：新增一个走能耗闸的效果必须来改本文件。
        //
        // ⚠️⚠️ **必须去空白后再匹配**（#252 PR #269 第 4 轮终审 S2-3，评审有变异实证）：
        // 上一版直接 `contains("EffectsEnergyState.resolve(")`，这对**新增文件**是
        // **fail-open** —— 一个新文件把调用写成跨行的
        // `EffectsEnergyState\n    .resolve(`，它既不进 `actual`、也不在 `energyGatedFiles`
        // 里 ⇒ 两个集合仍然相等 ⇒ ① 判绿，而下面 ② 的循环**根本不对它执行**
        // ⇒ 它在调用点里怎么二次消费 `reduceMotion` 都没人看得见。
        //（已经在名单里的文件这么写会判红——那个方向本来就是对的，漏的只有新增文件。）
        let actual = Set(scanned.filter { entry in
            entry.1.filter { !$0.isWhitespace }.contains("EffectsEnergyState.resolve(")
        }.map(\.0))
        #expect(actual == Self.energyGatedFiles,
                "走能耗闸的文件名单 \(Self.energyGatedFiles.sorted()) 与实际 \(actual.sorted()) 不一致")

        // ② 每个这样的文件里，`self.reduceMotion` 的每一次出现都必须正好是喂给纯函数那一次。
        for (name, code) in scanned where Self.energyGatedFiles.contains(name) {
            let reads = code.components(separatedBy: "self.reduceMotion").count - 1
            let fed = code.components(separatedBy: "presentation(reduceMotion: self.reduceMotion)")
                .count - 1
            #expect(fed >= 1,
                    "\(name) 没有把 reduceMotion 喂给 EffectsEnergyState.presentation(reduceMotion:) —— 两道闸的顺序在这个调用点上又变成各写一遍了")
            #expect(reads == fed,
                    "\(name) 里 `self.reduceMotion` 出现 \(reads) 次，但只有 \(fed) 次是喂给 presentation(reduceMotion:) 的 —— 多出来的那些是调用点自己又判了一遍 Reduce Motion，能耗闸会被绕过（I-1 的原形态）")

            // ③ ⚠️⚠️ **形态断言：堵掉「去掉 `self.` 就逃逸」**
            //（#252 PR #269 第 4 轮终审 S2-2，评审有变异实证）。
            //
            // ② 数的是**字面子串** `self.reduceMotion` ⇒ 把调用点写成
            // `let isReduced = reduceMotion`（去掉 `self.`，Swift 完全合法——
            // property wrapper 不强制 `self.`）⇒ `reads` 仍是 1、`fed` 仍是 1
            // ⇒ ② **判绿**，而 I-1 的原形态原封不动回来了。
            //
            // ⚠️ 「同类型内也显式写 `self.`」是本仓 `CLAUDE.md` 的成文风格约定，
            // 但**没有任何机器在守它**（无 SwiftLint 规则、无编译器诊断）
            // ⇒ 这是一个实打实的逃逸位，不是理论上的。
            //
            // ⇒ 本条把 ② 依赖的那个前提**自己钉住**：能耗闸文件里，词边界意义上的
            // `reduceMotion` 只许以三种形态出现——`var reduceMotion` 声明、
            // 实参标签 `reduceMotion:`、以及 `self.reduceMotion` 读取。裸写一律判红。
            //（`accessibilityReduceMotion` 里是大写 `R`，词边界匹配天然不会命中它。）
            let strays = Self.bareReduceMotionOccurrences(in: code)
            #expect(strays.isEmpty,
                    "\(name) 里这些 `reduceMotion` 既不是声明、也不是实参标签、更不是 `self.reduceMotion`：\n\(strays.joined(separator: "\n"))\n—— 去掉 `self.` 就能绕过上面按字面子串的计数，把 I-1 原样放回来")
        }
    }

    /// 能耗闸文件里**裸写**的 `reduceMotion`（返回 `行号: 该行源码`，1-based）。
    ///
    /// 词边界意义上的每一处 `reduceMotion`，只接受三种形态：
    /// · `var reduceMotion` —— `@Environment(\.accessibilityReduceMotion)` 声明本身；
    /// · `reduceMotion:` —— 实参标签（`presentation(reduceMotion: …)`）；
    /// · `self.reduceMotion` —— 读取。
    /// 其余一律登记：`let isReduced = reduceMotion`、`reduceMotion ? … : …`、
    /// `guard !reduceMotion` …——这些正是 `reduceMotionIsOnlyConsumedByTheSharedGate`
    /// 的 ② 按字面 `self.reduceMotion` 计数时看不见的形态。
    ///
    /// ⚠️ 吃的是**已去注释**的源码（调用点传的就是 `stripComments` 的结果），
    /// 否则文档注释里的 `presentation(reduceMotion:)` 会被当成真调用。
    /// `stripComments` 逐行处理、保留行数 ⇒ 这里的行号与原文件对得上。
    static func bareReduceMotionOccurrences(in code: String) -> [String] {
        func isIdentifierChar(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        let needle = "reduceMotion"
        var out: [String] = []
        for (index, rawLine) in code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(rawLine)
            var searchStart = line.startIndex
            while let r = line.range(of: needle, range: searchStart..<line.endIndex) {
                searchStart = r.upperBound
                // 词边界：前后都不能再是标识符字符。
                if r.lowerBound > line.startIndex,
                   isIdentifierChar(line[line.index(before: r.lowerBound)]) { continue }
                if r.upperBound < line.endIndex, isIdentifierChar(line[r.upperBound]) { continue }
                let prefix = line[line.startIndex..<r.lowerBound]
                if prefix.hasSuffix("var ") { continue }                              // 声明
                if r.upperBound < line.endIndex, line[r.upperBound] == ":" { continue } // 实参标签
                if prefix.hasSuffix("self.") { continue }                             // 读取
                out.append("\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        return out
    }

    /// 早退名单同样做**双向差集**——新领一张豁免必须改本文件 ⇒ 在 diff 里必然可见。
    @Test("早退名单与实际一致（双向差集）")
    func earlyExitListMatchesReality() throws {
        let actual = Set(try Self.motionFiles()
            .filter { code in Self.earlyExitMarkers.contains(where: { code.1.contains($0) }) }
            .map(\.0.lastPathComponent))
        #expect(actual == Self.approvedEarlyExit,
                "早退名单 \(Self.approvedEarlyExit.sorted()) 与实际 \(actual.sorted()) 不一致")
    }

    /// 形态 2 名单与实际使用**双向差集**——名单里有、文件却没走形态 2（或反之）都判红。
    @Test("形态 2 名单与实际一致（双向差集）")
    func formTwoListMatchesReality() throws {
        let files = try Self.motionFiles()
        let actual = Set(files
            .filter { !$0.1.contains("reduceMotionFallback(") }
            .map(\.0.lastPathComponent))
        #expect(actual == Self.approvedFormTwo,
                "形态 2 名单 \(Self.approvedFormTwo.sorted()) 与实际 \(actual.sorted()) 不一致")
    }

    /// ⚠️⚠️ **替代那句被证伪的「回退即编译失败」**（第 3 轮终审 C-2）。
    ///
    /// 我在测试注释与 commit 里写过：把 `TriggerRelay` 删掉、泛型直接进动画 modifier，
    /// **回退即编译失败**。评审把那枚变异真建出来跑了——`-swift-version 6`
    /// `-default-isolation MainActor` 下只得到一条
    /// `warning: capture of non-Sendable type 'T.Type' in an isolated closure`，
    /// **Build complete、测试全绿**。而 CI 没开 `-warnings-as-errors`
    /// ⇒ 那条 warning 不构成机器判据，只构成「希望下一个人注意到」。
    ///
    /// `IsolatedTrigger` 真正钉住的是**另一枚**变异（给 `T` 加 `Sendable` 约束 ⇒ 编译红）。
    /// 「泛型直接进动画 modifier」这枚由本判据接管：**效果的 `*Core` ViewModifier 不得泛型**。
    @Test("效果的 Core ViewModifier 不得是泛型（泛型必须停在 TriggerRelay）")
    func coreModifiersAreNotGeneric() throws {
        var offenders: [String] = []
        for (url, code) in try Self.swiftFiles().map({ ($0, Self.stripComments(try String(contentsOf: $0, encoding: .utf8))) }) {
            for line in code.split(separator: "\n") where line.contains("Core<") && line.contains("struct ") {
                offenders.append("\(url.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        let detail = offenders.joined(separator: "\n")
        #expect(offenders.isEmpty,
                "这些 Core modifier 是泛型 —— 泛型应停在 TriggerRelay：\n\(detail)")
    }

    /// ⚠️ **防假绿**：上面几条在"零文件"或"判据失配"时都会静默变绿。
    ///
    /// ⚠️ 阈值取**实际数**而非下界（第 3 轮终审 I-5）：`>= 9` 在文件从 10 个变成 9 个
    /// （被挪进子目录）时仍然通过，留了一格逃逸位。
    /// ⚠️ **fail-closed 分类**：每个文件要么被判为含运动、要么在 `approvedNoMotion` 里。
    /// 新增一个用 `Canvas` 画运动、又不在名单里的文件 ⇒ **判红**，而不是静默跳过。
    @Test("每个源文件都必须被分类（含运动 / 确认无运动），不留第三种")
    func everyFileIsClassified() throws {
        let all = Set(try Self.swiftFiles().map(\.lastPathComponent))
        let motion = Set(try Self.motionFiles().map(\.0.lastPathComponent))
        let unclassified = all.subtracting(motion).subtracting(Self.approvedNoMotion)
        #expect(unclassified.isEmpty,
                "这些文件既没被判为含运动、也不在 approvedNoMotion 名单里：\(unclassified.sorted())")
        let stale = Self.approvedNoMotion.subtracting(all)
        #expect(stale.isEmpty, "approvedNoMotion 里有已不存在的文件：\(stale.sorted())")
        let contradiction = Self.approvedNoMotion.intersection(motion)
        #expect(contradiction.isEmpty, "这些文件在无运动名单里，却被判为含运动：\(contradiction.sorted())")
    }
}
