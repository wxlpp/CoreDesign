import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 新 target 禁 chrome 文案裸字面量 / No bare chrome text literals（Issue #246）
//
// 公约 **G-4**（`docs/component-contract.md:1017`）逐字：「**A 类**文案不经任何一路进入
// FR-4 的机器视野……评审（无机器判据）」。A 类 = 组件自己写死在 `body` 里的 chrome 文案
// （`Text("Loading…")` / `Label("Retry", systemImage:)`），与 B 类（public init 的裸文本
// **参数**）是两回事——后者由 `ComponentTextParamGuard` 以**登记表条目**为定义域守着，
// 结构上守不到 A 类。
//
// ⚠️ **`ComponentTextParamGuard` 不在本 task 处理**（`#246` 任务书 Technical Details）：
// 它的扩展与 FR-7 边界编码归 `shipswift-effects` 的 A-6（与 `47→51` 同一处）。
// 本守卫是**另建**的一条，专打 A 类，不碰它的 `== 31`。
//
// ## 射程：**只有新 target**，且**不回溯改造 CoreDesign 现状**
//
// `GuardScanRoots.newTargetRoots`（`#279` 起含 `CoreDesignShaders`）。
// 主 target 现有 198 处 `Text("…")`——公约自己写着
// 「连 CoreDesign 自己都没守住 A 类」，回溯治理不是本 task 的题目。
// ⚠️ 但主 target 仍被当**靶场**用（`detectorFiresOnRealSource`）：新 target 今天命中必然
// 为 0，「零违规」与「探测器坏了」在这种输入上不可分辨。
//
// ## 覆盖面：不只 `Text` / `Label`
//
// `246.md:28-29` 的 AC 字面只写 `Text("…") / Label("…"`，但本守卫的失败信息是通用口吻
// （「下游 App 换语言时这些字会突然说英文」），而 Epic A 真正要落的 `BeforeAfterSlider` /
// `GlassOrb` 与图表图例现实中就会用 `Button` / `Section` / `Toggle`
// ⇒ 只认两个构造器时它会**报零并被采信**（PR #265 终审 I-3）。⇒ 覆盖两类：
//
// · **构造器**（`textConstructors`）：裸引用 `Text(…)`、**限定形态** `SwiftUI.Label(…)`
//   （仓内 `Tag.swift:219` 的预览已在用）、**initializer 形态** `Text.init(…)`；
// · **modifier**（`textModifiers`）：`.navigationTitle("…")` 这类
//   `MemberAccessExprSyntax` callee——首版要求 callee 必须是裸 `DeclReferenceExprSyntax`，
//   把上面**三种**形态一起结构性排除了（Copilot A-1 + 终审 I-3）。
//
// ## 已知口子（写在明处，不是漏了）
//
// ⚠️ **本标题有意不带数字**（PR #265 第 4 轮终审 S-3）：它此前写「已知的八个口子」，
// 于是每加一条口子都要顺手改标题——而这类「标题里的计数」在本仓已经漂过一次
// （`CLAUDE.md` 的按钮样式一节）。计数标题的唯一作用是给读者一个校验和，
// 而它恰恰是最容易与正文脱节的那一行。
//
// 1. **`Text(verbatim:)` 不判违规**——它是「这串东西不是给人读的自然语言」的显式声明
//    （数字、用户数据、符号）。它可 grep、可评审，比逼人把 verbatim 改写成别的形状好。
//    本守卫**清点**它并打印，让滥用看得见（`Text.init(verbatim:)` 同样清点）。
// 2. **`#Preview` 整体跳过**——预览是视觉冒烟入口、不是产品路径（与 a11y 守卫跳过
//    `#if DEBUG` 同一条裁断）。
// 3. **`.accessibilityLabel` / `.accessibilityValue` / `.accessibilityHint` 不在
//    `textModifiers` 里，这是分工不是漏**：它们由 `AccessibilityStringLiteralGuard`
//    以 `GuardScanRoots.allRoots`（含主 target）守着，还带一份逐站点的
//    `docs/a11y-exemptions.json`。在这里重复一遍只会让同一处违规被报两次。
// 4. **本守卫暂无例外台账**——本仓其余守卫（`bool-exemptions.json` /
//    `a11y-exemptions.json` / `knownMissingExtensionPoints`）都有带署名理由的逐站点
//    逃生门，本条与 `EffectsColorLiteralGuard` 都还没有。⚠️ **出现第一个正当例外时，
//    应新增台账（形态照 `a11y-exemptions.json`：`location` + `symbol` + 署名 `reason`），
//    不得放宽判据、更不得删掉本守卫**——「用削弱判据来消化一个正当例外」正是 G-7
//    记在案的失效形态。follow-up 见 `246.md` 的《后续》。
// 5. **`textConstructors` / `textModifiers` 是白名单，必然不完备**（PR #265 第 3 轮终审 F-3）。
//    这不是「再补几个就完了」：SwiftUI 承载文案的构造器与 modifier 是一个开放集合，
//    每个 iOS 大版本都会加。⚠️ **这条口子的危险不在漏报本身，而在「零命中会被采信」**
//    ——本守卫的失败信息是通用口吻，读者会把「新 target 零违规」读成「新 target 没有裸文案」。
//    终审第 2 轮已经用同一条理由把清单从 2 个扩到 9 个；第 3 轮实测又找出 6 个全数漏报的
//    常见构造器（`Menu` / `Link` / `NavigationLink` / `GroupBox` / `ContentUnavailableView` /
//    `DatePicker`）与 2 个 modifier（`navigationBarTitle` / `searchable(prompt:)`），本轮已补。
//    ⇒ 处置纪律：**发现漏报就往清单里加，永远不要反过来说「清单里没有 ⇒ 不是违规」**。
// 6. **modifier 分支不看接收者**（PR #265 第 3 轮终审 S-a）：`chromeCallName(of:)` 的
//    ② 号分支只按 `member.declName` 匹配，base 是任意表达式。于是 `logger.help("…")` /
//    `validator.alert("…", isPresented:)` / `MyNS.Section("Legend")` 都会被判红——
//    `help` / `alert` 太通用，Effects / Charts 里的非 SwiftUI API 撞得上。
//    ⚠️ **有意不加「接收者启发式」**：能写出来的廉价启发式（如「base 是小写裸标识符就跳过」）
//    会把 `content.help("Save")` 这类**真违规**一起放掉——那是把一条误报换成一条 fail-open
//    的漏报，与本守卫「宁可 fail-closed」的取向相反。⇒ 保留误报面，并把它钉成断言
//    （见 `detectorFiresOnSyntheticSource` 里「已知误报面」那三条）。
//    **第一个真误报出现时的处置**：走口子 4 的台账（新建 `docs/chrome-text-exemptions.json`，
//    `location` + `symbol` + 署名 `reason`），**不得**从 `textModifiers` 里删 `help` / `alert`
//    ——删掉等于把整类违规一起放掉，正是 G-7 记在案的形态。
//    ⚠️⚠️ **`docs/chrome-text-exemptions.json` 今天并不存在**（PR #265 第 4 轮终审 S-2）：
//    口子 4 与本条都拿它当处置出口，但它是一份**待建**的文件，不是现成的落点。
//    第一个误报出现时要先**新建**它并同轮补上「双向差集 + 死豁免自检」（照
//    `AccessibilityStringLiteralGuard.exemptionsAreNotDead` 的形态），否则「登记了 ≠ 守住了」。
//    ⚠️⚠️ **`textConstructors` 的裸同名类型撞车已经能点名，不再是抽象风险**
//    （同一条终审）：本条上面举的是**限定形态** `MyNS.Section("Legend")`，而
//    **裸形态**同样落在本守卫唯一的射程（新 target）上——
//    · `struct Link { init(_ id: String) {} }; Link("node-a to node-b")` → 误报；
//    · `struct Section { init(_ id: String) {} }; Section("legend area")` → 误报。
//    而 `CLAUDE.md`《多 target 结构》给 `CoreDesignCharts` 定的四类图表里就有
//    **力导向网络图**，图论里 edge 的惯用名恰恰是 `Link`（`Node` / `Link` 这一对）。
//    ⇒ `#255` 落件时**极可能**第一个撞上，届时请按上面那条走台账，**不要**把
//    `Link` / `Section` 从 `textConstructors` 里删掉当 bug 修——删掉会把
//    `SwiftUI.Link("Open docs", destination:)` 这类真违规一起放掉。
// 7. **`typealias` 可以绕过**（PR #265 第 3 轮终审 S-c）：本守卫按**文本**判构造器名，
//    `typealias T = Text; T("Loading")` 因此看不见（与 `EffectsColorLiteralGuard` 的口子 5
//    同源——纯语法、逐文件的扫描器解不了 alias）。没人会为了绕守卫这么写，登记在此
//    是因为上面那句「口子写在明处」要求它被写下来，而不是留在读者的想象里。
// 8. **隐式 `.init(…)` 只在上下文类型写得出来时才判**：`let t: Text = .init("Loading")`
//    走 `ImplicitMemberContext.contextualTypeName(of:)`（与 `EffectsColorLiteralGuard`
//    共用），它给不出数组元素 / 函数实参 / 闭包返回值位置的类型。首版**连有类型标注的
//    那种都漏**（`chromeCallName` 剥掉尾段 `init` 后要求尾段非空，隐式形态得到 `""` ⇒ `nil`），
//    而色相守卫对同一形态**有**处理——这条不对称此前没有任何记录（PR #265 第 3 轮终审 S-b）。
//    ⚠️ **共用即传染**（PR #265 第 4 轮终审 I-1 / I-2）：那份共用实现此前
//    (a) 把外层函数 / 计算属性的返回类型**错安**到实参位置
//    （`func title() -> Text { render(.init("Loading")) }` 误报）、
//    (b) 在三元 / `??` 上截断上行走查（`let t: Text = flag ? .init("Loading") : other` 漏报）。
//    两条都已改码修掉，实证在 `contextualTypeDoesNotLeakAcrossArgumentPositions`。
//    ⚠️⚠️ **第 5 轮终审又在共用实现上抓到三条**（I-a / I-b），同样原样传染到这里：
//    (c) 赋值右侧继承了被赋值属性的标注
//    （`var title: Text { get { … } set { self.store = .init("Loading") } }` 误报）；
//    (d) 默认参数值继承了外层返回类型
//    （`func title(id: Identifier = .init("Loading")) -> Text` 误报，镜像的
//    `func f(t: Text = .init("Loading"))` 漏报）；
//    (e) 条件绑定自带的 `typeAnnotation` 被外层标注顶掉
//    （`var title: Text { if let id: Identifier = .init("Loading") { … } }` 误报，
//    镜像的 `guard let t: Text = .init("Loading")` 漏报）。
//    三条的**双向**实证在 `contextualTypeRespectsAssignmentsDefaultsAndBindings`。
//    ⚠️⚠️ **(c) 当轮只关了一半，第 5 轮终审 I-1 又在同一处抓到复合赋值**：
//    `self.log += .init("Loading")` 里那个算子是 `BinaryOperatorExprSyntax("+=")`、
//    **不是** `AssignmentExprSyntax` ⇒ 只认后者的闸整族漏过，右侧仍继承被赋值属性的标注。
//    已改成走 `ImplicitMemberContext.assignmentOperators` 白名单，复合赋值形态进上面那条探针常驻。
//    ⚠️ **本条不再声称这一类已经关净。**「给不出」与「给错」是两回事，而这个 PR 里
//    已经有**三次**是被「现在确实只剩 …」这类完备性断言打回的（第 3/4/5 轮）：
//    共用实现每补一处锚点就可能新开一个「另有来源」的位置，逐条穷举做不到。
//    ⇒ **已知**给不出的有：数组 / 字典元素、函数实参、stored property、闭包返回值；
//    **已知**会给错（误报面）的有：**模式位置**——
//    `var title: Text { switch k { case .init("Loading"): … } }` 里的
//    `ExpressionPatternSyntax` 宿主类型来自**被 `switch` 的值**，走查却会取到外层 `Text`
//    （第 5 轮终审 S-1，与色相守卫口子 4 同一条，本轮只登记不改码）。
//    两张表都只是「已知的」，不是「全部的」。
// 9. **`isProse` 只要求「含至少一个字母」**（PR #265 第 4 轮终审 S-2）：于是标识符形态的
//    字面量会被判成文案，实测 `ContentUnavailableView("no-results-id", systemImage: "x")`
//    命中。这是 `isProse` 既有的启发式性质（它的文档已写明这是一条**收窄**），
//    但口子 5 新补的 6 个构造器把它的暴露面放大了——`ContentUnavailableView` /
//    `Link` / `NavigationLink` 的第一个无标签实参在现实代码里常是 id / route 而非文案。
//    ⇒ 处置同上：走台账，不要把 `isProse` 收得更窄（收窄会把真文案一起放掉）。
// 10. ⚠️⚠️ **A 类"默认标签"这一整族本守卫看不见**（#253 PR #273 终审 S-4，**留痕不改码**）。
//    本守卫的射程是 `textConstructors`（构造器的首个无标签实参）与 `textModifiers`。
//    而 A 类兜底文案的正典形态是一个**自建的 chrome 入口函数**：
//    `BeforeAfterSliderLabels.defaultBefore = .effectsChrome("Before")` /
//    `BeforeAfterSliderChrome.accessibilityTitle = .effectsChrome("Before and after comparison")`
//    ——`.effectsChrome(…)` 既不是构造器、也不在 modifier 名单上 ⇒ **零可见性**。
//    ⚠️ **这不是回归，也不是"该补进白名单"**：那两处走的正是本守卫处方第 2 条要求的
//    `Bundle.module` 通路（`LocalizedStringResource(_:bundle:)`），把 `.effectsChrome` 加进
//    `textConstructors` 反而会把**合规**写法判红。真正的缺口是「A 类**类型要求**无机器判据」
//    ——公约自己把它记为 **G-4**（`docs/component-contract.md`：「A 类的类型要求当前
//    无机器判据，靠评审」）。
//    ⇒ 今天唯一覆盖它的是**运行期**判据
//    `BeforeAfterSliderTests.defaultLabelsResolveThroughModuleBundle`（哨兵键证明查表命中）。
//    **写在这里是为了不让日后有人把「本守卫绿」误当成「A 类默认标签被查过」。**
@Suite("新 target 禁 chrome 文案裸字面量")
struct ChromeTextLiteralGuard {

