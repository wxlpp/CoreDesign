import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 位图断言纪律 / Bitmap expectation discipline（Issue #293）
//
// ## 它守什么
//
// **测试代码里不得对大 `Collection`（`Data` / `[UInt8]` / 像素缓冲）直接写
// `#expect(a == b)` / `#expect(a != b)`。** 比较必须先归约成 `Bool`
// ——走 `expectBitmapsEqual` / `expectBitmapsDiffer`，或本仓既有的
// `let matches = a == b; #expect(matches, …)` 成法。
//
// ## 为什么这是一条判据而不是一条约定
//
// `#expect(a == b)` 在两幅大位图上判红时**不判红，而是挂住**：swift-testing 为渲染
// 失败信息去求 `CollectionDifference`（Myers 差分）。本仓实测（`swift test`，两幅
// 160 000 字节的无关位图）：
//
// | 形态 | 结果 |
// |---|---|
// | `#expect(a == b, …)`，两侧 `Data`（非可选） | **SIGALRM at 90 s，一行汇总都没打印**（exit 142） |
// | 归约成 `Bool` 之后 | **0.038 s 判红** |
// | `#expect(a == b, …)`，两侧 `Data?`（可选） | **0.039 s 判红** —— `Optional` 不是 `Collection` |
//
// 端到端（本仓真实断言 + 一枚"整层被绕过"的库变异，
// `MaskRevealRenderTests.identityIsBytewiseIdentityEvenWithOverflow`，160 000 字节）：
//
// | 形态 | 结果 |
// |---|---|
// | `#expect(identity == bare, …)` | **200 秒 SIGALRM**，汇总行没打印，日志 860 KB、单行 430 225 字符，6 个 kind 只报出 2 个 |
// | `expectBitmapsEqual(identity, bare, …)` | **0.569 秒**判红，6 个 kind 全报，日志 6.4 KB、最长行 250 字符 |
//
// ⚠️⚠️ **可选性那一行是本轮实测出来的修正，issue 原文里没有。** 它**不是**
// 「大多数点位其实没事」的理由：会挂的那一类在本仓真实存在，且恰好是走
// `try #require(...)` 拿位图的那些**最承重**的断言；而「可选 ⇒ 非可选」只有
// 一次重构的距离（把 `let a = pixels(v)` 改成 `let a = try #require(pixels(v))`
// ——本仓一直鼓励的写法），那条断言当天就从 0.04 秒变成挂死，且没有任何提示。
// ⇒ **本判据对可选与非可选一视同仁。** 按可选性开例外，等于再造一张
// 「哪种拼法安全」的表，那正是本仓栽过四次的形态。
//
// ⚠️ **失效的恰好是最该判红的那一类变异**（整层被绕过 = 整幅图都变 = 差分规模爆炸），
// 而失效形态是「进程卡住、读不出是哪条判据在咬」——比静默绿更难诊断。
// 既有断言至今没被咬到，只是因为迄今判红的场景里两幅图差异都很小。
//
// 它还有一个二阶后果：**它让「按评审建议加一条位图判据」这个动作带上了前置条件**。
// 作者照做而不先归约，评审下一轮复现同一枚变异看到的是一个挂住的进程而不是预期的判红
// ——两边都会以为是别的问题。⇒ 这条纪律必须由机器守着，不能靠人记得。
//
// ## 判据形态：**不钉写法，钉「谁是位图」**
//
// ⚠️⚠️ **本判据刻意不是一张 needle 表。** 本仓已有四次「判据钉住某一种写法、
// 等价改写即逃逸」的实测教训（判据钉变量名 ⇒ 改名即逃逸；判据钉 `\.` 前缀 ⇒ 写成
// `\EnvironmentValues.` 即逃逸；needle 禁住 `MicroInteractionAPITests.stablePixels`
// 却放过严格更差的 `.pixels`；`storedProperties(in:)` 只认 `let ` ⇒ `var` 存储属性
// 整个不可见）。
// ⇒ 本判据用 SwiftSyntax 解析，从**声明**推导「哪些名字承载位图」，再看
// `#expect` / `#require` 的第一个实参里有没有以它们为操作数的 `==` / `!=`：
//
// 1. **`typealias` 一并解析**（`typealias Bitmap = Data` ⇒ `Bitmap` 也是大类型）；
// 2. **限定名不影响判定**：`pixels(v)` / `Self.pixels(v)` /
//    `MicroInteractionAPITests.pixels(v)` 同等对待——判的是 `pixels` 这个基名；
// 3. **函数名跨文件收集**：`CelebrationAndProcessingTests` 里调用的
//    `MicroInteractionAPITests.stablePixels` 声明在另一个文件里，逐文件收集会漏掉它；
// 4. **按表达式的「头」判定**：决定类型的是最外层那一步（`particleColor(at:)` 的返回值），
//    不是"操作数里出现过某个名字"——后者会把 `[Color.red, .blue].particleColor(at: 2) == .red`
//    判红，只因同一个函数里恰好有 `let red = Self.pixels(...)`（本判据首跑实测）；
// 5. **参数位也算**：`func check(_ a: Data, _ b: Data) { #expect(a == b) }` 判红；
// 6. **`==` 与 `!=` 同罚**，`#expect` 与 `#require` 同罚；
// 7. **名字启发式兜底**：名字里含 `pixel` / `bitmap` / `rgba`（不分大小写）的
//    函数或绑定，即使返回类型被藏进了本判据解析不出的形态，也照样按位图对待。
//
// ⚠️ **局部函数不进跨文件表**：`TextAndDisplayTests` 里有一个**函数内**的
// `func body(_:) -> Data?`。把它当全局名字，会让同 target 里所有写着 `body` 的表达式
// （`CoreTypography.Token.body.textStyle == .body`）被误判红——判据过宽同样是缺陷。
//
// ## ⚠️ 找到但**堵不住**的等价改写（如实登记，不是完备性宣称）
//
// **这一节是要求，不是既成事实的完备保证。** 以下写法今天能从本判据下走过去：
//
// - **泛型中转**：`func check<T: Equatable>(_ a: T, _ b: T) { #expect(a == b) }`，
//   再用两个 `Data` 调它。`#expect` 里的操作数类型是 `T`，语法层看不出是位图。
//   （`SwiftParser` 是纯语法解析，没有类型检查。）
// - **存进 `Any` / existential 再比**：同上，类型信息在语法层消失。
// - **把位图搬去非 test target**（`Sources/`）里比较：本判据的扫描根只有 `Tests/`。
// - **跨文件的局部 `let`**：函数名跨文件收集，但**局部绑定**只在本文件内解析
//   （局部绑定本来就不跨文件可见，故这不是漏，写在这里是为了说清射程）。
// - **闭包参数带类型标注**：`let check: (Data, Data) -> Void = { a, b in #expect(a == b) }`
//   ——`a` / `b` 的类型写在闭包的**类型标注**里，`bitmapBindingsInScope` 只解析
//   `FunctionDeclSyntax` 的形参。（实测 SILENT；今天本仓不存在这种写法。）
// - **跨类型的存储属性**：`#expect(a.bytes == b.bytes)`，其中 `a` / `b` 是别的类型的实例，
//   而那个类型有一个 `let bytes: Data`。头是 `bytes`，判据不知道它是位图。
//   ⚠️ 这是**最近的一条现成路径**：`TransitionClusterTests.swift` 里就有
//   `struct Frame { let bytes: Data }` 和它自己的 `==` 重载。（实测 SILENT。）
//   ⚠️ 顺带实测：`Self.blank == Self.blank` **会**判红（`blank` 在成员表里），
//   `Helper.blank == Helper.blank`（另一个类型的同名成员）**不会** —— 现状安全，形态存在。
// - **跨类型访问的计算属性**：`BigFunctionCollector` 只 visit `FunctionDeclSyntax`，
//   `var pixels: Data { … }` 这类计算属性不进跨文件表。（实测 SILENT。）
// - **把两侧各包一层再比**：`#expect(Array(a.prefix(n)) == Array(b.prefix(n)))` 的头是
//   `Array`，判据不认它承载位图；而两侧仍是大 `Collection` ⇒ 照挂不误。（实测 SILENT。）
//
// ⚠️ **`guard let` / `if let` 曾经也在这张表里，但它不属于这一类** —— 上面每一条都是
// 语法层原理上解不出类型，而可选绑定只是 `OptionalBindingConditionSyntax` 没被处理，
// 是**实现遗漏**。#298 评审指出：`guard let x = Self.pixels(v)` 与
// `try #require(Self.pixels(v))` 是同一惯用法的两种拼法，产出的都是**非可选 `Data`**
// ——正是本文件开头点名会挂死的那一类。已补齐（`collectOptionalBindings`），
// J3 的「`guard let` 解包后的非可选位图」「`if let` 解包后的非可选位图」两条 fixture 钉住。
//
// ## ⚠️ 射程边界：`App/Tests/` 不在本判据的射程内
//
// `App/Tests/SnapshotTests.swift` 属于 `App/CoreDesignPreview.xcodeproj`（xcodegen
// 生成的预览宿主）里的**真实 XCTest target**。它既不在 J1 / J5 的扫描根 `Tests/` 之下，
// 也就不受本判据与 XCTest 禁令的约束。今天无害（该文件只有一个空 class，且 CI 不构建
// `App/`），但**它不是"扫过了发现零违规"，而是根本没扫**——将来若在那里写位图断言，
// 要么把 `App/Tests/` 加进扫描根，要么明确接受它在射程外。
//
// 反过来，**下面这些不是漏洞，是安全出口**，别再去堵：
//
// - `#expect(a.elementsEqual(b))` —— 实测 0.038 s 判红。宏看到的是 `Bool`，
//   它不会去求差分。它与归约是同一件事的另一种拼法。
// - `let matches = a == b; #expect(matches, …)` —— #291 / #294 的成法，本判据放行。
// - **把位图包进一个不是 `Collection` 的值类型再比**——
//   `TransitionClusterTests.Frame`（`struct Frame: Equatable { let bytes: Data }`）
//   就是这条路，它比 #293 更早独立发现同一个坑（见该类型的文档：一次判红产出
//   **一行 21927 字符**的 `inserted [...]`）。本轮复测确认它是**真的**安全：
//   两幅 160 000 字节的无关位图包进 `Frame` 再 `#expect(a == b)` ⇒ **0.037 s 判红**。
//   ⇒ 本判据**不**把这类包装类型算作大类型。它是第三种被认可的形态，不是逃逸口子。
//   ⚠️ 但**包装成一个 conform 了 `Collection` 的自定义类型**是另一回事：实测它不挂
//   （1 s 判红，swift-testing 的差分机制没接管它），却把整份逐元素 `description`
//   打进日志——单次失败输出 **1.4 MB**。那不是 #293 的挂死形态，但同样别写。
// - `XCTAssertEqual` —— 本仓不用 XCTest（`CLAUDE.md` 明写），且
//   `noXCTestAssertions` 在下面把它一并禁掉，免得它成为绕过本判据的第三条路。
@Suite("#293 位图断言纪律")
struct BitmapExpectationGuard {

