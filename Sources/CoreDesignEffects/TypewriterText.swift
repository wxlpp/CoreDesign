//
//  TypewriterText.swift
//  CoreDesignEffects
//
//  逐字揭示的打字机文本 / Text revealed one character at a time.
//

import CoreDesign
import SwiftUI

// MARK: - 速度档位 / Speed

/// 打字机的速度档位。**调用方选档位，而不是传一个裸的毫秒数**
///（与 `MicroInteractionStrength` / `ButtonRoleStyleRole` 同一条调参纪律）。
///
/// ⚠️ 这条纪律管的是**调参入口**，不是"这个数字保密"：每档对应的间隔由下面**公开**的
/// `secondsPerCharacter` 给出，调用方读得到、也应当读得到（估算总时长、写文档、
/// 与别的时序对齐都要用它）。挡住的只是
/// `TypewriterText(..., secondsPerCharacter: 0.037)` 这种把裸数值当参数传进来的用法
/// ——那会让三档语义在调用方那里失去意义。
/// ⚠️ 上一版这句写的是「**不暴露**"每字多少毫秒"这类裸数值」（#253 PR #273 Copilot
/// 第 3 轮）：与紧接着的公开 `secondsPerCharacter` **直接矛盾**，是措辞错误。
///
/// ⚠️ `nonisolated`：本包开了 `.defaultIsolation(MainActor.self)`，不标的话
/// `TypewriterReveal`（`nonisolated`，要能在 nonisolated 上下文里被求值）读不到它
/// ——`ConfettiBurst.particleCount` 当初正是为了绕开这条才改吃 `Int`。
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

/// 「打到第几个字」的**纯函数契约**。
///
/// ⚠️ **抽出来的唯一理由是可测性**（与 `ConfettiBurst` / `ProcessingSweep` / `ShineBand`
/// 同一条纪律）：`\.accessibilityReduceMotion` **不可注入**
///（`EnvironmentValues` 上它是只读的系统偏好，写它编译红——`EffectsPresentation` 的
/// 文档已实测过），⇒ 「Reduce Motion 下直接显示完整文本」这条 AC 在位图上**结构上
/// 不可观测**，只能落在纯函数 + 调用点源码两条链上。
/// ⚠️ **不要把字面量写回 `TypewriterText`**——那会让判据重新变成"测试自说自话"。
nonisolated struct TypewriterPlan: Equatable, Sendable {
    /// 这一帧该显示到第几个字。
    let revealed: Int
    /// 还要不要继续逐字推进。**Reduce Motion 下为 `false`** —— 连计时器都不起。
    let types: Bool
}

nonisolated enum TypewriterReveal {

    /// 文本的**字素簇**个数。
    ///
    /// ⚠️ 逐 `Character` 而不是逐 `unicodeScalars` / `utf8`：后两者会把 emoji
    /// （`👨‍👩‍👧` 是 5 个标量）与组合字拆成半个字符，屏幕上会先闪出一个不完整的字形。
    static func characterCount(of text: String) -> Int { text.count }

    /// 这一帧该显示到第几个字、以及还要不要继续逐字推进。
    ///
    /// ⚠️⚠️ **这是 AC「Reduce Motion ⇒ 直接显示完整文本」的唯一裁决点**。
    /// 降级**不是 no-op**：文本本身是内容，抹掉它等于让开启该偏好的用户读不到东西；
    /// 也**不是**"打得快一点"——那仍然是运动。⇒ 一次给全，且**不再起打字计时器**。
    ///
    /// ⚠️⚠️ **为什么把"显示到第几个字"和"要不要继续打"合成一个结论、而不是两个函数**
    ///（本 PR 自查时用变异实证出来的洞）：上一版是 `revealedCount(...)` 单函数，
    /// 于是 `TypewriterText` 里有**两处**读 `self.reduceMotion`（渲染一处、状态机一处）。
    /// 而调用点判据数的是「`self.reduceMotion` 出现次数 == 喂给闸的次数」
    ///（同 `MicroInteractionReduceMotionGuard.reduceMotionIsOnlyConsumedByTheSharedGate`）
    /// ——**两处时把其中一处改成字面量 `false`，两个计数会一起降到 1，判据仍然全绿**，
    /// 而 Reduce Motion 在渲染路径上已经完全失效。
    /// ⇒ 合成一个结论 ⇒ 调用点只剩**一处**读 ⇒ 同一枚变异让 `fed` 归零、判据判红。
    /// `Confetti` / `ProcessingSweep` 之所以没踩到这条，正是因为它们各自只有一处。
    static func plan(total: Int, typed: Int, reduceMotion: Bool) -> TypewriterPlan {
        let ceiling = max(0, total)
        guard !reduceMotion else { return TypewriterPlan(revealed: ceiling, types: false) }
        return TypewriterPlan(revealed: min(ceiling, max(0, typed)), types: ceiling > 0)
    }

    /// 前 `count` 个字素簇。`count` 越界时钳住，不 trap。
    static func prefix(of text: String, count: Int) -> String {
        guard count > 0 else { return "" }
        return String(text.prefix(count))
    }
}

