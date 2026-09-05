import Foundation
import SwiftParser
import SwiftSyntax
import Testing

// MARK: - 文本型参数分类 / Text parameter classification

/// 一个参数与 FR-4 的关系。
///
/// ⚠️ **四分而不是二分，与 #39 的 `BoolParamKind` 同构，理由也同源**：朴素实现会在
/// 声明文本里找 `String` 子串，于是把四类东西混为一谈——(a) `Binding<String>` /
/// `[String]` 这类**双向或容器**通道、(b) `(String) -> Void` 这类把文本**传出去**的
/// 回调、(c) 真正的文案入口、(d) 类型已是 `LocalizedStringKey`/`LocalizedStringResource`
/// 因而由类型直接判定的入口。只有 (c) 需要登记表 `textParams[]` 的 A/B/C 分类条目；
/// (d) 走公约 §4「第四个 category 取值 `by-type`」，**要被识别、不要求登记**（AC 原文：
/// 「不能被当成『未知类型』漏判」）；(a)(b) 归 `.textCarrying`，**清点、打印、不进判据**。
nonisolated enum TextParamKind: Sendable, Equatable {
    /// 裸文本入口：`String` / `String?` / `Substring` / `S where S: StringProtocol`
    /// / 返回位是裸文本的函数类型（`(Item) -> String`）⇒ FR-4 要求登记表有分类条目。
    case bareText
    /// `LocalizedStringKey` / `LocalizedStringResource`（含可选、含返回位）⇒ 由类型直接判定。
    case localizedText
    /// 类型文本里还有文本标识符，但它不是「调用方填文案」的入口：
    /// `Binding<String>` / `[String]` / `(String) -> Void` / `inout String` …
    case textCarrying
    case notText
}

/// 「裸文本」的精确拼法等价类。
///
/// ⚠️ **`Substring` 一并折入**：`init(title: Substring)` 的调用点与 `String` 版几乎
/// 同价（`s[...]` 直接传），而登记表按「文案入口」登记，不按具体串类型登记。本仓当前
/// `Substring` 零命中，与 #39 的 `Bool?` 一样**先于第一例出现就写死**，免得将来靠
/// 「恰好没匹配上」蒙混。
nonisolated let bareTextTypeNames: Set<String> = [
    "String", "Swift.String", "Substring", "Swift.Substring",
]

/// 由类型直接判定分类（公约 §4 的 `by-type`）的两个类型及其限定名拼法。
nonisolated let localizedTextTypeNames: Set<String> = [
    "LocalizedStringKey", "SwiftUI.LocalizedStringKey",
    "LocalizedStringResource", "Foundation.LocalizedStringResource",
]

/// 剥掉 `some ` / `any ` 前缀之后剩下的部分若在此集合里，判定为 `StringProtocol` 的
/// opaque（`some`）/ existential（`any`）写法。
nonisolated let stringProtocolOpaqueOrExistentialTypeNames: Set<String> = [
    "StringProtocol", "Swift.StringProtocol",
]

/// 剥掉 `some ` / `any ` 前缀（若存在），返回剩余类型文本；不是这两种前缀则返回 `nil`。
///
/// ⚠️ **必须按词边界判断，不能用 `hasPrefix("some")` / `hasPrefix("any")`**：要求前缀
/// 后面紧跟一个空格（`"some "` / `"any "`，输入已经过 `stripTypeDecorations` 的空白归一
/// 化，token 间只会有单个空格）——`someCustomType` 的 `"some"` 后面紧跟 `C` 不是空格，
/// 不会被剥掉；反之 `hasPrefix("some")`（不带空格）会把 `someCustomType` 误剥成
/// `CustomType`。这与 #39 `@autoclosure(` 那条「前缀判断必须连带边界字符」是同一种陷阱。
nonisolated func stripSomeOrAnyPrefix(_ t: String) -> String? {
    for prefix in ["some ", "any "] where t.hasPrefix(prefix) {
        return String(t.dropFirst(prefix.count))
    }
    return nil
}

/// 取函数类型**最右侧（非最外层）** depth-0 `->` 右侧的类型文本；不是函数类型则返回 `nil`。
///
/// ⚠️ **函数名与实现按最右侧箭头取，不是「最外层返回类型」**（#40 Task 2 评审
/// Minor-3——此前的文档把这两者混为一谈）：对柯里化 `(A) -> (B) -> C`（`->` 右结合，
/// 最外层返回类型实际是 `(B) -> C`），下面的循环里 `lastArrow` 每遇到一个 depth 0 的
/// 箭头就覆盖，循环结束时留下的是**最后（最右）**一个，所以本函数对这个输入返回的是
/// `C`，不是 `(B) -> C`。评审已推演：四分类结果在两种取法下**恒相同**——最终落地的
/// 是否文本这个结论一致（`(B) -> C` 本身若递归下去，只要 `C` 不是文本，整个链条就不是
/// `.bareText`/`.localizedText`；`(B) -> C` 这个中间形态本身不会被 `bareTextTypeNames`
/// / `localizedTextTypeNames` 精确匹配上，只能落进 `textIdentifierPresent` 兜底，
/// 而兜底不关心取的是哪一段），因此不改实现、只在此更正措辞。
///
/// ⚠️ **`->` 必须整体当一个 token 消费**：只写 `case ">"` 递减深度的话，`(A) -> B` 里
/// 箭头的 `>` 会把深度算错，后面真正的泛型闭合就再也对不上。这里先匹配 `-` + `>` 两字符
/// 并整体跳过，`>` 分支只处理真正的泛型闭合。
/// ⚠️ **只认最外层（depth == 0）的箭头**：`Optional<(Item) -> String>` 的箭头在深度 1，
/// 这里返回 `nil`，交给调用方的 `Optional<...>` 递归分支处理，不在这里重复一套拆解。
nonisolated func functionReturnTypeText(_ t: String) -> String? {
    let chars = Array(t)
    var depth = 0
    var lastArrow: Int?
    var i = 0
    while i < chars.count {
        if chars[i] == "-", i + 1 < chars.count, chars[i + 1] == ">" {
            if depth == 0 { lastArrow = i }
            i += 2
            continue
        }
        switch chars[i] {
        case "(", "<", "[": depth += 1
        case ")", ">", "]": depth -= 1
        default: break
        }
        i += 1
    }
    guard let arrow = lastArrow else { return nil }
    return String(chars[(arrow + 2)...]).trimmingCharacters(in: .whitespaces)
}