    // MARK: - 违规记录

    nonisolated struct Violation: Hashable, Sendable, CustomStringConvertible {
        let file: String
        let line: Int
        let snippet: String
        let reason: String

        var description: String { "\(self.file):\(self.line)  \(self.reason)\n    \(self.snippet)" }
    }

    // MARK: - 大类型的拼法

    /// 「大 `Collection`」的基础拼法。归一化后（去 `?` / `!` / 空白）与之比对。
    ///
    /// ⚠️ 含限定名与 `Array<UInt8>` 的展开写法——`[UInt8]` 与 `Array<UInt8>` 是同一个
    /// 类型的两种拼法，只认一种就是「判据钉写法」那一族错误。
    nonisolated static let baseBigTypeSpellings: Set<String> = [
        "Data", "Foundation.Data",
        "[UInt8]", "Array<UInt8>", "[Swift.UInt8]", "Array<Swift.UInt8>",
        "ContiguousArray<UInt8>", "ContiguousArray<Swift.UInt8>",
        "[UInt8]?", "Slice<Data>", "ArraySlice<UInt8>",
    ]

    /// 名字里出现这些片段（不分大小写）就按位图对待——启发式兜底。
    nonisolated static let bitmapNameFragments: [String] = ["pixel", "bitmap", "rgba"]

    /// 把大 `Collection` **归约成标量**的成员名。操作数里出现它们 ⇒ 比较的不是位图本身。
    ///
    /// ⚠️ `count` 在列表里，是因为 `#expect(a.count == b.count)` 比的是两个 `Int`，
    /// 差分规模是 O(1)——它不是本判据要挡的东西。
    nonisolated static let scalarReducingMembers: Set<String> = [
        "count", "isEmpty", "first", "last", "hashValue", "description", "debugDescription",
        "size", "width", "height", "startIndex", "endIndex", "indices", "underestimatedCount",
        "base64EncodedString", "hexString", "hexEncodedString", "sha256", "fingerprint",
    ]

    /// 类型文本里是否**作为一个完整标识符**出现了 `Data` / `UInt8`。
    ///
    /// ⚠️⚠️ 这里曾是 `text.contains("Data") || text.contains("UInt8")`——SwiftSyntax
    /// 守卫里残留的**文本匹配**（#298 评审 S-4）。今天本仓无害（`Tests/` 与 `Sources/`
    /// 里都不存在名字含 `Data` / `UInt8` 的具名类型），但一旦引入 `ChartData` /
    /// `Metadata` / `DataPoint`，`let x: Metadata` 就会被当成位图而误判红。
    /// 按非标识符字符切分后逐段等值比对：`[String: Data]` / `Data?` / `Slice<Data>` /
    /// `Array<Swift.UInt8>` 照常命中，`Metadata` 不再命中。
    nonisolated static func mentionsBigElementType(_ text: String) -> Bool {
        let tokens = text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
        return tokens.contains("Data") || tokens.contains("UInt8")
    }

    nonisolated static func normalizedTypeText(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("?") || t.hasSuffix("!") { t.removeLast() }
        return t.replacingOccurrences(of: " ", with: "")
    }

