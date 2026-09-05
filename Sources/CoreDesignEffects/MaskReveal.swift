//
//  MaskReveal.swift
//  CoreDesignEffects
//
//  六种 mask reveal 转场共用的几何契约与绘制 /
//  The shared geometry contract behind the six mask-reveal transitions.
//

import CoreDesign
import SwiftUI

// MARK: - 为什么这一簇是「裁剪」而不是「遮罩」
//
// `#268` 的六种转场（iris / wipe / blinds / clock / glare / dissolve）在上游是
// **alpha 遮罩**：拿一个不透明色填出形状、`.mask { … }` 上去。本仓**不能**照抄，
// 有两条各自独立的硬理由：
//
// 1. ⚠️⚠️ **本仓没有"保证 α = 1"的可用颜色。**
//    · `Color.primary` / `Color.contentPrimary` **不是不透明的**——它们映射到系统
//      `label`，macOS 浅色外观下实测 α ≈ 0.8471（本 epic 已为此开 issue #276）。
//      拿它当遮罩，"完全揭示"那一端只揭示到 85%，而且**没有任何报错**：
//      转场看起来"能用"，只是内容永远偏淡一档。
//      ⚠️ **补一条平台限定**（#276 收尾时 iOS 腿实测）：0.8471 只是 macOS / AppKit
//      `labelColor` 的值；**iOS / UIKit 的 `label` 明暗两端实测 α = 1.0**
//      ⇒ 这条"只揭示到 85%"**只在 macOS 腿上成立**。本条的结论不变——一个
//      平台相关、未文档化的 α 不能当"保证 α = 1 的颜色"用。
//      登记在 `MaskOpaqueTokenTests.primaryAlphaIsPlatformDependent`。
//    · `Color.black` / `Color.white` / `Color(white: 1)` 是**颜色**写法里仅有的三种
//      能写死 α = 1 的形态，三者都被 `EffectsColorLiteralGuard` 判红（`hueNames` 含
//      `black` / `white`，`numericColorLabels` 含 `white`），且该守卫**至今没有例外
//      台账**——「用削弱判据来消化一个例外」正是它文件头点名禁止的 G-7 形态。
//      ⚠️⚠️ **上一版这里写「唯二」，那是个可被证伪的全称句，照录更正**（#276 终审 F3）：
//      **未填色的 `Shape`**（`.mask { Rectangle() }`）在遮罩里同样是 α = 1、且不含
//      任何颜色字面量 ⇒ 该守卫碰不到它（本轮 macOS 实测：明暗两端 `bare ==
//      mask { Rectangle() }` 均为 true）；仓内生产先例是 `Rating.swift` 的 `star(at:)`。
//      ⇒ 本条的**结论**不受影响（本簇根本不用遮罩），`Color.maskOpaque` 的必要性
//      也不受影响（那一族要的是 `Gradient(colors:)` / `MeshGradient` 的 `[Color]`，
//      未填色的 `Shape` 塞不进去）——但「唯二」这个措辞本身是假的。
//    · `ColorGrade` 资源色在 macOS `swift test` 下**全部解析为透明**（#275），
//      拿它当遮罩基色会让 macOS 腿上的每一条遮罩断言都测不到真东西。
//    ⚠️⚠️ **上一版这里写「三条路全堵死」，那句话是错的，照录更正**（终审 S-1）：
//      `EffectsColorLiteralGuard` 的扫描根**有意不含** `Sources/CoreDesign`
//      （`Tests/CoreDesignTests/EffectsColorLiteralGuard.swift` 扫的是
//      `GuardScanRoots.newTargetRoots`，只有 Effects / Charts）⇒ 在
//      `Sources/CoreDesign/Colors/` 加一个不透明基色 token（**不在四层色彩之内**）
//      再从 Effects 引用
//      **不会命中该守卫**，本仓已有现成先例：本文件用的 `Color.specularHighlight`
//      就是 `Sources/CoreDesign/Colors/FillColors.swift` 里的 `Color.white.opacity(0.45)`,
//      而 `CLAUDE.md` 也明写「缺少需要的语义 token，应在对应文件中补充新名称」。
//      #275 对这类字面量派生 token 同样不适用（它说的是资源色）。
//    ⇒ **正确的记账是**：遮罩路线**可行，只是代价更高** —— 要为它新开一个遮罩基色
//      token（**不在四层色彩之内**），且那个 token 的"α 恒为 1"本身还得有判据守着。
//      **选裁剪的真正理由是下面第 2 条——可判据性**。
//      别把本条读成"遮罩在本仓结构上不可能"。
//    ⚠️⚠️ **那个"更高的代价"现在已经付过了，本条第一句因此需要重读**（Issue #276）：
//      `Color.maskOpaque`（`Sources/CoreDesign/Colors/MaskColors.swift`）已经存在，
//      契约就是 α = 1，由 `MaskOpaqueTokenTests` 在明暗两端守着。⇒ 本仓**现在有**
//      一个"保证 α = 1"的可用颜色，上面那句「本仓没有」只对 #276 之前的树成立。
//      本簇**仍然选裁剪**，但理由只剩下面第 2 条（可判据性）与"硬边是可接受代价"，
//      不再包括"没有可用的不透明色"。
//    而**裁剪不涉及 alpha**：`clipShape` 是纯几何布尔运算，
//      揭示出来的像素就是内容原样的像素，不存在"揭示到 85%"这种状态。
//
// 2. **裁剪的判据可以是纯函数。** `Path.contains(_:)` 让"这一点此刻揭示了没有"
//    成为一个不经过渲染栈、两个平台一致、可穷举采样的布尔值
//    （见 `MaskRevealGeometryTests` 的单调性 / 覆盖 / 互异三条）。
//    alpha 遮罩只能靠位图比对，而位图比对在本仓已经反复被首帧伪影与
//    `ColorGrade` 透明问题咬过。
//
// ⚠️ 代价照录：**裁剪的边缘是硬的**，做不出上游那种羽化过渡。`glare` 的柔光带
// 因此是一层**叠加**（`Color.specularHighlight`，第 3 层 token）而不是遮罩的一部分
// ——叠加层的半透明是有意的装饰，不承载"揭示了多少"这个信息。