    /// 承载 chrome 文案的构造器。第一个**无标签**实参是字面量即违规。
    ///
    /// ⚠️ 只看第一个实参：`Label("Retry", systemImage: "arrow")` 里 `systemImage:` 的值
    /// 是 SF Symbol 名、`Toggle("…", isOn: $x)` 里 `isOn:` 是绑定——都不是给人读的文案。
    /// 「第一个**无标签**实参」这条规则对下面九个构造器一致成立，所以泛化是安全的。
    ///
    /// ⚠️ **`Text` / `Label` 之外的七个是 PR #265 终审 I-3 补的**：Epic A 的
    /// `BeforeAfterSlider` / `GlassOrb` 与图表图例现实中就会用 `Button` / `Section` /
    /// `Toggle`，只认两个构造器时本守卫会报零并被采信。
    /// ⚠️ **再补的六个来自 PR #265 第 3 轮终审 F-3**：探针实测 `Menu("Options") { }` /
    /// `Link("Open docs", destination:)` / `NavigationLink("Next") { }` / `GroupBox("Legend") { }` /
    /// `ContentUnavailableView("Nothing here", systemImage:)` / `DatePicker("When", selection:)`
    /// **全部漏报**（它们没有内层 `Text` 可兜底）。图例用 `Menu` / `GroupBox`、空状态用
    /// `ContentUnavailableView`，至少和已覆盖的 `Stepper` / `SecureField` 一样常见。
    /// ⚠️ 清单是白名单、**必然不完备**，见文件头口子 5——不要反过来把它读成违规的定义。
    nonisolated static let textConstructors: Set<String> = [
        "Text", "Label", "Button", "Toggle", "Section",
        "TextField", "SecureField", "Stepper", "Picker",
        "Menu", "Link", "NavigationLink", "GroupBox", "ContentUnavailableView", "DatePicker",
    ]

