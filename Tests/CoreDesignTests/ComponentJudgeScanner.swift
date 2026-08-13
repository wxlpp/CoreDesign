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

/// 取函数类型**最外层**的返回类型文本；不是函数类型则返回 `nil`。
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
/// - **泛型洗白**：`func f<T>(title: T) where T == String` 与
///   `f(title: some ExpressibleByStringLiteral)` 判不了（纯语法层解不了名字）。
///   `S: StringProtocol` 这一种**已经**由 `stringProtocolGenerics` 结构性覆盖（见
///   `ComponentJudgeCollector.stringProtocolGenericNames`），其余形态本仓零命中。
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