// MARK: - 恒等相位必须是**真的**恒等
//
// ⚠️⚠️ 自定义 `Transition` 的 `body(content:phase:)` 在被修饰视图的**整个生命周期**
// 里都生效——转场停住之后相位是 `.identity`，修饰器**并不会被摘掉**
// （`ParticleTransition` 已就同一件事记过账）。
// ⇒ 一个"裁到自身 bounds"的 `clipShape` 会**永久**改变这个视图：
// `Badge("PRO").shadow(radius: 12).transition(.iris)` 的阴影从此不见了，
// 而且是**转场结束之后**才不见——最难归因的那一类。
//
// ⇒ 本文件的解法分两段：
// · **最后 15%**（越过 `haloOnset`）：在已经算好的裁剪路径外**并上一圈向外张开的
//   外框**（`haloPath(progress:in:)` 的四条边），张开量按内容对角线走，只增不减；
// · **恒等相位本身**（`progress == 1`）：`path(for:in:)` 直接短路到 `openPath(in:)`,
//   余量是与内容尺寸**无关**的 `openReach`（一百万 pt）。
//
// ⚠️⚠️ **第二段是终审 I-2 补的，上一版这里写的是绝对句、而它是假的**：上一版恒等
// 相位也走 `haloPath`，余量恰好一条对角线 ⇒ 「裁剪对任何溢出内容都不再有任何作用」
// 只在**一条对角线以内**成立。实测（4×4 内容，恒等相位）：
// `contains(-4pt above) = true`、`contains(-30pt above) = false`
// ⇒ 20×20 的图标配 `.shadow(radius: 30)` 的阴影**转场结束之后仍被永久吃掉**。
// 同一限度也曾落在 Reduce Motion 上（`openPath` 的 `margin` 也是一条对角线）。
// 现在两处共用 `openReach`，判据
// `MaskRevealGeometryTests.identityClipsNothingRegardlessOfContentSize` 钉住实际阈值。
//
// ⚠️⚠️ **初版不是这么写的，把那次实测记在这里**：初版把整条裁剪路径**按中心
// 整体放大**（一条外轮廓，本以为可以躲开"两条恰好相邻的边被抗锯齿画出发丝缝"）。
// `revealGrowsMonotonically` 当场判红——**中心放大对非中心对称的几何族不是单调的**：
// `blinds` 的每条百叶、`dissolve` 的每个格子都有自己的中心，整体放大会把它们
// **推离** bounds 中心，于是一个原本落在某条百叶里的采样点会掉进两条百叶之间的缝里
// ⇒ 已经揭示的地方又被藏回去，用户看到的是最后 15% 一次闪烁。
// ⇒ 改回"并上外框"。发丝缝这一侧改用另一条办法：外框向内**压住 `seamBite` 一点点**
// （见该常量），两条边因此重叠而不是相邻。外框只增不减 ⇒ 单调性成立。
//
// 判据：`MaskRevealRenderTests.identityIsBytewiseIdentityEvenWithOverflow`
// ——被测内容**故意画到 bounds 之外**，恒等相位下必须与裸视图逐字节相同；
// `MaskRevealGeometryTests.revealGrowsMonotonically` ——上面那枚实测缺陷的常驻判据。

// MARK: - 几何族 / Geometry family

