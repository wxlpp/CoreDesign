import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 类型分类 / Parameter type classification

/// 一个参数的类型与 J-1 的关系。
///
/// ⚠️ **三分而不是二分，是本判据最容易做错的地方**：J-1 的谓词写的是「任何 Bool」，
/// 朴素实现会在声明文本里找 `Bool` 子串，于是把三类东西混为一谈——
/// (a) `-> Bool` 的**返回**类型、(b) `Binding<Bool>` / `FocusState<Bool>.Binding` 这类
/// **双向状态通道**、(c) 真正的配置开关。裁决见 `39-plan.md`「边界形态的裁决」：
/// 只有 (c) 是 J-1 命中；(a) 靠「只读 `parameterClause`、从不读 `returnClause`」在
/// **结构上**排除；(b) 由本枚举**显式**归入 `.boolCarrying` 并单独清点留痕
/// ——**不是靠「恰好没匹配上」**。
///
/// ⚠️ 还有一类**看起来像 (b)、其实是 (c)** 的：带 ownership specifier 的
/// `consuming Bool` / `borrowing Bool` / `sending Bool`——`trimmedDescription` 把
/// specifier 一起给出来，不剥掉就会落进 `\bBool\b` 兜底、被误判成 `.boolCarrying`
/// ⇒ 一条零成本的免豁免逃逸。裁决 (b′)：剥掉 specifier 后照常 `.plainBool`；
/// 只有 `inout` 因为**方向是双向**才归 `.boolCarrying`。
///
/// ⚠️ **`@autoclosure () -> Bool` 比 `consuming Bool` 还便宜**（裁决 (b″)）：把
/// `flag: Bool` 改写成 `flag: @autoclosure () -> Bool` 之后，**调用点逐字不变**
/// （`f(flag: true)` 照样编译），而类型文本变成 `"@autoclosure () -> Bool"`
/// ——不匹配任何 specifier 前缀、直接落进 `\bBool\b` 兜底 ⇒ `.boolCarrying`
/// ⇒ **不计违规、不需豁免**。裁决 (b′) 判死 specifier 的两条理由（「零成本改写就开出
/// 免豁免通道」「调用点仍是一个 Bool 参数」）对它**逐字成立** ⇒ 同样判 `.plainBool`。
/// 本仓 `@autoclosure` 当前**零命中**，与 `Bool?` 同款「先于第一例出现就写死」。
nonisolated enum BoolParamKind: Sendable, Equatable {
    /// 参数类型就是 `Bool`（含 `Bool?` / `Optional<Bool>` / `Swift.Bool`
    /// / `consuming Bool` / `borrowing Bool` / `sending Bool`
    /// / `@autoclosure () -> Bool`）⇒ J-1 命中。
    case plainBool
    /// 类型文本里还有 `Bool` 标识符，但类型本身不是 `Bool`：
    /// `Binding<Bool>` / `FocusState<Bool>.Binding?` / `[Bool]` / `(Bool) -> Void`
    /// / `() -> Bool`（**没有** `@autoclosure` 的普通闭包：调用点要写 `{ true }`，
    /// 不是换皮）/ `inout Bool`（裁决 (b′)：双向通道）…
    /// ⇒ **不是** J-1 命中，但要清点、要打印。
    case boolCarrying
    case notBool
}