/// FR-4 的参数类型分类。
///
/// ⚠️ **剥离层直接复用 #39 的 `stripTypeDecorations` / `stripOptionalSugarAndRedundantParens`**
/// （Task 1 抽出）：注释 / 空白 / 反引号 / 多余括号 / Optional 语法糖 / specifier /
/// attribute 这六个轴上，FR-4 面对的免登记逃逸与 J-1 的免豁免逃逸**逐字同源**——
/// `init(title: (String))` 与 `init(flag: (Bool))` 的调用点都逐字不变。复用而不是重写，
/// 是因为那六个轴上 #39 已经撞出并修复了 5 组残余；重写一份必然要把它们再撞一遍。
///
/// ⚠️ **`sawAutoclosure` 在这里不需要单独裁决**（与 J-1 不同）：J-1 必须把
/// `@autoclosure () -> Bool`（换皮）与 `() -> Bool`（真闭包）分开；FR-4 的规则更宽——
/// **返回位是文本的函数类型一律算文本入口**，因为登记表本来就是这么记的
/// （`SegmentedControl.title` / `UnderlinedTabBar.title` 的类型是 `(Item) -> String`，
/// 登记表 `notes` 原文：「title 由 `(Item) -> String` 闭包解出的分段标签文本」）。
/// ⇒ 两种写法都走同一条返回位递归分支，`sawAutoclosure` 无须读。
///
/// ⚠️ **已知盲区（留痕，未做机器拦截）**——不是「已覆盖全部」：
/// - **`typealias` 洗白**：`public typealias Title = String` 后写 `init(title: Title)`，
///   参数类型文本是 `"Title"` ⇒ `.notText`，命中/清点两层同时看不见。与 #39 裁决 (f)
///   同族；#39 在**声明侧**清点 `publicBoolTypeAliases` 并断言恒为空，FR-4 侧没有对应的
///   清点（本仓当前零个含文本的 public typealias）。移交 #41/#43。
/// - **泛型洗白**：`func f<T>(title: T) where T == String`（同类型约束把类型名换成了
///   别处声明的 `T`，纯语法层解不出 `T` 绑定的是什么）与 `f(title: some
///   ExpressibleByStringLiteral)`（`ExpressibleByStringLiteral` 不隐含「是文案」——
///   `Int`/`Bool` 都能遵守它，纯语法层解不出这个协议名背后是不是文本）这两种真正判不了。
///   `S: StringProtocol` 这一种**已经**由 `stringProtocolGenerics` 结构性覆盖（见
///   `ComponentJudgeCollector.stringProtocolGenericNames`）；`some StringProtocol` /
///   `any StringProtocol` ——与前者是**同一声明的语法糖、调用点逐字相同**——也**已经**
///   由 `stripSomeOrAnyPrefix` 结构性覆盖（#40 Task 2 评审 Important-1：此前这里把这个
///   形态误并入「判不了」，但它的类型文本逐字含 `StringProtocol`，纯语法层完全可解，
///   归类是错的）。其余形态（`where T == String`、`some ExpressibleByStringLiteral` 等
///   真正无法从类型文本解出是否文本的写法）本仓零命中，留痕未拦截。
/// - **`StaticString` / `AttributedString` 未折入**：两者都能承载界面文案，但把它们
///   并入 `.bareText` 是新裁决（不是「`String` 的另一种拼法」）。本仓零使用，先留痕。
/// - **第二道防线**：上述盲区对**已登记**的参数不构成逃逸——把 `title: String` 改写成
///   任何一种扫描器看不见的形态，登记表里那条 `textParams` 会在 FR-4 的**反向差集**
///   （`ghostRegistryParams`）里变成幽灵条目而判红（见 `judgeTextParamCoverage`）。
///   逃逸只对**新增且从未登记**的参数成立。
nonisolated func classifyTextParameterType(
    _ raw: String, stringProtocolGenerics: Set<String>
) -> TextParamKind {
    let stripped = stripTypeDecorations(raw)
    var t = stripped.text

    // `inout String` 是双向通道，与 `Binding<String>` 同类 —— 显式判 .textCarrying,
    // 不是「恰好没匹配上」。
    if stripped.sawInout {
        return textIdentifierPresent(t) ? .textCarrying : .notText
    }

    t = stripOptionalSugarAndRedundantParens(t)
    if bareTextTypeNames.contains(t) || stringProtocolGenerics.contains(t) { return .bareText }
    if localizedTextTypeNames.contains(t) { return .localizedText }
    // `some StringProtocol` / `any StringProtocol`：与已覆盖的
    // `init<S: StringProtocol>(title: S)` 是同一声明的语法糖、调用点逐字相同，结构性剥
    // 掉 opaque/existential 前缀后按 StringProtocol 判 .bareText，结论与泛型形态保持
    // 一致（#40 Task 2 评审 Important-1：此前这个形态会静默落进下面的 textIdentifierPresent
    // 兜底判 .notText——`\bString\b` 因词边界在 `StringProtocol` 里不命中，命中层与清点层
    // 双双不可见）。
    if let afterPrefix = stripSomeOrAnyPrefix(t),
        stringProtocolOpaqueOrExistentialTypeNames.contains(afterPrefix) {
        return .bareText
    }

    // `Optional<T>` 结构化递归（照 #39 裁决 (b‴‴) 的成法，不枚举拼法）。
    if let genericArgument = optionalGenericArgument(t) {
        let inner = classifyTextParameterType(genericArgument, stringProtocolGenerics: stringProtocolGenerics)
        if inner == .bareText || inner == .localizedText { return inner }
    }
    // 返回位是文本的函数类型 ⇒ 文本经这条闭包进入组件。
    if let returned = functionReturnTypeText(t) {
        let inner = classifyTextParameterType(returned, stringProtocolGenerics: stringProtocolGenerics)
        if inner == .bareText || inner == .localizedText { return inner }
    }
    return textIdentifierPresent(t) ? .textCarrying : .notText
}