/// 六种 mask reveal 各自的几何参数。
///
/// ⚠️ **`glare` 与 `wipe` 共用同一条半平面数学，这是有意的、也照录在这里**：
/// 两者的差别是**默认角度**（`wipe` 水平、`glare` 斜掠）与**高光带**
/// （`glare` 在揭示边上骑一条 `Color.specularHighlight` 的柔光带，`wipe` 没有）。
/// 把 `glare` 单列成一种而不是"`wipe` 的一个参数"，是因为 `#251` 的计数单位是
/// 「一种 transition」且登记表按 `Host.member` 去重——`.glare` 与 `.wipe` 是
/// 调用方眼里两个不同的名字、两条不同的登记条目。
nonisolated enum MaskRevealKind: Equatable, Sendable {

    /// 圆形光圈从 `anchor` 向外张开。
    case iris(anchor: UnitPoint)

    /// 半平面沿 `radians` 方向扫过。
    case wipe(radians: Double)

    /// `count` 条横向百叶各自从自己的中线向上下张开。
    case blinds(count: Int)

    /// 从 12 点方向起的扇形扫针，`sign` 为 +1 顺时针 / −1 逆时针。
    case clock(sign: Double)

    /// 斜掠的半平面 + 骑在揭示边上的柔光带。
    case glare(radians: Double)

    /// 网格逐格随机浮现，每格边长 `cellSize`（pt）。
    case dissolve(cellSize: CGFloat)
}

/// 一次 `body` 求值里，两道裁决（Reduce Motion + 相位）算出的**全部结论**。
///
/// ⚠️ **抽成值类型的唯一理由是可测性**（与 `ParticleBurst` / `FullScreenTransitionPlan`
/// 同一条纪律）：`\.accessibilityReduceMotion` 在本仓的单测里注入不进去，
/// 而"降级降对了没有"必须能被机器观测 ⇒ 把它变成一个纯函数的返回值。
nonisolated struct MaskRevealPlan: Equatable, Sendable {

    /// 揭示进度，已钳到 `0...1`。**1 = 完全揭示（恒等相位）**。
    let progress: Double

    /// 裁剪几何。**`nil` ⇒ 遮罩全开**（Reduce Motion 降级形态）。
    let kind: MaskRevealKind?

    /// 内容自身的不透明度。运动路径上恒为 1（揭示完全由几何承担）；
    /// Reduce Motion 下等于 `progress`，转场退化成一次纯淡入淡出。
    let contentOpacity: Double

    /// 柔光带。**`nil` ⇒ 不画**（非 `glare` 的五种，以及 Reduce Motion 下的 `glare`）。
    let glare: MaskRevealGlare?
}

/// 柔光带的两个参数。
nonisolated struct MaskRevealGlare: Equatable, Sendable {
    /// 掠过方向（弧度）。
    let radians: Double
    /// 行程，`0...1`，与揭示进度同步。
    let travel: Double
}

// MARK: - 纯几何 / Pure geometry
//
// ⚠️ 全部 `nonisolated static`：判据要对**这条真曲线**求值，而不是在测试里重抄一遍
// 常量（`ParticleBurst` / `ConfettiBurst` / `ShineBand` 已就同一件事立过规矩）。

