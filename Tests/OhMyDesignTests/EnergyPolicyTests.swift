import Foundation
import SwiftParser
import SwiftSyntax
import SwiftUI
import Testing
@testable import OhMyDesign

@Suite("NFR-7 能耗状态与渲染策略（#271 下沉）")
struct EnergyPolicyTests {
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

    @Test("`nil` 回落到系统读数（源码 + 运行期两条链）；`false` 注入 ⇒ 不读")
    func nilFallsBackToSystemButFalseDoesNot() throws {
        let sourceURL = GuardScanRoots.sourcesURL(of: "OhMyDesign")
            .appendingPathComponent("Environment/EnergyPolicy.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let finder = ResolveLowPowerArgumentFinder()
        finder.walk(Parser.parse(source: source))
        #expect(finder.lowPowerArguments.count == 1,
                "`EnergyState.resolve` 里 `isLowPower:` 实参出现 \(finder.lowPowerArguments.count) 处，应恰为 1 处")
        let argument = try #require(finder.lowPowerArguments.first,
                                    "在 `EnergyState.resolve` 里找不到 `isLowPower:` 实参 —— 判据无法工作，这不是「零违规」")
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

    @Test("两道闸的顺序：能耗闸压过 Reduce Motion 闸")
    func energyGateOutranksReduceMotion() {
        for phase in [ScenePhase.background, .inactive] {
            for isLowPower in [true, false] {
                let paused = EnergyState(scenePhase: phase, isLowPower: isLowPower)
                for reduceMotion in [true, false] {
                    #expect(paused.presentation(reduceMotion: reduceMotion) == .hidden,
                            "\(phase) / lowPower=\(isLowPower) / RM=\(reduceMotion) 下没有整层不画 —— 能耗闸没有压过 RM 闸")
                }
            }
        }
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

private nonisolated final class ResolveLowPowerArgumentFinder: SyntaxVisitor {
    static let expectedParameterLabels = ["injectedScenePhase", "systemScenePhase", "lowPowerModeOverride"]

    private(set) var lowPowerArguments: [ExprSyntax] = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let labels = node.signature.parameterClause.parameters.map { $0.firstName.text }
        guard node.name.text == "resolve",
              labels == Self.expectedParameterLabels,
              node.modifiers.contains(where: { $0.name.text == "static" }),
              let body = node.body
        else { return .skipChildren }
        let calls = EnergyStateCallCollector()
        calls.walk(body)
        self.lowPowerArguments += calls.lowPowerArguments
        return .skipChildren
    }
}

private nonisolated final class EnergyStateCallCollector: SyntaxVisitor {
    static let constructorSpellings: Set<String> = [
        "EnergyState", "Self", ".init", "EnergyState.init", "Self.init",
    ]

    private(set) var lowPowerArguments: [ExprSyntax] = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard Self.constructorSpellings.contains(node.calledExpression.trimmedDescription)
        else { return .visitChildren }
        for argument in node.arguments where argument.label?.text == "isLowPower" {
            self.lowPowerArguments.append(argument.expression)
        }
        return .visitChildren
    }
}