// MARK: - 绘制层（不读时间、不调度）

/// 给定"打到第几个字"画出一帧。**不读时间、不调度**——因此可以被单测钉在任意进度上渲染。
///
/// ⚠️⚠️ **必须用全文做尺寸底稿**（`opacity(0)` 的幽灵层 + `overlay` 的可见前缀）：
/// 直接渲染前缀会让每多打一个字就重排一次行宽 / 行数，文字在打字过程中不停跳动，
/// 且会把**下方**的整块布局一起推来推去。
/// 判据在 `TypewriterTextTests.ghostSizingKeepsLayoutStable`：量 `ImageRenderer` 在
/// revealed=1 与 revealed=全文时的**布局尺寸**并断言相等，配一条"裸 `Text` 前缀与全文
/// 尺寸必须不同"的互锁。
///
/// ⚠️ **上一版这里引的是 `revealedCountReachesRendering` 的「位图字节数必须相同」，
/// 那条结构性恒真**（PR #273 终审 I-2）：位图是 `w*h*4` 的裸缓冲，而被测视图被外层
/// `.frame(220×40)` 钉死 ⇒ 两个字节数**永远**相等。终审实证：把本类型整个换成裸
/// `Text(verbatim: shown)`（即删掉这个机制），那条判据 7/7 仍绿。
/// ⇒ 观测布局必须量**尺寸**，且被测视图不能被外层 `frame` 钉死。
///
/// ⚠️ 幽灵层用 `.opacity(0)` 而不是 `.hidden()`：两者在这里**布局等价**，
/// a11y 上也**没有差别**——本视图链尾就是 `.accessibilityElement(children: .ignore)`
/// + `.accessibilityLabel(全文)`，子树的 a11y 本来就被整块丢弃、标签显式给出。
/// ⇒ 选 `.opacity(0)` 只是本仓惯例，**不是**因为 `.hidden()` 会有别的后果。
/// ⚠️ 上一版这里写的是「`.hidden()` 会把整棵子树从 a11y 树里摘掉——而这里要的正好相反」
///（#253 PR #273 终审 S-C）：那条理由**今天是空的**，因为紧接着的 `children: .ignore`
/// 已经做了同一件事。留着会让下一个人以为这里有一条真的约束。
struct TypewriterBody: View {

    /// 完整文本（已解析为 `String`）。
    let text: String
    /// 当前该显示到第几个字。
    let revealed: Int

    var body: some View {
        // ⚠️ 先取成局部 `let`：本包开了 `.defaultIsolation(MainActor.self)`，
        // 在闭包里直接读 `self.x` 会撞上 `MicroInteractionSupport.swift`
        //《写微交互前必读：隔离约束》里记的那一族问题。
        let text = self.text
        let shown = TypewriterReveal.prefix(of: text, count: self.revealed)

        Text(verbatim: text)
            .opacity(0)
            .overlay(alignment: .topLeading) {
                Text(verbatim: shown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            // ⚠️ **a11y 分工（FR-13）与装饰层相反**：这里的文字**是内容**，不是装饰。
            // VoiceOver 必须一次读到**全文**，而不是跟着动画读半句
            //（屏幕阅读器的朗读节奏由用户控制，逐字揭示对它只是噪音）。
            // ⇒ 整块合成一个元素，标签取全文。
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: text))
    }
}

// MARK: - 打字任务的身份