nonisolated enum MaskReveal {

    // MARK: 相位

    /// 相位 → **揭示**进度，落在 `0...1`。
    ///
    /// ⚠️ 与 `ParticleBurst.progress` 方向**相反**，别照抄：粒子转场量的是"离恒等有多远"
    /// （identity ⇒ 0），mask reveal 量的是"揭示了多少"（identity ⇒ **1**）。
    /// 恒等相位必须是 1，否则转场停住之后内容永远只露出一部分。
    ///
    /// ⚠️⚠️ **本函数的可达取值只有 `{0, 1}`**：`TransitionPhase` 是 3 case frozen enum
    /// （`willAppear` / `identity` / `didDisappear`，`value` 分别是 −1 / 0 / 1）。
    /// 中间进度**全部**来自 SwiftUI 对 `MaskRevealChrome.animatableData` 的插值
    /// ——不是本函数给的。⇒ 任何"喂一个 0.4 进去"的判据都走不到真实相位上，
    /// 只能算在插值那条链上（`MaskRevealRenderTests.chromeRevealsMidFlight`）。
    static func progress(phase: TransitionPhase) -> Double {
        1 - abs(phase.value)
    }

    /// 两道裁决的**唯一**汇合点：Reduce Motion 先，几何后。
    ///
    /// ⚠️ **刻意 `internal`**（同 `FullScreenTransitionPlan.resolve` 的理由）：
    /// 一旦 `public`，裸 `Bool` 参数 `reduceMotion` 就会命中 `BoolExemptionGuard`、
    /// 要求署名豁免并抬棘轮基线（`CoreDesignEffects` 当前是 0 条）。
    /// 判据走 `@testable import` 够用。
    ///
    /// ⚠️ **Reduce Motion 的降级不是 no-op**：遮罩全开 + 内容不透明度跟着进度走
    /// ⇒ 用户仍然看得到"这块内容出现 / 消失了"，只是不再有一条扫过去的边。
    /// 这正是 `#251` 给整簇定的「位移 / 旋转类降级为淡入淡出」。
    /// ⚠️ **形参叫 `isReduced` 而不是 `reduceMotion`，这是承重的**：
    /// `MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences` 只接受三种形态
    /// （`var reduceMotion` 声明 / `reduceMotion:` 实参标签 / `self.reduceMotion` 读取），
    /// 形参名与函数体里的每一次引用都会被它判红——而那条判据挡的正是
    /// 「去掉 `self.` 就绕过按字面子串计数」这个逃逸位，不该为本函数放宽它。
    /// ⇒ 整个文件里 `reduceMotion` 这个词只出现两次：`@Environment` 的声明，
    /// 与 `MaskRevealChrome` 里那一次 `self.reduceMotion` 读取。
    static func plan(kind: MaskRevealKind, progress: Double, isReduced: Bool) -> MaskRevealPlan {
        let clamped = progress.isFinite ? min(max(progress, 0), 1) : 0
        guard !isReduced else {
            return MaskRevealPlan(progress: clamped, kind: nil, contentOpacity: clamped, glare: nil)
        }
        var glare: MaskRevealGlare?
        if case .glare(let radians) = kind {
            glare = MaskRevealGlare(radians: radians, travel: clamped)
        }
        return MaskRevealPlan(progress: clamped, kind: kind, contentOpacity: 1, glare: glare)
    }

    // MARK: 恒等余量

    /// 裁剪路径开始向外张开的进度点。
    static let haloOnset: Double = 0.85

    /// `progress` → 余量张开量，`0...1`。
    static func halo(progress: Double) -> Double {
        guard progress > Self.haloOnset else { return 0 }
        return min(1, (progress - Self.haloOnset) / (1 - Self.haloOnset))
    }

    /// 外框向内压住内容边缘的量（pt）。
    ///
    /// ⚠️ **不是装饰参数**：外框的内边界若与 `kindPath` 在 `progress == 1` 时的外轮廓
    /// **恰好相邻**，抗锯齿会在 bounds 边界上画出一条发丝缝——而恒等相位是用户长期
    /// 看到的那一帧。让两者重叠一点点即可消除。
    static let seamBite: CGFloat = 1

    /// 恒等余量：内容 bounds 外一圈向外张开的外框。
    ///
    /// ⚠️ 四条边各是一个矩形、彼此**重叠**（左右两条压住上下两条的端点），
    /// 不是一个"外矩形挖掉内矩形"的环——后者要靠 even-odd 填充规则，
    /// 而它与 `kindPath` 并集之后会把重叠区域**挖穿**。
    static func haloPath(progress: Double, in rect: CGRect) -> Path {
        let reach = hypot(rect.width, rect.height) * CGFloat(Self.halo(progress: progress))
        var path = Path()
        guard reach > 0 else { return path }
        let bite = min(Self.seamBite, reach)
        let outer = rect.insetBy(dx: -reach, dy: -reach)
        path.addRect(CGRect(
            x: outer.minX, y: outer.minY, width: outer.width, height: reach + bite
        ))
        path.addRect(CGRect(
            x: outer.minX, y: rect.maxY - bite, width: outer.width, height: reach + bite
        ))
        path.addRect(CGRect(
            x: outer.minX, y: rect.minY, width: reach + bite, height: rect.height
        ))
        path.addRect(CGRect(
            x: rect.maxX - bite, y: rect.minY, width: reach + bite, height: rect.height
        ))
        return path
    }

    // MARK: 路径总入口

    /// 给定裁决结论与内容 bounds，算出这一帧的裁剪路径。
    ///
    /// ⚠️⚠️ **`progress >= 1` 与 `kind == nil` 两种情形都短路到 `openPath(in:)`，
    /// 这是终审 I-2 实测换来的**：上一版这两处的余量都是**按内容对角线派生**的
    /// （`haloPath` 的 `reach` 与 `openPath` 的 `margin`），于是「恒等相位是真的恒等」
    /// 只在**一条对角线以内**成立。实测：一个 4×4 的内容在恒等相位上
    /// `contains(-4pt above) = true` 而 `contains(-30pt above) = false`
    /// ⇒ 一个 20×20 的图标配 `.shadow(radius: 30)`、或任何溢出超过自身对角线的内容，
    /// **转场结束之后阴影仍被永久吃掉**——正是这段设计要消灭的那类缺陷，
    /// 只是把阈值从 0 抬到了一条对角线。
    /// ⇒ 现在这两端直接给一个与内容尺寸**无关**的余量（`openReach`）。
    /// ⚠️ 短路只发生在**端点**，不碰任何中间进度 ⇒ `haloPath` 那条随进度张开的曲线
    /// （以及它换来的单调性）原样保留，插值路径一个字都没动。
    ///
    /// ⚠️ **代价照录**（#291 第 2 轮 Sug-2）：「不碰中间进度」不等于"没有副作用"。
    /// `progress` 逼近 1 的那一段余量仍是 `hypot(w, h) * halo(progress)`
    /// （`progress = 0.99` 时 ≈ 0.93 条对角线），到 `progress == 1` 一步跳到 `openReach`
    /// ⇒ **超过一条自身对角线的溢出内容是在最后一帧一次性「弹」出来的，而不是渐显**
    /// （移除转场则在第一帧「弹」进去随即被裁）。这是选「端点短路、不碰插值」这条路线的
    /// **必然代价**，比上一版「转场结束后永久吃掉」严格更好，因此**有意不改实现**；
    /// 写在这里是为了让下一个人收到「转场收尾闪一下」的反馈时省一次归因。
    static func path(for plan: MaskRevealPlan, in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        guard plan.progress < 1, let kind = plan.kind else { return Self.openPath(in: rect) }
        var path = Self.kindPath(kind, progress: plan.progress, in: rect)
        path.addPath(Self.haloPath(progress: plan.progress, in: rect))
        return path
    }

    /// 遮罩全开的余量（pt）。**常数、与内容尺寸无关**——见 `path(for:in:)` 的裁决记录。
    ///
    /// ⚠️ 取一个大常数而不是 `CGRect.infinite`：后者的坐标是 `±CGFLOAT_MAX/2`，
    /// 进 `clipShape` 之后要经过一次仿射变换，量级本身就是光栅化器的退化输入。
    /// 一百万 pt 已经比任何可能的溢出（阴影半径、超出 bounds 的子视图）大若干个数量级。
    /// ⚠️ 因此「裁剪对溢出内容不再有作用」这句话仍然是**有界**的，只是界与内容脱钩了；
    /// 判据 `MaskRevealGeometryTests.identityClipsNothingRegardlessOfContentSize`
    /// 钉的正是这个实际阈值（对 160×120 / 60×24 / 4×4 三种尺寸各采到 `openReach * 0.9`,
    /// 恒等相位与 Reduce Motion 两条路都走）。
    static let openReach: CGFloat = 1_000_000

    /// 遮罩全开（Reduce Motion 降级 / 恒等相位）。
    static func openPath(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: -Self.openReach, dy: -Self.openReach))
    }

    static func kindPath(_ kind: MaskRevealKind, progress: Double, in rect: CGRect) -> Path {
        switch kind {
        case .iris(let anchor):
            Self.irisPath(anchor: anchor, progress: progress, in: rect)
        case .wipe(let radians), .glare(let radians):
            Self.wipePath(radians: radians, progress: progress, in: rect)
        case .blinds(let count):
            Self.blindsPath(count: count, progress: progress, in: rect)
        case .clock(let sign):
            Self.clockPath(sign: sign, progress: progress, in: rect)
        case .dissolve(let cellSize):
            Self.dissolvePath(cellSize: cellSize, progress: progress, in: rect)
        }
    }

    // MARK: 各族几何
    //
    // ⚠️ 六族的**共同契约**，三条都有判据钉着：
    // · `progress == 0` ⇒ 路径为空（一个像素都不揭示）；
    // · `progress == 1` ⇒ 路径**完全覆盖** `rect`（内容整块可见）；
    // · 揭示区域随 `progress` **单调不减**（不许出现"先露后藏"）。
    // 判据：`MaskRevealGeometryTests` 的 `nothingRevealedAtZero` /
    // `everythingRevealedAtOne` / `revealGrowsMonotonically`。

    /// 相邻块之间的重叠比例：`blinds` 的相邻百叶与 `dissolve` 的相邻格子在
    /// `progress == 1` 时互相压住这么多，而不是恰好相邻。
    ///
    /// ⚠️⚠️ **它今天没有任何判据守着，照录在此，别写成"承重"**（变异实证）：
    /// 上一版这里写「不写它，两条恰好相邻的边会被抗锯齿画出一条发丝缝」。
    /// 把它改成 `0` 重跑整簇判据 —— **零红**（`batch3.log` 的 M11；终审 I-4 后
    /// 判据数从 31 涨到 37，用 M-C 重跑一次仍是 `37 tests … passed`）。
    /// 成因清楚：裁剪路径按非零环绕规则求的是**并集区域**，相邻子路径的公共边
    /// 落在区域**内部**、根本不是区域边界，抗锯齿无从下手。那条"发丝缝"是
    /// **分别填充**多个形状时才有的现象，裁剪没有。
    /// ⇒ 保留它的理由降级为**浮点舍入的余量**（`rect.height / 7` 这类除不尽的带宽，
    /// 相邻块的边界坐标可能差若干 ulp）——这一条同样**未被观测到**，是防御性的。
    /// 若将来有人要删它，删掉之后本簇判据仍会全绿，这不构成"删得对"的证据；
    /// 要证伪它请直接量 `progress == 1` 时块与块交界处的光栅，而不是看这 31 条。
    static let seamOverlap: CGFloat = 0.02

    static func irisPath(anchor: UnitPoint, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let center = CGPoint(
            x: rect.minX + rect.width * anchor.x,
            y: rect.minY + rect.height * anchor.y
        )
        let radius = Self.reach(from: center, in: rect) * CGFloat(progress)
        guard radius > 0 else { return Path() }
        return Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
        ))
    }

    /// `center` 到 `rect` 最远角的距离——`iris` / `clock` 铺满内容所需的半径。
    ///
    /// ⚠️ 命名是 `reach(...)` 而不是 `radius(...)`：与 `ParticleBurst.reach` 同名同义，
    /// 读者不必在两处之间换一套词汇。
    static func reach(from center: CGPoint, in rect: CGRect) -> CGFloat {
        let dx = max(abs(center.x - rect.minX), abs(rect.maxX - center.x))
        let dy = max(abs(center.y - rect.minY), abs(rect.maxY - center.y))
        return hypot(dx, dy)
    }

    static func wipePath(radians: Double, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let direction = CGPoint(x: cos(radians), y: sin(radians))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let projections = Self.corners(of: rect).map {
            ($0.x - center.x) * direction.x + ($0.y - center.y) * direction.y
        }
        // ⚠️ 两端各留一丝余量：`progress == 1` 时切线必须**越过**最远角而不是压在它上面，
        // 否则那一角是否被覆盖取决于浮点比较的方向。
        let slack = hypot(rect.width, rect.height) * 0.005
        let start = (projections.min() ?? 0) - slack
        let end = (projections.max() ?? 0) + slack
        let cut = start + (end - start) * CGFloat(progress)
        let half = hypot(rect.width, rect.height)

        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + direction.x * along + normal.x * across,
                y: center.y + direction.y * along + normal.y * across
            )
        }
        var path = Path()
        path.move(to: point(start, -half))
        path.addLine(to: point(cut, -half))
        path.addLine(to: point(cut, half))
        path.addLine(to: point(start, half))
        path.closeSubpath()
        return path
    }

    static func corners(of rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
        ]
    }

    /// 百叶条数的下限——`0` / 负数会让整条转场退化成"什么都不揭示"。
    static let minimumBlindCount: Int = 1

    static func blindsPath(count: Int, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let bands = max(Self.minimumBlindCount, count)
        let bandHeight = rect.height / CGFloat(bands)
        let grow = CGFloat(progress) * (1 + Self.seamOverlap)
        var path = Path()
        for index in 0..<bands {
            let midY = rect.minY + bandHeight * (CGFloat(index) + 0.5)
            let half = bandHeight * 0.5 * grow
            path.addRect(CGRect(
                x: rect.minX, y: midY - half, width: rect.width, height: half * 2
            ))
        }
        return path
    }

    static func clockPath(sign: Double, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // ⚠️ 半径乘一个余量。**理由与 `seamOverlap` 同一份台账、同样今天没有判据守着**
        // （终审 I-4：变异 M-C 把 `seamOverlap` 改成 0，整簇 37 条判据零红）——
        // 它是**防御性的浮点余量**（半径恰好压在最远角上时，那一角的覆盖取决于浮点
        // 比较方向），不是被观测到过的缺陷。证伪方法见 `seamOverlap` 的注释。
        let radius = Self.reach(from: center, in: rect) * (1 + Self.seamOverlap)
        let sweep = sign * progress * 360
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + sweep),
            // SwiftUI 的 y 轴向下：`clockwise: false` 对应视觉上的顺时针。
            clockwise: sign < 0
        )
        path.closeSubpath()
        return path
    }

    /// `dissolve` 的默认格边长（pt）。
    ///
    /// ⚠️ **唯一来源是 `MaskRevealTransition.defaultCellSize`**（#291 第 2 轮 Copilot）：
    /// 上一版这里独立写了一个字面量 `24`，而 `.dissolve()` 的默认实参取的是那个
    /// `public` 常量 ⇒ 只改一处，「默认值」与「`.nan` / `<= 0` 的回落值」就会**静默分叉**
    /// （两条路都不报错，只是同一个 `.dissolve()` 在两个入口给出两种格子）。
    /// 判据：`MaskRevealGeometryTests.dissolveClampsDegenerateCellSize` 的 ② 段直接断言
    /// 回落值 `== MaskRevealTransition.defaultCellSize`。
    static let dissolveDefaultCellSize: CGFloat = MaskRevealTransition.defaultCellSize

    /// 一次转场最多画多少格。
    ///
    /// ⚠️ **退化输入的闸**：`cellSize` 传 `0.5` 而内容是全屏，不设上限会是**百万级**
    /// 的子路径，每帧重建一次——那不是"慢"，是卡死。超限时把格子放大到刚好落在
    /// 上限内，而不是拒绝绘制（转场必须仍然发生）。
    static let dissolveMaximumCells: Int = 2000

    /// 单格从开始浮现到完全浮现所占的进度窗口。
    static let dissolveCellSpan: Double = 0.35

    static func effectiveCellSize(_ requested: CGFloat, in rect: CGRect) -> CGFloat {
        let base = requested.isFinite && requested > 0 ? requested : Self.dissolveDefaultCellSize
        let area = rect.width * rect.height
        guard area > 0 else { return base }
        return max(base, sqrt(area / CGFloat(Self.dissolveMaximumCells)))
    }

    /// 第 `(column, row)` 格的浮现次序，`0..<1`。
    ///
    /// ⚠️ **确定性伪随机：全部由下标派生，不用 `random`**——否则每次重绘格子的次序都会变，
    /// 且判据无法复现（`ParticleBurst.particle(at:count:)` 已就同一件事立过规矩）。
    static func cellThreshold(column: Int, row: Int) -> Double {
        let mixed = (column &* 73_856_093) ^ (row &* 19_349_663)
        // ⚠️ **括号只为可读性，不是承重的——上一版这里写"承重"，是假事实，已实测证伪。**
        // 上一版写「Swift 里 `%` 比 `&` 结合得紧，去掉括号会先算
        // `0x7FFF_FFFF % 1000`（= 647）」——那是 **C 的**优先级。Swift 的 `&` 是
        // `MultiplicationPrecedence`，与 `%` **同级、左结合** ⇒ 去掉括号得到的仍是
        // `(mixed & 0x7FFF_FFFF) % 1000`。实测（`swiftc` 直接求值，column 7 / row 3）：
        // 带括号 206、不带括号 206，`equal=true`；把括号去掉重跑整簇判据，
        // `dissolve` 的三条全绿、位图无变化。
        // ⇒ 留括号是给从 C / C++ 过来的读者省一次查表，别再把它写成判据。
        return Double((mixed & 0x7FFF_FFFF) % 1000) / 1000
    }

    /// 单格在整体 `progress` 时刻自己的浮现进度。
    static func cellProgress(threshold: Double, progress: Double) -> Double {
        let start = threshold * (1 - Self.dissolveCellSpan)
        guard progress > start else { return 0 }
        return min(1, (progress - start) / Self.dissolveCellSpan)
    }

    static func dissolvePath(cellSize: CGFloat, progress: Double, in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0 else { return path }
        let side = Self.effectiveCellSize(cellSize, in: rect)
        let columns = max(1, Int((rect.width / side).rounded(.up)))
        let rows = max(1, Int((rect.height / side).rounded(.up)))
        let cellWidth = rect.width / CGFloat(columns)
        let cellHeight = rect.height / CGFloat(rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let filled = Self.cellProgress(
                    threshold: Self.cellThreshold(column: column, row: row), progress: progress
                )
                guard filled > 0 else { continue }
                let grow = CGFloat(filled) * (1 + Self.seamOverlap)
                let midX = rect.minX + cellWidth * (CGFloat(column) + 0.5)
                let midY = rect.minY + cellHeight * (CGFloat(row) + 0.5)
                path.addRect(CGRect(
                    x: midX - cellWidth * 0.5 * grow,
                    y: midY - cellHeight * 0.5 * grow,
                    width: cellWidth * grow,
                    height: cellHeight * grow
                ))
            }
        }
        return path
    }

    // MARK: 柔光带（只有 `glare` 用）

    /// 柔光带宽度相对内容对角线的比例。
    static let glareBandRatio: CGFloat = 0.22

    /// 柔光带的不透明度包络。
    ///
    /// ⚠️ **两端必须恒为 0**：`travel == 1` 是恒等相位（转场停住后长期停留的那一帧），
    /// 那里还留着一条高光就是**永久残留**；`travel == 0` 是内容尚未出现的那一端，
    /// 那里画高光等于凭空多出一道光。
    static func glareOpacity(travel: Double) -> Double {
        guard travel > 0, travel < 1 else { return 0 }
        return sin(travel * .pi)
    }

    /// 柔光带这一帧的形状。与 `wipePath` 用同一套 `(direction, normal)` 坐标，
    /// 因此它**必然**骑在揭示边上，而不是各算各的。
    static func glarePath(_ glare: MaskRevealGlare, in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let direction = CGPoint(x: cos(glare.radians), y: sin(glare.radians))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let diagonal = hypot(rect.width, rect.height)

        let projections = Self.corners(of: rect).map {
            ($0.x - center.x) * direction.x + ($0.y - center.y) * direction.y
        }
        let slack = diagonal * 0.005
        let start = (projections.min() ?? 0) - slack
        let end = (projections.max() ?? 0) + slack
        let cut = start + (end - start) * CGFloat(glare.travel)
        let band = diagonal * Self.glareBandRatio

        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + direction.x * along + normal.x * across,
                y: center.y + direction.y * along + normal.y * across
            )
        }
        // ⚠️ 光带**骑跨**揭示边（前后各半条），而不是整条躲在已揭示的一侧：
        // 掠光的观感来自"光先到、内容随后现出来"，整条落在身后就只是一道拖影。
        // 判据：`MaskRevealGeometryTests.glareBandRidesTheRevealEdge`
        // ——光带必须同时压住已揭示与未揭示两侧，两个方向都判红。
        var path = Path()
        path.move(to: point(cut - band / 2, -diagonal))
        path.addLine(to: point(cut + band / 2, -diagonal))
        path.addLine(to: point(cut + band / 2, diagonal))
        path.addLine(to: point(cut - band / 2, diagonal))
        path.closeSubpath()
        return path
    }
}

