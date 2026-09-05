import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 判据引用的可核验性 / Judgement reference resolvability（Issue #287）
//
// ## 它守什么
//
// **源码注释、`#expect` 文案、`docs/**.md`、`docs/component-registry.json`
// 与**仓库根那一层 `.md`**（`CLAUDE.md` / `AGENTS.md` / `README.md` /
// `ACKNOWLEDGEMENTS.md`）里形如「测试类型 + 点 + 成员名」的引用，
// 其类型与成员必须在测试目标里真的存在。**
//
// ⚠️ 仓库根那一层是 `#287` 第 2 轮终审补进来的，代价是实测出来的：这条纪律**写在
// `CLAUDE.md` 里**，而 `CLAUDE.md` 当时不在扫描面 ⇒ 纪律对自己的载体不生效。
// 那一层当时活着两条真悬空引用（`CLAUDE.md` 与 `AGENTS.md` 各一条同文的
// `ComponentRegistryGuard` 单根声称，`#270` 之后已失真），且**本 PR 自己为同一个符号
// 修了另外三处**却漏了这两处——正是本判据要堵的形态。
//
// ## 为什么这是一条判据而不是一条约定
//
// 本仓的质量体系建立在「每条主张都有一条判据钉住它」之上，注释里的判据引用是这条链的
// **可核验入口**。悬空引用有两重腐蚀性：读者按图索骥找不到，无法核验注释声称的性质
// 是否真的被钉住；后来者维护时可能因为「注释指向的判据不存在」而误判某个真实守卫
// 是多余的并删掉。
//
// ⚠️⚠️ **这一族在单次会话里出现了六次，分布在四个 PR、六个不同 agent 写出的改动里，
// 每一次都是 Copilot 抓到、终审漏掉。** 终审漏掉的原因是结构性的：核对一条引用需要
// **逐符号去测试目录里找**，而评审读 diff 时手上没有那张表，于是「这个名字看着像真的」
// 就过去了。⇒ 这件事必须由机器做，靠人记得已经被证伪六次。
//
// ## 判据形态：符号表来自**解析出来的声明**，不是 grep
//
// ⚠️ 本仓已有四次「判据钉住某一种写法、等价改写即逃逸」的实测教训（判据钉变量名 ⇒
// 改名即逃逸；判据钉 `\.` 前缀 ⇒ 写成 `\EnvironmentValues.` 即等价逃逸；needle 禁住
// `MicroInteractionAPITests.stablePixels` 却放过严格更差的 `.pixels`；
// `storedProperties(in:)` 只认 `let ` ⇒ `var` 存储属性整个不可见），外加一条更狠的
// ——`TransitionPropertiesGuard.everyTransitionHasARuntimeExpectation` 初版是纯文本匹配，
// **两行注释就能满足它**。⇒ 本判据的两侧都不靠形状：
//
// 1. **符号表侧走 SwiftSyntax**：`Tests/**` 与 `Sources/**` 全量解析，从
//    `struct` / `class` / `enum` / `actor` / `protocol` / `extension` 的**声明节点**
//    收成员（`func` / `var` / `let` / `case` / 嵌套类型 / `typealias` / `init` / `subscript`）。
//    副产物很关键：**写在字符串字面量里的 fixture 类型不会进表**——本仓的守卫大量把
//    合成源码放在多行字符串里，逐行 grep 会把那些合成类型当成真类型，
//    从而给一堆散文引用发绿灯。
// 2. **引用侧走语法树的 trivia 与字符串片段**：Swift 文件只扫**注释**与**字符串字面量**，
//    不扫代码——代码里的引用由编译器管，比本判据严格得多。走 trivia 而不是整文件文本，
//    是为了让「这段文字是注释还是代码」由解析器判定。
//
// ## 判定规则
//
// 设引用为 `T.m`，`T` 的**可见范围**按引用所在文件定：`Tests/<target>/` 下的文件
// 看得到该 test target 与全部 `Sources/`；`Sources/**` 与 `docs/**` 看得到全部目标。
//
// · **规则 A（不钉形状）**：`T` 在可见范围的**测试目标**里有**主声明**
//   （`struct` / `class` / `enum` / `actor` / `protocol`，不是只有 `extension`），
//   **且它的成员集可知** ⇒ `m` 必须是它的成员（成员集取「测试表 ∪ `Sources/` 表」）。
//   这一条与命名习惯无关：把 suite 改名成任何东西，它照样管。
//   ⚠️ **只认测试目标里的主声明**，是 `#287` 验收逐字划的射程。库类型（设计 token /
//   组件）在文档里的引用漂移是**另一族缺陷**，本判据不认领——`docs/BREAKING-CHANGES.md`
//   整篇就是在记录被删掉的 token，一并判红只会逼人关掉判据。
// · **规则 B（钉形状，如实登记）**：`T` 在**任何**目标里都没出现过，但名字**长于**且以
//   `Tests` / `Guard` 结尾 ⇒ 判为悬空类型。
//   ⚠️ 这一条**必须**靠名字：类型压根不存在时，语法层没有任何别的信号能说明
//   「这是一个判据引用」而不是「这是别人家框架的一个类型」。
//
// ### 「成员集可知」是什么意思（这是本判据不误红的关键）
//
// 一个类型的成员集**只有在继承子句整条链都落在语料内**时才是可知的。
// `struct Node: GraphNode`、`GraphNode` 又继承语料外的协议 ⇒ `Node` 的 `ID` 是协议给的、
// 语法层看不见 ⇒ **`Node` 的成员不核**。
// 判据 suite 与守卫都是**不带继承子句的裸 `struct`**，全部落在规则 A 的射程内。
//
// ## ⚠️ 找到但**堵不住**的路径（如实登记，不是完备性宣称）
//
// **这一节是要求，不是既成事实的完备保证。** 以下写法今天能从本判据下走过去：
//
// - **给不存在的 suite 起一个不以 `Tests` / `Guard` 结尾的名字**（规则 B 的形状面）。
//   ⚠️ 但它一旦真的存在，规则 A 就接管了成员核对——逃的只有「类型名整个是编造的」这一半。
// - **引用一个 SDK / 第三方类型的不存在成员**：语料里没有该类型 ⇒ 两条规则都不认领。
//   这是有意的射程：本判据守的是**本仓判据引用**，不是全宇宙符号。
// - **有继承子句的类型，成员不核**（见上）。判据 suite 不在此列，但它们的**辅助类型**
//   （`Hashable` / `Sendable` 之类的一致性）在。
// - **只有 `extension` 的类型，成员不核**：扩展 stdlib 类型会让那个名字出现在语料里，
//   但它的成员集在 stdlib 里 ⇒ 不核（否则散文里提到的任何 stdlib 成员都会被判红）。
// - **跨 test target 的引用只核类型存在性、不核成员**：可见范围按 target 切
//   （两个 target 里各有一个的短名字，不切就会互相误判）。
// - **只在 `Sources/` 里声明的类型，成员不核**（见规则 A 的射程说明）。
// - **模块限定名整个不认领**：`<模块名>.<类型名>` 是 `swift test --filter` 的写法，
//   本仓文档里到处都是。模块名取自 `Package.swift` 的 target 声明（结构性，不是白名单）。
// - **`A.B.c` 只核到第一跳**：记下的是 `A.B`（`B` 若是 `A` 的嵌套类型就通过），
//   第二跳不再核。
// - **只写判据名、不写类型名**（「判据 `chromeDrawsParticlesMidFlight` 钉住…」）：
//   没有类型前缀就没有引用可解析。本仓惯例是写全限定名，但惯例不是判据。
// - **同名类型的成员并集**：符号表按**简名**归并（`Violation` 在好几个守卫里各有一个）。
//   收紧它需要按嵌套路径归并，代价是散文里的短写法（本仓通篇如此）会大面积误判红。
// - **`App/Tests/` 与 `scripts/downstream-probe/` 不在扫描面内**：前者属 xcodegen 生成的
//   预览宿主、后者是独立 SwiftPM 包，两者都不在 `Package.swift` 的 target 图里。
//   ⚠️ 这不是「扫过了发现零违规」，而是**根本没扫**。
// - **`.claude/**` 不在扫描面内**（`#287` 第 2 轮终审 I-2 (a)）：那是 PRD / epic / 任务的
//   **历史归档**，173 个 `.md`。⚠️ **代价已实测，不是零**：那片面里活着若干条真悬空引用
//   （`ComponentRegistryGuard` 的 `coreDesignSources` 在 `.claude/epics/**` 有 5 处、
//   `BoolExemptionGuard` 的同名成员 1 处，另有几条已失效的 suite 成员名）。
//   **有意不扫**：归档记录的是「写下它的那天的事实」，按「撤回痕迹拆开写」的纪律回改
//   等于篡改归档；而不改又必然判红 ⇒ 只能扫进来再全量豁免，那等于一张长白名单。
//   ⇒ 登记为已知缺口。仓库根那四个 `.md` 与它不同：那是**现行**指引，必须先管住自己。
// - **紧跟在 CJK 字符后面的引用永远提取不到**（`#287` 第 2 轮终审 I-2 (b)）：
//   `references(inText:file:startingAtLine:)` 在前一个字符 `.isLetter` 时拒绝该起点，
//   而 `Character("见").isLetter == true` ⇒ 形如「`见` 紧贴类型名、再跟点与成员名」的写法
//   整个抽不出来，隔一个空格的孪生体抽得出来（⚠️ 这里刻意**不写出**那个粘连例子本身：
//   它今天抽不出来、将来这个洞被堵上时就会变成本文件上的一条假引用）。
//   **在一个散文是中文的仓里这是结构性的洞。**
//   ⚠️ **今天曝露为零**（`grep -rnP '[\x{4e00}-\x{9fff}][A-Z]\w*(Tests|Guard)\.\w'`
//   over `Sources Tests docs` 加仓库根四个 `.md` = 0 命中）⇒ 这是**登记缺口，不是活缺陷**。
//   收紧它要把「前一个字符」的判据从 `isLetter` 改成「ASCII 标识符字符」，代价是
//   `内联CamelCase.member` 这种粘连写法会开始被认领——今天没有语料能证明那一侧不误红，
//   故留在此处登记而不动。
// - **Markdown 围栏代码块按散文扫**（`#287` 第 2 轮终审 I-2 (c)）：```` ```swift ```` 块里的
//   `X.y` 与散文里的一视同仁。这是**未来的假阳性发生器**——`docs/superpowers/plans/`
//   的 17 个 `.md` 已经含 Swift 片段。⚠️ **今天不咬人**：把扫描面扩到仓库根 `.md` 之后
//   跑 J1，命中恰好是 **I-1** 那两条真违规（`CLAUDE.md` / `AGENTS.md` 各一条同文的
//   `ComponentRegistryGuard` 单根声称），**零条来自围栏**。
//   ⚠️ 上一版此处写的是「I-2 (a)」——那是紧邻的 `.claude/**` 缺口，按其自述是 5+1 条
//   且**根本没被扫**，扩面一条都命中不到。⇒ 一条**指错的引用**，出现在讲「引用不能
//   指错」的文件里（`#287` 第 2 轮终审 S-1）。
//   **有意不做围栏剥离**：剥离本身要在这里再实现一个 Markdown 解析器
//   （围栏有 ``` / ~~~ 两种、可任意加长、可缩进），而它一旦有 bug 就是**静默放行**
//   ——把真引用当成围栏内容跳过，比今天这个已知的假阳性方向危险得多。
//   ⇒ 等第一条真假阳性出现时再处置，届时优先考虑「围栏内只降级为警告」而不是整块跳过。
// - **成员的可见性 / 静态性不核**：`private` 成员被外部文档引用照样放行。
//   本判据要答的问题是「这个名字指得到东西吗」，不是「这个名字在那个上下文里可访问吗」。
// - **扫描面按文件系统枚举，不按 git 索引**（`#287` 第 2 轮终审 S-4）：一个**从未
//   `git add`** 的文件只要落在扫描面里就照样被扫。实测：往仓库根扔一个未跟踪的
//   `.md` 草稿（里面写着两条悬空引用）⇒ J1 当场判红两条。
//   ⚠️ 这不是新**种类**（`docFiles()` / `swiftFiles(in:)` 一直是文件系统枚举），
//   但**仓库根是散文件最容易落地的一层**——随手的笔记、下载来的 README、agent 的临时
//   产物都往这儿掉，而 `docs/` 与 `Sources/` 不会。⇒ 本地看到「J1 红在一个你没提交过
//   的文件上」时，先看是不是这条，删掉草稿即绿。
//   **有意不改成读索引**：判据要守的是**工作树里的现行文本**——只认索引意味着
//   「改完还没 `git add` 的那一版不受约束」，那正是判据最该管住的时刻。
//
// ## ⚠️ 写作纪律：本判据不区分「活引用」与「历史提及」
//
// 「上一版这里写的是某个类型的某个成员」这种**撤回痕迹**，在本判据眼里与活引用一样
// ——它同样是一个读者会去找、却找不到的名字。⇒ 提及一个**已被改名 / 删除**的符号时
// 请**拆开写**（类型名与成员名各自加反引号，中间不用点连），并在同处写明它现在叫什么：
// 既保留撤回痕迹的可读性，又不产出一个指不到的符号。`#287` 按这条纪律改了三处历史提及。
//
// 同理，**跨仓符号**（`oh-my-story` 那边的判据）也要拆开写：本判据的语料只有本仓，
// 不拆开就会被判成悬空。
//
// ⚠️ **「按显式仓库前缀做结构性豁免」这个替代方案已评估并否掉**（`#287` 第 2 轮终审 S-2）：
// 唯一可实现的形态是「本行提到了外仓 slug ⇒ 豁免本行的引用」，而本仓文档里
// **含 `oh-my-story` 的行有 144 行、其上坐着 87 条候选引用**（占文档面 1943 条的 4.5%）
// ——`docs/component-contract.md` 的表格行动辄数千字符，一行里同时提外仓和本仓判据是常态。
// ⇒ 为省掉**今天仅 1 处**的散文别扭，代价是让判据在本仓文档最密的那一片上静默失效。
// 收益/代价倒挂 ⇒ 维持散文纪律。真到「跨仓引用多到 scale 不动」的那天，正确的做法是
// **给引用本身定一个可解析的形态**（例如 `<仓>#<类型>#<成员>`，三段各自可校验），
// 而不是按「同一行里出现过某个词」豁免。
//
// ⚠️ 本判据**会扫自己的注释与字符串字面量**。⇒ 上面的散文里不出现编造的类型名，
// 下面 J3 的 fixture 里那些「不存在的类型」一律**拼**出来，不写成字面量
// ——写死会让 J1 判红在本文件上。
//
// ## 相邻形态：`docs/component-registry.json` 的 `notes` 只被守住一半
//
// `notes` 里还有一族更隐蔽的失真：**引用的判据真实存在，但被声称证明了它证明不了的事**
//（`#286` 的 `.move`、`#291` 的 `blinds` 都是「别处已更正、登记表没跟上」）。
// 本判据抓得住「登记表引用了已删除 / 改名的判据」，抓不住「声称的证明力超过判据实际
// 能证明的」——后者**没有机器判据**，如实登记为人工评审项，缓解手段写在 `CLAUDE.md`
// 的评审约定里（更正一处声称必须 grep 该判据名，三处落点同步）。