/// 打字 `.task(id:)` 的身份。**三个字段任意一个变化都要重启打字任务。**
///
/// ⚠️ **单独立一个类型而不是塞元组**：`.task(id:)` 要 `Equatable & Sendable`，
/// 而具名字段让「为什么这三个」有地方写（见 `TypewriterText.body` 上的说明）。
/// ⚠️ **字段名是 `typing` 不是 `types`**：本文件的调用点判据逐次计数
/// `"types: plan.types"`，它必须恰好命中**状态机那一次**调用；这里再写一次
/// 会把计数顶到 2、判红一条本来正确的实现（判据
/// `TypewriterTextTests.typingTaskRestartsOnPlanAndSpeed` 反过来钉住本行的字面形态）。
nonisolated struct TypewriterRun: Equatable, Sendable {
    let text: String
    let typing: Bool
    let speed: TypewriterSpeed
}

// MARK: - 公开入口

/// 逐字揭示的打字机文本。典型用途：AI 回答流式呈现、引导页标题、终端风格提示。
///
/// ```swift
/// TypewriterText("Welcome aboard", speed: .slow)
/// TypewriterText(verbatim: streamedAnswer)      // 运行期内容（AI / 用户产生）
/// ```
///
/// ## 两个 init 的分工（公约 §4 文案三分法）
///
/// | init | 公约类别 | 用于 |
/// |---|---|---|
/// | `init(_:speed:)`（`LocalizedStringResource`） | **B 类**：调用方传入的界面文案 | 标题、引导语 |
/// | `init(verbatim:speed:)`（`String`） | **C 类**：运行期动态内容，不存在编译期本地化键 | AI 流式输出、用户输入回显 |
///
/// ⚠️ **为什么 B 类这一条用 `LocalizedStringResource` 而不是公约第 4 节裁决的
/// `LocalizedStringKey`**（`docs/component-contract.md`「新增 B 类参数用
/// `LocalizedStringKey`」，`.rise(text:)` 正是按那条落的）：
///
/// **`LocalizedStringKey` 在本组件上结构性不可用**——打字机要按**字素簇**切前缀，
/// 而 SwiftUI **没有**把 `LocalizedStringKey` 解析成 `String` 的公开 API
/// （它只能整体交给 `Text`）。`LocalizedStringResource` 有：`String(localized:)`。
/// ⇒ 这不是"两种都行、我选了另一种"，是只有一种做得到。
///
/// ⚠️ **代价照录**：`.rise(text:)` 用 LSK、本组件用 LSR，本仓的 B 类文案参数因此
/// 不再是同一种类型。FR-7 自身写的是「`LocalizedStringResource` / `LocalizedStringKey`」
/// **二选一**（`shipswift-harvest` PRD），故两者都合规；但"新增 B 类一律 LSK"这句
/// 从本组件起有了一条**成文例外**，理由就是上一段。
/// ⚠️ **例外已登记进公约本体**（PR #273 终审 I-5）：`docs/component-contract.md` §4
/// 「文案类型三分法」里那条裁决**下面**有一段带射程的例外记录，射程是**谓词**——
///「**仅当**组件必须对解析后的字符串做索引 / 切片时」。
/// ⇒ 下一个同形态组件照那条射程判，**不要**照抄本文件却不带理由；
/// 也不要把它读成「就这一个组件」或「任何逐字符处理的文本参数」。
/// ⚠️ 该例外**无机器判据**（A / B 类类型本就无机器判别，公约记为缺口 **G-4**）⇒ 靠评审。
/// ⚠️ 顺带一条**行为差异**（不是等价替换）：`LocalizedStringResource` 的字面量走
/// `init(stringLiteral:)`，其 bundle 同样是 `Bundle.main`（`Rise.swift` 实测记着这条），
/// 但调用方**可以**显式写 `bundle:` 指向自己的 `.module`——LSK 做不到，
/// 只能靠"先解析成字符串再包成 key"绕。⇒ 对来自另一个 package 的调用方，本组件更好用。
///
/// ## ⚠️⚠️ 已知限度：本组件**不跟随 `\.locale` 环境**
///
/// （#253 PR #273 终审 I-4。上一版只用"性能"解释急切解析，**没有任何地方记这个后果**。）
///
/// 文本在 `init` 里就用 `String(localized:)` 解析完（理由见 `text` 属性），
/// 而 `String(localized:)` 按 **resource 自己的 locale**（默认进程 locale）查表，
/// **不看 SwiftUI 的 `\.locale` 环境**。⇒
///
/// ```swift
/// TypewriterText("Welcome").environment(\.locale, .init(identifier: "fr"))  // ⚠️ 无效
/// Text("Welcome").rise().environment(\.locale, .init(identifier: "fr"))     // ✅ 有效（LSK）
/// ```
///
/// 换 locale 要**重建视图**（例如 `.id(locale)`）。这条对 `.rise(text:)` 那种走
/// `LocalizedStringKey` 的参数不成立——同一份 B 类文案，两种类型的 locale 行为**不同**。
///
/// **为什么记而不改**：改成"存 LSR + 在 `body` 里按 `\.locale` 重解析"要每帧走一次查表
///（`text` 属性逐字记着为什么不这么做），且 `init(verbatim:)` 那条 C 类路径根本没有
/// 可重解析的 resource ⇒ 两条 init 会分岔成两种生命周期。
/// ⇒ 本轮**登记为已知限度**；真要跟随环境 locale 属独立改动，届时两条 init 一起重设计。
///
/// ## Reduce Motion
///
/// **直接显示完整文本**（AC 逐字）。不是 no-op、也不是"打快一点"——文本是内容，
/// 而"打字"这个过程本身才是运动。裁决点是纯函数
/// `TypewriterReveal.plan(total:typed:reduceMotion:)`，
/// 判据见 `TypewriterTextTests.reduceMotionRevealsEverything` 与同 suite 的调用点判据。
///
/// ## 后台 / 低电量（NFR-7）
///
/// ⚠️ **本组件不接能耗闸，这是一条判定不是遗漏**：NFR-7 管的是**常驻渲染**的效果
/// （`colorEffect` 背景、`Confetti`、`ScanningOverlay` 那一类持续调度的）。
/// 打字机是**有限时长**的一次性揭示——打完就停，没有 `TimelineView`、没有常驻调度器，
/// 驱动它的 `.task` 在最后一个字之后自然结束。给它接能耗闸的唯一可见后果是
/// 「切后台再回来时文字停在半句」，那既不省电也更糟。
/// ⚠️ 另一半理由：能耗闸的 `.none` 语义是**一个像素都不画**，而本组件画的是**内容**
/// ——把内容整块隐藏不是"停摆"，是 bug。
///
/// ## a11y
///
/// 与装饰性效果（FR-13：`accessibilityHidden(true)`）**相反**：这里的文字是内容，
/// 已合成为一个元素、标签恒为**全文**，VoiceOver 不会跟着动画逐字朗读。
public struct TypewriterText: View {

