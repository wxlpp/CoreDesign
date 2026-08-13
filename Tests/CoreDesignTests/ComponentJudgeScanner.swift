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