/// ⚠️ **`Bool?` 归 `.plainBool`，不归 `.boolCarrying`**：它只是同一个旋钮多了个「没说」态,
/// 而公约第 3 节「头号反例」封的正是这类换皮逃逸（两 case enum 不算替代路径）,
/// `Bool?` 是最廉价的换皮。当前源码里 public 的 `Bool?` 参数为 0 条，本条**先于**
/// 第一例出现就写死，免得将来靠「恰好没匹配上」蒙混。
///
/// ⚠️ **ownership / parameter specifier 必须先剥掉**（裁决 (b′)）：SwiftSyntax 的
/// `type.trimmedDescription` 把 specifier 一起给出来（`"inout Cache"`、`"consuming Bool"`
/// ——本仓 `Layout/FlowLayout.swift:37/44/61` 就有三处真实的 `inout`）。不剥掉的话
/// `consuming Bool` 不等于 `"Bool"`、却能匹配 `\bBool\b` ⇒ 被判 `.boolCarrying`
/// ⇒ **一条零成本的免豁免逃逸**。剥掉之后：
/// · `borrowing` / `consuming` / `sending` 只是所有权标注，方向仍是单向输入 ⇒ 照常 `.plainBool`；
/// · `inout` 是**双向通道**（被调用方要往回写）⇒ 与裁决 (b) 的 `Binding<Bool>` 同类，
///   显式判 `.boolCarrying`——**是裁决，不是「恰好没匹配上」**。
///
/// ⚠️ **attribute 也必须先剥掉，且 `@autoclosure` 要单独裁决**（裁决 (b″)）：
/// `trimmedDescription` 同样把 attribute 一起给出来。`flag: @autoclosure () -> Bool`
/// 的**调用点与 `flag: Bool` 逐字相同**（`f(flag: true)`），是比 `consuming Bool`
/// **更便宜**的免豁免逃逸 ⇒ 剥掉 attribute 后若整体恰为 `() -> Bool`**且**原文带
/// `@autoclosure`，判 `.plainBool`。
/// 反过来，**不带** `@autoclosure` 的 `() -> Bool` / `@escaping (Bool) -> Void`
/// 调用点必须写闭包（`{ true }` / `{ _ in }`），不是换皮 ⇒ 维持 `.boolCarrying` 不变。
nonisolated func classifyBoolParameterType(_ raw: String) -> BoolParamKind {
    var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    // 1) 剥 specifier 与 attribute。两者可以交替出现（`borrowing @Sendable …`），
    //    所以放在同一个循环里剥到剥不动为止。
    //    `inout` 与 `@autoclosure` 各自单独裁决。
    var sawInout = false
    var sawAutoclosure = false
    while true {
        var stripped = false
        for specifier in ["inout", "borrowing", "consuming", "sending", "__owned", "__shared"]
        where t.hasPrefix(specifier + " ") {
            if specifier == "inout" { sawInout = true }
            t = String(t.dropFirst(specifier.count + 1)).trimmingCharacters(in: .whitespaces)
            stripped = true
            break
        }
        // `@autoclosure` / `@escaping` / `@Sendable` / `@MainActor` / `@convention(c)` …
        // 一个 attribute 到第一个空白为止（`@convention(c)` 括号里没有空白，安全）。
        if !stripped, t.hasPrefix("@") {
            let attribute = String(t.prefix(while: { !$0.isWhitespace }))
            if attribute == "@autoclosure" { sawAutoclosure = true }
            t = String(t.dropFirst(attribute.count)).trimmingCharacters(in: .whitespaces)
            stripped = true   // `t` 严格变短 ⇒ 循环必然终止
        }
        if !stripped { break }
    }
    if sawInout {
        // ⚠️ 裁决 (b′)：`inout Bool` 是双向状态通道，归 .boolCarrying；
        // `inout Cache` 这类非 Bool 仍要落到下面的 .notBool。
        return t.range(of: #"\bBool\b"#, options: .regularExpression) != nil ? .boolCarrying : .notBool
    }
    if sawAutoclosure {
        // ⚠️ 裁决 (b″)：`@autoclosure () -> Bool` 的调用点与 `flag: Bool` 逐字相同
        // ⇒ 与 `consuming Bool` 同类，判命中。空白写法不唯一，先归一化再比。
        let normalized = t.replacingOccurrences(of: " ", with: "")
        if normalized == "()->Bool" || normalized == "()->Swift.Bool" { return .plainBool }
    }

    // 2) 剥 Optional 语法糖。
    while t.hasSuffix("?") || t.hasSuffix("!") {
        t.removeLast()
        t = t.trimmingCharacters(in: .whitespaces)
    }
    if t == "Bool" || t == "Swift.Bool" { return .plainBool }
    if t == "Optional<Bool>" || t == "Optional<Swift.Bool>" || t == "Swift.Optional<Bool>" {
        return .plainBool
    }
    // `\bBool\b` 的词边界保证 `MyBool` / `Boolish` 不误命中。
    if t.range(of: #"\bBool\b"#, options: .regularExpression) != nil { return .boolCarrying }
    return .notBool
}

// MARK: - 命中项 / Hit

/// 一处「public 声明上的 Bool 参数」。
struct BoolParamHit: Hashable, Comparable, Sendable {
    /// 宿主：具名类型用点分全名（`SegmentedControlStyleConfiguration.Segment`）；
    /// extension 上的成员用**被扩展的类型名**（`View` / `ButtonStyle` / `Tag`）。
    let owner: String
    /// `init` / 函数名 / `subscript`。
    let decl: String
    /// 参数的**内部名**（`_ isActive:` 取 `isActive`）。
    let parameter: String
    let file: String
    let line: Int

    /// 豁免清单的键。
    ///
    /// ⚠️ **刻意不含标签表**（`init(_:variant:outlined:)` 这种）：
    /// · `Tag` 的指定 init（`Tag.swift:87`）与 `extension Tag where Label == Text` 的
    ///   便利 init（`:189`）都带 `removable`，`Badge` / `SidebarNavigationRow` 同理
    ///   ——它们是**同一个 API 概念的两个入口**，合成一条豁免才读得懂；
    /// · 反过来，键里带上完整标签表会让任何无关的签名调整（加一个参数）把现有豁免
    ///   判成「过期条目」，把判据变成噪音源。
    var key: String { "\(self.owner).\(self.decl)#\(self.parameter)" }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key ? lhs.line < rhs.line : lhs.key < rhs.key
    }
}

struct BoolScanResult: Sendable {
    var hits: [BoolParamHit] = []
    var carrying: [BoolParamHit] = []
    /// public 的 Bool **属性**（不是参数）。⚠️ 裁决 (d)：**不进判据**，只清点打印。
    var publicBoolProperties: [String] = []
    /// underlying 类型含 Bool 的 **public typealias**（`public typealias Flag = Bool`）。
    ///
    /// ⚠️ 裁决 (f)：**这个集合必须恒为空**，由 Task 2 的判据断言（见那里的理由）。
    /// 它比裁决 (b′)/(b″) 更黑——`public init(flag: Flag)` 的参数类型文本是 `"Flag"`
    /// ⇒ `.notBool` ⇒ **命中、清点、留痕三层同时看不见**。扫描器是纯语法、逐文件的，
    /// 解不了 alias（要解就得两遍扫描建跨文件映射）⇒ 这里只做**声明侧**的清点。
    var publicBoolTypeAliases: [String] = []

    /// 命中的豁免键集合。两处源码位置共用一个键时在此合并——这是设计，见 `BoolParamHit.key`。
    var keys: Set<String> { Set(self.hits.map(\.key)) }
}

// MARK: - 双向差集 / Bidirectional diff

/// **纯函数**（照 #38 `compareRegistryToScan` 的成法）：扫描命中集 vs 豁免清单键集的双向差集。
///
/// 抽成自由函数是为了能用**合成输入**写常驻单元测试，证伪两个方向
/// （未豁免违规 / 过期条目）不必真的改 `docs/bool-exemptions.json` 或真的改源码。
func compareBoolHitsToExemptions(
    hits: Set<String>, exempted: Set<String>
) -> (violations: Set<String>, stale: Set<String>) {
    (violations: hits.subtracting(exempted), stale: exempted.subtracting(hits))
}

// MARK: - 扫描入口 / Scan entry points

/// ⚠️ **必须先断言路径存在**：`FileManager.enumerator(at:)` 对不存在的路径
/// **静默产出空序列** ⇒「零命中 ⇒ 零违规 ⇒ 绿」会静默通过（#38 同款纪律）。
func scanBoolParams(root: URL) throws -> BoolScanResult {
    guard FileManager.default.fileExists(atPath: root.path) else {
        Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
        return BoolScanResult()
    }
    // ⚠️ **不要强制解包**：`enumerator(at:)` 在权限 / IO 异常时返回 nil，
    // `!` 会让测试进程崩掉，判据连「为什么失败」都报不出来。
    guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
        Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作，这不是「零违规」")
        return BoolScanResult()
    }
    var result = BoolScanResult()
    for case let url as URL in walker where url.pathExtension == "swift" {
        let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
        // ⚠️ **解析保真检查**：parser major 与工具链不配套时会静默产出 error node
        // ⇒ 声明被漏采，而扫描器照样「成功」返回一个偏小的集合。
        if tree.hasError {
            Issue.record("解析出错：\(url.lastPathComponent) —— swift-syntax major 可能与工具链不配套")
        }
        let partial = collectBoolParams(tree: tree, fileName: url.lastPathComponent)
        result.hits += partial.hits
        result.carrying += partial.carrying
        result.publicBoolProperties += partial.publicBoolProperties
        result.publicBoolTypeAliases += partial.publicBoolTypeAliases
    }
    return result
}