@Suite("#287 判据引用的可核验性")
struct JudgementReferenceGuard {

    // MARK: - 违规记录

    nonisolated enum ViolationKind: String, Hashable, Sendable {
        /// 类型名在任何目标里都不存在（规则 B）。
        case unknownType
        /// 类型存在且成员集可知，但没有这个成员（规则 A）。
        case unknownMember
    }

    nonisolated struct Violation: Hashable, Sendable, CustomStringConvertible {
        let file: String
        let line: Int
        let type: String
        let member: String
        let kind: ViolationKind

        var description: String {
            switch self.kind {
            case .unknownType:
                return "\(self.file):\(self.line)  `\(self.type).\(self.member)` —— 类型 `\(self.type)` 在测试目标里不存在"
            case .unknownMember:
                return "\(self.file):\(self.line)  `\(self.type).\(self.member)` —— `\(self.type)` 存在，但它没有成员 `\(self.member)`"
            }
        }
    }

    // MARK: - 规则 B 的形状面（如实登记：这一条靠名字）

    /// 类型不存在时，仅凭名字判定「这是一个判据引用」的后缀。
    ///
    /// ⚠️ 比对要求**严格长于**后缀本身：「拿后缀当通配符」的写法（本仓真实存在，
    /// `MaskRevealTests` 里数的就是两个以 `Tests` 结尾的调用后缀）不是一次引用，
    /// `hasSuffix` 单独用会把它判红。
    nonisolated static let suiteNameSuffixes: [String] = ["Tests", "Guard"]

