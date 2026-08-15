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
///
/// ⚠️ **括号包裹比 `@autoclosure` 还更便宜**（裁决 (b‴)，Task 1 评审 Important-2 补）：
/// `func f(flag: (Bool))` **合法**，调用点 `f(flag: true)` **逐字不变**——裁决 (b′)/(b″)
/// 判命中的两条理由对它逐字成立，改写成本比两者都低（只加一对括号）。`trimmedDescription`
/// 给出的类型文本是 `"(Bool)"` ≠ `"Bool"`，不剥的话会落进 `\bBool\b` 兜底判成
/// `.boolCarrying` ⇒ **免豁免逃逸**。裁决：剥掉「包裹整个类型、剥完仍是单一类型」的外层
/// 括号（`(Bool)` → `Bool`，`((Bool))` → `Bool`，要剥到底），判 `.plainBool`。
/// ⚠️ **元组不能这样剥**：`(Bool, Int)` 的外层括号**不是多余分组**，是元组语法的一部分
/// ——调用点要写 `f(x: (true, 1))`，不是 `f(x: true)`，与 (b′)/(b″)/(b‴) 「调用点逐字
/// 不变」的命中前提不成立，不判 `.plainBool`；但类型文本仍含 `Bool` 标识符，与
/// `[Bool]` / `(Bool) -> Void` 同类落进 `\bBool\b` 兜底，判 `.boolCarrying`
/// （清点、不计违规，与其余「含 Bool 但类型本身不是 Bool」的形态一致处理，不是漏网）。
/// 同一条评审还挑出白名单漏了第四种拼法：`Swift.Optional<Swift.Bool>`（原先只列了
/// `Optional<Bool>` / `Optional<Swift.Bool>` / `Swift.Optional<Bool>` 三种）。
///
/// ⚠️ **括号剥离只作用于最外层，泛型实参位由 Optional 递归分类覆盖**（Task 1 评审
/// 第 2 轮 Important-B）：上面「剥到底」说的是字符串**最外层**这一对括号（`(Bool)` /
/// `((Bool))`），不包括嵌在 `Optional<...>` 泛型实参位里的括号——`Optional<(Bool)>`
/// 的最外层是 `Optional<...>` 这层泛型，不是括号，`isRedundantOuterParen` 从不会碰到
/// 里面那对 `(Bool)`。真正堵住它的是 `classifyBoolParameterType` 剥掉 `Optional<...>`
/// 外壳后对泛型实参**递归调用自身**——递归覆盖了实参位的**括号嵌套**（`Optional<(Bool)>`
/// / `Optional<((Bool))>`），不必对「`Optional` × 括号」逐条枚举拼法。
/// ⚠️ **括号轴与空白轴均为真**（空白轴已随残余组 4 在 Task 2 修复，见
/// `normalizeWhitespace` 的顶层 `\s*([.<>])\s*` 收紧）：递归调用的是**同一个**
/// `classifyBoolParameterType`，它的已知残余会**在实参位原样复现**——最典型的是
/// 残余组 4（标点周围空白）：`Optional<Swift . Bool>` 的实参 `Swift . Bool` 曾经在
/// 递归里同样过不了 `normalizeWhitespace`（只折叠空白**串**、不消空白**位置**），
/// 返回 `.boolCarrying` ⇒ 外层的 `== .plainBool` 检查不成立 ⇒ 整体落兜底，
/// 同款免豁免逃逸。Task 2 在 `normalizeWhitespace` 里补上对 `.`/`<`/`>` 两侧空白的
/// 收紧之后，**最外层全串收紧已覆盖，递归重跑是第二道**（Task 2 评审第 2 轮
/// Suggestion）：`normalizeWhitespace` 在 `classifyBoolParameterType` **顶层对整个
/// 传入字符串**先执行一次，`Optional<Swift . Bool>` 这个全串在递归发生**之前**就已经
/// 被收紧成 `Optional<Swift.Bool>`，实参位的 `Swift . Bool` 早已不存在；该函数在
/// **每次递归调用**都会重新执行只是第二道保险（覆盖递归自身拆出的、未经过外层
/// 收紧的子串），不是这条残余唯一被覆盖的原因——不需要对「Optional × 空白」逐条
/// 枚举拼法；specifier 在泛型实参位不合法，无关。
/// （六组残余的完整清单见 `stripComments` 上方的三通道文档；其中组 6 只留痕、未修，
/// 代码修复移交 #41/#43。）
/// `@autoclosure () -> (Bool)` 同理：返回位的括号在归一化后单独剥（见
/// `classifyBoolParameterType` 里 `sawAutoclosure` 分支），不依赖这里的「最外层」剥离。
///
/// ⚠️ **类型文本内的注释同样是免豁免逃逸**（裁决 (b‴‴‴)，Task 1 评审第 3 轮 Important-1）：
/// `(Bool/*x*/)` / `Optional<Bool/*x*/>` 的调用点与 `f(flag: true)` 逐字相同，改写成本
/// 比 `(Bool)` 还低。⚠️ 这条**不使该通道穷尽**——三通道的覆盖状态与 6 组已知残余见
/// `stripComments` 的文档，不在此重复。
///
/// ⚠️ **反引号转义标识符是这条逃逸通道的第五个 token 侧自由度**（Task 1 评审第 4 轮
/// Important-2）：`` `Bool` `` 是 `Bool` 的合法拼法，`func f(flag: `Bool`)` 的调用点
/// 与 `f(flag: true)` 逐字相同，改写成本比裁决 (b‴) 的 `(Bool)` 还低——只需两个反引号。
/// 全局剥除后与其余四条（括号 / Optional 糖 / specifier·attribute / 空白）并列，见
/// `classifyBoolParameterType` 里的剥离，以及 `stripComments` 文档里的三通道覆盖状态。
nonisolated enum BoolParamKind: Sendable, Equatable {
    /// 参数类型就是 `Bool`（含 `Bool?` / `Optional<Bool>` / `Swift.Bool`
    /// / `consuming Bool` / `borrowing Bool` / `sending Bool`
    /// / `@autoclosure () -> Bool` / `(Bool)` / `((Bool))` / `` `Bool` ``
    /// （反引号转义标识符），剥掉注释后同上均适用）
    /// ⇒ J-1 命中。
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
/// `t` 的最外层括号是否是**多余分组**（`(Bool)` / `((Bool))`），而不是元组语法的一部分
/// （`(Bool, Int)`）——只有前者剥掉之后仍是「同一个类型」，可以继续判定；元组剥了会
/// 把 `(Bool, Int)` 错改成 `Bool, Int`，语义完全变了，绝不能剥。裁决 (b‴)。
///
/// 判法：整个字符串必须被最外层这一对括号**完整包裹**（左边第一个 `(` 与右边最后一个
/// `)` 是同一对，中途不提前闭合——防住 `(A) -> (B)` 这类两段式，虽然当前语法用不到），
/// 且这对括号内部**顶层**不能有逗号（有逗号就是元组的分隔符，不是多余分组）。
nonisolated func isRedundantOuterParen(_ t: String) -> Bool {
    guard t.hasPrefix("("), t.hasSuffix(")") else { return false }
    let chars = Array(t)
    var depth = 0
    var topLevelComma = false
    for (index, char) in chars.enumerated() {
        if char == "(" {
            depth += 1
        } else if char == ")" {
            depth -= 1
            // 最外层括号在字符串末尾之前就闭合 ⇒ 这对括号没有包裹整个字符串，不算多余分组。
            if depth == 0, index != chars.count - 1 { return false }
        } else if char == ",", depth == 1 {
            topLevelComma = true
        }
    }
    return !topLevelComma
}

/// ⚠️ **类型文本内的注释是仍然开着的免豁免逃逸**（裁决 (b‴‴‴)，Task 1 评审第 3 轮
/// Important-1）：`classifyBoolParameterType` 的预处理原先只做
/// `trimmingCharacters(in: .whitespacesAndNewlines)`、从不剥注释；`trimmedDescription`
/// 也只剥整个节点**首尾** trivia，**内部**注释原样保留。`func f(flag: (Bool/*x*/))` 与
/// `func f(flag: Optional<Bool/*x*/>)` 的调用点都与 `f(flag: true)` **逐字相同**
/// ——改写成本比裁决 (b‴) 的 `(Bool)` 还低，只需一对括号 + 一个注释。`//` 行注释同理
/// （括号内换行合法）。
///
/// J-1 的免豁免逃逸可以分三类通道。⚠️ **三条通道现在都是「已枚举 + 已留痕」，没有一条
/// 能给出穷尽论证** —— 通道 (i) 曾在 Task 1 评审第 3 轮被宣称为「穷尽」，随后**连续三轮
/// 被端到端反例证伪**（第 4 轮 2 个、第 5 轮 7 个），该宣称已在第 5 轮撤回，理由见本段末尾。
/// - (i) **调用点不变的类型文本改写** —— **已覆盖并测试**的形态：括号（裁决 (b‴)）✓、
///   Optional 语法糖 / 名义拼法（`Optional<Bool>` / `Swift.Optional<Swift.Bool>` 等，由
///   裁决 (b‴‴) 的递归分类覆盖，不是逐条枚举拼法）✓、ownership specifier / attribute
///   （裁决 (b′)/(b″)）**△（不是 ✓，见下方「specifier 白名单是开放集」，这条通道
///   结构上不可能穷尽）**、空白折叠（trim + `normalizeWhitespace`）✓、**反引号转义标识符**
///   （`` `Bool` ``，评审第 4 轮 Important-2）✓、**注释**（本条，行终止符集合
///   `{'\n', '\r'}`——Swift 词法把 lone `\r` 也当换行，见 `stripComments`）✓。
///
///   ⚠️ **specifier 白名单是开放集，不是可以穷尽枚举的封闭表**（Task 8 终审 Important-1，
///   第十处定义域盲区：`_const`）：`classifyBoolParameterType` 在 `trimmedDescription`
///   摊平后的**字符串**上重造词法，而 specifier / attribute 的 token 集合是**由 Swift
///   工具链单方面扩张的开放集**（`sending` 与 `borrowing` 本身就是 Swift 5.9/6.0 才加的；
///   `_const` 这类下划线前缀 token 连语言演进提案都不需要）。**白名单 ⊂ 开放集 ⇒ 差集
///   恒非空 ⇒ 只能靠撞见。**下面第 5 组是「撞见并修复的最新一个 token」，不是「补完
///   之后这条通道就封闭了」——不要把这条修复读成「specifier 白名单现在穷尽了」。
///
///   ⚠️ **6 组已知残余：组 1–5 是「已撞见并修复」（Task 2 + Task 8 终审第 2 轮），组 6
///   是「已撞见、只留痕、未修」（Task 8 终审第 3 轮，代码修复移交 #41/#43，见下方组 6
///   条目）**（组 1–5 评审实测：均 `swiftc -typecheck` 合法、`hasError == false`、调用点
///   与 `f(flag: true)` 逐字相同，曾落 `.boolCarrying`（组 5 之前）或 `.boolCarrying`
///   未判命中 ⇒ 免豁免逃逸。**本仓当前全部零命中，修复未改变 `keys=35`**——见 Task 2
///   report 与 Task 8 终审 report 的实测输出）：
///   1. **组合糖**：`@autoclosure () -> Bool?` / `@autoclosure () -> Optional<Bool>` /
///      `@autoclosure () -> (Bool)?` —— 裁决 (b″) 与 `Bool?` 裁决**各自成立、组合漏了**；
///      修法：autoclosure 返回位改成**递归调用** `classifyBoolParameterType` 自身，
///      不再对返回位单独手写「剥括号后精确比较」。
///   2. **specifier 无空格**：`consuming(Bool)` / `borrowing(Bool)` —— 原匹配强制要求
///      specifier 后随空格；修法：specifier 后随空格**或** `(` 均可剥离（下一字符只能是
///      这两者之一的白名单，防误撞真实标识符前缀）。
///   3. **attribute 无空格（含粘连兄弟形态，Task 2 评审第 2 轮 Important-1 补 +
///      Task 8 终审 Important-2 补）**：
///      `@autoclosure() -> Bool` —— 原实现按空白终止切出 `"@autoclosure()"` ≠
///      `"@autoclosure"`；修法：识别出粘连的空 `()` 属于后面函数类型的参数表（不是
///      attribute 实参），只消费 attribute 名本身，把 `()` 留给 `sawAutoclosure`
///      分支按 `"() -> Bool"` 认。⚠️ **这一修法本身在离已修样例一个空格处就失效并
///      劣化到最黑一类**：`@autoclosure()->Bool`（箭头也无空格）全串无空白，
///      `prefix(while:)` 切出**整串**当 attribute 吞掉，`t` 被清空、`sawAutoclosure`
///      未置位，落 `.notBool`——命中/清点/留痕三层同时看不见，比这里落 `.boolCarrying`
///      的其余残余更黑。追加修法：`hasPrefix("@autoclosure()")`（**必须**带闭合括号）
///      单独识别这个粘连兄弟形态。
///      ⚠️ **`@autoclosure( )->Bool`（括号内有空格）不是「不同类、正确落
///      `.boolCarrying`」——这是 Task 8 终审 Important-2 抓到的一处裁决层错误**：
///      按裁决 (b″) 判命中的两条理由（「零成本改写就开免豁免通道」「调用点仍是一个
///      Bool 参数」）对它逐字成立，与已判 `.plainBool` 的 `@autoclosure() -> Bool`
///      只差括号里一个空格，注释此前给的区分理由是纯**词法**的（`prefix(while:)`
///      在哪截停），不是裁决层面的——是「绿得理由不对」的镜像：新块写反了旧句。
///      修法：`(` 与下一个 `)` 之间若确实**只有空白**（不要求紧邻无空格），同样只
///      消费 attribute 名本身、把 `"(...)"`（含内部空白）留给 `sawAutoclosure`
///      分支去认——与 `hasPrefix("@autoclosure()")` 分支同一手法，只是改成先找到
///      匹配的 `)` 再校验中间是否全空白，不再要求 `(` 后紧邻 `)`。**不能只写
///      `hasPrefix("@autoclosure(")`**（少一个闭合括号）：那会把本条与
///      `@autoclosure(x)->Bool` 这类假想的、真的带参数内容的形态（若未来出现）混为
///      一谈，见下方代码里该分支的注释。
///   4. **标点周围空白**：`Swift . Bool` / `Optional <Bool>` —— 原 `normalizeWhitespace`
///      只收敛空白**串**、不消除 `.` 与 `<`/`>` 周围的空白；修法：折叠后再收紧这三个
///      标点两侧的空白，因为在函数顶部执行、每次递归调用都会重跑，泛型实参位的复现
///      形态（`Optional<Swift . Bool>`）随之一并覆盖，不需要单独处理。
///   5. **specifier 白名单遗漏的下一个 token（Task 8 终审 Important-1）**：`_const Bool`
///      ——`_const` 是与 `borrowing`/`consuming`/`sending` 同族的 ownership/compile-time
///      specifier（Embedded Swift），原白名单 `["inout", "borrowing", "consuming",
///      "sending", "__owned", "__shared"]` 没列到它，`public init(flag: _const Bool)`
///      的调用点 `A(flag: true)` 逐字不变、`swiftc -typecheck` 零诊断，不剥的话滑进
///      `\bBool\b` 兜底判成 `.boolCarrying`（清点、不判违规）⇒ 免豁免逃逸。
///      ⚠️ **补充事实，加强而非削弱其严重性**：`_const` 会强制调用点**只能传字面量**
///      （`A(flag: x)` 报「expect a compile-time constant literal」），把这个 API
///      钉死成「只能写 `f(flag: true)`」——这正是公约要治的「换皮成本几乎为零」的
///      Bool 旋钮形态，甚至比 `consuming`/`sending` 更彻底地排除了非字面量调用。
///      修法：把 `"_const"` 并入 specifier 白名单，剥法与其余非 `inout` specifier
///      相同（单向，剥完判 `.plainBool`）。**这条修复本身不使 specifier 通道穷尽**
///      ——见上方「specifier 白名单是开放集」，下一个 token（无论是未来的语言提案还是
///      又一个下划线前缀标注）大概率还是要靠撞见才会被发现，不是本条修复能预先堵死的。
///   6. **effects 位夹在 `()` 与 `->` 之间，autoclosure 返回位前缀匹配失效（Task 8 终审
///      第 3 轮 Important-1，第十一处定义域盲区；只留痕、不修复）**：`@autoclosure ()
///      throws -> Bool` / `@autoclosure () async -> Bool` / `@autoclosure () async
///      throws -> Bool` / `@autoclosure () throws(E) -> Bool` / `@autoclosure() throws
///      -> Bool` / `@autoclosure () throws -> Bool?` —— `sawAutoclosure` 分支去空白后
///      只认 `normalized.hasPrefix("()->")`，`throws` / `async` / `throws(E)` 夹在
///      `()` 与 `->` 之间时前缀匹配直接失败，落 `.boolCarrying`，与组 1–5 同款免豁免
///      逃逸：`swiftc -typecheck -swift-version 6` 对
///      `public struct Probe { public init(flag: @autoclosure () throws -> Bool)
///      rethrows { _ = try flag() } }` 零诊断，调用点 `Probe(flag: true)` 合法
///      （编译器甚至提示 `try Probe(flag: true)` 里的 `try` 多余）。
///      ⚠️ **不适用上方「specifier 白名单是开放集」的论证**——effects 位不是「工具链
///      单方面扩张的开放 token 集」：语法上只有 `async` / `throws` / `throws(T)`
///      **三种**（`rethrows` 不能出现在函数**类型**里），是**封闭集**，可以由构造
///      （吃 `TypeSyntax` 而非在摊平字符串上重造词法，见下文「为什么撤回『穷尽』」
///      段落推荐的重构）一次性关掉；用开放集论证覆盖这一条会是一次「**绿得理由
///      不对**」。
///      ⚠️ **比组 5 的 `_const` 更该修**：`@autoclosure () throws -> Bool` 是 Swift 里
///      Bool-autoclosure 的**教科书写法**（`assert` / `precondition` /
///      `XCTAssertTrue` 全是这个声明），比 `_const`（Embedded Swift 边角）或
///      `@autoclosure( )`（括号加空格，根本没人这样写）都更可能被真人写出来。
///      **本仓当前零命中**；修法（剥 `throws` / `async` / `throws(E)`，或走
///      `TypeSyntax` 重构）**移交 #41/#43，本轮不改实现**。
///
///   另外**折入**（不算独立残余组，是 Task 2 补的一族别名）：`Swift.CBool`
///   （stdlib `typealias CBool = Bool`，与 `Bool`/`Swift.Bool` 同属一个类型的不同拼法）
///   现与 `Bool`/`Swift.Bool` 一起精确比较判 `.plainBool`。`ObjCBool` / `DarwinBoolean`
///   是独立的 `ExpressibleByBooleanLiteral` 类型（不是 `Bool` 的别名），并入需要新裁决，
///   **只在 `PublicBoolParamCollector` 类文档的「已知盲区」留痕，未做机器拦截**
///   （本仓零使用）。
///
///   ⚠️ **修复之后仍然不宣称穷尽**——上面 6 组里，组 1–5 是「已撞见并修复」，组 6 是
///   「已撞见、已留痕、代码修复移交 #41/#43」，两者都不是「所有残余的完整清单」；
///   下一组残余大概率还是靠撞见，不是靠推导发现。**这条本身就是三轮反例
///   教训的应用**，不要因为这一轮修完了就把措辞改回「穷尽」。
///
///   ⚠️ **为什么撤回「穷尽」这个措辞**：本分类器在 `trimmedDescription` **摊平后的字符串**
///   上**重造词法/语法分析**，而「token × trivia 的摆放位置」是**乘积**级自由度——只能
///   靠逐个撞见来枚举，三轮连续被证伪就是经验证据。**全称量词本身是反例制造机。**
///   真正的收敛修法是让分类器直接吃 `TypeSyntax` 节点（采集器手里本来就有，见下方
///   `visit` 各处拿到节点后立刻摊平的位置）：括号（单元素 `TupleType`）、
///   specifier / attribute（`AttributedType` 的结构字段）、Optional 糖（`OptionalType` /
///   泛型实参）、成员类型、trivia、反引号在**结构层天然消解**，穷尽性**由构造保证**而非
///   由宣称。该重构超出本 plan 定稿范围，作为 Suggestion 记在此处。
/// - (ii) **声明位置搬家**：`init` / `func` / `subscript` / `enum case` / protocol
///   requirement 已采（裁决 (e)），宏展开 / attribute 已留痕（见类文档「已知盲区」）。
/// - (iii) **名字解析间接层**：`typealias`（裁决 (f)）已清点 + 空断言，泛型洗 Bool
///   已留痕。
///
/// 剥法：`//` 剥到行尾（行终止符集合是 `{'\n', '\r'}`——Swift 词法把 lone `\r` 也当
/// 换行，只认 `\n` 会把 `\r` 连同其后字符一起吞掉，Task 1 评审第 4 轮 Important-1）；
/// `/* … */` **必须按深度计数扫描，不能用非贪婪正则**
/// （`/\*.*?\*/` 在 `/* a /* b */ c */` 这类合法的嵌套块注释里会在内层 `*/` 提前闭合，
/// 剩下 ` c */` 污染结果）。每处注释替换成**单个空格**，避免把注释两侧的 token 意外
/// 粘连（`consuming/*x*/Bool` 不能剥成 `consumingBool`）。
///
/// ⚠️ **已知留痕，不做机器拦截（Task 1 评审第 4 轮 Suggestion-1/2）**：
/// - **不识别字符串字面量**：类型位置唯一合法的字符串字面量出现在
///   `@convention(c, cType: "…")` 实参里，串内若含 `/*` 会被本函数误当块注释起点剥掉。
///   失败方向是 **fail-closed（安全）**：误剥导致文本对不上 `Bool`，落 `.boolCarrying`
///   兜底（清点、不放行），不会把非命中误判成命中；本仓当前该 attribute 零使用。
/// - **不处理未闭合的 `/*`**：这种输入只能来自解析失败的源码——`scanBoolParams(root:)`
///   已经在 `tree.hasError` 那道检查上拦截了这种情况（见该函数文档），本函数不需要
///   自己再判一次；方向同样是 fail-closed，不是盲区。
/// ⚠️ **#40 复用点**：本函数与 `normalizeWhitespace` / `isRedundantOuterParen` /
/// `optionalGenericArgument` 由 `private` 放开为 internal，供
/// `ComponentJudgeScanner.swift` 的 `classifyTextParameterType` 复用同一套剥离规则
/// ——FR-4 面对的类型文本自由度与 J-1 同源，重写一份等于把这里 5 组已撞见并修复的
/// 残余（组合糖 / specifier 无空格 / attribute 无空格 / 标点周围空白 / `_const`）
/// 在另一个文件里从零再撞一遍。
nonisolated func stripComments(_ t: String) -> String {
    let chars = Array(t)
    var result = ""
    result.reserveCapacity(chars.count)
    var i = 0
    var depth = 0
    while i < chars.count {
        if depth > 0 {
            if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                depth += 1
                i += 2
            } else if chars[i] == "*", i + 1 < chars.count, chars[i + 1] == "/" {
                depth -= 1
                i += 2
                if depth == 0 { result.append(" ") }
            } else {
                i += 1
            }
            continue
        }
        if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "*" {
            depth = 1
            i += 2
            continue
        }
        if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "/" {
            // ⚠️ **终止符必须同时认 `\n` 与 `\r`**（Task 1 评审第 4 轮 Important-1）：
            // Swift 词法把 lone `\r` 也当行终止符，只认 `\n` 会把 `\r` 及其后所有字符
            // 当成注释内容一并吞掉——`(Bool // c\r)` 会把 `\r)` 也吃掉，剩下的文本再也
            // 凑不出 `Bool`，落进兜底判成 `.boolCarrying` ⇒ 免豁免逃逸（fail-open）。
            while i < chars.count, chars[i] != "\n", chars[i] != "\r" { i += 1 }
            result.append(" ")
            continue
        }
        result.append(chars[i])
        i += 1
    }
    return result
}