/// 合成输入入口——`BoolParameterScannerTests.swift` 用它逐类证伪边界形态，不碰磁盘。
func scanBoolParams(source: String, fileName: String = "Synthetic.swift") -> BoolScanResult {
    collectBoolParams(tree: SwiftParser.Parser.parse(source: source), fileName: fileName)
}

private func collectBoolParams(tree: SourceFileSyntax, fileName: String) -> BoolScanResult {
    let converter = SourceLocationConverter(fileName: fileName, tree: tree)
    let collector = PublicBoolParamCollector(fileName: fileName, converter: converter)
    collector.walk(tree)
    var result = BoolScanResult()
    result.hits = collector.hits
    result.carrying = collector.carrying
    result.publicBoolProperties = collector.publicBoolProperties
    result.publicBoolTypeAliases = collector.publicBoolTypeAliases
    return result
}

// MARK: - 采集器 / Collector

/// 采集**有效 public** 的 `init` / `func` / `subscript` 上的 Bool 参数。
///
/// ⚠️ **只读 `parameterClause`，从不读 `returnClause`，也从不对整行声明文本做子串匹配**
/// ——这是裁决 (a)（`-> Bool` 不是命中）的**结构性**落法，不是一条可以被绕过的约定。
///
/// ⚠️ **覆盖面（裁决 (e)：这两条是补上的结构性缺口，不是可选项）**：
/// - `ProtocolDeclSyntax` **要压栈**：protocol requirement 语法上不允许写访问修饰符，
///   不压栈的话 `public protocol X { init(flag: Bool) }` 会以「空 frames + 无 public 修饰符」
///   被判成非 public ⇒ **结构性不可见**。
/// - `EnumCaseDeclSyntax` **要采**：`public enum E { case a(active: Bool) }` 在调用点写作
///   `E.a(active: true)`，就是一个 Bool 参数——把 init 参数改写成 case 关联值是一条
///   现成的换皮路线。
/// - `TypeAliasDeclSyntax` **要采**（裁决 (f)）：只收进 `publicBoolTypeAliases`，由 Task 2
///   断言其**恒为空**——见该字段与那条判据的文档。
/// - `public extension` **给嵌套具名类型发默认 public**（裁决 (g)），`pushType` 必须建模——见下。
///
/// ⚠️ **已知盲区（留痕，未做机器拦截）**：
/// - public 的 Bool **属性**只收进 `publicBoolProperties` 并打印，不进判据（裁决 (d)）。
/// - 宏展开产物看不见：`visit(_:MacroExpansionDeclSyntax)` 直接 `.skipChildren`
///   （目的是跳过 `#Preview`，代价是任何生成 public 声明的宏都会被漏采；本仓当前
///   没有这类宏）。`MacroDeclSyntax`（`public macro f(flag: Bool)` 的**声明**侧）
///   同样没访问——本包没有 macro target，加上这一句只为留痕。
/// - **泛型洗 Bool 判不了**：`func f<T>(flag: T) where T == Bool`、
///   `func f(flag: some ExpressibleByBooleanLiteral)` 的参数类型文本是 `T` / `some …`
///   ⇒ `.notBool`，而调用点仍写 `f(flag: true)`。要拦就得做类型检查，纯语法层做不到
///   ⇒ 与宏展开并列，**只留痕不拦截**。（本仓零命中。）
/// - `extension` 扩展的类型是否 public 本文件判不出（可能声明在 SwiftUI 里）。
///   ⚠️ **这条盲区的两侧方向相反，都要说清**：
///   · **被扩展类型可能非 public** 那一侧是 **fail-closed（可能多报）**：
///     `extension 内部类型 { public func … }` **能编译**（成员被钳到 internal，编译器
///     不给诊断），此时本采集器会把它当成 public 而**多**报一条。多报的后果是有人被迫
///     来看一眼并解释，不是漏网 ⇒ 安全的那一侧。
///     （更早一版注释写「理论上是 fail-open」，方向说反了；结论「安全」不变。）
///   · **`public extension` 给成员发默认访问级** 那一侧原本是 **fail-open（会漏采）**：
///     `public extension Tag { enum Mode { case fancy(active: Bool) } }` 里的 `Mode`
///     在 Swift 语义上**是 public**，但它以 `isPublic: false` 压栈，就被
///     `isEffectivelyPublic` / `inheritsPublicFromContainer` 的「任一具名类型层不是
///     public ⇒ 否」整支判掉。**这一侧由 `pushType` 与 `visit(_:ProtocolDeclSyntax)`
///     两处显式建模堵上**（见那两处），不再是盲区；留在这里是为了记住两侧方向不同，
///     别再用单侧表述概括整条。
private nonisolated final class PublicBoolParamCollector: SyntaxVisitor {
    var hits: [BoolParamHit] = []
    var carrying: [BoolParamHit] = []
    var publicBoolProperties: [String] = []
    var publicBoolTypeAliases: [String] = []

    private let fileName: String
    private let converter: SourceLocationConverter

    private struct Frame {
        let name: String
        let isPublic: Bool
        let isPrivate: Bool
        let isInternal: Bool
        let isExtension: Bool
        /// protocol 帧：它的 requirement **不能自带访问修饰符**，可见性完全由 protocol 决定。
        var isProtocol: Bool = false
    }
    private var frames: [Frame] = []

    init(fileName: String, converter: SourceLocationConverter) {
        self.fileName = fileName
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: 访问级别

    private static func access(_ modifiers: DeclModifierListSyntax) -> (pub: Bool, priv: Bool, int: Bool) {
        let names = Set(modifiers.map { $0.name.text })
        return (
            names.contains("public") || names.contains("open"),
            names.contains("private") || names.contains("fileprivate"),
            names.contains("internal")
        )
    }

    /// 有效 public 判定。
    ///
    /// 1. 自身或任一外层带 `private`/`fileprivate`/`internal` ⇒ 否。
    /// 2. 任一**具名类型**层不是 public ⇒ 否
    ///    （`struct BottomInputBar`（无 `public`）里的 init 就是靠这条被排除的，
    ///    公约 AD-2 的 `SurfaceModifier` 范式同理）。
    /// 3. 最内层是 extension ⇒ `public extension X { func f }` 与
    ///    `extension X { public func f }` 两种写法都算 public。
    /// 4. 最内层是 **protocol** ⇒ requirement **不允许**写访问修饰符，可见性 == protocol 自身
    ///    （裁决 (e)。少了这一条，`public protocol X { init(flag: Bool) }` 会因为
    ///    `a.pub == false` 被静默判成非 public ⇒ 结构性不可见）。
    /// 5. 最内层是具名类型 ⇒ 必须显式写 `public`/`open`（Swift 不会让成员自动继承类型的 public）。
    private func isEffectivelyPublic(_ modifiers: DeclModifierListSyntax) -> Bool {
        let a = Self.access(modifiers)
        if a.priv || a.int { return false }
        if self.frames.contains(where: { $0.isPrivate || $0.isInternal }) { return false }
        if self.frames.contains(where: { !$0.isExtension && !$0.isPublic }) { return false }
        guard let innermost = self.frames.last else { return a.pub }
        if innermost.isExtension { return innermost.isPublic || a.pub }
        if innermost.isProtocol { return innermost.isPublic }
        return a.pub
    }

    /// 成员**在语法上没有自己的访问修饰符**时（`enum case`）的可见性：完全由容器决定。
    /// ⚠️ 不能复用 `isEffectivelyPublic(_:)` 传空 modifiers——那条路在「最内层是具名类型」
    /// 时会 `return a.pub == false`，把 `public enum` 的 case 全判成非 public。
    private func inheritsPublicFromContainer() -> Bool {
        if self.frames.contains(where: { $0.isPrivate || $0.isInternal }) { return false }
        if self.frames.contains(where: { !$0.isExtension && !$0.isPublic }) { return false }
        guard let innermost = self.frames.last else { return false }
        return innermost.isPublic
    }

    private var owner: String {
        self.frames.isEmpty ? "(top-level)" : self.frames.map(\.name).joined(separator: ".")
    }

    // MARK: 容器帧

    /// ⚠️ **裁决 (g)：`public extension` 会给它的成员（含嵌套具名类型）发默认访问级**：
    /// ```swift
    /// public extension Tag { enum Mode { case fancy(active: Bool) } }   // Mode 是 public
    /// public extension Tag { struct Options { public init(flag: Bool) } } // Options 是 public
    /// ```
    /// 不建模的话这两帧都以 `isPublic: false` 压栈，而 `isEffectivelyPublic`
    /// 与 `inheritsPublicFromContainer` **共用**的第二道检查
    /// `frames.contains { !$0.isExtension && !$0.isPublic }` 会把整支判非 public
    /// ⇒ **fail-open 漏采**（与上面那条 extension 盲区的另一侧方向相反）。
    ///
    /// ⚠️ **只在类型自身「没有任何显式访问修饰符」时才继承**——显式修饰符永远压过默认值
    /// （`public extension X { private enum M {} }` 里 `M` 就是 private）。
    /// 也**只看直接外层帧**：Swift 的默认访问级只发给 extension 的**直接**成员，
    /// `public extension X { enum M { enum N {} } }` 里的 `N` 仍是 internal
    /// ——这条边界正是靠「`frames.last` 不是 extension ⇒ 不继承」自然落到位的，
    /// 不是漏写。
    private func pushType(_ name: String, _ modifiers: DeclModifierListSyntax) {
        let a = Self.access(modifiers)
        let hasExplicitAccess = a.pub || a.priv || a.int
        let inheritsPublicFromExtension =
            !hasExplicitAccess
            && self.frames.last?.isExtension == true
            && self.frames.last?.isPublic == true
        self.frames.append(
            Frame(
                name: name,
                isPublic: a.pub || inheritsPublicFromExtension,
                isPrivate: a.priv, isInternal: a.int, isExtension: false
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { self.frames.removeLast() }

    /// ⚠️ **裁决 (e) 的第一条缺口**：不压这一帧，`public protocol X { init(flag: Bool) }`
    /// 里的 requirement 会以空 frames 走 `isEffectivelyPublic`，而 requirement
    /// **不允许**写 `public` ⇒ 恒判非 public ⇒ 结构性不可见。
    ///
    /// ⚠️ **裁决 (g) 对嵌套 protocol 同样成立，且 `pushType` 盖不到它**：
    /// `pushType` 只在 `StructDeclSyntax` / `EnumDeclSyntax` / `ClassDeclSyntax` /
    /// `ActorDeclSyntax` 四处调用，`ProtocolDeclSyntax` 有自己独立的压栈逻辑（就是本函数）
    /// ⇒ 裁决 (g) 修的「public extension 给嵌套具名类型发默认 public」只堵住了那四种类型，
    /// 没堵住 protocol。而 SE-0404 起嵌套 protocol 合法，`public extension Host { protocol
    /// Styling { init(flag: Bool) } }` 里的 `Styling` **确实是 public**（`swiftc -typecheck`
    /// 对把它当泛型约束的调用点通过），必须在这里**独立复制** `pushType` 同款的继承判定
    /// ——否则 `Styling` 恒以 `isPublic: a.pub == false` 压栈，`isEffectivelyPublic` 走到
    /// 第 4 条 `return innermost.isPublic` 恒非 public ⇒ 与裁决 (e)「protocol requirement
    /// 是命中」正面冲突。
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let a = Self.access(node.modifiers)
        let hasExplicitAccess = a.pub || a.priv || a.int
        let inheritsPublicFromExtension =
            !hasExplicitAccess
            && self.frames.last?.isExtension == true
            && self.frames.last?.isPublic == true
        self.frames.append(
            Frame(
                name: node.name.text,
                isPublic: a.pub || inheritsPublicFromExtension,
                isPrivate: a.priv, isInternal: a.int,
                isExtension: false, isProtocol: true
            )
        )
        return .visitChildren
    }
    override func visitPost(_ node: ProtocolDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        var extended = node.extendedType.trimmedDescription
        // `extension Array<Int>` / `extension Tag<Label>` ⇒ 只留基名。
        if let angle = extended.firstIndex(of: "<") { extended = String(extended[..<angle]) }
        let a = Self.access(node.modifiers)
        self.frames.append(
            Frame(
                name: extended.trimmingCharacters(in: .whitespaces),
                isPublic: a.pub, isPrivate: a.priv, isInternal: a.int, isExtension: true
            )
        )
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { self.frames.removeLast() }

    /// `#if os(iOS)` 的两个分支都要走（照抄 #38）：只走一支会漏采另一支的声明。
    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        for clause in node.clauses {
            if let elements = clause.elements { self.walk(elements) }
        }
        return .skipChildren
    }

    /// 跳过 `#Preview` 等宏展开块——见类文档的盲区说明。
    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

    // MARK: 声明

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(node.signature.parameterClause.parameters, decl: "init", modifiers: node.modifiers, at: node)
        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(node.signature.parameterClause.parameters, decl: node.name.text, modifiers: node.modifiers, at: node)
        return .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(node.parameterClause.parameters, decl: "subscript", modifiers: node.modifiers, at: node)
        return .skipChildren
    }

    /// ⚠️ **裁决 (e) 的第二条缺口**：`public enum E { case a(active: Bool) }` 在调用点写作
    /// `E.a(active: true)`——就是一个 Bool 参数，是把 init 参数换皮的现成路线。
    /// case **不能自带访问修饰符** ⇒ 可见性走 `inheritsPublicFromContainer()`。
    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        guard self.inheritsPublicFromContainer() else { return .skipChildren }
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        for element in node.elements {
            guard let parameters = element.parameterClause?.parameters else { continue }
            for (index, parameter) in parameters.enumerated() {
                // `EnumCaseParameterSyntax` 的 firstName/secondName **都是可选的**
                // （与 `FunctionParameterSyntax` 不同）：`case a(Bool)` 两者皆 nil
                // ⇒ 用**位置**兜底（`#_0`），与「完全匿名的 `_: Bool` 键里就是 `_`、
                // **不跳过**」同一原则——跳过等于给它开洞。
                let name = (parameter.secondName ?? parameter.firstName)?.text ?? "_\(index)"
                let hit = BoolParamHit(
                    owner: self.owner, decl: element.name.text, parameter: name,
                    file: self.fileName, line: line
                )
                switch classifyBoolParameterType(parameter.type.trimmedDescription) {
                case .plainBool: self.hits.append(hit)
                case .boolCarrying: self.carrying.append(hit)
                case .notBool: break
                }
            }
        }
        return .skipChildren
    }

    /// public 的 Bool **属性**：只清点，不判据（裁决 (d)）。
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard self.isEffectivelyPublic(node.modifiers) else { return .skipChildren }
        for binding in node.bindings {
            guard let type = binding.typeAnnotation?.type,
                  classifyBoolParameterType(type.trimmedDescription) == .plainBool,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { continue }
            self.publicBoolProperties.append("\(self.owner).\(name)")
        }
        return .skipChildren
    }

    /// ⚠️ **裁决 (f)：`public typealias Flag = Bool` 是比 (b′)/(b″) 更黑的洗白路线**。
    /// `public init(flag: Flag)` 的参数类型文本是 `"Flag"` ⇒ `.notBool`
    /// ⇒ **命中、清点、留痕三层同时看不见**。本采集器是纯语法、逐文件的，代不进 alias
    /// （要代就得两遍扫描建跨文件映射，成本远超本仓现状的收益）
    /// ⇒ 走**最小档**：只在**声明侧**清点，由 Task 2 断言这个集合恒为空。
    /// 那条空断言**本身就是裁决**——「本仓不得引入含 Bool 的 public typealias，
    /// 除非同轮扩展扫描器」，第一例出现即红、逼人重新裁决。
    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard self.isEffectivelyPublic(node.modifiers) else { return .skipChildren }
        let underlying = node.initializer.value.trimmedDescription
        if classifyBoolParameterType(underlying) != .notBool {
            self.publicBoolTypeAliases.append("\(self.owner).\(node.name.text) = \(underlying)")
        }
        return .skipChildren
    }

    private func collect(
        _ parameters: FunctionParameterListSyntax,
        decl: String,
        modifiers: DeclModifierListSyntax,
        at node: some SyntaxProtocol
    ) {
        guard self.isEffectivelyPublic(modifiers) else { return }
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        for parameter in parameters {
            // `_ isActive: Bool` ⇒ 取 `isActive`；`visible: Bool` ⇒ 取 `visible`；
            // 完全匿名的 `_: Bool` ⇒ 键里就是 `_`（**不跳过**，跳过等于给它开洞）。
            let name = (parameter.secondName ?? parameter.firstName).text
            let hit = BoolParamHit(
                owner: self.owner, decl: decl, parameter: name, file: self.fileName, line: line
            )
            switch classifyBoolParameterType(parameter.type.trimmedDescription) {
            case .plainBool: self.hits.append(hit)
            case .boolCarrying: self.carrying.append(hit)
            case .notBool: break
            }
        }
    }
}