    /// 永远不当成成员的名字。
    ///
    /// ⚠️ `Type` / `self` / `Protocol` 是 Swift 的元类型语法，不是成员；
    /// `swift` / `md` / `json` 这些是**文件扩展名**——散文里写
    /// `ComponentRegistryGuard.swift` 指的是文件不是成员，那是本仓最常见的一种写法。
    nonisolated static let excludedMemberNames: Set<String> = [
        "self", "Type", "Protocol",
        "swift", "md", "json", "yml", "yaml", "sh", "png", "jpg", "jpeg", "pdf", "txt",
        "plist", "xcassets", "xcodeproj", "xcworkspace", "xcscheme", "lproj", "resolved",
        "metal", "car", "strings", "xcstrings", "toml", "lock", "gitignore", "bundle",
    ]

    // MARK: - 符号表（SwiftSyntax：只认解析出来的声明）

    /// 一批源文件里的类型声明。
    ///
    /// ⚠️ **主声明与 `extension` 分开记**：只有 `extension` 的类型其成员集在语料之外，
    /// 核成员只会误红。
    nonisolated struct SymbolTable: Sendable {
        /// 有主声明的类型 → 主声明体里的成员名。
        var primaryMembers: [String: Set<String>] = [:]
        /// 任意类型 → `extension` 体里的成员名。
        var extensionMembers: [String: Set<String>] = [:]
        /// 类型 → 继承子句里出现过的名字（主声明与 `extension` 都算）。
        var inherited: [String: Set<String>] = [:]
        /// 语料里以任何形式出现过的类型名（主声明 / 被扩展 / 出现在继承子句里）。
        var knownNames: Set<String> = []

        mutating func formUnion(_ other: SymbolTable) {
            for (key, value) in other.primaryMembers { self.primaryMembers[key, default: []].formUnion(value) }
            for (key, value) in other.extensionMembers { self.extensionMembers[key, default: []].formUnion(value) }
            for (key, value) in other.inherited { self.inherited[key, default: []].formUnion(value) }
            self.knownNames.formUnion(other.knownNames)
        }

        func union(_ other: SymbolTable) -> SymbolTable {
            var copy = self
            copy.formUnion(other)
            return copy
        }

        func members(of name: String) -> Set<String> {
            (self.primaryMembers[name] ?? []).union(self.extensionMembers[name] ?? [])
        }

        /// 成员集**可知**的类型：有主声明，且继承链上每个名字都在本表里有主声明。
        ///
        /// ⚠️ 定点迭代而不是一遍扫：`A: B`、`B: C`、`C` 不在语料里 ⇒ 三个都不可知，
        /// 一遍扫只能判出 `B`。
        var knowableTypes: Set<String> {
            var open: Set<String> = []
            var changed = true
            while changed {
                changed = false
                for name in self.primaryMembers.keys where !open.contains(name) {
                    let parents = self.inherited[name] ?? []
                    let unresolved = parents.contains { self.primaryMembers[$0] == nil || open.contains($0) }
                    if unresolved {
                        open.insert(name)
                        changed = true
                    }
                }
            }
            return Set(self.primaryMembers.keys).subtracting(open)
        }
    }

    nonisolated static func symbolTable(of files: [(name: String, source: String)]) -> SymbolTable {
        var out = SymbolTable()
        for file in files {
            let tree = SwiftParser.Parser.parse(source: file.source)
            let collector = DeclarationCollector(viewMode: .sourceAccurate)
            collector.walk(tree)
            out.formUnion(collector.table)
        }
        return out
    }

    // MARK: - 引用抽取

    nonisolated struct Reference: Hashable, Sendable {
        let file: String
        let line: Int
        let type: String
        let member: String
    }