/// 把 `stripComments` 留下的空白（含注释替换出的空格、括号内合法的换行）归一化成
/// 单个空格再首尾 trim。⚠️ 不能省略这一步：下游多处用 `.whitespaces`（**不含换行**）
/// 做局部 trim（例如剥外层括号那一步），注释剥离后若残留内嵌换行会让那些 trim 漏剥，
/// 逐字比较假阴性。
nonisolated func normalizeWhitespace(_ t: String) -> String {
    let collapsed = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    // ⚠️ **Task 2 前置修复：残余组 4（标点周围空白）**——上面的折叠只收敛空白**串**，
    // 不消除空白**位置**：`Swift . Bool` 折叠后仍是 `"Swift . Bool"`，逐字不等于
    // `"Swift.Bool"`；`Optional <Bool>` 同理不等于 `Optional<Bool>` 前缀。两者调用点
    // 都与 `f(flag: true)` 逐字相同 ⇒ 免豁免逃逸。这里额外收紧 `.` / `<` / `>` 两侧的
    // 空白（不含 `,`——逗号两侧空白不影响元组 vs. 非元组的判定，不需要动）。
    // ⇒ **最外层全串收紧已覆盖，递归重跑是第二道**（Task 2 评审第 2 轮 Suggestion）：
    // 本函数在 `classifyBoolParameterType` 顶部对**整个传入字符串**先执行一次，
    // `Optional<Swift . Bool>` 这类泛型实参位的复现形态在**递归发生之前**、对全串的
    // 那一次调用里就已经被收紧；本函数对**每次递归调用**都会重新执行只是第二道保险，
    // 不需要在 `optionalGenericArgument` 那一层单独处理。
    return collapsed.replacingOccurrences(
        of: #"\s*([.<>])\s*"#, with: "$1", options: .regularExpression
    )
}