    nonisolated static func looksLikeBitmapName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return Self.bitmapNameFragments.contains { lowered.contains($0) }
    }

    // MARK: - 扫描根（fail-closed）

    nonisolated static var testsRoot: URL { GuardScanRoots.testsRoot }

    /// `Tests/` 下的每个子目录 = 一个 test target 的源码根。
    ///
    /// ⚠️ **不做任何白名单**：新增 test target 只要按 SwiftPM 约定落在 `Tests/<名字>/`
    /// 就自动进扫描范围。`scanRootsMatchTheManifest` 用 `Package.swift` 与本表做**双向**
    /// 差集，堵住「新 target 静默逃出本判据」。
    ///
    /// ⚠️ `#287` 起实现搬去 `GuardScanRoots.testRootDirectories()`（第二条守卫要用同一份根，
    /// 复制一份必然漂）。这里保留转发，本文件其余引用点不必改。
    nonisolated static func testRootDirectories() throws -> [URL] {
        try GuardScanRoots.testRootDirectories()
    }

    nonisolated static func testSourceFiles() throws -> [URL] {
        var out: [URL] = []
        for root in try Self.testRootDirectories() {
            out.append(contentsOf: GuardScanRoots.swiftFiles(in: root))
        }
        return out.sorted { $0.path < $1.path }
    }

    // MARK: - 判据本体（纯函数：合成输入即可自证，不碰磁盘）

    /// 一个 target 的全部源文件（文件名 → 源码）里的违规。
    ///
    /// ⚠️ **入口按 target 收整批文件，不是逐文件**：`stablePixels` 声明在
    /// `MicroInteractionTests.swift`，却被 `CelebrationAndProcessingTests.swift`
    /// 以 `MicroInteractionAPITests.stablePixels(...)` 调用。逐文件收集函数名
    /// 会让后者整个看不见——那正是「needle 放过了严格更差的那一条」的同型错误。
    nonisolated static func violations(in files: [(name: String, source: String)]) -> [Violation] {
        let trees = files.map { (name: $0.name, tree: SwiftParser.Parser.parse(source: $0.source)) }

        // 第 0 遍：大类型拼法。三轮定点迭代 —— `typealias A = Data` +
        // `typealias B = A` + `typealias C = [B]` 这种链式别名要能连起来
        // （别名各自声明在不同文件里时，一轮收不完）。
        // ⚠️ **不含「含大类型存储属性的包装类型」**：`Frame { let bytes: Data }`
        // 是被认可的安全形态，见 `BigTypeCollector` 的文档。
        var bigTypes = Self.baseBigTypeSpellings
        var declaredTypeNames: Set<String> = []
        for _ in 0..<3 {
            for entry in trees {
                let collector = BigTypeCollector(known: bigTypes, viewMode: .sourceAccurate)
                collector.walk(entry.tree)
                bigTypes.formUnion(collector.discovered)
                declaredTypeNames.formUnion(collector.declaredTypeNames)
            }
        }

        // 第 1 遍：跨文件的「承载位图的函数名」。
        var bigFunctionNames: Set<String> = []
        var knownNonBitmapNames: Set<String> = []
        for entry in trees {
            let collector = BigFunctionCollector(
                bigTypes: bigTypes, declaredTypeNames: declaredTypeNames, viewMode: .sourceAccurate
            )
            collector.walk(entry.tree)
            bigFunctionNames.formUnion(collector.names)
            knownNonBitmapNames.formUnion(collector.knownNonBitmapNames)
        }

        // 第 2 遍：逐文件找违规。
        var out: [Violation] = []
        for entry in trees {
            let converter = SourceLocationConverter(fileName: entry.name, tree: entry.tree)
            let finder = ComparisonFinder(
                bigTypes: bigTypes,
                bigFunctionNames: bigFunctionNames,
                knownNonBitmapNames: knownNonBitmapNames,
                fileName: entry.name,
                converter: converter,
                viewMode: .sourceAccurate
            )
            finder.walk(entry.tree)
            out.append(contentsOf: finder.violations)
        }
        return out.sorted { ($0.file, $0.line) < ($1.file, $1.line) }
    }

    nonisolated static func violations(inSource source: String, fileName: String = "fixture.swift") -> [Violation] {
        Self.violations(in: [(name: fileName, source: source)])
    }

    // MARK: - J1：全仓扫描

    @Test("J1：test target 里不得对大 Collection 直接 #expect(==) / #expect(!=)")
    func noDirectBitmapComparisons() throws {
        let files = try Self.testSourceFiles()
        // ⚠️ **非空前置**：枚举失效时下面的断言会在空集上恒真——「零文件 ⇒ 零违规 ⇒ 绿」
        // 是本仓反复记在案的病型。
        try #require(files.count > 80, """
        只枚举到 \(files.count) 个测试源文件 —— 扫描失效，这不是「零违规」。
        """)

        // ⚠️ **按 target 分批**：`violations(in:)` 跨文件汇总"承载位图的函数名"，
        // 而两个 test target 互不可见——混成一批会让 `CoreDesignEffectsTests` 的
        // 助手名字去误判 `CoreDesignTests` 里的同名表达式。
        var violations: [Violation] = []
        for root in try Self.testRootDirectories() {
            let loaded: [(name: String, source: String)] = try GuardScanRoots.swiftFiles(in: root).map {
                (GuardScanRoots.relativePath($0), try String(contentsOf: $0, encoding: .utf8))
            }
            violations.append(contentsOf: Self.violations(in: loaded))
        }
        violations.sort { ($0.file, $0.line) < ($1.file, $1.line) }
        #expect(violations.isEmpty, """
        以下断言把**大 Collection**（`Data` / `[UInt8]` / 像素缓冲）直接交给了
        `#expect` / `#require` 的 `==` / `!=`（共 \(violations.count) 处）：

        \(violations.map(\.description).joined(separator: "\n"))

        ⚠️ 这类断言**判红时不判红，而是挂住**：swift-testing 会去求
        `CollectionDifference`，两幅 160 000 字节的无关位图实测 90 秒不收敛
        （SIGALRM，一行汇总都没打印）。而失效的恰好是最该判红的那一类变异
        ——整层被绕过 ⇒ 整幅图都变 ⇒ 差分规模爆炸。

        处置（任选，两种本判据都放行）：
        · `expectBitmapsEqual(a, b, "…")` / `expectBitmapsDiffer(a, b, "…")`
          —— 见 `BitmapExpectations.swift`，失败信息自带指纹与首个相异下标；
        · `let matches = a == b; #expect(matches, "…")` —— #291 / #294 的成法。
        """)
    }

    // MARK: - J2：扫描根与 manifest 双向一致

    @Test("J2：扫描根与 Package.swift 里声明的 test target 双向一致")
    func scanRootsMatchTheManifest() throws {
        let directories = Set(try Self.testRootDirectories().map(\.lastPathComponent))
        try #require(directories.count >= 3, """
        `Tests/` 下只找到 \(directories.count) 个子目录 —— 扫描根解析失效，这不是「零违规」。
        """)

        // ⚠️ `DeclaredTarget` 只区分 library / 非 library。本仓当下的非 library target
        // **恰好**就是三个 test target；将来若加了 `executableTarget` / `macro`，
        // 本条会判红——那是**正确的**提醒：届时要把 `DeclaredTarget` 扩出 kind，
        // 而不是把这条断言放宽。
        let declared = Set(try GuardScanRoots.declaredTargets().filter { !$0.isLibrary }.map(\.name))
        #expect(declared == directories, """
        `Tests/` 的子目录 \(directories.sorted()) 与 `Package.swift` 里声明的
        非 library target \(declared.sorted()) 不一致。

        · 目录多出来 ⇒ 那份源码不属于任何 target，`swift test` 根本不编它；
        · manifest 多出来 ⇒ 该 target 的源码不在 `Tests/<名字>/`，本判据扫不到它
          （fail-open：它里面写什么位图断言都不受约束）。
        """)
    }

    // MARK: - J3：判据自证会开火（AD-E：能触发红的 fixture）

    /// ⚠️ **每条 fixture 都是一种真实的等价改写**，不是同一种写法的复读。
    /// 判据只要退化成「按某个名字/某种拼法查子串」，这一批里就会有若干条静默变绿。
    nonisolated static let firingFixtures: [(name: String, source: String)] = [
        ("裸写法：局部绑定 + `==`", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0)
                let b = T.pixels(1)
                #expect(a == b, "…")
            }
        }
        """),
        ("`!=` 与 `==` 同罚", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.shot(0), b = T.shot(1)
                #expect(a != b)
            }
        }
        """),
        ("`#require` 与 `#expect` 同罚", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() throws {
                let a = T.shot(0), b = T.shot(1)
                try #require(a == b)
            }
        }
        """),
        ("typealias 别名藏住 Data", """
        typealias Bitmap = Data
        struct T {
            static func shot(_ v: Int) -> Bitmap? { nil }
            func t() {
                let a = T.shot(0), b = T.shot(1)
                #expect(a == b)
            }
        }
        """),
        ("typealias 别名藏住 [UInt8]", """
        typealias Buffer = [UInt8]
        struct T {
            static func grab(_ v: Int) -> Buffer { [] }
            func t() { #expect(T.grab(0) == T.grab(1)) }
        }
        """),
        ("显式类型前缀（跨类型限定名）", """
        struct Other {
            static func shot(_ v: Int) -> Data? { nil }
        }
        struct T {
            func t() { #expect(Other.shot(0) == Other.shot(1)) }
        }
        """),
        ("函数参数位承载位图", """
        struct T {
            func check(_ a: Data, _ b: Data) { #expect(a == b, "…") }
        }
        """),
        ("显式类型标注的局部量（没有任何 helper 调用）", """
        struct T {
            func t() {
                let a: Data = Data()
                let b: Data = Data()
                #expect(a == b)
            }
        }
        """),
        ("藏在 `&&` 里的那一半", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.shot(0), b = T.shot(1)
                #expect(a != nil && a == b)
            }
        }
        """),
        ("名字启发式兜底：返回类型解析不出，但名字是位图", """
        struct T {
            static func framePixels(_ v: Int) -> SomeOpaqueThing { .init() }
            func t() { #expect(T.framePixels(0) == T.framePixels(1)) }
        }
        """),
        ("字典/数组容器里的位图", """
        struct T {
            func t() {
                let shots: [String: Data] = [:]
                #expect(shots["a"] == shots["b"])
            }
        }
        """),
        ("跨文件：helper 声明在另一个文件里", """
        struct Consumer {
            func t() { #expect(Producer.pixels(0) == Producer.pixels(1)) }
        }
        """),
        // ⚠️ 下面两条钉住 #298 评审 I-1：`guard let` / `if let` 解包出来的是
        // **非可选 `Data`**，正是文件头点名会挂死的那一类，而判据初版整条放过。
        ("`guard let` 解包后的非可选位图", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                guard let a = T.shot(0), let b = T.shot(1) else { return }
                #expect(a == b, "…")
            }
        }
        """),
        ("`if let` 解包后的非可选位图（绑定写在条件里）", """
        struct T {
            static func shot(_ v: Int) -> Data? { nil }
            func t() {
                if let a = T.shot(0), let b = T.shot(1) {
                    #expect(a == b)
                }
            }
        }
        """),
        // ⚠️ 钉住 #298 评审 I-2：子树里出现 `.size` 不该豁免整条比较。
        ("标量成员只出现在实参里（`.size` 不是这条比较的头）", """
        struct T {
            static func pixels(_ v: Int, size: CGSize) -> Data? { nil }
            func t() {
                let canvas = CGRect.zero
                #expect(T.pixels(0, size: canvas.size) == T.pixels(1, size: canvas.size))
            }
        }
        """),
    ]

    /// 跨文件 fixture 的另一半——单独一个"文件"。
    nonisolated static let crossFileProducer = """
    struct Producer {
        static func pixels(_ v: Int) -> Data? { nil }
    }
    """

    /// ⚠️ **必须与上面成对**：只有"会开火"没有"该放行时放行"，判据可以退化成恒真
    /// （全部判红）而这一批不会发现。
    ///
    /// ⚠️⚠️ **这一批钉住的不是同一条过宽路径**（#298 评审 I-3 的实测更正——本节此前
    /// 笼统写成「防判据恒真」，把 10 条都算在分类器头上，与实测不符）。
    /// 把 `ComparisonFinder.isBitmapOperand` 首行改成 `if true { return true }`
    /// （即分类器恒真）后，本批**只有 5 条**变红：
    ///
    /// · `a?.count == b?.count`（标量归约）
    /// · 包装进非 `Collection` 值类型（`Frame`）
    /// · `particleColor(at:) == .red`（按头判定，不是全名扫描）
    /// · `one == all`（同名局部量在另一个函数里是 `CGSize` —— 作用域）
    /// · `Metadata` 具名类型（类型判定按标识符切分，不是子串匹配）
    ///
    /// 另外 5 条静默的原因**与分类器无关**，它们钉的是另外两条独立的过宽路径：
    ///
    /// · `#expect(a != nil && b != nil)` —— 被**字面量豁免**（`NilLiteralExprSyntax`）
    ///   挡在分类器之前；
    /// · `let matches = a == b` / `expectBitmapsEqual(a, b)` / `elementsEqual` ——
    ///   根本没有 `==` 落在 `#expect` 的第一个实参里，钉的是「只看 `#expect` 内部」；
    /// · `name == "x"` / `3 == 3` —— 字符串 / 整数**字面量豁免**。
    ///
    /// ⚠️ 字面量豁免自己是有**互锁**的，不是无人看守：把 `isLiteral` 改成恒真
    /// （`true || expr.is(NilLiteralExprSyntax.self) …`）后**实测** J3 的 15 条
    /// **全部**变红（即 15 条 fixture 全部不再被判红）——放宽字面量豁免会立刻被 J3 抓住。
    /// ⇒ 这两批互相钉住对方，不是同一条路径的复读。
    nonisolated static let silentFixtures: [(name: String, source: String)] = [
        ("`!= nil` 是可选性检查，不是位图比较", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                #expect(a != nil && b != nil)
            }
        }
        """),
        ("归约成标量之后比较", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                #expect(a?.count == b?.count)
            }
        }
        """),
        ("成法一：`let matches = a == b`", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                let matches = a == b
                #expect(matches, "…")
            }
        }
        """),
        ("成法二：走 expectBitmapsEqual", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let a = T.pixels(0), b = T.pixels(1)
                expectBitmapsEqual(a, b, "…")
            }
        }
        """),
        ("包装进非 Collection 值类型（实测 0.037 s 判红 —— 第三种被认可的形态）", """
        struct Frame: Equatable { let bytes: Data }
        struct T {
            static func grab(_ v: Int) -> Frame { Frame(bytes: Data()) }
            func t() {
                let a = T.grab(0), b = T.grab(1)
                #expect(a == b)
            }
        }
        """),
        ("最外层是取色函数，只是操作数里出现了同名的位图绑定", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            func t() {
                let red = T.pixels(0)
                expectBitmapsEqual(red, T.pixels(1))
                #expect([Color.red, .blue].particleColor(at: 2) == .red)
            }
        }
        """),
        ("`elementsEqual` 已经是 Bool（实测 0.038 s 判红，不是逃逸口子）", """
        struct T {
            static func pixels(_ v: Int) -> Data { Data() }
            func t() { #expect(T.pixels(0).elementsEqual(T.pixels(1))) }
        }
        """),
        ("同名局部量在另一个函数里是 CGSize —— 作用域必须分得开", """
        struct T {
            static func pixels(_ v: Int) -> Data? { nil }
            static func size(_ v: Int) -> CGSize { .zero }
            func a() {
                let one = T.pixels(0), all = T.pixels(1)
                expectBitmapsEqual(one, all)
            }
            func b() {
                let one = T.size(0)
                let all = T.size(1)
                #expect(one == all, "布局尺寸")
            }
        }
        """),
        ("非位图的普通相等断言", """
        struct T {
            func t() {
                let name = "x"
                #expect(name == "x")
                #expect(3 == 3)
            }
        }
        """),
        // ⚠️ 钉住 #298 评审 S-4：类型判定曾用 `text.contains("Data")` 子串匹配，
        // 于是任何名字里含 `Data` 的具名类型（`Metadata` / `ChartData` / `DataPoint`）
        // 都会被当成位图。改成按标识符切分后逐个等值比对。
        ("名字里含 Data 的具名类型不是位图", """
        struct Metadata: Equatable { let tag: Int }
        struct T {
            func t() {
                let a: Metadata = .init(tag: 0)
                let b: Metadata = .init(tag: 1)
                #expect(a == b)
            }
        }
        """),
    ]

    @Test("J3：判据自证会开火 —— 15 种等价改写逐个打红")
    func judgeFiresOnEveryEquivalentRewrite() {
        for fixture in Self.firingFixtures {
            let files: [(name: String, source: String)] =
                fixture.name.hasPrefix("跨文件")
                ? [("producer.swift", Self.crossFileProducer), ("fixture.swift", fixture.source)]
                : [("fixture.swift", fixture.source)]
            let hits = Self.violations(in: files)
            #expect(!hits.isEmpty, """
            fixture「\(fixture.name)」**没有**被判红 —— 这条等价改写可以从判据下走过去。

            \(fixture.source)
            """)
        }
    }

    @Test("J3b：判据不是恒真 —— 10 种合规写法逐个放行")
    func judgeStaysSilentOnSanctionedForms() {
        for fixture in Self.silentFixtures {
            let hits = Self.violations(inSource: fixture.source)
            #expect(hits.isEmpty, """
            fixture「\(fixture.name)」被误判红了 —— 判据过宽会把合规写法一起挡掉：

            \(hits.map(\.description).joined(separator: "\n"))

            \(fixture.source)
            """)
        }
    }

    // MARK: - J4：两份 `BitmapExpectations.swift` 拷贝必须同步

    @Test("J4：每个带 BitmapExpectations.swift 的 test target 里，拷贝逐字节相同")
    func copiesAreInSync() throws {
        // ⚠️ 两个 test target 按 `Package.swift` 的 AD-D 刻意互不依赖，
        // 归约入口只能各放一份拷贝。没有这条判据，改了一份忘了另一份不会有任何提示。
        //
        // ⚠️⚠️ **不写死是哪几个 target**（#298 评审 S-2）：本条曾把
        // `["CoreDesignTests", "CoreDesignEffectsTests"]` 硬编码在这里，而 J1 的扫描根
        // 是从 `Tests/` 目录枚举出来的、**不做任何白名单**——`CoreDesignChartsTests`
        // 今天没有拷贝，但它确实在 J1 的射程里。⇒ 一旦有人在 Charts 测试里写位图断言，
        // J1 会判红并开出「用 `expectBitmapsEqual`」的处方，照做就要落下**第三份**拷贝，
        // 而写死名单的本条看不见它，漂移毫无提示。这里改成从扫描根推导，与 `:163-167`
        // 对 J1 扫描根的自陈是同一条纪律。
        let candidates = try Self.testRootDirectories()
            .map { $0.appendingPathComponent("BitmapExpectations.swift") }
        let present = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }

        try #require(present.count >= 2, """
        `Tests/` 的 \(candidates.count) 个 target 根里只找到 \(present.count) 份
        `BitmapExpectations.swift` —— 归约入口缺失，
        J1 会因为「没人用它」而在一批已经改回裸 `==` 的断言上继续绿。
        找过的位置：
        \(candidates.map { GuardScanRoots.relativePath($0) }.joined(separator: "\n"))
        """)

        let texts = try present.map { try String(contentsOf: $0, encoding: .utf8) }
        let drifted = zip(present, texts).filter { $0.1 != texts[0] }.map { GuardScanRoots.relativePath($0.0) }
        #expect(drifted.isEmpty, """
        以下 `BitmapExpectations.swift` 与 \(GuardScanRoots.relativePath(present[0])) 不同：
        \(drifted.joined(separator: "\n"))
        改动其中一份时必须同步所有拷贝（共 \(present.count) 份）。
        """)
    }

    // MARK: - J5：不得用 XCTest 断言绕过

    @Test("J5：测试代码里不得出现 XCTAssert* 系列断言")
    func noXCTestAssertions() throws {
        let files = try Self.testSourceFiles()
        try #require(files.count > 80, "只枚举到 \(files.count) 个测试源文件 —— 扫描失效")

        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            // ⚠️ 本文件自己会命中（下面这个字面量）——按路径排除自身，
            // 不能靠"注释剥离"：这里的 needle 在**代码**里。
            guard file.lastPathComponent != "BitmapExpectationGuard.swift" else { continue }
            let tree = SwiftParser.Parser.parse(source: text)
            let finder = XCTAssertFinder(viewMode: .sourceAccurate)
            finder.walk(tree)
            if !finder.hits.isEmpty {
                offenders.append("\(GuardScanRoots.relativePath(file)): \(finder.hits.sorted().joined(separator: ", "))")
            }
        }
        #expect(offenders.isEmpty, """
        以下文件用了 XCTest 断言：
        \(offenders.joined(separator: "\n"))

        本仓统一用 Swift Testing（`CLAUDE.md`）。就 #293 而言它还是一条**绕过通路**：
        `XCTAssertEqual(a, b)` 同样会为失败信息去展开两个大 `Collection`，
        而 `BitmapExpectationGuard` 只看 `#expect` / `#require`。
        """)
    }
}

// MARK: - 语法遍历器

/// 收集「其实是大 `Collection` 的类型名」：**只有 `typealias` 别名**
/// （`typealias Bitmap = Data` ⇒ `Bitmap` 也算大类型），外加语料里声明过的具名类型清单。
///
/// ⚠️ 本类**刻意不把「含大类型存储属性的包装类型」算作大类型**——
/// `TransitionClusterTests.Frame`（`struct Frame: Equatable { let bytes: Data }`）
/// 是本仓认可的第三种安全形态（实测 0.037 s 判红），把它算进来会让十几处合规比较误判红。
/// （本注释此前写成「+ 含大类型存储属性的包装类型」，与实现不符，#298 评审时更正。）
private nonisolated final class BigTypeCollector: SyntaxVisitor {
    private let known: Set<String>
    private(set) var discovered: Set<String> = []
    /// 语料里**声明过**的具名类型。用来分辨「返回类型已知且不是位图」与「返回类型看不懂」
    /// ——名字启发式只对后者兜底，否则 `interpolatedPixels() -> Frame?` 会被名字误判。
    private(set) var declaredTypeNames: Set<String> = []

    init(known: Set<String>, viewMode: SyntaxTreeViewMode) {
        self.known = known
        super.init(viewMode: viewMode)
    }

    private func isBig(_ type: TypeSyntax?) -> Bool {
        guard let type else { return false }
        let text = BitmapExpectationGuard.normalizedTypeText(type.trimmedDescription)
        if self.known.contains(text) || self.discovered.contains(text) { return true }
        // `[String: Data]` / `[Data]` 这类容器：里面装着位图，下标出来的还是位图。
        return BitmapExpectationGuard.baseBigTypeSpellings.contains { spelling in
            spelling.count > 4 && text.contains(spelling)
        } || BitmapExpectationGuard.mentionsBigElementType(text)
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if self.isBig(node.initializer.value) { self.discovered.insert(node.name.text) }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.declaredTypeNames.insert(node.name.text)
        return .visitChildren
    }
}

/// 收集「返回位图的函数名」。跨文件汇总，限定名一律按基名比对。
private nonisolated final class BigFunctionCollector: SyntaxVisitor {
    private let bigTypes: Set<String>
    private let declaredTypeNames: Set<String>
    private(set) var names: Set<String> = []
    /// 返回类型**已解析且确定不是位图**的函数名。名字启发式对它们失效——
    /// 否则 `interpolatedPixels() -> Frame?` 会因为名字里有 `Pixels` 被误判。
    private(set) var knownNonBitmapNames: Set<String> = []

    init(bigTypes: Set<String>, declaredTypeNames: Set<String>, viewMode: SyntaxTreeViewMode) {
        self.bigTypes = bigTypes
        self.declaredTypeNames = declaredTypeNames
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // ⚠️ **局部函数不进跨文件表**（本判据首跑实测的误判源）：
        // `TextAndDisplayTests` 的某条测试里有一个**函数内**的
        // `func body(_ revealed: Int) -> Data?`。把它当成全局名字，会让同 target 里
        // 任何写着 `body` 的表达式（`CoreTypography.Token.body.textStyle == .body`、
        // `Self.squeezed(body)`）被误判红。局部函数本来就只在它自己的作用域里可见
        // ——由 `ComparisonFinder.bitmapBindingsInScope` 按作用域处理。
        guard !Self.isNested(node) else { return .visitChildren }
        let name = node.name.text
        guard let returnType = node.signature.returnClause?.type else {
            // 没有返回类型 ⇒ 只能靠名字。
            if BitmapExpectationGuard.looksLikeBitmapName(name) { self.names.insert(name) }
            return .visitChildren
        }
        let text = BitmapExpectationGuard.normalizedTypeText(returnType.trimmedDescription)
        if self.bigTypes.contains(text) {
            self.names.insert(name)
        } else if self.declaredTypeNames.contains(text) {
            self.knownNonBitmapNames.insert(name)
        } else if BitmapExpectationGuard.looksLikeBitmapName(name) {
            // ⚠️ **名字启发式只对"看不懂的返回类型"兜底**：
            // `TransitionClusterTests.interpolatedPixels(_:towards:amount:) -> Frame?`
            // 名字里有 `Pixels`，返回的却是那个**故意不 conform `Collection`** 的
            // `Frame` 包装（本身就是 #293 同一个坑的另一种解法）。语料里已经声明了
            // `Frame` ⇒ 我们知道它不是位图，此时不该再让名字说了算。
            self.names.insert(name)
        }
        return .visitChildren
    }

    private static func isNested(_ node: FunctionDeclSyntax) -> Bool {
        var cursor = node.parent
        while let current = cursor {
            if current.is(FunctionDeclSyntax.self) || current.is(ClosureExprSyntax.self)
                || current.is(AccessorDeclSyntax.self) {
                return true
            }
            cursor = current.parent
        }
        return false
    }
}

/// 找 `#expect` / `#require` 第一个实参里以位图为操作数的 `==` / `!=`。
private nonisolated final class ComparisonFinder: SyntaxVisitor {
    private let bigTypes: Set<String>
    private let bigFunctionNames: Set<String>
    private let knownNonBitmapNames: Set<String>
    private let fileName: String
    private let converter: SourceLocationConverter
    private(set) var violations: [BitmapExpectationGuard.Violation] = []

    init(
        bigTypes: Set<String>,
        bigFunctionNames: Set<String>,
        knownNonBitmapNames: Set<String>,
        fileName: String,
        converter: SourceLocationConverter,
        viewMode: SyntaxTreeViewMode
    ) {
        self.bigTypes = bigTypes
        self.bigFunctionNames = bigFunctionNames
        self.knownNonBitmapNames = knownNonBitmapNames
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        guard ["expect", "require"].contains(node.macroName.text),
              let first = node.arguments.first
        else { return .visitChildren }

        for (op, lhs, rhs, whole) in Self.equalityComparisons(in: Syntax(first.expression)) {
            // ⚠️ **有一侧是字面量 ⇒ 整条比较放行**：`#expect(a != nil)` 是可选性检查，
            // `#expect(a == b)` 才是位图比较。少了这一条，本仓每一条
            // 「渲染失败前置」（`#expect(bitmap != nil, …)`）都会被误判红。
            if Self.isLiteral(lhs) || Self.isLiteral(rhs) { continue }
            let lhsBig = self.isBitmapOperand(lhs, at: Syntax(node))
            let rhsBig = self.isBitmapOperand(rhs, at: Syntax(node))
            guard lhsBig || rhsBig else { continue }

            let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
            self.violations.append(.init(
                file: self.fileName,
                line: line,
                snippet: Self.oneLine(whole),
                reason: "`#\(node.macroName.text)` 的第一个实参里有位图 `\(op)` 比较"
            ))
        }
        return .visitChildren
    }

    /// 表达式里的 `==` / `!=` 比较，返回 `(运算符, 左操作数, 右操作数, 原文)`。
    ///
    /// ⚠️⚠️ **必须同时认 `SequenceExprSyntax` 与 `InfixOperatorExprSyntax`**。
    /// `SwiftParser` 是**纯解析**，不做运算符优先级折叠 ⇒ `a == b` 落在
    /// `SequenceExprSyntax`（元素依次是 `a` / `==` / `b`），
    /// **`InfixOperatorExprSyntax` 在未折叠的树里根本不出现**。
    /// 本判据初版只找 `InfixOperatorExprSyntax`，于是 14 条 fixture **一条都没打红**
    /// ——而 J1 同时"通过"，那是一次典型的假绿（判据什么都没在看）。
    /// 折叠形态一并处理，是因为将来若有人接上 `OperatorTable.foldAll`，
    /// 这里不该跟着失效。
    private static func equalityComparisons(
        in node: Syntax
    ) -> [(op: String, lhs: ExprSyntax, rhs: ExprSyntax, text: String)] {
        var out: [(op: String, lhs: ExprSyntax, rhs: ExprSyntax, text: String)] = []

        if let sequence = node.as(SequenceExprSyntax.self) {
            let elements = Array(sequence.elements)
            for (index, element) in elements.enumerated() {
                guard let op = element.as(BinaryOperatorExprSyntax.self)?.operator.text,
                      op == "==" || op == "!=",
                      index > 0, index + 1 < elements.count
                else { continue }
                let lhs = elements[index - 1]
                let rhs = elements[index + 1]
                out.append((op, lhs, rhs, "\(lhs.trimmedDescription) \(op) \(rhs.trimmedDescription)"))
            }
        }
        if let infix = node.as(InfixOperatorExprSyntax.self),
           let op = infix.operator.as(BinaryOperatorExprSyntax.self)?.operator.text,
           op == "==" || op == "!=" {
            out.append((op, infix.leftOperand, infix.rightOperand, infix.trimmedDescription))
        }
        for child in node.children(viewMode: .sourceAccurate) {
            out.append(contentsOf: Self.equalityComparisons(in: child))
        }
        return out
    }

    private static func oneLine(_ text: String) -> String {
        let squashed = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let joined = squashed.joined(separator: " ")
        return joined.count > 140 ? String(joined.prefix(140)) + "…" : joined
    }

    // MARK: - 操作数分类

    /// `nil` / 布尔 / 数字 / 字符串字面量。
    private static func isLiteral(_ expr: ExprSyntax) -> Bool {
        expr.is(NilLiteralExprSyntax.self) || expr.is(BooleanLiteralExprSyntax.self)
            || expr.is(IntegerLiteralExprSyntax.self) || expr.is(FloatLiteralExprSyntax.self)
            || expr.is(StringLiteralExprSyntax.self)
    }

    /// 操作数是不是**位图本身**。
    ///
    /// ⚠️⚠️ **按表达式的「头」判定，不是"里面出现过某个名字"**（本判据首跑实测的第二类误判）：
    /// `[Color.red, .blue].particleColor(at: 2) == .red` 里出现了 `red`，而同一个函数里
    /// 恰好有 `let red = Self.pixels(...)` ⇒ 全名扫描把它判红。
    /// 真正决定类型的是**最外层**那一步：这里是 `particleColor(at:)` 的返回值。
    /// 同理 `probe.animatable(v) == v` 的头是 `animatable`，不是 `probe`。
    private func isBitmapOperand(_ expr: ExprSyntax, at site: Syntax) -> Bool {
        if Self.isLiteral(expr) { return false }

        if let head = Self.headName(of: expr) {
            // ⚠️⚠️ **标量归约也按「头」判**（#298 评审 I-2）。这里曾是
            // `mentionsScalarReducer(整棵子树)` —— 与上面那条「按头判定」的纪律**自相矛盾**，
            // 而且矛盾的方向是 **fail-open**（该判红的放过），比它想避免的那种误判更糟：
            //
            //     let canvas = CGRect.zero
            //     #expect(T.pixels(0, size: canvas.size) == T.pixels(1, size: canvas.size))
            //
            // 子树里出现了 `.size` ⇒ 整条比较被豁免，而两侧仍然是 160 000 字节的 `Data`
            // ⇒ 照挂不误。改成只看最外层那一步之后它判红；而
            // `a?.count == b?.count`（J3b fixture）的**头就是 `count`** ⇒ 仍然放行。
            if BitmapExpectationGuard.scalarReducingMembers.contains(head) { return false }
            return self.isBitmapName(head, at: site)
        }

        // 头取不出来（数组字面量、元组、闭包调用之类）⇒ 退回全名扫描。
        // ⚠️ 退回路径**故意更宽**：宁可多问一句，也不放过一处会挂死的断言。
        // ⚠️ 全子树的标量豁免**只留在这条退回路径上**，与它配套：全名扫描会把
        // `#expect((a.count, b.count) == (1, 2))` 里的 `a` / `b` 一起收进来，
        // 没有配套的宽豁免就会误判红。头能取出来时不走这里，故那条 fail-open 已经堵住。
        if Self.mentionsScalarReducer(Syntax(expr)) { return false }
        let names = Self.referencedBaseNames(in: Syntax(expr))
        return names.contains { self.isBitmapName($0, at: site) }
    }

    private func isBitmapName(_ name: String, at site: Syntax) -> Bool {
        if self.bigFunctionNames.contains(name) { return true }
        // ⚠️ 顺序是承重的：**先问"这个名字是不是已经被解析过且确定不是位图"**，
        // 再动名字启发式。反过来的话，`interpolatedPixels() -> Frame?` 会被自己的
        // 名字判成位图——而 `Frame` 正是本仓为同一个坑写的另一种解法。
        if self.knownNonBitmapNames.contains(name) { return false }
        if BitmapExpectationGuard.looksLikeBitmapName(name) { return true }
        return self.bitmapBindingsInScope(of: site).contains(name)
    }

    /// 表达式最外层那一步的名字。取不出来时返回 `nil`（调用方退回全名扫描）。
    private static func headName(of expr: ExprSyntax) -> String? {
        if let tryExpr = expr.as(TryExprSyntax.self) { return Self.headName(of: tryExpr.expression) }
        if let awaitExpr = expr.as(AwaitExprSyntax.self) { return Self.headName(of: awaitExpr.expression) }
        if let forced = expr.as(ForceUnwrapExprSyntax.self) { return Self.headName(of: forced.expression) }
        if let chained = expr.as(OptionalChainingExprSyntax.self) {
            return Self.headName(of: chained.expression)
        }
        if let call = expr.as(FunctionCallExprSyntax.self) {
            return Self.headName(of: call.calledExpression)
        }
        if let subscriptCall = expr.as(SubscriptCallExprSyntax.self) {
            return Self.headName(of: subscriptCall.calledExpression)
        }
        if let member = expr.as(MemberAccessExprSyntax.self) {
            // `.red` / `.body` 这种**隐式成员**永远不是局部绑定 —— 有 base 才算。
            guard member.base != nil else { return nil }
            return member.declName.baseName.text
        }
        if let ref = expr.as(DeclReferenceExprSyntax.self) { return ref.baseName.text }
        // `try #require(e, "…")` 的类型就是 `e` 解包后的类型 ⇒ 头取第一个实参的头。
        if let macro = expr.as(MacroExpansionExprSyntax.self),
           ["require", "expect"].contains(macro.macroName.text),
           let first = macro.arguments.first {
            return Self.headName(of: first.expression)
        }
        return nil
    }

    private static func mentionsScalarReducer(_ node: Syntax) -> Bool {
        if let member = node.as(MemberAccessExprSyntax.self),
           BitmapExpectationGuard.scalarReducingMembers.contains(member.declName.baseName.text) {
            return true
        }
        for child in node.children(viewMode: .sourceAccurate) where Self.mentionsScalarReducer(child) {
            return true
        }
        return false
    }

    /// 表达式里出现的**基名**：`Self.pixels(v)` / `Other.pixels(v)` / `pixels(v)` 都产出 `pixels`。
    ///
    /// ⚠️ 这一步是「限定名不影响判定」的实现：判据不认前缀，只认最后那个名字。
    private static func referencedBaseNames(in node: Syntax) -> Set<String> {
        var out: Set<String> = []
        // ⚠️ **成员访问要单独处理，不能靠通用递归**：`MemberAccessExprSyntax.declName`
        // 自己就是一个 `DeclReferenceExprSyntax` ⇒ 通用递归会把 `.red` 里的 `red`
        // 当成一个标识符引用收进来，于是 `… == .red` 撞上同函数里的 `let red = pixels(…)`。
        if let member = node.as(MemberAccessExprSyntax.self) {
            guard let base = member.base else { return [] }   // 隐式成员：`.red` / `.body`
            out.insert(member.declName.baseName.text)
            out.formUnion(Self.referencedBaseNames(in: Syntax(base)))
            return out
        }
        if let ref = node.as(DeclReferenceExprSyntax.self) { out.insert(ref.baseName.text) }
        for child in node.children(viewMode: .sourceAccurate) {
            out.formUnion(Self.referencedBaseNames(in: child))
        }
        return out
    }

    /// 断言点**可见范围内**承载位图的绑定名。
    ///
    /// ⚠️ **必须按作用域解析，不能按整文件**：同一个名字（`all` / `banner`）在本仓里
    /// 既有绑定到位图的函数、也有绑定到 `CGSize` / `Int` 的函数。整文件收集会把后者
    /// 一起判红——判据过宽同样是缺陷，它会逼着后人去关掉判据。
    private func bitmapBindingsInScope(of site: Syntax) -> Set<String> {
        var out: Set<String> = []
        var cursor: Syntax? = site
        var childPosition = site.position

        while let node = cursor {
            if let block = node.as(CodeBlockItemListSyntax.self) {
                // 语句块：绑定只看断言点**之前**的声明；
                // 局部 `func`（`func body(_:) -> Data?`）整块都算——它在自己的作用域里可见。
                for item in block {
                    if let function = item.item.as(FunctionDeclSyntax.self) {
                        if self.isBigType(function.signature.returnClause?.type)
                            || BitmapExpectationGuard.looksLikeBitmapName(function.name.text) {
                            out.insert(function.name.text)
                        }
                        continue
                    }
                    guard item.position < childPosition else { continue }
                    self.collectBindings(from: Syntax(item.item), into: &out)
                }
            }
            if let members = node.as(MemberBlockItemListSyntax.self) {
                // 类型成员：与书写顺序无关，全收。
                for member in members {
                    self.collectBindings(from: Syntax(member.decl), into: &out)
                }
            }
            if let function = node.as(FunctionDeclSyntax.self) {
                for parameter in function.signature.parameterClause.parameters
                where self.isBigType(parameter.type) {
                    out.insert(parameter.secondName?.text ?? parameter.firstName.text)
                }
            }
            // ⚠️ `if let a = …, let b = … { #expect(a == b) }`：绑定写在**条件里**，
            // 断言点在 `if` 体内 ⇒ 只有沿父链走到 `IfExprSyntax` / `WhileStmtSyntax`
            // 才看得见它们。（`guard let` 的绑定在语句块里，由上面的 `CodeBlockItemListSyntax`
            // 分支经 `collectBindings` 收。）
            if let ifExpr = node.as(IfExprSyntax.self) {
                self.collectOptionalBindings(from: ifExpr.conditions, into: &out)
            }
            if let whileStmt = node.as(WhileStmtSyntax.self) {
                self.collectOptionalBindings(from: whileStmt.conditions, into: &out)
            }
            childPosition = node.position
            cursor = node.parent
        }
        return out
    }

    private func collectBindings(from item: Syntax, into out: inout Set<String>) {
        // ⚠️⚠️ **`guard let` 也是一种绑定**（#298 评审 I-1）。这里曾只认
        // `VariableDeclSyntax` ⇒ 下面这条整条从判据下走过去（实测 SILENT）：
        //
        //     guard let a = T.shot(0), let b = T.shot(1) else { return }
        //     #expect(a == b)          // ← 不报
        //
        // 而 `guard let x = Self.pixels(v)` 与 `try #require(Self.pixels(v))` 是
        // **同一惯用法的两种拼法**，产出的都是**非可选 `Data`**——正是本文件开头点名
        // 「会挂死的那一类」。⇒ 判据曾恰好放过自己文档里说最危险的那种写法。
        // 这不是原理性堵不住（那些登记在文件头），是纯粹的实现遗漏。
        if let guardStmt = item.as(GuardStmtSyntax.self) {
            self.collectOptionalBindings(from: guardStmt.conditions, into: &out)
            return
        }
        guard let variable = item.as(VariableDeclSyntax.self) else { return }
        for binding in variable.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { continue }
            if self.isBigType(binding.typeAnnotation?.type) {
                out.insert(name)
                continue
            }
            if BitmapExpectationGuard.looksLikeBitmapName(name) {
                out.insert(name)
                continue
            }
            guard let value = binding.initializer?.value else { continue }
            if self.initializerLooksLikeBitmap(value) { out.insert(name) }
        }
    }

    /// `guard let` / `if let` / `while let` 条件里的可选绑定。
    ///
    /// ⚠️ 与 `collectBindings` 共用**同一套**「按初始化表达式的头判定」逻辑
    /// （`initializerLooksLikeBitmap`）——两条路各写一份是本仓栽过的那类漂移。
    ///
    /// ⚠️ `guard let a`（简写形态，没有 `=`）不在这里收：它重新绑定的是**外层同名量**，
    /// 那一处早已由 `collectBindings` 或本函数按顺序收过；这里再猜一次只会两头不一致。
    private func collectOptionalBindings(
        from conditions: ConditionElementListSyntax, into out: inout Set<String>
    ) {
        for condition in conditions {
            guard let binding = condition.condition.as(OptionalBindingConditionSyntax.self),
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { continue }
            if self.isBigType(binding.typeAnnotation?.type) {
                out.insert(name)
                continue
            }
            if BitmapExpectationGuard.looksLikeBitmapName(name) {
                out.insert(name)
                continue
            }
            guard let value = binding.initializer?.value else { continue }
            if self.initializerLooksLikeBitmap(value) { out.insert(name) }
        }
    }

    /// 初始化表达式是不是产出位图。
    ///
    /// ⚠️ 与操作数同一条纪律：**按初始化表达式的「头」判定**。
    /// `let moved = try #require(probe.render(v, false), …)` 的头是 `render`
    /// （返回一个非 `Collection` 的 `Frame`），不是里面出现过的 `probe`。
    /// 靠全名扫描会把它当位图，于是 `TransitionClusterTests` 里十几处
    /// 合规的 `Frame` 比较被误判红。
    private func initializerLooksLikeBitmap(_ value: ExprSyntax) -> Bool {
        if let head = Self.headName(of: value) {
            return self.bigFunctionNames.contains(head)
                || (!self.knownNonBitmapNames.contains(head)
                    && BitmapExpectationGuard.looksLikeBitmapName(head))
        }
        let names = Self.referencedBaseNames(in: Syntax(value))
        return names.contains(where: { self.bigFunctionNames.contains($0) })
            || names.contains(where: BitmapExpectationGuard.looksLikeBitmapName)
    }

    private func isBigType(_ type: TypeSyntax?) -> Bool {
        guard let type else { return false }
        let text = BitmapExpectationGuard.normalizedTypeText(type.trimmedDescription)
        if self.bigTypes.contains(text) { return true }
        // 容器：`[String: Data]` 下标出来的还是位图。
        return BitmapExpectationGuard.mentionsBigElementType(text)
    }
}

/// XCTest 断言的出现点。
private nonisolated final class XCTAssertFinder: SyntaxVisitor {
    private(set) var hits: Set<String> = []

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // ⚠️ **限定名不影响判定**（#298 评审 S-3）：callee 写成 `X.XCTAssertEqual(a, b)` 时
        // 是 `MemberAccessExprSyntax`，只认 `DeclReferenceExprSyntax` 会整条漏掉。
        // `ComparisonFinder.referencedBaseNames` 在同一文件里**专门处理掉了**这一族，
        // 两个 finder 的严谨度不该不一致 —— 而这一条的失败方向是 fail-open。
        //
        // ⚠️ **更正评审给的那个例子**：`XCTest.XCTAssertEqual(a, b)` 这一写法本身
        // **编译不过** —— `XCTest` 这个**类**遮蔽了同名 module，实测报
        // `error: type 'XCTest' has no member 'XCTAssertEqual'`。
        // ⇒ 它不是今天真实存在的逃逸口子。本改动仍然做，理由是**形态**存在
        // （任何 `<某命名空间>.XCTAssertEqual(…)` 都是这个 callee 形状）、代价是几行、
        // 方向是 fail-closed，且它消除了同文件里两个 finder 之间无理由的严谨度差。
        // 实测：合成 `enum N { static func XCTAssertEqual(_:_:) }` + `N.XCTAssertEqual(1, 1)`
        // ⇒ 改前静默、改后判红。
        guard let callee = Self.calleeBaseName(of: node.calledExpression) else { return .visitChildren }
        if callee.hasPrefix("XCTAssert") || callee == "XCTFail" || callee == "XCTUnwrap" {
            self.hits.insert(callee)
        }
        return .visitChildren
    }

    private static func calleeBaseName(of expr: ExprSyntax) -> String? {
        if let ref = expr.as(DeclReferenceExprSyntax.self) { return ref.baseName.text }
        if let member = expr.as(MemberAccessExprSyntax.self) { return member.declName.baseName.text }
        return nil
    }
}