    /// 一段**纯文本**里的引用。`startingAtLine` 是这段文本第一行在文件里的行号。
    ///
    /// ⚠️ 手写扫描而不是正则：需要「前一个字符不是标识符字符 / 点 / 斜杠 / 反斜杠」这条
    /// 边界——文件名里的扩展名、限定名中段的成员、键路径根之后的类型名
    /// 都不该被当成一次引用的起点。
    nonisolated static func references(
        inText text: String, file: String, startingAtLine: Int
    ) -> [Reference] {
        var out: [Reference] = []
        var lineNumber = startingAtLine
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let chars = Array(rawLine)
            var index = 0
            while index < chars.count {
                guard chars[index].isUppercase, chars[index].isLetter else {
                    index += 1
                    continue
                }
                if index > 0 {
                    let previous = chars[index - 1]
                    if previous.isLetter || previous.isNumber
                        || previous == "_" || previous == "." || previous == "/" || previous == "\\" {
                        index += 1
                        continue
                    }
                }
                var end = index
                while end < chars.count, Self.isIdentifierCharacter(chars[end]) { end += 1 }
                let type = String(chars[index..<end])
                guard end < chars.count, chars[end] == "." else {
                    index = end
                    continue
                }
                let memberStart = end + 1
                guard memberStart < chars.count,
                      chars[memberStart].isLetter || chars[memberStart] == "_" else {
                    index = end + 1
                    continue
                }
                var memberEnd = memberStart
                while memberEnd < chars.count, Self.isIdentifierCharacter(chars[memberEnd]) { memberEnd += 1 }
                out.append(Reference(
                    file: file, line: lineNumber,
                    type: type, member: String(chars[memberStart..<memberEnd])
                ))
                index = memberEnd
            }
            lineNumber += 1
        }
        return out
    }

    nonisolated static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// 一个 Swift 文件里的引用：**只取注释 trivia 与字符串字面量片段**。
    ///
    /// ⚠️ 代码里的同形引用有意不收：那些由编译器核对，比本判据严格。
    nonisolated static func references(inSwift source: String, file: String) -> [Reference] {
        let tree = SwiftParser.Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        var out: [Reference] = []

        func emit(_ text: String, at offset: Int) {
            let line = converter.location(for: AbsolutePosition(utf8Offset: offset)).line
            out.append(contentsOf: Self.references(inText: text, file: file, startingAtLine: line))
        }

        for token in tree.tokens(viewMode: .sourceAccurate) {
            var offset = token.position.utf8Offset
            for piece in token.leadingTrivia {
                if let text = Self.commentText(of: piece) { emit(text, at: offset) }
                offset += piece.sourceLength.utf8Length
            }
            if case .stringSegment = token.tokenKind {
                emit(token.text, at: token.positionAfterSkippingLeadingTrivia.utf8Offset)
            }
            offset = token.endPositionBeforeTrailingTrivia.utf8Offset
            for piece in token.trailingTrivia {
                if let text = Self.commentText(of: piece) { emit(text, at: offset) }
                offset += piece.sourceLength.utf8Length
            }
        }
        return out
    }

    nonisolated static func commentText(of piece: TriviaPiece) -> String? {
        switch piece {
        case .lineComment(let text), .blockComment(let text),
             .docLineComment(let text), .docBlockComment(let text):
            return text
        default:
            return nil
        }
    }

    // MARK: - 判定

    /// 引用的可见范围：`Tests/<target>/…` 只看得到那个 test target；其余看得到全部。
    nonisolated static func visibleScope(of file: String) -> String? {
        let parts = file.split(separator: "/")
        guard parts.count >= 2, parts[0] == "Tests" else { return nil }
        return String(parts[1])
    }

    /// 引用所在的**扫描面** —— 成员核对计数的桶键。
    ///
    /// ⚠️ 这个枚举是**全**的（`other` 兜底、无 `nil` 出口），于是
    /// `memberCheckedCount == memberCheckedByFace.values` 之和**结构性成立**：
    /// 任何一条走到规则 A 的引用都必然落进某个桶，按面下界不会因为「归错桶 ⇒ 该桶恒为 0
    /// ⇒ 判据永远红」或「漏计 ⇒ 某面恒真」而失真。
    nonisolated enum ScanFace: String, Hashable, Sendable, CaseIterable {
        case sources = "Sources/**"
        case tests = "Tests/**"
        case docs = "docs/**"
        case rootDocuments = "<仓库根>/*.md"
        case other = "(扫描面之外)"

        /// 路径按 `GuardScanRoots.relativePath(_:)` 的口径（相对仓库根、无前导 `/`）。
        /// ⚠️ 仓库根那一层的判别是「**不含斜杠**」，不是列举那四个文件名
        /// ——列举等于把 `rootDocFiles()` 的枚举结果抄一份，两处会各自漂移。
        nonisolated static func of(_ file: String) -> ScanFace {
            if file.hasPrefix("Sources/") { return .sources }
            if file.hasPrefix("Tests/") { return .tests }
            if file.hasPrefix("docs/") { return .docs }
            if !file.contains("/") { return .rootDocuments }
            return .other
        }
    }

    /// 一次判定的产物：违规清单 + **规则 A 在每个扫描面上各真的走到过几次**。
    ///
    /// ⚠️ 成员核对计数不是统计口味，是 J1 的**非空前置**：J1 那几条既有 `#require` 只钉住
    /// 「文件枚举 / 文档枚举 / 引用条数 / 符号表大小」非空，再加上「某个 URL 在枚举列表里」
    /// ——**没有任何一条证明规则 A 的成员核对分支在真实语料上被进入过**。将来任何一次重构
    /// （作用域切分改动、`primaryMembers` 归并口径变化、抽取端对某一层直接返回空）让规则 A
    /// 在真实语料上不可达时，J1 照绿——只有 J3-a 的合成 fixture 会红，而那证明不了真实语料。
    ///
    /// ⚠️ **按面分桶而不是一个总数**（`#287` 第 2 轮终审 I-1 / I-2）：总数下界只拦得住
    /// 「语料整个塌掉」，拦不住「**某一面**被静默掐掉」——两条实测见 J1 里那段注释。
    nonisolated struct Analysis: Sendable {
        var violations: [Violation] = []
        /// 走到规则 A 成员核对的引用条数，按扫描面分桶（不论最终是否判红）。
        var memberCheckedByFace: [ScanFace: Int] = [:]

        /// 全部面之和。
        var memberCheckedCount: Int { self.memberCheckedByFace.values.reduce(0, +) }

        func memberChecked(on face: ScanFace) -> Int { self.memberCheckedByFace[face] ?? 0 }

        /// 各面当下值，给失败信息用。
        var faceBreakdown: String {
            ScanFace.allCases
                .map { "\($0.rawValue)=\(self.memberChecked(on: $0))" }
                .joined(separator: "、")
        }
    }

    /// - Parameters:
    ///   - testSymbols: 每个 test target 一张表。
    ///   - sourceSymbols: 全部 `Sources/` 合成一张表（library target 之间互相可见）。
    ///   - moduleNames: `Package.swift` 里声明的全部 target 名——模块限定名不认领。
    nonisolated static func violations(
        references: [Reference],
        testSymbols: [String: SymbolTable],
        sourceSymbols: SymbolTable,
        moduleNames: Set<String>
    ) -> [Violation] {
        Self.analyse(
            references: references, testSymbols: testSymbols,
            sourceSymbols: sourceSymbols, moduleNames: moduleNames
        ).violations
    }

    nonisolated static func analyse(
        references: [Reference],
        testSymbols: [String: SymbolTable],
        sourceSymbols: SymbolTable,
        moduleNames: Set<String>
    ) -> Analysis {
        var globalTests = SymbolTable()
        for table in testSymbols.values { globalTests.formUnion(table) }
        let globalNames = globalTests.knownNames.union(sourceSymbols.knownNames)

        var scopedTables: [String: SymbolTable] = [:]
        var scopedKnowable: [String: Set<String>] = [:]
        let globalScopeKey = ""
        /// 该可见范围内的**测试**符号表（不含 `Sources/`）——决定「这个名字算不算判据引用」。
        func scopedTestOnly(_ scope: String?) -> SymbolTable {
            scope.flatMap { testSymbols[$0] } ?? globalTests
        }
        /// 测试表 ∪ `Sources/` 表——成员核对与可知性计算都在这张合并表上做
        ///（判据 suite 里的嵌套类型可能继承 `Sources/` 里的协议）。
        func table(for scope: String?) -> SymbolTable {
            let key = scope ?? globalScopeKey
            if let cached = scopedTables[key] { return cached }
            let built = scopedTestOnly(scope).union(sourceSymbols)
            scopedTables[key] = built
            scopedKnowable[key] = built.knowableTypes
            return built
        }

        var out: [Violation] = []
        var memberChecked: [ScanFace: Int] = [:]
        for reference in references {
            if Self.excludedMemberNames.contains(reference.member) { continue }
            if moduleNames.contains(reference.type) { continue }

            let scope = Self.visibleScope(of: reference.file)
            let visible = table(for: scope)
            let knowable = scopedKnowable[scope ?? globalScopeKey] ?? []

            // ⚠️ **只有「测试目标里主声明过的类型」才核成员**（`#287` 验收逐字划的射程）：
            // 库类型（设计 token / 组件）在文档里的引用漂移是**另一族缺陷**，本判据不认领
            // ——`docs/BREAKING-CHANGES.md` 整篇就是在记录被删掉的 token，
            // 一并判红只会逼人关掉判据。
            if scopedTestOnly(scope).primaryMembers[reference.type] != nil {
                guard knowable.contains(reference.type) else { continue }
                memberChecked[ScanFace.of(reference.file), default: 0] += 1
                if !visible.members(of: reference.type).contains(reference.member) {
                    out.append(Violation(
                        file: reference.file, line: reference.line,
                        type: reference.type, member: reference.member, kind: .unknownMember
                    ))
                }
                continue
            }
            // 可见范围之外但语料里确实有 ⇒ 跨 target 引用，只核到「类型存在」为止。
            guard !globalNames.contains(reference.type) else { continue }
            let looksLikeSuite = Self.suiteNameSuffixes.contains {
                reference.type.count > $0.count && reference.type.hasSuffix($0)
            }
            if looksLikeSuite {
                out.append(Violation(
                    file: reference.file, line: reference.line,
                    type: reference.type, member: reference.member, kind: .unknownType
                ))
            }
        }
        return Analysis(
            violations: out.sorted {
                ($0.file, $0.line, $0.type, $0.member) < ($1.file, $1.line, $1.type, $1.member)
            },
            memberCheckedByFace: memberChecked
        )
    }

    // MARK: - 磁盘装载

    nonisolated static func load(_ urls: [URL]) throws -> [(name: String, source: String)] {
        try urls.map { (GuardScanRoots.relativePath($0), try String(contentsOf: $0, encoding: .utf8)) }
    }

    nonisolated static func swiftScanFace() throws -> [URL] {
        var out: [URL] = GuardScanRoots.allRoots.flatMap { GuardScanRoots.swiftFiles(in: $0.url) }
        for root in try GuardScanRoots.testRootDirectories() {
            out.append(contentsOf: GuardScanRoots.swiftFiles(in: root))
        }
        return out.sorted { $0.path < $1.path }
    }

    /// 文档面 = `docs/**`（`.md` + 登记表）**加上仓库根那一层 `.md`**。
    ///
    /// ⚠️ 根那一层是 `#287` 第 2 轮终审补进来的：`CLAUDE.md` / `AGENTS.md` 就是写着
    /// 「判据引用必须指得到真实符号」这条纪律的文件，却在扫描面之外
    /// ——纪律对自己的载体不生效，实测代价是那一层当时活着两条真悬空引用。
    nonisolated static func docScanFace() -> [URL] {
        (GuardScanRoots.docFiles() + GuardScanRoots.rootDocFiles()).sorted { $0.path < $1.path }
    }

    /// 仓库根那一层里**必须**在扫描面内的 `.md` —— J1 与 J2 共用同一张表。
    ///
    /// ⚠️ **一张表而不是两处各写一份**（`#287` 第 2 轮终审 S-2）：上一版 J1 钉两个
    /// （`CLAUDE.md` / `AGENTS.md`）、J2 钉三个（多一个 `README.md`），
    /// `ACKNOWLEDGEMENTS.md` **两处都没钉**，而两处名单为何不同也没写过理由
    /// ⇒ 将来给 `rootDocFiles()` 加一个「跳过第三方文本」之类的过滤，两条断言都不会响。
    /// 现在四个全钉、只有一份名单：删掉其中任何一个都得动这一行。
    nonisolated static let pinnedRootDocuments: [String] = [
        "ACKNOWLEDGEMENTS.md", "AGENTS.md", "CLAUDE.md", "README.md",
    ]

    // MARK: - J1：全仓扫描

    @Test("J1：源码 / 测试 / 文档里的判据引用必须指得到真实符号")
    func everyJudgementReferenceResolves() throws {
        let swiftURLs = try Self.swiftScanFace()
        // ⚠️ **非空前置**：枚举失效时下面的断言会在空集上恒真——「零文件 ⇒ 零违规 ⇒ 绿」
        // 是本仓反复记在案的病型。
        try #require(swiftURLs.count > 200, """
        只枚举到 \(swiftURLs.count) 个 Swift 源文件 —— 扫描失效，这不是「零违规」。
        """)
        let docURLs = Self.docScanFace()
        try #require(docURLs.count > 30, """
        只枚举到 \(docURLs.count) 个文档文件 —— 扫描失效，这不是「零违规」。
        """)
        try #require(docURLs.contains { $0.lastPathComponent == "component-registry.json" }, """
        `docs/component-registry.json` 不在扫描面里 —— `#287` 的追加验收逐字要求它在。
        """)
        for guide in Self.pinnedRootDocuments {
            try #require(docURLs.contains { $0.lastPathComponent == guide }, """
            `\(guide)` 不在扫描面里 —— 仓库根那一层是**现行**指引的所在地，
            「判据引用必须指得到真实符号」这条纪律就写在其中两份里，它必须先管住自己
            （`#287` 第 2 轮终审 I-1：那一层当时活着两条真悬空引用，正是从这个缺口漏出去的）。
            """)
        }

        var testSymbols: [String: SymbolTable] = [:]
        for root in try GuardScanRoots.testRootDirectories() {
            testSymbols[root.lastPathComponent] = Self.symbolTable(
                of: try Self.load(GuardScanRoots.swiftFiles(in: root))
            )
        }
        let sourceSymbols = Self.symbolTable(
            of: try Self.load(GuardScanRoots.allRoots.flatMap { GuardScanRoots.swiftFiles(in: $0.url) })
        )
        try #require(testSymbols.values.reduce(0) { $0 + $1.primaryMembers.count } > 100, """
        测试符号表里的主声明类型太少 —— 解析失效，下面的成员核对会大面积漏。
        """)

        var references: [Reference] = []
        for url in swiftURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            references.append(contentsOf: Self.references(inSwift: source, file: GuardScanRoots.relativePath(url)))
        }
        for url in docURLs {
            let text = try String(contentsOf: url, encoding: .utf8)
            references.append(contentsOf: Self.references(
                inText: text, file: GuardScanRoots.relativePath(url), startingAtLine: 1
            ))
        }
        try #require(references.count > 500, """
        只抽出 \(references.count) 条候选引用 —— 抽取失效，这不是「零违规」。
        """)

        let analysis = Self.analyse(
            references: references,
            testSymbols: testSymbols,
            sourceSymbols: sourceSymbols,
            moduleNames: Set(try GuardScanRoots.declaredTargets().map(\.name))
        )
        // ⚠️ **规则 A 必须在真实语料的每一面上都真的被走到**（`#287` 第 2 轮终审 I-1 / I-2）。
        // 上面那几条 `#require` 只钉住两件事：输入非空、某个 URL 在枚举列表里。
        // **没有一条钉住「从这一层真的抽出过引用、真的核对过」** ⇒ 两条实测的静默失效路径：
        //
        // · **变异 F2**：让 `references(inText:file:startingAtLine:)` 对四个根 `.md`
        //   直接返回 `[]`（枚举照旧、抽取归零）⇒ 上一版**六个测试全绿**。扩进来的那一面
        //   被整个掐掉而全套件不响——这正是本 PR 的 I-3 刚修掉的形态（断言在防的机制
        //   不是它真正防住的机制），在紧邻的改动上复发了一次。
        // · **变异 G**：成员核对只保留 `Tests/` 面（`docs/` + `Sources/` + 根 `.md` 三面全灭）
        //   ⇒ 聚合值 **201**，上一版门槛 `> 200` **照绿**，判红的只有 J3-a 的合成 fixture
        //   ——而合成 fixture 恰恰证明不了真实语料。⇒ 聚合下界只拦得住「掉到 200 以下」
        //   ≈ 丢掉 55% 以上语料 ≈ 完全归零，拦不住最现实的「某一面不可达」。
        //
        // ⇒ 下界**按面切分**。今天实测（把聚合门槛临时抬到 999999 读出来的）：
        // `Sources/**` 98、`Tests/**` 202、`docs/**` 145、`<仓库根>/*.md` 8、
        // `(扫描面之外)` 0，合 **453**——五个桶可加，因为 `ScanFace` 的归类是全的（无 `nil` 出口）。
        // ⚠️ 这段注释本身也在 `Tests/**` 面上：它里面的引用会被算进去，所以这几个数会
        // 随本文件的散文一起微动。⇒ 更不该拿它们当断言。
        // ⚠️ 每面取 `> 0` 而**不是**这五个数的快照：这些数会随语料
        // 增长而漂移，钉死只会制造无谓的红；而要检出的形态恰恰是「某一面整个不可达」，
        // `> 0` 正好卡在那条线上，且不随语料漂移。
        for face in [ScanFace.sources, .tests, .docs, .rootDocuments] {
            try #require(analysis.memberChecked(on: face) > 0, """
            扫描面 `\(face.rawValue)` 上**零**条引用走到了规则 A 的成员核对
            —— 这一面要么没被枚举、要么没被抽取、要么没被核对。三者都是**静默失效**：
            J1 在这一面上的绿来自「没核」，不是「核过了都对」。
            各面当下值：\(analysis.faceBreakdown)
            """)
        }
        // 聚合下界一并留着，但**如实登记它的射程**：它只拦得住「四面同时大幅萎缩」这一档
        // ——上面变异 G 的 201 就是从它下面走过去的。真正的守卫是上面那四条按面下界。
        try #require(analysis.memberCheckedCount > 200, """
        全部扫描面合计只有 \(analysis.memberCheckedCount) 条引用走到了规则 A 的成员核对
        —— 语料整个塌了，J1 的绿来自「没核」而不是「核过了都对」。
        各面当下值：\(analysis.faceBreakdown)
        """)
        let violations = analysis.violations
        #expect(violations.isEmpty, """
        以下判据引用**指不到任何符号**（共 \(violations.count) 处）：

        \(violations.map(\.description).joined(separator: "\n"))

        ⚠️ 悬空引用有两重腐蚀性：读者按图索骥找不到，无法核验注释声称的性质是否真的
        被钉住；后来者可能因为「注释指向的判据不存在」而误判某个真实守卫是多余的并删掉。

        处置（三选一）：
        · 去 `Tests/` 里找到那条判据的**真实**类型名与方法名，逐符号核对后改过来
          ——只改类型前缀是不够的，`#287` 的引用里就有判据名本身也不对的；
        · 若是**历史提及**（「上一版这里写的是…」）或**跨仓符号**，把它拆开写
          （类型名与成员名各自加反引号、中间不用点连），并写明它现在叫什么；
        · 若指的是**文件**而不是成员，把扩展名写全。
        """)
    }

    // MARK: - J2：扫描面与 manifest 双向一致

    @Test("J2：扫描面覆盖 Package.swift 里声明的全部 target，且与 GuardScanRoots 同步")
    func scanFaceMatchesTheManifest() throws {
        let declared = try GuardScanRoots.declaredTargets()
        let declaredLibraries = Set(declared.filter(\.isLibrary).map(\.name))
        #expect(declaredLibraries == Set(GuardScanRoots.targetNames), """
        `Package.swift` 里的 library target \(declaredLibraries.sorted()) 与
        `GuardScanRoots.targetNames` \(GuardScanRoots.targetNames.sorted()) 不一致
        —— 少一个就意味着那个 target 的注释整个不受本判据约束（fail-open）。
        """)

        let declaredNonLibraries = Set(declared.filter { !$0.isLibrary }.map(\.name))
        let testDirectories = Set(try GuardScanRoots.testRootDirectories().map(\.lastPathComponent))
        #expect(declaredNonLibraries == testDirectories, """
        `Tests/` 的子目录 \(testDirectories.sorted()) 与 `Package.swift` 里声明的
        非 library target \(declaredNonLibraries.sorted()) 不一致 —— 符号表会漏掉整个 target，
        而漏掉的那个 target 里的判据会被本条判成悬空引用（或反过来放行真正的悬空引用）。
        """)

        // ⚠️ 文档根同样 fail-closed：目录在、且里面真的有 `.md` 与那份登记表。
        #expect(FileManager.default.fileExists(atPath: GuardScanRoots.docsRoot.path), """
        `docs/` 不存在 —— 文档面的扫描会在空输入上恒绿。
        """)
        let docs = Self.docScanFace()
        #expect(docs.contains { $0.pathExtension == "md" }, "`docs/` 下一个 `.md` 都没有 —— 扫描失效")
        #expect(docs.contains { $0.lastPathComponent == "component-registry.json" },
                "`docs/component-registry.json` 不在扫描面里")

        // 仓库根那一层的指引文件同样 fail-closed：它们是这条纪律的**载体**。
        let rootDocs = Set(GuardScanRoots.rootDocFiles().map(\.lastPathComponent))
        #expect(rootDocs.isSuperset(of: Self.pinnedRootDocuments), """
        仓库根 `.md` 只枚举到 \(rootDocs.sorted()) —— 指引文件不在扫描面里，
        「判据引用必须指得到真实符号」这条纪律就管不住写着它的那份文件。
        必须在面内的是 \(Self.pinnedRootDocuments)（J1 与 J2 共用这张表）。
        """)
    }

    // MARK: - J3：判据自证会开火（AD-E：能触发红的 fixture）

    /// ⚠️ **fixture 里那个「不存在的类型名」拼出来而不是写死**：本判据会扫自己的字符串
    /// 字面量，写死会让 J1 判红在本文件上。
    nonisolated static var ghostSuiteName: String { "Ghost" + "Tests" }

    /// fixture 的两个模块名。
    ///
    /// ⚠️ **它们必须以 `Tests` / `Guard` 结尾**（`#287` 第 2 轮终审 I-3）：J3-b ⑨ 断言
    /// 「模块限定名不认领」，而这条断言只有在**规则 B 本来会对这个名字开火**时才有内容。
    /// 初版的名字是 `MainFixtureTarget`——不带后缀 ⇒ 规则 B 压根不看它 ⇒ ⑨ **恒真**：
    /// 实测把 `moduleNames` 那条豁免整个短路掉（变异 E），J3-a/b/c/d **全绿**。
    /// 改成带后缀之后，豁免成为 ⑨ 保持绿的**唯一**原因，同一个变异当场让 ⑨ 判红。
    ///
    /// ⚠️ 同样**拼**出来而不写死：带这两个后缀的名字写成字面量会被 J1 自己判成悬空类型。
    nonisolated static var fixtureModuleName: String { "MainFixture" + "Tests" }
    nonisolated static var otherFixtureModuleName: String { "OtherFixture" + "Tests" }

    /// fixture 的默认文件路径 —— 目录名必须等于 `fixtureModuleName`，
    /// 否则 `visibleScope(of:)` 切出来的范围取不到 `fixtureTestSymbols` 里的主表。
    nonisolated static var fixtureSwiftFile: String { "Tests/" + Self.fixtureModuleName + "/fixture.swift" }

    /// 合成符号表。
    ///
    /// ⚠️ **fixture 里那个「真实存在的 suite」刻意不叫 `…Tests` / `…Guard`**：同上，
    /// 带那两个后缀的名字写在本文件的字符串里会被 J1 判成悬空类型（它们只是这张合成表
    /// 里的键，仓库里并不存在）。规则 A 与命名无关 ⇒ 不带后缀同样能证明它。
    nonisolated static var fixtureTestSymbols: [String: SymbolTable] {
        var main = SymbolTable()
        main.primaryMembers["SampleSuite"] = ["existingJudgement", "NestedProbe"]
        main.primaryMembers["SampleSupport"] = ["helper"]
        // 只有 extension、没有主声明 ⇒ 成员集在语料之外。
        main.extensionMembers["SampleArray"] = ["localHelper"]
        // 有未解析的继承子句 ⇒ 成员集不可知。
        main.primaryMembers["SampleNode"] = ["position"]
        main.inherited["SampleNode"] = ["SomeExternalProtocol"]
        main.knownNames = ["SampleSuite", "SampleSupport", "SampleArray", "SampleNode"]

        var other = SymbolTable()
        other.primaryMembers["OtherTargetOnly"] = ["itsOwnMember"]
        other.knownNames = ["OtherTargetOnly"]
        return [Self.fixtureModuleName: main, Self.otherFixtureModuleName: other]
    }

    nonisolated static var fixtureModuleNames: Set<String> {
        [Self.fixtureModuleName, Self.otherFixtureModuleName]
    }

    nonisolated static func fixtureViolations(swift source: String, file: String? = nil) -> [Violation] {
        Self.violations(
            references: Self.references(inSwift: source, file: file ?? Self.fixtureSwiftFile),
            testSymbols: Self.fixtureTestSymbols,
            sourceSymbols: SymbolTable(),
            moduleNames: Self.fixtureModuleNames
        )
    }

    nonisolated static func fixtureViolations(text: String, file: String = "docs/fixture.md") -> [Violation] {
        Self.violations(
            references: Self.references(inText: text, file: file, startingAtLine: 1),
            testSymbols: Self.fixtureTestSymbols,
            sourceSymbols: SymbolTable(),
            moduleNames: Self.fixtureModuleNames
        )
    }

    @Test("J3-a：五种真实形态的悬空引用都判红")
    func firingFixtures() {
        let ghost = Self.ghostSuiteName

        // ① 行注释里引用了不存在的类型（`#287` 在 `MaskReveal.swift` 上的原始形态）。
        let lineComment = Self.fixtureViolations(swift: """
        // 判据：`\(ghost).chromeDrawsParticlesMidFlight` 钉住这一步。
        let x = 1
        """)
        #expect(lineComment.map(\.kind) == [.unknownType], "行注释里的悬空类型没被抓到：\(lineComment)")

        // ② 文档注释里类型对、**判据名错**——`#287` 逐字点名的那一半
        //   （「不只是改前缀——已发现至少一例判据名本身也不对」）。
        let wrongMember = Self.fixtureViolations(swift: """
        /// 判据 `SampleSuite.judgementThatWasRenamedAwayLastWeek` 逐字复刻这一步。
        struct A {}
        """)
        #expect(wrongMember.map(\.kind) == [.unknownMember], "改名后的判据名没被抓到：\(wrongMember)")

        // ③ 块注释同样在射程内（两种注释是两种 trivia，只处理一种即漏一半）。
        let blockComment = Self.fixtureViolations(swift: """
        /* 见 `SampleSupport.helperThatNeverExisted`。 */
        let y = 2
        """)
        #expect(blockComment.map(\.kind) == [.unknownMember], "块注释没被扫到：\(blockComment)")

        // ④ `#expect` 的失败文案里也会写判据引用——那是给判红的人读的，指错同样有害。
        let message = Self.fixtureViolations(swift: """
        func t() {
            #expect(ok, "互锁见 `SampleSuite.theOtherHalfOfTheInterlock`")
        }
        """)
        #expect(message.map(\.kind) == [.unknownMember], "字符串字面量没被扫到：\(message)")

        // ⑤ Markdown / 登记表 `notes` 这一面（`docs/component-registry.json` 是 JSON，
        //    但同样按文本扫——键名是驼峰不含点，不会产生候选引用）。
        let markdown = Self.fixtureViolations(text: """
        - `SampleSuite.identityFrameDrawsNothing`——绘制层那一层。
        """)
        #expect(markdown.map(\.kind) == [.unknownMember], "文档面没被扫到：\(markdown)")
    }

    @Test("J3-b：合规的写法不判红（判据不能宽到逼人关掉它）")
    func silentFixtures() {
        // ① 真实类型 + 真实成员。
        #expect(Self.fixtureViolations(swift: """
        /// 判据：`SampleSuite.existingJudgement`。
        struct A {}
        """).isEmpty)

        // ② 嵌套类型也是成员。
        #expect(Self.fixtureViolations(swift: """
        // 同一形态的另一份：`SampleSuite.NestedProbe`。
        let x = 1
        """).isEmpty)

        // ③ 文件名不是成员引用（扩展名在排除表里）。
        #expect(Self.fixtureViolations(swift: """
        // 见 `SampleSuite.swift` 与 `SampleSupport.md`。
        let x = 1
        """).isEmpty, "文件名被当成了成员引用 —— 这是本仓最常见的写法，误判红会逼人关掉判据")

        // ④ 元类型语法不是成员引用。
        #expect(Self.fixtureViolations(swift: """
        // 形态是 `SampleSuite.Type` / `SampleSuite.self`。
        let x = 1
        """).isEmpty)

        // ⑤ 语料里根本没有的类型、名字又不像 suite ⇒ 不认领（射程之外，不是漏）。
        #expect(Self.fixtureViolations(swift: """
        // 系统类型：`EnvironmentValues.accessibilityReduceMotion`。
        let x = 1
        """).isEmpty)

        // ⑥ **代码里的引用不收**：编译器管得比本判据严。这条 fixture 里的成员是假的，
        //    但它出现在代码位置 ⇒ 本判据放行。
        #expect(Self.fixtureViolations(swift: """
        func t() {
            _ = SampleSuite.notARealMemberButCompilerCheckedAnyway
        }
        """).isEmpty, "代码位置被收进了引用面 —— 会与编译器重复，且把类型推断的东西误判红")

        // ⑦ 只有 `extension` 的类型不核成员（否则散文里提到的 stdlib 成员全红）。
        //   ⚠️ **这条是纵深防御，不是唯一把关的闸**（`#287` 第 2 轮终审 I-3b 实测）：
        //   把「主声明才核成员」那条判断短路掉，本条**照绿**——真正吸收它的是
        //   `analyse` 里的 `guard knowable.contains(...)`，而 `knowableTypes` 由
        //   `primaryMembers.keys` 算出 ⇒ 只有 extension 的类型永远不可知。
        //   ⇒ 失败信息点名的机制与真正兜住它的机制不是同一个，改这条断言前先看那道 `guard`。
        #expect(Self.fixtureViolations(swift: """
        // 见 `SampleArray.sort`。
        let x = 1
        """).isEmpty, "只有 extension 的类型被当成了闭世界 —— stdlib 成员会大面积误红")

        // ⑧ 有未解析继承子句的类型不核成员（协议给的成员语法层看不见）。
        #expect(Self.fixtureViolations(swift: """
        // 见 `SampleNode.ID`。
        let x = 1
        """).isEmpty, "带继承子句的类型被当成了闭世界 —— 协议要求会被误判成不存在")

        // ⑨ 模块限定名不认领（`swift test --filter` 的写法，本仓文档里到处都是）。
        //   ⚠️ 模块名**刻意以 `Tests` 结尾**：不带后缀的话规则 B 本来就不会开火，
        //   这条断言就是恒真的（`#287` 第 2 轮终审 I-3 实测：初版在变异 E 下全绿）。
        //   现在唯一让它保持绿的是 `moduleNames` 那条豁免。
        #expect(Self.fixtureViolations(text: """
        `swift test --filter \(Self.fixtureModuleName).SampleSuite`
        """).isEmpty, "模块限定名被当成了类型引用")

        // ⑩ 「拿后缀当通配符」不是引用：本仓 `MaskRevealTests` 里真的这么数过调用点。
        #expect(Self.fixtureViolations(text: """
        按两个后缀 `Tests.pixels(` 与 `Tests.stablePixels(` 计数。
        """).isEmpty, "后缀通配写法被当成了一个真类型")

        // ⑪ 只在 `Sources/` 里声明的库类型 ⇒ 不核成员（射程之外，见规则 A）。
        var sources = SymbolTable()
        sources.primaryMembers["SampleToken"] = ["small"]
        sources.knownNames = ["SampleToken"]
        let libraryReference = Self.violations(
            references: Self.references(
                inText: "见 `SampleToken.mediumPlus`。", file: "docs/fixture.md", startingAtLine: 1
            ),
            testSymbols: Self.fixtureTestSymbols,
            sourceSymbols: sources,
            moduleNames: []
        )
        #expect(libraryReference.isEmpty, "只在 `Sources/` 里声明的库类型被核了成员：\(libraryReference)")

        // ⑫ 跨 target 引用：类型在**别的** test target 里 ⇒ 只核到「类型存在」为止，
        //    成员不核（两个 target 里各有一个同名短类型时，不切范围就会互相误判）。
        #expect(Self.fixtureViolations(swift: """
        // 见 `OtherTargetOnly.somethingOnlyThatTargetKnows`。
        let x = 1
        """).isEmpty, "跨 target 引用被按本 target 的符号表核了成员")
    }

    @Test("J3-c：引用抽取的边界（前一个字符决定起点）")
    func referenceBoundaries() {
        // 限定名的中段不另起一次引用：三跳只记第一跳。
        let chained = Self.references(
            inText: "见 `SampleSuite.NestedProbe.body`。", file: "f", startingAtLine: 1
        )
        #expect(chained.map { "\($0.type).\($0.member)" } == ["SampleSuite.NestedProbe"], """
        三跳限定名抽出了 \(chained.map { "\($0.type).\($0.member)" }) —— 中段被当成了新起点。
        """)

        // 路径分隔符后面的大写标识符不是引用起点。
        #expect(Self.references(
            inText: "见 Tests/CoreDesignTests/GuardScanRoots.swift", file: "f", startingAtLine: 1
        ).allSatisfy { $0.type != "CoreDesignTests" }, "路径中段被当成了类型名")

        // 行号跟着走：第三行的引用报第三行。
        let multiline = Self.references(
            inText: "a\nb\n`SampleSuite.existingJudgement`", file: "f", startingAtLine: 10
        )
        #expect(multiline.map(\.line) == [12], "多行文本的行号没跟上：\(multiline.map(\.line))")
    }

    @Test("J3-d：符号表只认解析出来的声明，字符串里的 fixture 类型不进表")
    func symbolTableIgnoresFixtureSources() {
        let table = Self.symbolTable(of: [("f.swift", """
        struct RealThing {
            static func realMember() {}
            var stored = 0
            enum Inner { case a }
        }
        extension RealThing {
            func fromExtension() {}
        }
        struct DerivedThing: SomeUnknownProtocol {
            func ownMember() {}
        }
        extension StdlibLike {
            func onlyViaExtension() {}
        }
        let fixture = \"\"\"
        struct FixtureOnly {
            static func fixtureMember() {}
        }
        \"\"\"
        """)])
        #expect(table.members(of: "RealThing") == ["realMember", "stored", "Inner", "fromExtension"], """
        解析出来的成员是 \(table.members(of: "RealThing").sorted()) —— 扩展成员或嵌套类型漏了。
        """)
        #expect(table.primaryMembers["FixtureOnly"] == nil, """
        写在多行字符串里的 fixture 类型进了符号表 —— 本仓的守卫大量把合成源码放在字符串里，
        逐行 grep 会把它们当成真类型，从而给一堆散文引用发绿灯。
        """)
        let knowable = table.knowableTypes
        #expect(knowable.contains("RealThing"), "没有继承子句的类型应当是闭世界的")
        #expect(!knowable.contains("DerivedThing"), """
        `DerivedThing` 的继承子句里有语料外的名字，成员集不可知 —— 却被判成闭世界了。
        """)
        #expect(table.primaryMembers["StdlibLike"] == nil, "只有 extension 的类型不该有主声明成员")
        #expect(table.knownNames.contains("StdlibLike"), "被扩展过的类型仍算「语料里出现过」")
    }
}

// MARK: - 声明收集器

/// 从**声明节点**收「类型简名 → 成员名 / 继承子句」。
///
/// ⚠️ 走 `SyntaxVisitor` 而不是逐行匹配：字符串字面量里的合成源码不是声明节点，
/// 于是天然不进表——这正是本判据不被 fixture 污染的原因。
private nonisolated final class DeclarationCollector: SyntaxVisitor {
    private(set) var table = JudgementReferenceGuard.SymbolTable()

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(node.name.text, node.memberBlock, node.inheritanceClause, primary: true)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(node.name.text, node.memberBlock, node.inheritanceClause, primary: true)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(node.name.text, node.memberBlock, node.inheritanceClause, primary: true)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(node.name.text, node.memberBlock, node.inheritanceClause, primary: true)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        self.record(node.name.text, node.memberBlock, node.inheritanceClause, primary: true)
        return .visitChildren
    }

    /// 扩展的成员并进被扩展类型的**简名**，但**不**算主声明：
    /// 扩展一个 stdlib 类型不会让它的成员集变成闭世界的。
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let name = Self.trailingTypeName(of: node.extendedType) {
            self.record(name, node.memberBlock, node.inheritanceClause, primary: false)
        }
        return .visitChildren
    }

    private func record(
        _ rawName: String, _ block: MemberBlockSyntax,
        _ inheritance: InheritanceClauseSyntax?, primary: Bool
    ) {
        let name = Self.unescaped(rawName)
        var set: Set<String> = []
        for item in block.members { set.formUnion(Self.memberNames(of: item.decl)) }
        if primary {
            self.table.primaryMembers[name, default: []].formUnion(set)
        } else {
            self.table.extensionMembers[name, default: []].formUnion(set)
        }
        self.table.knownNames.insert(name)
        for inherited in inheritance?.inheritedTypes ?? [] {
            guard let parent = Self.trailingTypeName(of: inherited.type) else { continue }
            self.table.inherited[name, default: []].insert(parent)
            self.table.knownNames.insert(parent)
        }
    }

    private static func memberNames(of decl: DeclSyntax) -> Set<String> {
        if let function = decl.as(FunctionDeclSyntax.self) { return [Self.unescaped(function.name.text)] }
        if let variable = decl.as(VariableDeclSyntax.self) {
            return Set(variable.bindings.compactMap {
                $0.pattern.as(IdentifierPatternSyntax.self).map { Self.unescaped($0.identifier.text) }
            })
        }
        if let enumCase = decl.as(EnumCaseDeclSyntax.self) {
            return Set(enumCase.elements.map { Self.unescaped($0.name.text) })
        }
        if let nested = decl.as(StructDeclSyntax.self) { return [Self.unescaped(nested.name.text)] }
        if let nested = decl.as(ClassDeclSyntax.self) { return [Self.unescaped(nested.name.text)] }
        if let nested = decl.as(EnumDeclSyntax.self) { return [Self.unescaped(nested.name.text)] }
        if let nested = decl.as(ActorDeclSyntax.self) { return [Self.unescaped(nested.name.text)] }
        if let nested = decl.as(ProtocolDeclSyntax.self) { return [Self.unescaped(nested.name.text)] }
        if let alias = decl.as(TypeAliasDeclSyntax.self) { return [Self.unescaped(alias.name.text)] }
        if let associated = decl.as(AssociatedTypeDeclSyntax.self) { return [Self.unescaped(associated.name.text)] }
        if let macro = decl.as(MacroExpansionDeclSyntax.self) { return [Self.unescaped(macro.macroName.text)] }
        if decl.is(InitializerDeclSyntax.self) { return ["init"] }
        if decl.is(SubscriptDeclSyntax.self) { return ["subscript"] }
        return []
    }

    private static func trailingTypeName(of type: TypeSyntax) -> String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) { return Self.unescaped(identifier.name.text) }
        if let member = type.as(MemberTypeSyntax.self) { return Self.unescaped(member.name.text) }
        if let attributed = type.as(AttributedTypeSyntax.self) { return Self.trailingTypeName(of: attributed.baseType) }
        return nil
    }

    /// 去掉反引号转义标识符的反引号。
    private static func unescaped(_ text: String) -> String {
        text.hasPrefix("`") && text.hasSuffix("`") && text.count > 2
            ? String(text.dropFirst().dropLast())
            : text
    }
}