// MARK: - 类型文本剥离层（Task 1 抽出，#40 复用）/ Type-text stripping layer

/// 类型文本剥掉「装饰层」（注释 / 空白 / 反引号 / specifier / attribute）之后的结果。
///
/// ⚠️ **抽出的唯一目的是复用，不是重构口味**：`classifyBoolParameterType` 与
/// `classifyTextParameterType`（`ComponentJudgeScanner.swift`）面对的是**同一个**
/// 「token × trivia 摆放位置」的乘积空间；两份实现必然漂移，而本 epic 已经有 8 次以上
/// 「加了新块、没改旧句」的实例。`sawInout` / `sawAutoclosure` 作为**结果字段**返回，
/// 是因为两个调用方对它们的裁决不同：J-1 的 `inout Bool` 是双向通道（`.boolCarrying`），
/// FR-4 的 `@autoclosure () -> String` 与 `(Item) -> String` 同属「文本经此进入组件」。
struct StrippedTypeText: Equatable, Sendable {
    let text: String
    let sawInout: Bool
    let sawAutoclosure: Bool
}

nonisolated func stripTypeDecorations(_ raw: String) -> StrippedTypeText {
    // ⚠️ **反引号转义标识符必须全局剥除**（Task 1 评审第 4 轮 Important-2）：
    // `` `Bool` `` 是 `Bool` 的合法拼法（反引号只用来给标识符转义关键字冲突，不改变
    // 标识符本身），`func f(flag: `Bool`)` 的调用点与 `f(flag: true)` 逐字相同——比
    // 括号（裁决 (b‴)）还便宜的免豁免逃逸：`` "`Bool`" `` ≠ `"Bool"`，不剥的话滑进
    // `\bBool\b` 兜底判成 `.boolCarrying`。类型文本里反引号只包裹标识符，全局删除
    // 是安全的；`` Optional<`Bool`> ``、`` Swift.`Bool` `` 等组合由既有的 Optional
    // 递归分类自然覆盖，不必单独枚举。
    var t = normalizeWhitespace(stripComments(raw)).replacingOccurrences(of: "`", with: "")
    var sawInout = false
    var sawAutoclosure = false
    // 1) 剥 specifier 与 attribute。两者可以交替出现（`borrowing @Sendable …`），
    //    所以放在同一个循环里剥到剥不动为止。
    //    `inout` 与 `@autoclosure` 各自单独裁决。
    while true {
        var stripped = false
        for specifier in ["inout", "borrowing", "consuming", "sending", "__owned", "__shared", "_const"]
        where t.hasPrefix(specifier) {
            let rest = t.dropFirst(specifier.count)
            guard let next = rest.first, next == " " || next == "(" else { continue }
            if specifier == "inout" { sawInout = true }
            t = String(rest).trimmingCharacters(in: .whitespaces)
            stripped = true
            break
        }
        if !stripped, t.hasPrefix("@") {
            let attribute = String(t.prefix(while: { !$0.isWhitespace }))
            let attributeName: String
            if attribute.hasSuffix("()") {
                attributeName = String(attribute.dropLast(2))
            } else if attribute.hasPrefix("@autoclosure()") {
                attributeName = "@autoclosure"
            } else if attribute == "@autoclosure(",
                let closeParen = t.dropFirst(attribute.count).firstIndex(of: ")"),
                t.dropFirst(attribute.count)[..<closeParen].allSatisfy(\.isWhitespace) {
                // ⚠️ **`@autoclosure( )->Bool`（括号内有空格）不是「不同类，正确落
                // `.boolCarrying`」**——按裁决 (b″) 判命中的两条理由（零成本改写 + 调用点
                // 仍是一个 Bool 参数）对它逐字成立，与已判 `.plainBool` 的
                // `@autoclosure() -> Bool` 只差括号里一个空格，此前的区分理由是纯词法的
                // （`prefix(while:)` 在哪截停），不是裁决层面的（Task 8 终审 Important-2）。
                // `attribute` 在这种输入下恰好等于未闭合的 `"@autoclosure("`（空白截断了
                // `prefix(while:)`），真正的 `)` 还在 `t` 剩余部分里——上面已经往后找到
                // 它并校验中间只有空白（`@autoclosure` 不接受参数，非空白内容不是这个
                // 形态），与 `hasPrefix("@autoclosure()")` 分支一样只消费 attribute 名
                // 本身（不含 `(`），把 `"(...)"` 原样留给**调用方的** `sawAutoclosure` 裁决
                // 分支去认（抽取后该分支不在本函数内；且 `StrippedTypeText` 已预告会有
                // 第二个裁决不同的消费方，故不用「下面的分支」这种单数方位指称）。
                // ⚠️ **不能只写 `hasPrefix("@autoclosure(")`**（少一个闭合括号）：那会把
                // 本条与 `@autoclosure(x)->Bool` 这类假想的、真的带参数内容的形态
                // （若未来出现）混为一谈，所以这里显式要求闭合括号存在、且括号内容全为
                // 空白，两个条件缺一不可。
                attributeName = "@autoclosure"
            } else {
                attributeName = attribute
            }
            if attributeName == "@autoclosure" {
                sawAutoclosure = true
                t = String(t.dropFirst(attributeName.count)).trimmingCharacters(in: .whitespaces)
            } else {
                t = String(t.dropFirst(attribute.count)).trimmingCharacters(in: .whitespaces)
            }
            stripped = true   // `t` 严格变短 ⇒ 循环必然终止
        }
        if !stripped { break }
    }
    return StrippedTypeText(text: t, sawInout: sawInout, sawAutoclosure: sawAutoclosure)
}