    /// 承载 chrome 文案的 **modifier**（callee 是 `MemberAccessExprSyntax`）。
    ///
    /// ⚠️ **a11y 三件套有意不在这里**（见文件头口子 3）：它们归
    /// `AccessibilityStringLiteralGuard`，那条守卫的射程更宽（含主 target）且带台账。
    ///
    /// ⚠️ **`navigationBarTitle` / `searchable` 是 PR #265 第 3 轮终审 F-3 补的**；
    /// 后者的文案在**带标签的** `prompt:` 上，「第一个无标签实参」这条通则对它不成立
    /// ⇒ 另立 `labeledProseArguments`。
    ///
    /// ⚠️ **本分支不看接收者**（`logger.help("…")` 会被判红）——那是一条**有意保留**的
    /// 误报面，理由与处置见文件头口子 6。
    nonisolated static let textModifiers: Set<String> = [
        "navigationTitle", "navigationSubtitle", "navigationBarTitle",
        "alert", "confirmationDialog", "help", "searchable",
    ]

    /// 文案落在**带标签实参**上的调用：`调用名 → 承载文案的标签集合`。
    ///
    /// ⚠️ `.searchable(text: $q, prompt: "Search charts")` 的第一个实参是 `text:`（一个
    /// Binding），通则的「第一个无标签实参」永远取不到它的文案 ⇒ 这里按标签取。
    /// `prompt:` 写成 `Text("…")` 时由内层 `Text` 兜住，两条路不会把同一处报两次
    /// （标签分支只认**字符串字面量**）。
    nonisolated static let labeledProseArguments: [String: Set<String>] = [
        "searchable": ["prompt"],
    ]