// MARK: - 绘制 / Drawing

/// 裁剪形状。**不读时间、不读相位**——只吃一个已经算好的 `MaskRevealPlan`，
/// 因此可以被单测钉在任意进度上求值。
struct MaskRevealShape: Shape {

    let plan: MaskRevealPlan

    func path(in rect: CGRect) -> Path {
        MaskReveal.path(for: self.plan, in: rect)
    }
}

/// 柔光带。**纯装饰**：`accessibilityHidden(true)` + `allowsHitTesting(false)`。
struct MaskRevealGlareBand: View {

    let glare: MaskRevealGlare

    var body: some View {
        let glare = self.glare
        GeometryReader { proxy in
            MaskRevealGlareShape(glare: glare)
                .fill(Color.specularHighlight)
                .blur(radius: min(proxy.size.width, proxy.size.height) * 0.06)
                .opacity(MaskReveal.glareOpacity(travel: glare.travel))
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct MaskRevealGlareShape: Shape {

    let glare: MaskRevealGlare

    func path(in rect: CGRect) -> Path {
        MaskReveal.glarePath(self.glare, in: rect)
    }
}

/// 转场的实际绘制。**非泛型**（只吃一个 `Double` 与一个值类型枚举）——
/// 与 `TriggerRelay` / `ParticleTransitionChrome` 同一条纪律：泛型进动画路径
/// 会带出 `capture of non-Sendable type 'T.Type'` 一族问题。
///
/// ## ⚠️⚠️ 为什么本类型必须 `Animatable`
///
/// `TransitionPhase` 是 **3 case frozen enum** ⇒ `MaskReveal.progress(phase:)` 的
/// **可达取值只有 `{0, 1}`**。若本类型只是普通 `ViewModifier`，SwiftUI 就只在这两个
/// 端点上求值它——用户看到的是"整块内容凭空出现"，中间那条扫过去的边**从未发生**，
/// 而三个真实相位的位图断言**照样全绿**（`ParticleTransition` 的 C-A 就是这枚缺陷，
/// 本簇是同一族机制，因此同一枚缺陷在这里同样是默认结果而不是意外）。
///
/// ⇒ 把 `progress` 声明为 `animatableData`：SwiftUI 在一次动画事务里把它从端点 A
/// 插值到端点 B 并**逐帧重求 `body`**，裁剪路径于是每帧拿到一个新的中间进度。
/// 判据：`MaskRevealRenderTests.chromeRevealsMidFlight`（把 SwiftUI 的插值步骤
/// 原样跑一遍，中间帧必须与"直接用中间进度构造"的 chrome 逐字节相同）。
///
/// ⚠️ **不用 `TimelineView` / `keyframeAnimator`**：`Transition` 拿不到任何时间源
/// ——它只被喂三个离散相位，既不知道调用方的 `withAnimation` 用了多长、什么曲线。
/// 自建时间线会与 SwiftUI 自己的转场时钟两套时序。`animatableData` 是唯一
/// "跟着 SwiftUI 的时钟走"的选项。
struct MaskRevealChrome: ViewModifier, Animatable {

    var progress: Double
    let kind: MaskRevealKind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }

    func body(content: Content) -> some View {
        let plan = MaskReveal.plan(
            kind: self.kind, progress: self.progress, isReduced: self.reduceMotion
        )
        return content
            .clipShape(MaskRevealShape(plan: plan))
            .opacity(plan.contentOpacity)
            .overlay {
                if let glare = plan.glare {
                    MaskRevealGlareBand(glare: glare)
                }
            }
    }
}