/// 类型文本里是否还出现了文本类型的**标识符**（词边界匹配，`MyStringish` / `StringLike`
/// 不误命中）。命中即归 `.textCarrying`：清点、打印、不进判据。
nonisolated func textIdentifierPresent(_ t: String) -> Bool {
    t.range(
        of: #"\b(String|Substring|LocalizedStringKey|LocalizedStringResource)\b"#,
        options: .regularExpression
    ) != nil
}

// MARK: - 命中项 / Hit

/// 一处「public 声明上的文本型参数」。
struct TextParamHit: Hashable, Comparable, Sendable {
    /// 宿主：具名类型用点分全名（`SegmentedControlStyleConfiguration.Segment`）；
    /// extension 上的成员用**被扩展的类型名**（`View` / `Color` / `Tag`）。
    let owner: String
    /// `init` 或函数名。
    let decl: String
    /// 参数的**内部名**（`_ titleKey:` 取 `titleKey`）。
    let parameter: String
    let file: String
    let line: Int
    let kind: TextParamKind
    /// FR-4 的主判据只吃 `init`（AC 原文：「每个 public init 的文本型参数」）；
    /// `func` 侧同样采集，但只进「留痕桶」——见 `ComponentTextParamGuard` 的
    /// `functionSideTextParams` 断言与那里的移交说明。
    let isInitializer: Bool

    /// 与登记表对账用的键。⚠️ 刻意不含标签表：`SectionHeader.init(_ titleKey:)` 与
    /// `init<S: StringProtocol>(_ title:)` 是同一个 API 概念的两个入口，键里带完整标签表
    /// 会让它们变成两条互不相干的条目，反而看不出「同一个文案入口的两种写法」。
    var key: String { "\(self.owner).\(self.decl)#\(self.parameter)" }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key ? lhs.line < rhs.line : lhs.key < rhs.key
    }
}

// MARK: - 扫描结果 / Scan result

/// 一个**本仓声明**的自有样式协议。
///
/// ⚠️ **识别信号是结构性的，不是名字**（任务书明令：不许用裸字符串 `"Style"` 子串匹配）：
/// 判据是「`protocol` 的成员里有 `func makeBody(configuration:)` requirement」——这正是
/// Apple `ButtonStyle` / `ToggleStyle` / `ProgressViewStyle` 的形状，也是本仓
/// `BannerStyle` / `SegmentedControlStyle` 照抄的形状（两者的文档注释原文都写着
/// 「形态对齐 Apple `ButtonStyle`」）。名字后缀只作为报告里的旁证字段
/// （`nameHasStyleSuffix`）打印，**不参与任何判定**。
///
/// ⚠️ **Apple 的原生样式协议不会被采进来**：它们声明在 SwiftUI 里，不在
/// `Sources/CoreDesign` 的扫描范围内 ⇒ `styleProtocols` 天然只含本仓自有协议，
/// J-3 因此不会「用 `ProgressViewStyle` 判 `ProgressIndicator` 的红」。这条是
/// **构造保证**，不是靠名字清单排除的——后者正是任务书点名要避开的脆弱写法。
///
/// ⚠️ **已知盲区（留痕，未做机器拦截）**：requirement 写在 protocol **extension** 里
/// （`extension Foo { func makeBody(configuration:) }`）或用别的定制点名字（例如
/// `body(configuration:)`）的样式协议识别不出来。本仓两个自有协议都把 `makeBody`
/// 写在 protocol 体内（实测零漏），但这是**现状核对**，不是**结构保证**。
struct StyleProtocolDecl: Hashable, Sendable {
    let name: String
    let file: String
    let line: Int
    let isPublic: Bool
    /// 仅供报告打印的旁证，**不参与判定**。
    let nameHasStyleSuffix: Bool
}

/// 一处 conformance 声明（类型声明自带的，或 `extension X: P` 补的）。
/// 形态 D1「外观槽」的一条采集记录：某个类型的 `init` 里带 `@ViewBuilder` 的公开参数。
///
/// ⚠️ **只采 `init` 参数、且只采公开可见的** —— 私有 body 里的 `@ViewBuilder` 计算属性
/// （如 `Timeline.swift:220` 的 `private var nodeView`）**不是**扩展点，调用方够不着它。
/// 若把那种也采进来，J-2 会把「组件自己有个私有 ViewBuilder」误判成「已给扩展点」。
struct StyleSlotDecl: Hashable, Sendable {
    let typeName: String
    let paramName: String
    let file: String
    let line: Int
    /// `TypeName.paramName` —— 登记表 `styleSlot` 字段的比对键。
    var key: String { "\(self.typeName).\(self.paramName)" }
}

/// 参数类型 → 基名：剥掉 `?` / `!`、泛型实参、点分前缀，取最后一段。
/// `SwiftUI.StepsAxis?` → `StepsAxis`；`[StepItem]` → `""`（容器类型不参与 D2 接线）。
///
/// ⚠️ 文件级 `internal` 而非 collector 的 static 成员 —— 后者是 `private`，单测够不着，
/// 而这是纯字符串处理、值得单独钉住（含**已知限度**：`Binding<Enum>` 会在 `<` 处截断，
/// 见 `ComponentJudgeScannerTests.baseTypeNameKnownLimits`）。
nonisolated func componentJudgeBaseTypeName(_ raw: String) -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    while text.hasSuffix("?") || text.hasSuffix("!") { text.removeLast() }
    if let angle = text.firstIndex(of: "<") { text = String(text[text.startIndex..<angle]) }
    guard !text.contains("["), !text.contains("("), !text.contains(" ") else { return "" }
    return text.split(separator: ".").last.map(String.init) ?? ""
}