    /// 已解析的完整文本。
    ///
    /// ⚠️ 在 `init` 里就解析成 `String`，而不是把 `LocalizedStringResource` 存起来
    /// 每帧解析：`String(localized:)` 要走一次查表，逐帧做它是白烧 CPU；
    /// 且揭示进度以字素簇计，必须先有 `String` 才谈得上"第几个字"。
    ///
    /// ⚠️⚠️ **代价照录**：急切解析 ⇒ 本组件**看不见 `\.locale` 环境**，
    /// 换 locale 必须重建视图。完整说明在类型文档「已知限度」一节（终审 I-4）。
    private let text: String
    private let speed: TypewriterSpeed

    /// 已经打出的字数。**只由下面的 `.task` 推进。**
    @State private var typed: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 界面文案（公约 §4 **B 类**）。见类型文档「两个 init 的分工」。
    public init(_ text: LocalizedStringResource, speed: TypewriterSpeed = .regular) {
        self.init(resolved: String(localized: text), speed: speed, initialTyped: 0)
    }

    /// 运行期动态内容（公约 §4 **C 类**：AI / 用户 / 工具产生，不存在编译期本地化键）。
    ///
    /// ⚠️ 标签是 `verbatim:`，与 SwiftUI 自己的 `Text(verbatim:)` 同名同义
    /// ——「这串东西不是给人读的自然语言键，别拿它去查表」。本仓的
    /// `ChromeTextLiteralGuard` 对 `Text(verbatim:)` 也是**清点不判违规**，同一条语义。
    public init(verbatim text: String, speed: TypewriterSpeed = .regular) {
        self.init(resolved: text, speed: speed, initialTyped: 0)
    }