    nonisolated struct Violation: Hashable, Sendable {
        let file: String
        let line: Int
        let literal: String
        let snippet: String
        var description: String { "\(self.file):\(self.line) → 「\(self.literal)」| \(self.snippet)" }
    }

    nonisolated struct ScanResult: Sendable {
        var violations: [Violation] = []
        /// `Text(verbatim:)` 的清点（不判违规，见文件头口子 1）。
        var verbatimSites: [String] = []
    }

    /// 一个字面量是否算「文案」。
    ///
    /// ⚠️ **要求至少含一个字母**：`Text("")` / `Text(" ")` / `Text("•")` 不是可翻译的
    /// 自然语言，判它们违规只会制造噪音。这是一条**收窄**，写在明处——
    /// 「用全角符号拼一句话」能绕过去，但那已经不是本守卫要防的失效形态了。
    nonisolated static func isProse(_ literal: String) -> Bool {
        literal.contains(where: { $0.isLetter })
    }

    /// 合成输入入口——变红自证与边界形态都走它，不碰磁盘。
    static func scan(source: String, fileName: String = "Synthetic.swift") -> ScanResult {
        let tree = SwiftParser.Parser.parse(source: source)
        if tree.hasError {
            Issue.record("解析出错：\(fileName) —— swift-syntax major 可能与工具链不配套")
        }
        let converter = SourceLocationConverter(fileName: fileName, tree: tree)
        let collector = ChromeTextCollector(fileName: fileName, converter: converter)
        collector.walk(tree)
        return ScanResult(violations: collector.violations, verbatimSites: collector.verbatimSites)
    }

    static func scan(root: URL) throws -> ScanResult {
        var out = ScanResult()
        for url in GuardScanRoots.swiftFiles(in: root) {
            let partial = Self.scan(
                source: try String(contentsOf: url, encoding: .utf8),
                fileName: GuardScanRoots.relativePath(url)
            )
            out.violations += partial.violations
            out.verbatimSites += partial.verbatimSites
        }
        return out
    }