/// 形态 D2「配置枚举」的一条**接线**记录：某个公开 `init` 参数以该 enum 为类型。
///
/// ⚠️ 为什么需要它：只核「公开 enum 声明存在」的话，登记表填**任意**一个本仓已有的
/// 公开 enum 名就能判绿 —— 组件代码一行不写。这正是 D1 那条臂用 `styleSlotKeys`
/// （`类型名.参数名`）避免的形态，D2 一开始漏掉了（PR #206 第 2 轮 review 抓到）。
struct StyleEnumUse: Hashable, Sendable {
    /// 参数类型的基名（剥掉 `?` / 泛型实参 / 点分前缀后的最后一段）。
    let enumName: String
    /// 承载该 `init` 的类型名。
    let hostType: String
    let paramName: String
    let file: String
    let line: Int
    /// `HostType.enumName` —— 诊断用。
    var key: String { "\(self.hostType).\(self.enumName)" }
}

/// 形态 D2「配置枚举」的一条采集记录：公开 `enum` 声明。
struct StyleEnumDecl: Hashable, Sendable {
    let name: String
    let file: String
    let line: Int
    /// case 名集合 —— 供「候选形态能否被 case 一一覆盖」的人工核对使用。
    let caseNames: Set<String>
}

struct ConformanceRecord: Hashable, Sendable {
    /// 具名类型用**简单名**（不含外层点分前缀）；extension 用被扩展类型的基名。
    let typeName: String
    /// 继承子句里每一项的**最后一段**（容忍 `SwiftUI.View` 这类限定名）。
    let inheritedNames: [String]
    let file: String
    let line: Int
}

struct ComponentJudgeScanResult: Sendable {
    var textParams: [TextParamHit] = []
    var styleProtocols: [StyleProtocolDecl] = []
    var conformances: [ConformanceRecord] = []
    var styleSlots: [StyleSlotDecl] = []
    var styleEnums: [StyleEnumDecl] = []
    var styleEnumUses: [StyleEnumUse] = []
    /// 类型名（含被 extension 扩展的类型名）→ 声明它的文件名集合。J-3 用它定「组件作用域」。
    var typeDeclFiles: [String: Set<String>] = [:]

    /// 四个桶全空 —— 扫描器的三条失败路径（路径不存在 / 无法枚举 / 解析出错）产出的
    /// 正是这个形状。⚠️ **判「失败」的信号是全空，不是「`textParams` 空」**
    /// （PR #195 第 2 轮 review）：只看 `textParams` 会把「扫描成功、恰好零文本参数」
    /// 也判成失败。`ComponentJudgeSources.scan()` 的缓存准入与
    /// `scanComponentJudgeInputs(roots:)` 的逐根断言共用本属性，免得两处各写一份而漂。
    var isEmpty: Bool {
        self.textParams.isEmpty && self.styleProtocols.isEmpty
            && self.conformances.isEmpty && self.typeDeclFiles.isEmpty
    }

    var bareTextKeys: Set<String> { Set(self.textParams.filter { $0.kind == .bareText }.map(\.key)) }
    var localizedTextKeys: Set<String> { Set(self.textParams.filter { $0.kind == .localizedText }.map(\.key)) }
    var carryingKeys: Set<String> { Set(self.textParams.filter { $0.kind == .textCarrying }.map(\.key)) }

    var styleProtocolNames: Set<String> { Set(self.styleProtocols.map(\.name)) }

    /// 形态 D1 的比对键集合，形如 `TimelineItem.node`。
    var styleSlotKeys: Set<String> { Set(self.styleSlots.map(\.key)) }
    /// 形态 D2 的公开枚举名集合。
    var styleEnumNames: Set<String> { Set(self.styleEnums.map(\.name)) }
    /// 形态 D2 的**接线**索引：enum 名 → 以它为参数类型的公开 `init` 的宿主类型集合。
    var styleEnumHosts: [String: Set<String>] {
        self.styleEnumUses.reduce(into: [:]) { $0[$1.enumName, default: []].insert($1.hostType) }
    }

    /// 采纳了指定协议的类型名集合（声明侧与 extension 侧合并）。
    func conformers(of protocolName: String) -> Set<String> {
        Set(self.conformances.filter { $0.inheritedNames.contains(protocolName) }.map(\.typeName))
    }
}

// MARK: - 扫描入口 / Scan entry points