    /// **判据用的渲染缝**：`typed` 的初值。
    ///
    /// ⚠️ **生产路径永远不传它**（两个公开 init 都固定传 0）。它存在的理由与
    /// `ConfettiCore.initialBurstStart` 完全同源：`.task` 在 macOS 的 `ImageRenderer`
    /// 下**不跑**、在 iOS Simulator 下**会被调度**，判据无法从外部把状态推到"打字中"。
    /// ⇒ 给一个初值，整条渲染路径就变成可断言的。
    init(resolved text: String, speed: TypewriterSpeed, initialTyped: Int) {
        self.text = text
        self.speed = speed
        self._typed = State(initialValue: initialTyped)
    }

    public var body: some View {
        let total = TypewriterReveal.characterCount(of: self.text)
        // ⚠️⚠️ **`reduceMotion` 在本文件里只在这一处被消费**，判据
        //（`TypewriterTextTests.reduceMotionIsOnlyConsumedByTheRevealGate`）逐次计数。
        // 任何"自己再拿它判一次"的写法都会让计数对不上 ⇒ 判红。
        // ⚠️ 状态机拿的也是**这一次**的结论（`plan.types`），不是自己再读一遍环境
        // ——理由与变异实证写在 `TypewriterReveal.plan(total:typed:reduceMotion:)` 上。
        let plan = TypewriterReveal.plan(
            total: total, typed: self.typed, reduceMotion: self.reduceMotion
        )
        TypewriterBody(text: self.text, revealed: plan.revealed)
            // ⚠️⚠️ **`id:` 必须带上 `plan.types` 与 `speed`，不能只有 `text`**
            //（#253 PR #273 Copilot 第 2 轮）。上一版只用 `self.text` 做 key，两个后果：
            // ① 视图存活期间用户在系统设置里打开 Reduce Motion ⇒ 渲染那一侧立刻跳到全文
            //    （`plan.revealed`），但**先前启动的任务不会被取消**，它会继续每
            //    `secondsPerCharacter` 醒一次、一路 `self.typed = index` 写到底
            //    ——白烧一条定时任务，且中途每次写状态都触发一次无谓的重绘；
            // ② `text` 不变而 `speed` 变了（调用方按状态换档）⇒ 任务不重启，
            //    新速度要等下一次换文案才生效。
            // ⚠️ **不新增一次 `self.reduceMotion` 读取**：本文件的调用点判据
            //（`reduceMotionIsOnlyConsumedByTheRevealGate`）数的是
            // 「`self.reduceMotion` 出现次数 == 喂给闸的次数」，多读一次即判红。
            // ⇒ key 里放的是闸的**结论** `plan.types`，不是环境本身。
            // ⚠️ 代价照录：换 `speed` 会从第 0 个字重打（`type` 开头就 `self.typed = 0`），
            // 而不是保持进度换速度。这是有意的——保持进度换速度要把 `typed` 从
            // `.task` 里搬出来单独维护，换来的只是一个没人提过的用法。
            .task(id: TypewriterRun(text: self.text, typing: plan.types, speed: self.speed)) {
                await self.type(total: total, types: plan.types)
            }
    }

    /// 打字状态机。**逐字推进，打完即结束**（没有常驻调度器 —— 见类型文档 NFR-7 一节）。
    ///
    /// - Parameter types: 还要不要逐字推进。由 `TypewriterReveal.plan` 给出，
    ///   **本方法不自己读环境**。
    private func type(total: Int, types: Bool) async {
        self.typed = 0
        guard total > 0 else { return }
        // ⚠️ Reduce Motion 下**一次到位**：渲染那一侧已经由 `plan.revealed` 保证显示全文，
        // 这里同步推进状态是为了避免留下一个"其实没打完"的内部状态（换文案时会闪）。
        guard types else {
            self.typed = total
            return
        }
        for index in 1...total {
            do {
                try await Task.sleep(for: .seconds(self.speed.secondsPerCharacter))
            } catch {
                // 被取消（文本又变了）⇒ 这一轮交给新任务，**不**回写状态。
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
