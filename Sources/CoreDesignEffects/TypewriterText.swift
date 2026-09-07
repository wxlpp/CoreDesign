import CoreDesign
import SwiftUI

// MARK: - 速度档位 / Speed

/// 打字机的速度档位。**调用方选档位，而不是传一个裸的毫秒数**
///（与 `MicroInteractionStrength` / `ButtonRoleStyleRole` 同一条调参纪律）。
public nonisolated enum TypewriterSpeed: Sendable, CaseIterable {
    /// 慢（约 13 字 / 秒）。适合一两行的标题。
    case slow
    /// 常规（约 25 字 / 秒）。
    case regular
    /// 快（约 55 字 / 秒）。适合整段正文。
    case fast

    /// 每个字符之间的间隔（秒）。
    public var secondsPerCharacter: Double {
        switch self {
        case .slow: 0.075
        case .regular: 0.040
        case .fast: 0.018
        }
    }
}

// MARK: - 揭示契约（纯函数，生产代码与判据共用同一份）

nonisolated struct TypewriterPlan: Equatable, Sendable {
    let revealed: Int
    let types: Bool
}

nonisolated enum TypewriterReveal {
    static func characterCount(of text: String) -> Int { text.count }

    static func plan(total: Int, typed: Int, reduceMotion: Bool) -> TypewriterPlan {
        let ceiling = max(0, total)
        guard !reduceMotion else { return TypewriterPlan(revealed: ceiling, types: false) }
        return TypewriterPlan(revealed: min(ceiling, max(0, typed)), types: ceiling > 0)
    }

    static func prefix(of text: String, count: Int) -> String {
        guard count > 0 else { return "" }
        return String(text.prefix(count))
    }
}

// MARK: - 绘制层（不读时间、不调度）

struct TypewriterBody: View {
    let text: String
    let revealed: Int

    var body: some View {
        let text = self.text
        let shown = TypewriterReveal.prefix(of: text, count: self.revealed)

        Text(verbatim: text)
            .opacity(0)
            .overlay(alignment: .topLeading) {
                Text(verbatim: shown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: text))
    }
}

// MARK: - 打字任务的身份

nonisolated struct TypewriterRun: Equatable, Sendable {
    let text: String
    let typing: Bool
    let speed: TypewriterSpeed
}

// MARK: - 公开入口

/// 逐字揭示的打字机文本。典型用途：AI 回答流式呈现、引导页标题、终端风格提示。
public struct TypewriterText: View {
    private let text: String
    private let speed: TypewriterSpeed

    @State private var typed: Int

    @State private var typedRun: TypewriterRun?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 界面文案（公约 §4 **B 类**）：编译期本地化键，走 `LocalizedStringResource`。
    public init(_ text: LocalizedStringResource, speed: TypewriterSpeed = .regular) {
        self.init(resolved: String(localized: text), speed: speed, initialTyped: 0)
    }

    /// 运行期动态内容（公约 §4 **C 类**：AI / 用户 / 工具产生，不存在编译期本地化键）。
    public init(verbatim text: String, speed: TypewriterSpeed = .regular) {
        self.init(resolved: text, speed: speed, initialTyped: 0)
    }

    init(resolved text: String, speed: TypewriterSpeed, initialTyped: Int) {
        self.text = text
        self.speed = speed
        self._typed = State(initialValue: initialTyped)
    }

    public var body: some View {
        let total = TypewriterReveal.characterCount(of: self.text)
        let plan = TypewriterReveal.plan(
            total: total, typed: self.typed, reduceMotion: self.reduceMotion
        )
        let run = TypewriterRun(text: self.text, typing: plan.types, speed: self.speed)
        TypewriterBody(text: self.text, revealed: plan.revealed)
            .task(id: run) {
                await self.type(run: run, total: total)
            }
    }

    private func type(run: TypewriterRun, total: Int) async {
        if self.typedRun != run {
            self.typedRun = run
            self.typed = 0
        }
        guard total > 0 else { return }
        guard run.typing else {
            self.typed = total
            return
        }
        guard self.typed < total else { return }
        for index in (self.typed + 1)...total {
            do {
                try await Task.sleep(for: .seconds(self.speed.secondsPerCharacter))
            } catch {
                return
            }
            self.typed = index
        }
    }
}

#Preview("TypewriterText") {
    VStack(alignment: .leading, spacing: CoreSpacing.xl) {
        TypewriterText("Shipping a design system is mostly bookkeeping.", speed: .slow)
            .font(.title2.weight(.semibold))
        TypewriterText(verbatim: "run-time content arrives here, one grapheme at a time.")
            .font(.callout)
            .foregroundStyle(Color.contentSecondary)
    }
    .padding(CoreSpacing.xxl)
    .frame(width: 360, alignment: .leading)
}