/// 多根扫描（`#270`）。J-2 / J-3 / FR-4 三条判据的真实入口是
/// `ComponentJudgeSources.scan()`，它传的就是 `ComponentRegistryGuard.componentScanRoots`。
///
/// ⚠️ **为什么必须跟着登记表一起扩根**：登记表 `#270` 起收 `CoreDesignEffects` /
/// `CoreDesignCharts` 的 public 类型，而 J-2 是「登记表说要扩展点 ⇒ 源码里必须真的有」。
/// 只扩登记表不扩本扫描器，新条目的扩展点在源码里找不到 ⇒ J-2 会把**已经存在的**扩展点
/// 判成缺失；反过来若把新条目全判 `prescriptive` 逃开 J-2，J-3（原生协议纯度）与 FR-4
/// （文本参数分类）**照样**看不见它们的源码 —— 那正是本 issue 要收的那个口。
///
/// ⚠️ **三层 fail-closed，缺一层就留一条缝**：
/// ① `GuardScanRoots.assertRootsExist` —— 列表非空 + 每根目录存在；
/// ② `scanComponentJudgeInputs(root:)` 内部 —— 该根的路径存在 / 可枚举；
/// ③ **逐根产出非空**（PR #297 终审 S-3 补上的一层）。
///
/// ⚠️ **③ 是本轮补的，此前只有 ①②**：它的姊妹
/// `ComponentRegistryGuard.scannerFindsComponentTypes` 早就明写着「多根扫描最容易的
/// 假绿正是『新根静默产出空集』，故每个根各自也要有非空断言」，而同一族、同一批扩根的
/// 本函数**没有**这条 —— 同风险、同文件族、待遇不对称。
/// 「目录存在、里面也有 `.swift`，但整根一个声明都没采到」（解析器对新 target 的语法
/// 形态整体失效、拷贝出错、`.swift` 全在被跳过的子目录里）会让合并结果只少掉一部分，
/// 而下游的 `bareTextKeys.count > 20` 这类**合计**下界靠主 target 一家就能满足。
func scanComponentJudgeInputs(
    roots: [(target: String, url: URL)],
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) throws -> ComponentJudgeScanResult {
    GuardScanRoots.assertRootsExist(roots)
    var result = ComponentJudgeScanResult()
    for root in roots {
        let one = try scanComponentJudgeInputs(root: root.url)
        if one.isEmpty {
            Issue.record("""
            扫描根 \(root.target)（\(root.url.path)）四个桶全空 —— 判据无法工作，这不是「零违规」。
            多根扫描最容易的假绿就是新根静默产出空集：合并之后主 target 的量把合计下界撑满，
            而这一根的源码**完全不受 J-2 / J-3 / FR-4 覆盖**。
            """, sourceLocation: sourceLocation)
        }
        result.merge(one)
    }
    return result
}

/// ⚠️ **必须先断言路径存在**：`FileManager.enumerator(at:)` 对不存在的路径**静默产出
/// 空序列** ⇒「零命中 ⇒ 零违规 ⇒ 绿」会静默通过（#38/#39 同款纪律）。
///
/// ⚠️ **`fileName` 从裸文件名改成了 `<根目录名>/<根内相对路径>`**（`#270`）：
/// 该字符串**不只是诊断**——J-3 的「组件作用域」靠 `typeDeclFiles[component]` 与
/// `styleProtocols.file` 做**集合相交**（见 `ComponentJudgeRules` 的通道 (i)），
/// 裸文件名在三根之下会让 `CoreDesign/Foo.swift` 与 `CoreDesignEffects/Foo.swift`
/// **塌成同一个作用域**，一个 target 里的协议声明会被算进另一个 target 的组件作用域。
/// ⚠️ **前缀取的是根目录名而不是仓库根相对路径**（`GuardScanRoots.relativePath` 会给出
/// `Sources/CoreDesign/…`）：`ComponentJudgeMutationTests` 把源码树拷进 `NSTemporaryDirectory()`
/// 再扫，用仓库根相对路径的话副本里的 `file` 会退化成一串绝对路径，
/// `copiedTreeReproducesBaseline` 的「副本 == 真实源码」就不再成立。根目录名两边一致。
/// ⚠️ **根内相对路径那一段必须走 `GuardScanRoots.relativePath(_:from:)`，不得自己拼串**
///（`#311`）：这里原来是 `url.path.replacingOccurrences(of: root.path + "/", with: "")`，
/// 与 `GuardScanRoots.relativePath` 同一份缺陷 —— 根与枚举结果对 `/private` 前缀不一致时，
/// `replacingOccurrences` 会在串中间挖掉一段，键被污染。
///
/// ⚠️ **分叉有两个彼此独立的来源，别写成一段**（`#313` 终审 C-7 拆开；原文把第 1 条的
/// 实测串接在第 2 条的理由后面，因果错位）：
/// 1. **真实扫描根**——checkout 落在 `/tmp` 这类符号链接下时，`#filePath` 推出的根不解析
///    `/private`、`FileManager` 枚举解析。`#311` 复现里由
///    `NativeProtocolPurityGuard.nativeProtocolComponentsAreFreeOfCustomStyleProtocols`
///    打印出的 `"CoreDesign//privateComponents/ProgressIndicator/ProgressIndicator.swift"`
///    （实测）来自**这一条**——它**只在**符号链接 checkout 下出现。
/// 2. **`NSTemporaryDirectory()` 副本根**——`ComponentJudgeMutationTests` 的副本树落在
///    `/var/folders/…`，而 `/var` 同样是 `/private/var` 的符号链接。⚠️ 这一条
///    **与 checkout 位置无关、在任何机器上都会发生**（覆盖面比第 1 条更广）：
///    实测修法前该组 125 条键**全部**形如 `"CoreDesign//privateShape/StarShape.swift"`。
///    ⚠️ 但它**行为中性**：那串只被 `ComponentJudgeRules` 的**同一次扫描内**集合相交与
///    诊断消费，污染在相交的两侧一致；而 `copiedTreeReproducesBaseline` 比的是
///    `bareTextKeys` / `styleProtocolNames` 这类**符号键**，根本不比文件串
///    ⇒ 修法前后判据结论不变，改它是为了诊断可读与「不留第二份缺陷实现」。
///    ⇒ 判据 `ComponentJudgeScannerPathKeyTests.componentJudgeKeysAreImmuneToSymlinkDivergence`
///    钉的正是这一条（`#313` 终审 C-1：本处此前**零判据覆盖**）。
/// ⇒ 两个来源都要归一。
func scanComponentJudgeInputs(root: URL) throws -> ComponentJudgeScanResult {
    guard FileManager.default.fileExists(atPath: root.path) else {
        Issue.record("源码路径不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
        return ComponentJudgeScanResult()
    }
    // ⚠️ **不要强制解包**：`enumerator(at:)` 在权限 / IO 异常时返回 nil，`!` 会让测试
    // 进程崩掉，判据连「为什么失败」都报不出来。
    guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
        Issue.record("无法枚举源码目录：\(root.path)（权限或 IO 异常）—— 判据无法工作，这不是「零违规」")
        return ComponentJudgeScanResult()
    }
    var result = ComponentJudgeScanResult()
    let rootPrefix = root.lastPathComponent
    for case let url as URL in walker where url.pathExtension == "swift" {
        let name = rootPrefix + "/" + GuardScanRoots.relativePath(url, from: root)
        let tree = SwiftParser.Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
        // ⚠️ **解析保真检查**：parser major 与工具链不配套时会静默产出 error node
        // ⇒ 声明被漏采，而扫描器照样「成功」返回一个偏小的集合。
        if tree.hasError {
            Issue.record("解析出错：\(name) —— swift-syntax major 可能与工具链不配套")
        }
        result.merge(collectComponentJudgeInputs(tree: tree, fileName: name))
    }
    return result
}