    @Test("新 target 里零 chrome 文案裸字面量（公约 A 类）")
    func noBareChromeTextInNewTargets() throws {
        #expect(GuardScanRoots.assertRootsExist(GuardScanRoots.newTargetRoots))

        var result = ScanResult()
        var scannedFiles = 0
        for root in GuardScanRoots.newTargetRoots {
            let files = GuardScanRoots.swiftFiles(in: root.url)
            #expect(!files.isEmpty, "\(root.target) 下没有任何 .swift 文件 —— 本守卫在它上面恒绿")
            scannedFiles += files.count
            let partial = try Self.scan(root: root.url)
            result.violations += partial.violations
            result.verbatimSites += partial.verbatimSites
        }
        #expect(scannedFiles > 0, "新 target 一个源文件都没扫到 —— 「零违规」不可信")

        // ⚠️ 口子 1 的可见化：`verbatim:` 不判违规，但要打印出来，滥用才看得见。
        print("【chrome 文案】新 target 的 `Text(verbatim:)` 共 \(result.verbatimSites.count) 处：\(result.verbatimSites)")

        #expect(result.violations.isEmpty, """
        新 target 里出现了写死的 chrome 文案（公约 A 类）：
        \(result.violations.map(\.description).joined(separator: "\n"))
        —— 下游 App 换语言时这些字会突然说英文，而组件自己不带 String Catalog。
        处置（按优先级）：
        1. 把文案**交给调用方**（做成 init 参数，那样它落 B 类、由登记表的 textParams 管）；
        2. 确实该由库提供时，走 `String(localized:bundle:)` 指向**该 target 自己的**
           String Catalog——`Package.swift` 的 `resources:` **与**
           `Sources/<target>/Resources/` 目录**必须同轮一起加**
           （`GuardScanRootsGuard.moduleBundleOwnership` 钉住这条一致性；
           ⚠️ 括注更新（#253 PR #273 终审 S-3）：`CoreDesignCharts` 与 `CoreDesignEffects`
           **今天都已经有资源包了** —— 上一版这里写「新 target 今天**没有**资源包，
           写 `bundle: .module` 编译不过」，处方本身没错，括注已失真）；
        3. 那串东西根本不是自然语言（数字 / 符号 / 用户数据）时用 `Text(verbatim:)`，
           它会被清点并打印出来。
        """)
    }

    @Test("探测器真的会开火：合成输入逐形态变红自证")
    func detectorFiresOnSyntheticSource() {
        // ⚠️ `#246` AC「每条新守卫必须附一个会让它变红的 fixture」的落点。
        let cases: [(name: String, source: String, literal: String)] = [
            ("`Text(\"…\")`", """
            import SwiftUI
            public struct A: View {
                public var body: some View { Text("Loading") }
            }
            """, "Loading"),
            ("`Label(\"…\", systemImage:)`", """
            import SwiftUI
            public struct B: View {
                public var body: some View { Label("Retry", systemImage: "arrow.clockwise") }
            }
            """, "Retry"),
            ("折行写法", """
            import SwiftUI
            let t = Text(
                "Something went wrong"
            )
            """, "Something went wrong"),
            // ⚠️ 以下是 PR #265 双评审补的形态（Copilot A-1 / 终审 I-3）。
            ("限定形态 `SwiftUI.Label(\"…\", systemImage:)`（仓内 `Tag.swift:219` 在用）", """
            import SwiftUI
            let l = SwiftUI.Label("verified", systemImage: "checkmark.seal.fill")
            """, "verified"),
            ("initializer 形态 `Text.init(\"…\")`", """
            import SwiftUI
            let t = Text.init("Loading")
            """, "Loading"),
            ("`Button(\"…\") { }`", """
            import SwiftUI
            let b = Button("Retry") { }
            """, "Retry"),
            ("`Toggle(\"…\", isOn:)`", """
            import SwiftUI
            let t = Toggle("Reduce Motion", isOn: $flag)
            """, "Reduce Motion"),
            ("`Section(\"…\")`", """
            import SwiftUI
            let s = Section("Legend") { EmptyView() }
            """, "Legend"),
            ("`TextField(\"…\", text:)`", """
            import SwiftUI
            let f = TextField("Search", text: $q)
            """, "Search"),
            ("`Stepper(\"…\", value:)`", """
            import SwiftUI
            let s = Stepper("Speed", value: $v)
            """, "Speed"),
            ("`.navigationTitle(\"…\")`（modifier 形态）", """
            import SwiftUI
            let v = EmptyView().navigationTitle("Settings")
            """, "Settings"),
            ("`.alert(\"…\", isPresented:)`", """
            import SwiftUI
            let v = EmptyView().alert("Something failed", isPresented: $shown) { }
            """, "Something failed"),
            // ⚠️ 以下是 PR #265 **第 3 轮**终审补的形态（F-3 / S-b）：探针实测这批此前
            // **全部漏报**，且都没有内层 `Text` 可兜底。
            ("`Menu(\"…\") { }`（图例现实用法）", """
            import SwiftUI
            let m = Menu("Options") { EmptyView() }
            """, "Options"),
            ("`Link(\"…\", destination:)`", """
            import SwiftUI
            let l = Link("Open docs", destination: url)
            """, "Open docs"),
            ("`NavigationLink(\"…\") { }`", """
            import SwiftUI
            let n = NavigationLink("Next") { EmptyView() }
            """, "Next"),
            ("`GroupBox(\"…\") { }`（图例现实用法）", """
            import SwiftUI
            let g = GroupBox("Legend") { EmptyView() }
            """, "Legend"),
            ("`ContentUnavailableView(\"…\", systemImage:)`（空状态现实用法）", """
            import SwiftUI
            let e = ContentUnavailableView("Nothing here", systemImage: "x")
            """, "Nothing here"),
            ("`DatePicker(\"…\", selection:)`", """
            import SwiftUI
            let d = DatePicker("When", selection: $date)
            """, "When"),
            ("`.navigationBarTitle(\"…\")`（modifier 形态）", """
            import SwiftUI
            let v = EmptyView().navigationBarTitle("Settings")
            """, "Settings"),
            ("`.searchable(text:prompt:)`——文案在**带标签**实参上（`labeledProseArguments`）", """
            import SwiftUI
            let v = EmptyView().searchable(text: $q, prompt: "Search charts")
            """, "Search charts"),
            ("隐式 `.init` 形态 `let t: Text = .init(\"…\")`（S-b，与色相守卫对齐）", """
            import SwiftUI
            let t: Text = .init("Loading")
            """, "Loading"),
            // ⚠️ **口子 6 的落点**：modifier 分支**有意不看接收者**，因此下面三条
            // **是已知误报、不是本该命中的违规**。把它钉成断言，是为了让这条误报面
            // 在判据里可见——后人若加了接收者启发式，这里会当场红，逼一次口子清单的更新
            // （而不是让「误报面」悄悄变成「fail-open 的漏报面」）。
            ("已知误报面：非 SwiftUI 接收者的 `.help(…)`（口子 6）", """
            let x = logger.help("this is documentation")
            """, "this is documentation"),
            ("已知误报面：非 SwiftUI 接收者的 `.alert(…)`（口子 6）", """
            let x = validator.alert("some message", isPresented: $b)
            """, "some message"),
            ("已知误报面：模块限定的同名类型 `MyNS.Section(…)`（口子 6）", """
            let s = MyNS.Section("Legend")
            """, "Legend"),
            // ⚠️ **裸同名类型同样撞车，且落在本守卫唯一射程上**（PR #265 第 4 轮终审 S-2）：
            // 口子 6 此前只钉了**限定形态**，读起来像「裸形态没事」。`CoreDesignCharts`
            // 要交付力导向网络图，图论里 edge 的惯用名就是 `Link` ⇒ `#255` 落件时极可能第一个撞上。
            ("已知误报面：裸同名类型 `Link(…)`（图论 edge 的惯用名，口子 6）", """
            struct Link { init(_ id: String) {} }
            let e = Link("node-a to node-b")
            """, "node-a to node-b"),
            ("已知误报面：裸同名类型 `Section(…)`（口子 6）", """
            struct Section { init(_ id: String) {} }
            let s = Section("legend area")
            """, "legend area"),
            // ⚠️ 口子 9：`isProse` 只要求含一个字母 ⇒ 标识符形态的字面量被判成文案。
            ("已知误报面：标识符形态被 `isProse` 判成文案（口子 9）", """
            import SwiftUI
            let e = ContentUnavailableView("no-results-id", systemImage: "x")
            """, "no-results-id"),
        ]
        for c in cases {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.contains(where: { $0.literal == c.literal }),
                    "\(c.name)：探测器漏报（期望「\(c.literal)」，实得 \(hits.map(\.literal))）—— 上面那条「零违规」毫无意义")
        }

        // 反向：不该误报的形态。
        let clean: [(name: String, source: String)] = [
            ("文案来自参数", """
            import SwiftUI
            public struct C: View {
                let title: String
                public var body: some View { Text(self.title) }
            }
            """),
            ("走 String Catalog", #"let t = Text(String(localized: "Loading", bundle: .module))"#),
            ("`Text(verbatim:)`（口子 1，只清点）", #"let t = Text(verbatim: "42")"#),
            ("`Label` 的 systemImage 不是文案", """
            import SwiftUI
            let l = Label(self.title, systemImage: "star")
            """),
            ("非文案字面量（无字母）", #"let t = Text("•")"#),
            ("`#Preview` 里的写死文案（有意跳过，见文件头）", """
            import SwiftUI
            #Preview { Text("Preview only") }
            """),
            ("同名但不是 SwiftUI 构造（注释与字符串）", """
            // Text("in a comment")
            let s = "Label(\\"in a string\\")"
            """),
            ("非文案 modifier 的字面量实参（不在 `textModifiers` 里）", """
            import SwiftUI
            let v = EmptyView().accessibilityIdentifier("legend-row")
            """),
            ("`Picker` 的标签式写法（首个实参有标签）", """
            import SwiftUI
            let p = Picker(selection: $mode, label: label) { EmptyView() }
            """),
            // ⚠️ 以下两条钉的是**已知口子**，不是「本该干净」（文件头口子 7 / 8）。
            // 它们**目前放行**；后人收紧判据会在这里当场红，必须同轮改口子清单。
            ("口子 7：`typealias` 改名后按文本判构造器名看不见 ⇒ 放行", """
            import SwiftUI
            typealias T = Text
            let t = T("Loading")
            """),
            ("口子 8：隐式 `.init` 的上下文类型只存在于推断里（数组元素位置）⇒ 放行", """
            import SwiftUI
            let rows: [Text] = [.init("Loading")]
            """),
            ("隐式 `.init` 但上下文类型不是文案构造器 ⇒ 放行", """
            struct Tooltip { init(_ body: String) {} }
            let t: Tooltip = .init("Loading")
            """),
        ]
        for c in clean {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.isEmpty, "\(c.name)：误报 \(hits.map(\.description))")
        }

        // 口子 1 真的被清点了（不判违规 ≠ 看不见）。
        #expect(Self.scan(source: #"let t = Text(verbatim: "42")"#).verbatimSites.count == 1,
                "`Text(verbatim:)` 没有被清点 —— 那个口子就真成了盲区")
        // ⚠️ initializer 形态同样要记账（Copilot A-1：首版连 verbatim 站点都绕过）。
        #expect(Self.scan(source: #"let t = Text.init(verbatim: "42")"#).verbatimSites.count == 1,
                "`Text.init(verbatim:)` 没有被清点 —— 记账通道被 initializer 形态绕过")
        // ⚠️ **隐式** initializer 形态的 verbatim 记账（PR #265 第 3 轮终审 S-b：
        // 首版把 `let t: Text = .init(verbatim: "42")` 整条排除，连清点都丢了）。
        #expect(Self.scan(source: #"let t: Text = .init(verbatim: "42")"#).verbatimSites.count == 1,
                "隐式 `.init(verbatim:)` 没有被清点 —— 记账通道被隐式成员形态绕过")

        // ⚠️ 口子 3 的落点：a11y 三件套**有意**不在本守卫里（归 `AccessibilityStringLiteralGuard`）。
        #expect(Self.scan(source: #"let v = EmptyView().accessibilityHint("Opens settings")"#)
                .violations.isEmpty,
                "a11y modifier 被本守卫重复报了一遍 —— 同一处违规会被两条守卫各报一次")
    }

    /// PR #265 **第 4 轮**终审 I-1 / I-2 在 chrome 侧的对应形态。
    ///
    /// ⚠️ `ImplicitMemberContext` 由两条守卫**共用**（文件头口子 8），色相守卫那边的
    /// 误报 / 漏报因此会**传染**到这里——本条是那条传染路径的实证。
    @Test("上下文类型：实参位置不继承外层返回类型；三元 / `??` 不截断（第 4 轮终审 I-1 / I-2）")
    func contextualTypeDoesNotLeakAcrossArgumentPositions() {
        // ① 误报：外层 `-> Text` 的返回类型被错安到实参位置上的 `.init("…")`。
        let falsePositives: [(name: String, source: String)] = [
            ("函数返回类型被错安到实参", """
            import SwiftUI
            func title() -> Text { render(.init("Loading")) }
            """),
            ("计算属性返回类型被错安到实参", """
            import SwiftUI
            var title: Text { render(.init("Loading")) }
            """),
        ]
        for c in falsePositives {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.isEmpty, """
            \(c.name)：误报 \(hits.map(\.description))
            —— `.init("…")` 落在实参位置时类型来自形参，与外层 `-> Text` 无关。
            """)
        }

        // ② 漏报：三元 / `??` 里**写了类型标注**的隐式 `.init`。
        let falseNegatives: [(name: String, source: String, literal: String)] = [
            ("三元的分支（有类型标注）", """
            import SwiftUI
            let t: Text = flag ? .init("Loading") : other
            """, "Loading"),
            ("`??` 的右侧（有类型标注）", """
            import SwiftUI
            let t: Text = maybe ?? .init("Loading")
            """, "Loading"),
        ]
        for c in falseNegatives {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.contains(where: { $0.literal == c.literal }),
                    "\(c.name)：漏报（期望「\(c.literal)」，实得 \(hits.map(\.literal))）")
        }

        // ③ **没有换来新的漏报**：真标注 / 真返回位置必须仍然命中。
        #expect(Self.scan(source: """
        import SwiftUI
        let t: Text = .init("Loading")
        """).violations.contains(where: { $0.literal == "Loading" }),
                "类型标注形态被收紧判据误伤 —— 这不是 I-1 / I-2 要的结果")
        #expect(Self.scan(source: """
        import SwiftUI
        func title() -> Text { .init("Loading") }
        """).violations.contains(where: { $0.literal == "Loading" }),
                "单表达式返回位置被收紧判据误伤 —— 这不是 I-1 / I-2 要的结果")
    }

    /// PR #265 **第 5 轮**终审 I-a / I-b 在 chrome 侧的对应形态。
    ///
    /// ⚠️ 与上一条同理：`ImplicitMemberContext` 由两条守卫**共用**（文件头口子 8），
    /// 色相守卫那边的赋值右侧误报、默认参数值误报、条件绑定误报会原样**传染**到这里。
    /// 上一轮补断言时 chrome 侧同样只覆盖了实参位置与三元 / `??` 两类 ⇒ 本条补齐两个方向。
    @Test("上下文类型：赋值右侧 / 默认参数值 / 条件绑定各按自己的类型判（第 5 轮终审 I-a / I-b）")
    func contextualTypeRespectsAssignmentsDefaultsAndBindings() {
        // ① 误报方向 —— 必须**清零**（这些位置的宿主类型来自左值 / 形参 / 绑定自己的标注）。
        let falsePositives: [(name: String, source: String)] = [
            ("计算属性 `set` 里的赋值右侧（I-a）", """
            import SwiftUI
            struct S {
                var store = Identifier("")
                var title: Text { get { other } set { self.store = .init("Loading") } }
            }
            """),
            ("`didSet` 里的赋值右侧（I-a）", """
            import SwiftUI
            struct S {
                var store = Identifier("")
                var title: Text = other { didSet { self.store = .init("Loading") } }
            }
            """),
            // ⚠️ **复合赋值**（PR #265 第 5 轮终审 I-1）：`x += .init(…)` 里那个算子是
            // `BinaryOperatorExprSyntax("+=")`、**不是** `AssignmentExprSyntax`，
            // 上一轮只认后者的闸整条漏过 ⇒ 右侧继承了被赋值属性的 `Text` 标注。
            // 上一轮两条 I-a 行只写了裸 `=`，故本组常驻复合赋值形态。
            ("计算属性 `set` 里的**复合**赋值右侧（`+=`，第 5 轮终审 I-1）", """
            import SwiftUI
            struct S {
                var log = ""
                var title: Text { get { other } set { self.log += .init("Loading") } }
            }
            """),
            ("`didSet` 里的复合赋值右侧（`+=`）", """
            import SwiftUI
            struct S {
                var log = ""
                var title: Text = other { didSet { self.log += .init("Loading") } }
            }
            """),
            ("默认参数值继承了外层返回类型（I-b①）", """
            import SwiftUI
            struct Identifier { init(_ raw: String) {} }
            func title(id: Identifier = .init("Loading")) -> Text { other }
            """),
            ("条件绑定自带的类型标注被换成外层标注（I-b②）", """
            import SwiftUI
            struct Identifier { init(_ raw: String) {} }
            var title: Text { if let id: Identifier = .init("Loading") { other } else { other } }
            """),
        ]
        for c in falsePositives {
            let hits = Self.scan(source: c.source).violations
            #expect(!hits.contains(where: { $0.literal == "Loading" }), """
            \(c.name)：误报 \(hits.map(\.description))
            —— 共用的 `ImplicitMemberContext` 把外层标注 / 返回类型错安到了这里。
            """)
        }

        // ② 漏报方向 —— 源码里**写下了** `Text`，必须判红。
        let falseNegatives: [(name: String, source: String)] = [
            ("默认参数值写了 `Text`（I-b① 的镜像）", """
            import SwiftUI
            struct S { func f(t: Text = .init("Loading")) {} }
            """),
            ("`guard let t: Text = .init(…)`（I-b② 的镜像）", """
            import SwiftUI
            func title() -> Text {
                guard let t: Text = .init("Loading") else { return other }
                return t
            }
            """),
        ]
        for c in falseNegatives {
            let hits = Self.scan(source: c.source).violations
            #expect(hits.contains(where: { $0.literal == "Loading" }),
                    "\(c.name)：漏报（期望「Loading」，实得 \(hits.map(\.literal))）")
        }

        // ③ 旧行为不许回退。
        #expect(!Self.scan(source: """
        import SwiftUI
        func title() -> Text { render(.init("Loading")) }
        """).violations.contains(where: { $0.literal == "Loading" }),
                "实参位置的旧修法回退了（第 4 轮 I-1）")
        #expect(Self.scan(source: """
        import SwiftUI
        let t: Text = .init("Loading")
        """).violations.contains(where: { $0.literal == "Loading" }),
                "类型标注这条基本形态被本轮修法误伤")
    }

    @Test("探测器在真实源码上非真空：拿主 target 当靶场必须打出命中")
    func detectorFiresOnRealSource() throws {
        // ⚠️ 与 `EffectsColorLiteralGuard` 同款：`CoreDesign` **不在射程内**
        // （公约 G-4 明载连它自己都没守住 A 类），这里只把它当靶场用。
        let hits = try Self.scan(root: GuardScanRoots.sourcesURL(of: GuardScanRoots.primaryTargetName)).violations
        #expect(hits.count > 10, """
        在 Sources/CoreDesign 上只打出 \(hits.count) 处裸 chrome 文案 —— 探测器疑似失效。
        本条**不是**要求主 target 保持违规，而是「新 target 的零命中来自干净、不是来自
        坏掉的探测器」这句话的活证据。主 target 真被治理干净时，请改成扫常驻 fixture，
        不要直接删掉它。
        """)
    }
}

// MARK: - 采集器 / Collector

private nonisolated final class ChromeTextCollector: SyntaxVisitor {
    var violations: [ChromeTextLiteralGuard.Violation] = []
    var verbatimSites: [String] = []

    private let fileName: String
    private let converter: SourceLocationConverter

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    /// 字面量的**静态段**拼起来（插值段取不到文本，也不该算进可翻译文案）。
    private static func proseText(of literal: StringLiteralExprSyntax) -> String {
        literal.segments.compactMap { segment -> String? in
            segment.as(StringSegmentSyntax.self)?.content.text
        }.joined()
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        node.macroName.text == "Preview" ? .skipChildren : .visitChildren
    }

    /// 从 callee 取「这是不是一个承载 chrome 文案的调用」，取不到返回 `nil`。
    ///
    /// ⚠️ **首版只认裸 `DeclReferenceExprSyntax`**，于是三种形态被**结构性排除**
    /// （Copilot A-1 + 终审 I-3）：限定形态 `SwiftUI.Label(…)`（仓内 `Tag.swift:219`
    /// 的预览已在用）、initializer 形态 `Text.init(verbatim:)`（连 verbatim 记账都绕过）、
    /// 以及 `.navigationTitle("…")` 这类 modifier。
    private static func chromeCallName(of callee: ExprSyntax) -> String? {
        // ① 裸引用：`Text(…)` / `Button(…)`。
        if let ref = callee.as(DeclReferenceExprSyntax.self) {
            return ChromeTextLiteralGuard.textConstructors.contains(ref.baseName.text)
                ? ref.baseName.text : nil
        }
        guard let member = callee.as(MemberAccessExprSyntax.self) else { return nil }
        // ② modifier：`.navigationTitle("Settings")`。base 是任意 View 表达式，不看它。
        let memberName = member.declName.baseName.text
        if ChromeTextLiteralGuard.textModifiers.contains(memberName) { return memberName }
        // ③ 限定 / initializer 形态：`SwiftUI.Label(…)` / `Text.init(…)` / `SwiftUI.Text.init(…)`。
        var segments = callee.trimmedDescription
            .split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let isInitForm = segments.last == "init"
        if isInitForm { segments.removeLast() }
        // ④ **隐式** initializer 形态 `let t: Text = .init("Loading")`（PR #265 第 3 轮终审 S-b）：
        // 剥掉尾段 `init` 之后只剩一个空段（`omittingEmptySubsequences: false` 之故），
        // 首版在这里要求「尾段非空」⇒ 整条形态被结构性排除，**连 verbatim 记账都绕过**。
        // 而 `EffectsColorLiteralGuard` 对同一形态**有**处理——这条不对称此前无任何记录。
        // ⇒ 与色相守卫共用 `ImplicitMemberContext`：宿主类型来自上下文里真的写下的类型。
        if isInitForm, segments.last == "" || segments.isEmpty {
            guard let annotated = ImplicitMemberContext.contextualTypeName(of: callee),
                  ChromeTextLiteralGuard.textConstructors.contains(annotated) else { return nil }
            return annotated
        }
        guard let last = segments.last,
              ChromeTextLiteralGuard.textConstructors.contains(last) else { return nil }
        return last
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let callName = Self.chromeCallName(of: node.calledExpression)
        else { return .visitChildren }

        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let snippet = node.trimmedDescription
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")

        // 带标签实参上的文案（今天只有 `.searchable(prompt:)`，见 `labeledProseArguments`）。
        if let labels = ChromeTextLiteralGuard.labeledProseArguments[callName] {
            for argument in node.arguments {
                guard let label = argument.label?.text, labels.contains(label),
                      let literal = argument.expression.as(StringLiteralExprSyntax.self)
                else { continue }
                let text = Self.proseText(of: literal)
                guard ChromeTextLiteralGuard.isProse(text) else { continue }
                self.violations.append(
                    .init(file: self.fileName, line: line, literal: text, snippet: String(snippet.prefix(120)))
                )
            }
        }

        guard let first = node.arguments.first else { return .visitChildren }

        // 口子 1：`Text(verbatim:)` 只清点。
        if first.label?.text == "verbatim" {
            self.verbatimSites.append("\(self.fileName):\(line)")
            return .visitChildren
        }
        // 只看**第一个无标签实参**——`systemImage:` 之类的值不是给人读的文案。
        guard first.label == nil,
              let literal = first.expression.as(StringLiteralExprSyntax.self)
        else { return .visitChildren }

        let text = Self.proseText(of: literal)
        guard ChromeTextLiteralGuard.isProse(text) else { return .visitChildren }

        self.violations.append(
            .init(file: self.fileName, line: line, literal: text, snippet: String(snippet.prefix(120)))
        )
        return .visitChildren
    }
}
