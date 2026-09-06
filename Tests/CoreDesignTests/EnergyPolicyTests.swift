import Foundation
import SwiftParser
import SwiftSyntax
import SwiftUI
import Testing
@testable import CoreDesign

/// NFR-7 的**通用**能耗策略表（`#271` 下沉后住在 `CoreDesign`）。
///
/// ⚠️ **为什么这套判据必须住在 `CoreDesignTests` 而不是 `CoreDesignEffectsTests`**：
/// 下沉后这些类型是 `CoreDesign` 的公开面。留在 Effects 的测试里，等于
/// 「`CoreDesign` 自己的公开面由另一个 target 的测试来守」——
/// 那个 target 一旦被拆掉 / 被 skip，这一面就静默失守。
@Suite("NFR-7 能耗状态与渲染策略（#271 下沉）")
struct EnergyPolicyTests {

    /// ⚠️ **非前台两档 × 低电量两档必须逐格断言**：只测 `.background + 非低电量` 时，
    /// 把「停摆」写成「低电量优先」（`.background + lowPower ⇒ .reduced`）**不会红**
    /// —— 那正是"降错方向"的形态。
    @Test("后台 / 非活跃 ⇒ 停摆（含低电量）；前台低电量 ⇒ 降级；其余 ⇒ 满帧")
    func policyMapping() {
        #expect(EnergyState(scenePhase: .active, isLowPower: false).policy == .full)
        #expect(EnergyState(scenePhase: .active, isLowPower: true).policy == .reduced)
        for phase in [ScenePhase.inactive, .background] {
            #expect(EnergyState(scenePhase: phase, isLowPower: false).policy == .paused)
            #expect(EnergyState(scenePhase: phase, isLowPower: true).policy == .paused,
                    "\(phase) + 低电量给出的不是停摆 —— 能耗档位被降错了方向")
        }
    }

    @Test("注入值优先，`nil` 才从系统读")
    func injectionWinsOverSystem() {
        let injected = EnergyState.resolve(
            injectedScenePhase: .background, systemScenePhase: .active, lowPowerModeOverride: false
        )
        #expect(injected.scenePhase == .background, "注入的 scenePhase 没有盖过系统值 —— NFR-7 的判据整条落空")
        #expect(injected.policy == .paused)

        let fallback = EnergyState.resolve(
            injectedScenePhase: nil, systemScenePhase: .inactive, lowPowerModeOverride: false
        )
        #expect(fallback.scenePhase == .inactive, "注入 nil 时没有回落到系统值")

        let injectedLowPower = EnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, lowPowerModeOverride: true
        )
        #expect(injectedLowPower.policy == .reduced, "注入的低电量没有生效")
    }

    /// ⚠️ **`nil` 与 `false` 必须可区分**：`false` 是「有人明确注入了『不低电量』」，
    /// `nil` 才是「没人注入、去问系统」。这正是那个环境键是 `Bool?` 而不是 `Bool` 的理由
    /// —— 写成 `Bool` 的话本条无从表达。
    ///
    /// ⚠️⚠️ **运行期那一半在非低电量机器上没有区分力**（`#271` 第 2 轮终审 I-5，有变异实证）：
    /// 把 `?? ProcessInfo…` 改成 `?? false`（永不读系统）⇒ 在 `isLowPowerModeEnabled == false`
    /// 的机器上 `resolved.isLowPower == system` 恰好是 `false == false` ⇒ **本 suite 五条全绿**。
    /// CI 与开发机常态就是 `false`，所以那一半实际上只在低电量机器上才成立。
    /// ⇒ 「真的去问了系统」这句由下面的**语法树断言**钉住，它与机器的电量状态无关；
    /// 运行期断言留着，它在低电量机器上是真判据、在别的机器上是一致性检查。
    ///
    /// ⚠️ **语法树而不是字符串**（第 3 轮终审 I-2，评审有变异实证）：上一版比的是去空白后的
    /// **整文件子串** ⇒ 把表达式改成 `?? false`、但让**上方的文档注释**里留着那串字面量，
    /// 判据照绿。而那正是本仓最可能发生的形态 —— 紧邻的 `resolve` 文档本来就在转述这个表达式。
    /// 现在改为从 `resolve` 的函数体里取 `isLowPower:` 实参、断言它是
    /// `lowPowerModeOverride ?? ProcessInfo.processInfo.isLowPowerModeEnabled` 这个 `??` 表达式。
    @Test("`nil` 回落到系统读数（源码 + 运行期两条链）；`false` 注入 ⇒ 不读")
    func nilFallsBackToSystemButFalseDoesNot() throws {
        // 语法树这半是与机器电量状态无关的那半，见上面的实测登记。
        let sourceURL = GuardScanRoots.sourcesURL(of: "CoreDesign")
            .appendingPathComponent("Environment/EnergyPolicy.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let finder = ResolveLowPowerArgumentFinder()
        finder.walk(Parser.parse(source: source))
        // ⚠️ 找不到也要判红，不能"没找到 ⇒ 没违规 ⇒ 绿"。
        let argument = try #require(finder.lowPowerArgument,
                                    "在 `EnergyState.resolve` 里找不到 `isLowPower:` 实参 —— 判据无法工作，这不是「零违规」")
        // 只取实参**表达式**的 token 文本，注释与别处的死代码都进不来。
        let expression = argument.tokens(viewMode: .sourceAccurate).map(\.text).joined()
        #expect(expression == "lowPowerModeOverride??ProcessInfo.processInfo.isLowPowerModeEnabled", """
        `resolve` 的 `isLowPower:` 实参是 `\(expression)` —— 「没人注入就去问系统」这条断了。\
        ⚠️ 等价改写（如把 `ProcessInfo.processInfo` 提成局部量）也会判红：本条钉的是**这个表达式的形状**，\
        要改先来这里改，别让改动静默通过。
        """)

        let system = ProcessInfo.processInfo.isLowPowerModeEnabled
        let resolved = EnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, lowPowerModeOverride: nil
        )
        #expect(resolved.isLowPower == system, "注入 nil 时没有从 ProcessInfo 读 —— 默认值不是系统值")

        let explicitFalse = EnergyState.resolve(
            injectedScenePhase: .active, systemScenePhase: .active, lowPowerModeOverride: false
        )
        #expect(explicitFalse.isLowPower == false, "注入 false 被当成了 nil —— 两者必须可区分")
    }

    /// ⚠️⚠️ **承重：两道闸的顺序**。能耗闸必须压过 Reduce Motion 闸——反过来写的话，
    /// 开启「减弱动态效果」的用户恰好在系统规定该停摆的状态下拿到一个还在跑动画的层。
    /// 本仓出过一次「两个调用点各写一遍就写反了」的事故，`#271` 把它下沉正是为此。
    @Test("两道闸的顺序：能耗闸压过 Reduce Motion 闸")
    func energyGateOutranksReduceMotion() {
        // ⚠️ **`.inactive` 这一维不能省**：只测 `.background` 时，把 `presentation` 写成
        // 绕过 `policy`、直接判 `scenePhase == .background` 的形态照绿，
        // 而 `.inactive` 才是本仓登记了「可见窗口失焦」限度的那一档。
        for phase in [ScenePhase.background, .inactive] {
            for isLowPower in [true, false] {
                let paused = EnergyState(scenePhase: phase, isLowPower: isLowPower)
                for reduceMotion in [true, false] {
                    #expect(paused.presentation(reduceMotion: reduceMotion) == .hidden,
                            "\(phase) / lowPower=\(isLowPower) / RM=\(reduceMotion) 下没有整层不画 —— 能耗闸没有压过 RM 闸")
                }
            }
        }
        // ⚠️ **前台的低电量这一维同样不能省**：`.reduced` 仍要画，只是画得省。
        // 只测 `isLowPower: false` 时，把 `guard policy.drawsAnything` 收紧成
        // `guard policy == .full` ⇒ `active + lowPower ⇒ .hidden`（低电量下整层消失）
        // 而本 suite 全绿。
        for isLowPower in [true, false] {
            let active = EnergyState(scenePhase: .active, isLowPower: isLowPower)
            #expect(active.presentation(reduceMotion: true) == .resting,
                    "前台 / lowPower=\(isLowPower) / RM 开 ⇒ 应是静止帧，不是整层不画")
            #expect(active.presentation(reduceMotion: false) == .animated,
                    "前台 / lowPower=\(isLowPower) / RM 关 ⇒ 应是正常动")
        }
    }

    @Test("通用旋钮：停摆不画、低电量降帧、满帧不限速")
    func genericKnobs() {
        #expect(RenderPolicy.paused.drawsAnything == false)
        #expect(RenderPolicy.reduced.drawsAnything)
        #expect(RenderPolicy.full.drawsAnything)
        #expect(RenderPolicy.full.minimumInterval == nil, "满帧不该限速")
        #expect(RenderPolicy.reduced.minimumInterval == 1.0 / 15.0)
        #expect(RenderPolicy.paused.minimumInterval == nil)
    }
}

/// 从 `EnergyState.resolve` 的函数体里抠出 `EnergyState(…)` 调用的 `isLowPower:` 实参。
///
/// ⚠️ 只认**名为 `resolve` 的函数体内**的那个调用 —— 文件里别处的 `EnergyState(...)`
/// （包括注释、别的初始化）都不算。
private nonisolated final class ResolveLowPowerArgumentFinder: SyntaxVisitor {

    private(set) var lowPowerArgument: ExprSyntax?

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.text == "resolve", let body = node.body else { return .skipChildren }
        for call in body.tokens(viewMode: .sourceAccurate).compactMap({
            $0.parent?.as(FunctionCallExprSyntax.self)
        }) where call.calledExpression.trimmedDescription == "EnergyState" {
            for argument in call.arguments where argument.label?.text == "isLowPower" {
                self.lowPowerArgument = argument.expression
            }
        }
        return .skipChildren
    }
}