/// 合成输入入口——常驻单测用它逐类证伪边界形态，不碰磁盘。
func scanComponentJudgeInputs(source: String, fileName: String = "Synthetic.swift") -> ComponentJudgeScanResult {
    collectComponentJudgeInputs(tree: SwiftParser.Parser.parse(source: source), fileName: fileName)
}

private func collectComponentJudgeInputs(tree: SourceFileSyntax, fileName: String) -> ComponentJudgeScanResult {
    let converter = SourceLocationConverter(fileName: fileName, tree: tree)
    let collector = ComponentJudgeCollector(fileName: fileName, converter: converter)
    collector.walk(tree)
    var result = ComponentJudgeScanResult()
    result.textParams = collector.textParams
    result.styleProtocols = collector.styleProtocols
    result.conformances = collector.conformances
    result.styleSlots = collector.styleSlots
    result.styleEnumUses = collector.styleEnumUses
    result.styleEnums = collector.styleEnums
    result.typeDeclFiles = collector.typeDeclFiles
    return result
}

extension ComponentJudgeScanResult {
    mutating func merge(_ other: ComponentJudgeScanResult) {
        self.textParams += other.textParams
        self.styleProtocols += other.styleProtocols
        self.conformances += other.conformances
        // ⚠️ 新增字段必须同时接进这里 —— 磁盘扫描入口逐文件走 `merge`，漏接会让该字段
        // 在真实扫描下**恒为空**，而合成输入的单测照样绿（那条路径不走 merge）。
        self.styleSlots += other.styleSlots
        self.styleEnumUses += other.styleEnumUses
        self.styleEnums += other.styleEnums
        for (name, files) in other.typeDeclFiles {
            self.typeDeclFiles[name, default: []].formUnion(files)
        }
    }
}

// MARK: - 采集器 / Collector