/// 交替剥 Optional 语法糖（`?` / `!`）与「多余」的外层括号，剥到剥不动为止。
/// ⚠️ 顺序不能固定死：`(Bool)?` 要先剥 `?` 再剥括号，`(Bool?)` 反过来，`((Bool))`
/// 要剥两层；元组的外层括号由 `isRedundantOuterParen` 挡住，不会被误剥。
/// ⚠️ **只剥最外层**——泛型实参位（`Optional<(Bool)>`）留给调用方的递归分类处理。
/// ⚠️ **前置条件：输入须为 `stripTypeDecorations(_:).text`**（已归一化空白、剥掉注释与
/// 反引号、首尾无空白，Task 1 评审 Minor-3）：`isRedundantOuterParen` 用
/// `hasPrefix("(")` 判定是否要剥括号，带前导空白或内嵌注释的原始类型文本会**静默剥
/// 不动**（原样返回，不报错、不 crash）——不是「大多数情况能用，边角报错」，是「不满足
/// 前置条件时悄悄不生效」。当前唯一调用方 `classifyBoolParameterType` 满足这个前置
/// 条件；本函数是 #40 Task 1 新建的（不是「放开」既有 private 函数——放开的是另外 4 个
/// 辅助函数），默认 internal，供 `ComponentJudgeScanner.swift` 复用（见
/// `stripComments` 文档「#40 复用点」），新增调用方前必须先过 `stripTypeDecorations`。
nonisolated func stripOptionalSugarAndRedundantParens(_ raw: String) -> String {
    var t = raw
    while true {
        var stripped = false
        while t.hasSuffix("?") || t.hasSuffix("!") {
            t.removeLast()
            t = t.trimmingCharacters(in: .whitespaces)
            stripped = true
        }
        if isRedundantOuterParen(t) {
            t = String(t.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            stripped = true
        }
        if !stripped { break }
    }
    return t
}

nonisolated func classifyBoolParameterType(_ raw: String) -> BoolParamKind {
    // 1) 剥 specifier 与 attribute（含注释 / 空白 / 反引号）——见 `stripTypeDecorations`。
    let stripped = stripTypeDecorations(raw)
    var t = stripped.text
    if stripped.sawInout {
        // ⚠️ 裁决 (b′)：`inout Bool` 是双向状态通道，归 .boolCarrying；
        // `inout Cache` 这类非 Bool 仍要落到下面的 .notBool。
        return t.range(of: #"\bBool\b"#, options: .regularExpression) != nil ? .boolCarrying : .notBool
    }
    if stripped.sawAutoclosure {
        // ⚠️ 裁决 (b″)：`@autoclosure () -> Bool` 的调用点与 `flag: Bool` 逐字相同
        // ⇒ 与 `consuming Bool` 同类，判命中。空白写法不唯一，先归一化再比。
        //
        // ⚠️ **返回位同样要剥括号**（Task 1 评审第 2 轮 Important-B）：
        // `@autoclosure () -> (Bool)` 去空白后是 `"()->(Bool)"`，逐字不等于 `"()->Bool"`
        // ——不剥的话又是一条免豁免逃逸，与裁决 (b‴) 判 `(Bool)` 命中的理由完全同源。
        //
        // ⚠️ **Task 2 前置修复：残余组 1（组合糖）**——`@autoclosure () -> Bool?` /
        // `@autoclosure () -> Optional<Bool>` / `@autoclosure () -> (Bool)?` 原先只
        // 精确比较 `returnType == "Bool"`，裁决 (b″) 与 `Bool?` 裁决各自成立、组合漏了。
        // 修法：返回位改成**递归调用 `classifyBoolParameterType` 自身**，而不是继续
        // 手写「剥括号再精确比较」——返回位本质上就是一个普通的类型文本，`Bool?` /
        // `Optional<Bool>` / `(Bool)?` 这些形态在顶层已经被递归分类覆盖，不需要在这里
        // 重新枚举一遍。
        let normalized = t.replacingOccurrences(of: " ", with: "")
        if normalized.hasPrefix("()->") {
            let returnType = String(normalized.dropFirst(4))
            if classifyBoolParameterType(returnType) == .plainBool { return .plainBool }
        }
    }

    // 2) 剥 Optional 语法糖与「多余」的外层括号——见 `stripOptionalSugarAndRedundantParens`。
    t = stripOptionalSugarAndRedundantParens(t)
    // ⚠️ **Task 2 前置修复：跨模块 Bool 别名族——`Swift.CBool`**（`typealias CBool = Bool`
    // 是 stdlib 自带的别名，`flag: CBool` + 调用点 `f(flag: true)` 零成本，而裁决 (f) 的
    // 空断言（`publicBoolTypeAliases`）只清点**本仓声明**的 alias，管不到 stdlib 里已经
    // 定义好的这一个）。`CBool` 就是 `Bool` 本身（不是包一层的独立名义类型），并进这里的
    // 精确拼法等价类，不需要单独的裁决分支。
    // ⚠️ **`ObjCBool` / `DarwinBoolean` 不在此列**——它们是 `ExpressibleByBooleanLiteral`
    // 的独立类型（不是 `Bool` 的别名），调用点同样能写 `true`，但把它们并入 `.plainBool`
    // 需要新的裁决（它们不是「同一个类型的另一种拼法」）。本仓当前零使用，先留痕在这里，
    // 不做机器拦截——与 `PublicBoolParamCollector` 类文档「已知盲区」的其余条目同族。
    if t == "Bool" || t == "Swift.Bool" || t == "CBool" || t == "Swift.CBool" { return .plainBool }
    // ⚠️ **`Optional<T>` 结构化递归分类，不是枚举穷尽拼法**（Task 1 评审第 2 轮
    // Important-B）：真实形态空间是「`Optional`/`Swift.Optional` × `Bool`/`Swift.Bool`
    // × 括号 × 空白」的乘积——`Optional<(Bool)>`、`Optional< Bool >` 都曾滑过旧的
    // 四条精确字符串枚举。改成剥掉 `Optional<...>` 外壳后对泛型实参**递归**调用本函数：
    // 只有实参本身判 `.plainBool`（递归会自己剥实参里的括号/空白/specifier），整个
    // `Optional<T>` 才判 `.plainBool`；`Optional<(Bool, Int)>` 这类元组实参递归后落
    // `.boolCarrying`（裁决 (b‴) 判元组不剥），不会被误判成 `.plainBool`。
    // ⚠️ **递归天然收敛、不会爆栈**：`optionalGenericArgument` 每层至少剥掉
    // `"Optional<"` 与 `">"` 共 10 个字符，字符串严格变短，`Optional<Optional<Bool>>`
    // 这类嵌套最多递归到嵌套层数就必然触底（不匹配 `Optional<...>` 外壳或匹配到
    // `"Bool"`），没有环、没有无界增长。
    if let genericArgument = optionalGenericArgument(t),
        classifyBoolParameterType(genericArgument) == .plainBool {
        return .plainBool
    }
    // `\bBool\b` 的词边界保证 `MyBool` / `Boolish` 不误命中。
    if t.range(of: #"\bBool\b"#, options: .regularExpression) != nil { return .boolCarrying }
    return .notBool
}

/// 剥 `Optional<...>` / `Swift.Optional<...>` 外壳，返回泛型实参原文（未 trim，
/// 交给递归调用的 `classifyBoolParameterType` 自己 trim）。不是外壳则返回 `nil`。
///
/// ⚠️ 用「前缀 + 末字符」直接切片，不是正则或括号计数：`Optional<T>` 只有一个泛型实参，
/// 整段文本来自 `trimmedDescription`（保证语法上是良构的），实参本身含嵌套泛型
/// （`Optional<Binding<Bool>>`）时第一个 `<` 与最后一个 `>` 确实互相配对，不需要额外
/// 配平。
/// **这个「配对」宣称对 `Optional<X>.Y<Z>` 这类成员类型文本不成立**（Task 1 评审第 3 轮
/// Suggestion-2）——`t.hasSuffix(">")` 会先失败（结尾是成员类型的 `>`，不是外壳的），
/// 万一某种拼法凑巧仍以 `>` 结尾，切出的实参也会包含多余的 `.Y<Z` 尾巴。**误配对时
/// 失败方向是安全的**：切歪的实参递归分类不到 `Bool`，落 `.boolCarrying` 兜底
/// （清点、不放行），不会把非命中误判成 `.plainBool`。
nonisolated func optionalGenericArgument(_ t: String) -> String? {
    for prefix in ["Optional<", "Swift.Optional<"] where t.hasPrefix(prefix) && t.hasSuffix(">") {
        let start = t.index(t.startIndex, offsetBy: prefix.count)
        let end = t.index(before: t.endIndex)
        guard start <= end else { continue }
        return String(t[start..<end])
    }
    return nil
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
/// - 宏展开产物看不见：`visit(_:MacroExpansionDeclSyntax)` **与**
///   `visit(_:MacroExpansionExprSyntax)` 都直接 `.skipChildren`（目的是跳过
///   `#Preview`——它在文件顶层实际落在 expr 语法节点，只跳 decl 侧堵不住，两处都要跳；
///   见那两处的注释）。代价是任何生成 public 声明的宏都会被漏采（本仓当前没有这类宏）。
///   `MacroDeclSyntax`（`public macro f(flag: Bool)` 的**声明**侧）同样没访问
///   ——本包没有 macro target，加上这一句只为留痕。
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
/// - **`package` 访问级未建模**（Task 1 评审 Minor-1）：`Self.access(_:)` 只认
///   `public`/`open`/`private`/`fileprivate`/`internal` 五种，`package` 修饰符落进
///   「无显式修饰符」那一支。方向是 **fail-closed（多报，不是漏报）**：
///   `public extension X { package func f(flag: Bool) {} }` 里的 `f` 语义上是
///   `package`（比 `public` 更窄），但会被当成继承 extension 的默认 `public` 而**多**报
///   一条——后果是有人被迫来核实一条本不该报的条目，不是漏网。本仓当前 `package` 修饰符
///   零使用，先留痕，不做机器拦截；若后续引入 `package`，再补一个 `isPackage` 分支重新裁决。
/// - **`associatedtype` 默认值洗 Bool 未留痕**（Task 1 评审第 3 轮 Suggestion-1）：
///   `public protocol P { associatedtype F = Bool; init(flag: F) }` 的 requirement
///   参数文本是 `"F"` ⇒ `.notBool`，且 `AssociatedTypeDeclSyntax` 不进
///   `publicBoolTypeAliases`——与上面「泛型洗 Bool 判不了」同族（纯语法解不了名字）。
///   不是独立的机器拦截缺口：本仓侧 conformer 仍要写出具体的 `public init(flag: Bool)`
///   才能满足 requirement，那条会被正常采到；这里只留痕，与 `typealias`（裁决 (f)）
///   条目呼应，不单独扩展扫描器。
/// - **`ObjCBool` / `DarwinBoolean` 未折入 `.plainBool`**（Task 2 前置修复留痕）：
///   两者都是 `ExpressibleByBooleanLiteral` 的独立具名类型（不是 `Bool` 的别名），
///   `flag: ObjCBool` + 调用点 `f(flag: true)` 一样零成本编译，但把它们并入
///   `.plainBool` 是与 `Swift.CBool`（本仓已折入，见 `classifyBoolParameterType` 里
///   `"CBool"` / `"Swift.CBool"` 那两个精确比较分支）不同性质的裁决——`CBool` 与 `Bool`
///   是**同一个类型**的不同拼法，`ObjCBool`/`DarwinBoolean` 是**不同类型**只是字面量可转换。
///   本仓当前两者均零使用，先留痕不做机器拦截；若后续出现真实用例，需要单独裁决是否
///   以及如何把这类「非别名但可转换」的类型并入判据。
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

    /// ⚠️ **`#Preview` 在文件顶层实际解析成 `MacroExpansionExprSyntax`，不是
    /// `MacroExpansionDeclSyntax`**（Task 1 评审 Important-1 补：给合成输入的 `#Preview`
    /// 体塞进一个必然入账的声明后现场抓到——`swiftc -typecheck` 的语法树在顶层把
    /// `#Preview("x") { … }` 落在 expr 侧，不是 decl 侧）。上面那条 `MacroExpansionDeclSyntax`
    /// 的 `.skipChildren` 对**真实源码里的 `#Preview`** 从未生效过：旧的合成测试因为
    /// `#Preview` 体内没有放任何可采集声明，这个洞被完全遮住了，测试照绿。
    /// 这里补上对称处理——两种宏展开语法节点都跳过，`#Preview` 才真的被挡住。
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

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