/// 采集**有效 public** 的 `init` / `func` 上的文本型参数。
///
/// ⚠️ **可见性判定与 #39 的 `PublicBoolParamCollector` 同构**（裁决 (e)/(g) 同样适用）：
/// protocol 帧要压栈（requirement 语法上不能写访问修饰符）、`public extension` 给嵌套
/// 具名类型发默认 public、`#if` 两支都要走、`#Preview` 在文件顶层落在
/// `MacroExpansionExprSyntax` 而非 decl 侧（两处都要跳）。这些不是可选项，是结构性缺口。
/// ⚠️ **本类不复用 `PublicBoolParamCollector` 的实例**——那个类是 `private`，且它的
/// `visit` 已经绑定「读 Bool 参数」的语义。两者共用的是**裁决**（写在这段注释里）与
/// **类型文本剥离层**（`stripTypeDecorations`，Task 1 抽出的真代码），可见性帧机的复制
/// 是已知代价，由 `ComponentJudgeScannerTests` 里 `collectorSkipsNonPublic` /
/// `collectorHandlesPublicExtension` 两条测试对齐同一批边界形态。
///
/// ⚠️ **已知盲区（留痕，未做机器拦截）**：
/// - `subscript` 未采（FR-4 的 AC 只点名 `init`；`func` 侧已采但只进留痕桶）。
/// - `enum case` 关联值未采（`case a(title: String)` 在调用点是一个文本参数）。本仓
///   public enum 的关联值零文本参数；与 #39 裁决 (e) 对 Bool 的处置**方向相反**，
///   是本任务刻意收窄到 AC 原文范围的结果，不是遗漏 —— 移交 #41/#43。
/// - 宏展开产物看不见（跳 `#Preview` 的代价）；本仓无生成 public 声明的宏。
private nonisolated final class ComponentJudgeCollector: SyntaxVisitor {
    var textParams: [TextParamHit] = []
    var styleProtocols: [StyleProtocolDecl] = []
    var conformances: [ConformanceRecord] = []
    var styleSlots: [StyleSlotDecl] = []
    var styleEnumUses: [StyleEnumUse] = []
    var styleEnums: [StyleEnumDecl] = []
    var typeDeclFiles: [String: Set<String>] = [:]

    private let fileName: String
    private let converter: SourceLocationConverter

    private struct Frame {
        let name: String
        let isPublic: Bool
        let isPrivate: Bool
        let isInternal: Bool
        let isExtension: Bool
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

    private var owner: String {
        self.frames.isEmpty ? "(top-level)" : self.frames.map(\.name).joined(separator: ".")
    }

    // MARK: 声明索引 / Declaration index

    /// 继承子句里每一项取**最后一段**：容忍 `SwiftUI.View` 这类限定名。
    private func inheritedNames(_ clause: InheritanceClauseSyntax?) -> [String] {
        (clause?.inheritedTypes ?? []).map {
            $0.type.trimmedDescription.split(separator: ".").last.map(String.init) ?? ""
        }
    }

    /// 记录「类型名 → 文件」与（有继承子句时）一条 conformance。
    private func indexDecl(
        name: String, inheritance: InheritanceClauseSyntax?, at node: some SyntaxProtocol
    ) {
        self.typeDeclFiles[name, default: []].insert(self.fileName)
        let names = self.inheritedNames(inheritance)
        guard !names.isEmpty else { return }
        self.conformances.append(
            ConformanceRecord(
                typeName: name, inheritedNames: names, file: self.fileName,
                line: self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
            )
        )
    }

    // MARK: 容器帧

    private func pushType(_ name: String, _ modifiers: DeclModifierListSyntax, isProtocol: Bool = false) {
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
                isPrivate: a.priv, isInternal: a.int, isExtension: false, isProtocol: isProtocol
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        // ⚠️ 形态 D2「配置枚举」：只采**公开**的。可见性判据与外观槽同源。
        if self.isEffectivelyPublic(node.modifiers) {
            var cases: Set<String> = []
            for member in node.memberBlock.members {
                guard let decl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in decl.elements { cases.insert(element.name.text) }
            }
            self.styleEnums.append(
                StyleEnumDecl(
                    name: node.name.text, file: self.fileName,
                    line: node.startLocation(converter: self.converter).line, caseNames: cases
                )
            )
        }
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        self.pushType(node.name.text, node.modifiers); return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        self.indexDecl(name: node.name.text, inheritance: node.inheritanceClause, at: node)
        // ⚠️ 结构性信号：成员里有 `func makeBody(configuration:)` requirement。
        let hasMakeBodyRequirement = node.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self),
                  function.name.text == "makeBody" else { return false }
            let parameters = function.signature.parameterClause.parameters
            return parameters.count == 1 && parameters.first?.firstName.text == "configuration"
        }
        if hasMakeBodyRequirement {
            self.styleProtocols.append(
                StyleProtocolDecl(
                    name: node.name.text, file: self.fileName,
                    line: self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
                    isPublic: Self.access(node.modifiers).pub,
                    nameHasStyleSuffix: node.name.text.hasSuffix("Style")
                )
            )
        }
        self.pushType(node.name.text, node.modifiers, isProtocol: true); return .visitChildren
    }
    override func visitPost(_ node: ProtocolDeclSyntax) { self.frames.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        var extended = node.extendedType.trimmedDescription
        if let angle = extended.firstIndex(of: "<") { extended = String(extended[..<angle]) }
        extended = extended.trimmingCharacters(in: .whitespaces)
        self.indexDecl(name: extended, inheritance: node.inheritanceClause, at: node)
        let a = Self.access(node.modifiers)
        self.frames.append(
            Frame(
                name: extended,
                isPublic: a.pub, isPrivate: a.priv, isInternal: a.int, isExtension: true
            )
        )
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { self.frames.removeLast() }

    /// `#if os(iOS)` 的两个分支都要走：只走一支会漏采另一支的声明。
    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        for clause in node.clauses {
            if let elements = clause.elements { self.walk(elements) }
        }
        return .skipChildren
    }

    /// 跳过 `#Preview` 等宏展开块。⚠️ **两处都要跳**：`#Preview` 在文件顶层实际解析成
    /// `MacroExpansionExprSyntax`，只跳 decl 侧堵不住（#39 Task 1 评审现场抓到过）。
    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

    // MARK: 声明

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(
            node.signature.parameterClause.parameters, decl: "init", modifiers: node.modifiers,
            generics: Self.stringProtocolGenericNames(node.genericParameterClause, node.genericWhereClause),
            isInitializer: true, at: node
        )
        self.collectStyleSlots(node)
        self.collectStyleEnumUses(node)
        return .skipChildren
    }

    /// 采形态 D1「外观槽」：`init` 参数里带 `@ViewBuilder` 的公开参数。
    ///
    /// ⚠️ **可见性沿用 `isEffectivelyPublic` 那套判据**（父类型链上有 private/internal 就不算）
    /// —— 一个 internal 类型上的 `@ViewBuilder` 参数调用方够不着，不构成扩展点。
    private func collectStyleSlots(_ node: InitializerDeclSyntax) {
        guard let typeName = self.frames.last?.name else { return }
        guard self.isEffectivelyPublic(node.modifiers) else { return }
        for parameter in node.signature.parameterClause.parameters {
            let hasViewBuilder = parameter.attributes.contains { attribute in
                guard case let .attribute(attr) = attribute else { return false }
                return attr.attributeName.trimmedDescription == "ViewBuilder"
            }
            guard hasViewBuilder else { continue }
            // ⚠️ 外部标签优先：调用方写的是外部标签，登记表 `styleSlot` 也该按调用方视角写。
            let name = (parameter.firstName.text == "_"
                ? parameter.secondName?.text : parameter.firstName.text) ?? parameter.firstName.text
            let line = node.startLocation(converter: self.converter).line
            self.styleSlots.append(
                StyleSlotDecl(typeName: typeName, paramName: name, file: self.fileName, line: line)
            )
        }
    }

    /// 采形态 D2 的**接线**：公开 `init` 的每个参数类型基名（可见性判据与 D1 同源）。
    ///
    /// ⚠️ 采的是**全部**参数类型、不预筛「看起来像枚举的」—— 是否为公开 enum 由规则层与
    /// `styleEnumNames` 求交决定，扫描器只负责如实记录接线事实。
    private func collectStyleEnumUses(_ node: InitializerDeclSyntax) {
        guard let hostType = self.frames.last?.name else { return }
        guard self.isEffectivelyPublic(node.modifiers) else { return }
        let line = node.startLocation(converter: self.converter).line
        for parameter in node.signature.parameterClause.parameters {
            let base = componentJudgeBaseTypeName(parameter.type.trimmedDescription)
            guard !base.isEmpty else { continue }
            let name = (parameter.firstName.text == "_"
                ? parameter.secondName?.text : parameter.firstName.text) ?? parameter.firstName.text
            self.styleEnumUses.append(
                StyleEnumUse(
                    enumName: base, hostType: hostType, paramName: name,
                    file: self.fileName, line: line
                )
            )
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        self.collect(
            node.signature.parameterClause.parameters, decl: node.name.text, modifiers: node.modifiers,
            generics: Self.stringProtocolGenericNames(node.genericParameterClause, node.genericWhereClause),
            isInitializer: false, at: node
        )
        self.collectStyleEnumUsesFromViewModifier(node)
        return .skipChildren
    }

    /// 采形态 D2 的**第二条接线通路**：`public extension View` 上的 modifier 方法参数
    /// （`wxlpp/oh-my-story#65`）。
    ///
    /// ## 为什么需要它
    ///
    /// D2 原本只认公开 `init` 的参数。但有些组件的**唯一公开入口就是一个 modifier 方法**
    /// —— `Toast` 的 `View.toastHost(edge:presentation:)` 就是：它的 `ToastHost` 由内部
    /// modifier 的 `@State` 持有，调用方**够不着任何 `init`**。往那种 `init` 上加参数等于
    /// 「声明了但调用方用不上」，恰恰是 D2 第二道门槛要挡的东西。
    ///
    /// ## ⚠️ 三条收窄条件同时满足，缺一不可
    ///
    /// 1. 声明在 `extension View` 上（被扩展类型逐字为 `View`）；
    /// 2. 方法 `isEffectivelyPublic`（沿用与 D1 / `init` 通路同一套可见性判据）；
    /// 3. 返回类型是 `some View`。
    ///
    /// 不收窄的话，**任意公开方法的任意参数**都会变成「扩展点接线」，D2 第二道门槛会被
    /// 稀释到没有意义。
    ///
    /// ## ⚠️ `hostType` 这里记的是**方法名**，不是类型名
    ///
    /// 对 modifier 型 API，调用方写的就是方法名（`.toastHost(...)`），方法名即其身份；
    /// 而 `frames.last?.name` 在 `extension View` 里是 `"View"`，对判定毫无意义。
    /// ⇒ `styleEnumHosts` 的值集合因此**混装类型名与方法名**。登记表侧靠
    /// `componentHostAliases` 把条目名映射到合法宿主标识（见 `ComponentJudgeRules`）。
    private func collectStyleEnumUsesFromViewModifier(_ node: FunctionDeclSyntax) {
        // 条件 1：在 `extension View` 上。
        guard let frame = self.frames.last, frame.isExtension, frame.name == "View" else { return }
        // 条件 2：公开可见。
        guard self.isEffectivelyPublic(node.modifiers) else { return }
        // 条件 3：返回 `some View`。
        guard let returnType = node.signature.returnClause?.type.trimmedDescription,
              returnType == "some View" else { return }

        let hostType = node.name.text
        let line = node.startLocation(converter: self.converter).line
        for parameter in node.signature.parameterClause.parameters {
            let base = componentJudgeBaseTypeName(parameter.type.trimmedDescription)
            guard !base.isEmpty else { continue }
            let name = (parameter.firstName.text == "_"
                ? parameter.secondName?.text : parameter.firstName.text) ?? parameter.firstName.text
            self.styleEnumUses.append(
                StyleEnumUse(
                    enumName: base, hostType: hostType, paramName: name,
                    file: self.fileName, line: line
                )
            )
        }
    }

    /// 取出「被约束为 `StringProtocol` 的泛型形参名」集合。
    ///
    /// ⚠️ **两种写法都要认**：本仓 7 处 `init<S: StringProtocol>` 用的是内联约束，但
    /// `init<T>(...) where T: StringProtocol` 完全等价、且改写成本为零 —— 只认一种就
    /// 开出一条免登记逃逸。⚠️ 这**不使该轴穷尽**：`where T == String`、
    /// `some ExpressibleByStringLiteral` 等形态仍判不了，见 `classifyTextParameterType`
    /// 文档的「已知盲区」。
    private static func stringProtocolGenericNames(
        _ clause: GenericParameterClauseSyntax?, _ whereClause: GenericWhereClauseSyntax?
    ) -> Set<String> {
        var names: Set<String> = []
        for parameter in clause?.parameters ?? [] {
            guard let inherited = parameter.inheritedType?.trimmedDescription else { continue }
            if Self.mentionsStringProtocol(inherited) { names.insert(parameter.name.text) }
        }
        for requirement in whereClause?.requirements ?? [] {
            guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else { continue }
            if Self.mentionsStringProtocol(conformance.rightType.trimmedDescription) {
                names.insert(conformance.leftType.trimmedDescription)
            }
        }
        return names
    }

    /// `StringProtocol` / `Swift.StringProtocol` / `StringProtocol & Sendable` 都算。
    private static func mentionsStringProtocol(_ text: String) -> Bool {
        text.split(separator: "&")
            .map { $0.trimmingCharacters(in: .whitespaces).split(separator: ".").last.map(String.init) ?? "" }
            .contains("StringProtocol")
    }

    private func collect(
        _ parameters: FunctionParameterListSyntax,
        decl: String,
        modifiers: DeclModifierListSyntax,
        generics: Set<String>,
        isInitializer: Bool,
        at node: some SyntaxProtocol
    ) {
        guard self.isEffectivelyPublic(modifiers) else { return }
        let line = self.converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        for parameter in parameters {
            // `_ titleKey: LocalizedStringKey` ⇒ 取 `titleKey`；完全匿名的 `_: String`
            // ⇒ 键里就是 `_`（**不跳过**，跳过等于给它开洞）。
            let name = (parameter.secondName ?? parameter.firstName).text
            let kind = classifyTextParameterType(
                parameter.type.trimmedDescription, stringProtocolGenerics: generics
            )
            guard kind != .notText else { continue }
            self.textParams.append(
                TextParamHit(
                    owner: self.owner, decl: decl, parameter: name, file: self.fileName,
                    line: line, kind: kind, isInitializer: isInitializer
                )
            )
        }
    }
}
