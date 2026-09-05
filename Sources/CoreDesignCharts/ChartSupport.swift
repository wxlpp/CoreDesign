//
//  ChartSupport.swift
//  CoreDesignCharts
//
//  四个图表的公共约定 / Shared conventions for the four charts.
//

import CoreDesign
import SwiftUI

// MARK: - ⚠️ 本 target 的三条硬约束（写新图表前必读）

// 1. **不 `import Charts`**。本 target 只收容 Swift Charts **原生画不出来**的四类：
//    雷达图 / 活动环 / 贡献热力图 / 力导向网络图。line / bar / area / point / sector
//    原生已支持，重造它们的换皮是本 target 明确的 Non-Goal。
//
// 2. **退化输入是一等契约，不是边角**（FR-19）。力导向布局节点重合会 NaN、雷达图轴值
//    全等会除零——这是图表类组件最常见的 crash 源。每个图表都必须对空数组、单点、
//    以及自己特有的退化形态有**定义好的行为**（渲染空态 / 忽略该点），并有测试。
//
// 3. **超限行为固定为「截断 + 降级 + 文档」，不得抛断言**（FR-20）。
//    库代码对数据规模 `precondition` / `fatalError` 就是让宿主 App crash。

// MARK: - ChartValue

/// 图表数据点的最小契约。
///
/// ⚠️ **调用方传入的标签是「内容」不是「UI 文案」**——不强制 `LocalizedStringResource`
/// （FR-7 的边界声明）。轴标题这类**组件自带**的 chrome 文案才走本地化类型。
///
/// ⚠️ **`Sendable` 的实际代价（本仓第三次撞到，写在这里免得第四次）**：
/// 在**同样设了 `defaultIsolation(MainActor)` 的模块**里声明遵从类型，会拿到
/// MainActor 隔离的 `Identifiable` conformance，满足不了 `Sendable`，报
/// `main actor-isolated conformance ... cannot satisfy conformance requirement
/// for a 'Sendable' type parameter`。
/// ⇒ **解法是给该类型标 `nonisolated`**（提到文件作用域不够——该设置作用于整个 target）。
/// ⚠️ **别以为"下游 App 不设 `defaultIsolation`，所以不受影响"**——Xcode 26 的工程模板
/// 默认就写 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，而本库的部署目标正是 iOS 26+
/// ⇒ **下游多半和这里一样**，同一道摩擦会原样出现在调用方的模型类型上。
/// 解法相同：给该类型标 `nonisolated`。
///
/// ⚠️ **为什么仍然要 `Sendable`**：图表的数据入参是**调用方在自己模型层构造的值类型**，
/// 若被 `MainActor` 隔离，下游在后台线程准备数据时就用不了——而那正是
/// `scripts/downstream-probe` 存在的理由。这条约束是**有意的**，不是顺手加的。
public protocol ChartValue: Identifiable, Sendable {
    /// 该点在图表上的显示名。由调用方的模型提供。
    var label: String { get }
    /// 该点的数值。
    var value: Double { get }
}

// MARK: - 另外两个数据契约

// ⚠️ **AC 要求四个图表的数据入参都泛型**（终审 I-7 抓到初版只做了 2 个）：
// `ActivityHeatmap` 与 `NetworkGraph` 曾绑死自带的具体 struct，调用方必须先把自己的
// 模型映射一遍——正是 AC 要避开的形态。与 `ChartValue` 同理，`nonisolated` 不可省。

/// 热力图的一天。
public protocol HeatmapDay: Identifiable, Sendable {
    /// 该格对应的日期。⚠️ 归一化到哪一天由图表按注入的 `Calendar` 决定，调用方不必对齐。
    var date: Date { get }
    /// 该天的计数。
    var count: Int { get }
}

/// 网络图的一个节点。
public protocol GraphNode: Identifiable, Sendable where ID: Hashable & Sendable {
    /// 节点的显示名。
    var label: String { get }
}

/// 网络图的一条边。**以节点 `ID` 相连**，不持有节点本身。
///
/// ⚠️ 指向不存在节点的边会被**静默忽略**（不是错误：调用方常常先删节点后删边）。
public nonisolated struct GraphEdge<ID: Hashable & Sendable>: Sendable, Hashable {
    public let from: ID
    public let to: ID
    public init(from: ID, to: ID) {
        self.from = from
        self.to = to
    }
}

// MARK: - 退化输入

/// 一组数据点的退化形态。**每个图表在渲染前都要过这一关。**
enum ChartDegeneracy: Equatable {

    /// 数据可用。
    case usable
    /// 空数组 —— 渲染空态。
    case empty
    /// 点数不足以构成该图表 —— 附上所需的最小点数。
    ///
    /// ⚠️ **原名 `.singlePoint` 名不副实**（评审 S-2）：`of([1, 2], minimumCount: 3)`
    /// 返回的是它，但那是 **2** 个点；而 `of([5])`（默认 `minimumCount: 1`）返回的
    /// 是 `.flat` 不是它。名字暗示的"恰好一个点"两头都不成立 ⇒ 改成按**缺口**命名。
    case insufficientPoints(needed: Int)
    /// 所有值相等 —— 归一化会除零。
    case flat
    /// 总和为 0 —— 占比类图表会除零。
    ///
    /// ⚠️ **目前没有图表消费它**（评审 C-3 证据 3）：`RingChart` 走的是自己的
    /// `goal` 守卫，从不调用 `ChartDegeneracy`。保留本 case 是因为
    /// `of()` 是通用判定器，**但不得据此声称"RingChart 零总和已覆盖"**——
    /// 那是本轮评审抓到的一处虚假信心。
    case zeroTotal
    /// 含非有限值（`NaN` / `±∞`）—— 归一化与 `ClosedRange` 构造都会炸。
    ///
    /// ⚠️ **这一类是评审 C-4 实测出来的**：`ClosedRange` 拿到 `NaN` 端点会直接
    /// **触发前置条件失败、进程 trap**——而 `NaN <= 0` 为假，普通的
    /// `<= 0` 守卫**拦不住它**。库代码让宿主 App crash 与 FR-20 的原则冲突。
    case nonFinite

    /// ⚠️ **判定顺序有意为之**：空 > 非有限 > 点数不足 > 零总和 > 全等。
    /// 非有限排在很前面，因为它会让后面每一步的算术都失去意义。
    static func of(_ values: [Double], minimumCount: Int = 1) -> Self {
        guard !values.isEmpty else { return .empty }
        guard values.allSatisfy({ $0.isFinite }) else { return .nonFinite }
        // ⚠️ 这里原本还有一行 `guard count >= max(minimumCount, 2) || minimumCount <= 1`，
        // 与下面这句**结果完全等价**（穷举 minimumCount ∈ {1,2,3} 无差异分支）⇒ 已删（评审 S-1）。
        if values.count < minimumCount { return .insufficientPoints(needed: minimumCount) }
        let total = values.reduce(0, +)
        if total == 0 { return .zeroTotal }
        if let first = values.first, values.allSatisfy({ $0 == first }) { return .flat }
        return .usable
    }
}

// MARK: - 本地化

// ⚠️ **本 target 必须自带 `Resources/en.lproj/Localizable.strings` 才拿得到译文**（评审 C-5）。
// 初版**连资源目录都没有** ⇒ `Text(LocalizedStringKey)` 只能落到 `Bundle.main`（宿主 App）
// ⇒ 本包**永远无法为自己的 chrome 文案提供翻译**。
//
// ⚠️ **别把这条写成「没有 `Package.swift` 里的 `resources:` 就没有 `Bundle.module`」**
// ——那句话实测为假（PR #263 Copilot 第 2 轮）。本包设了 `defaultLocalization: "en"`，
// SwiftPM 会**自动**把 `*.lproj` 当本地化资源收进去：把 `CoreDesignCharts` 那行
// `resources: [.process("Resources")]` 删掉、用干净的 scratch path 重新 `swift build`，
// 照样生成 `CoreDesign_CoreDesignCharts.bundle`（内含 `en.lproj/Localizable.strings`）。
// 该行是**显式声明**（将来放非 `.lproj` 资源时不必再想一次），不是必需品——
// 完整理由与同一份实测记在 `Package.swift` 的 `CoreDesignCharts` target 上。
// 真正不可省的是**资源文件本身**与下面 `.chart(_:)` / `chartAXString(_:)` 的 `bundle:` 实参。
//
// 而初版还把中文字面量当默认值，
// 与全库 `defaultLocalization: "en"`、`en.lproj` 为源语言的事实相反——
// `grep -rnE "(LocalizedStringKey|LocalizedStringResource) *= *\"" Sources/CoreDesign`
// 在既有组件上**零命中**，即本仓没有一个组件这么写过。

extension LocalizedStringResource {
    /// 本 target 自带 chrome 文案的唯一入口（公约 §4 **A 类** ⇒ `LocalizedStringResource`）。
    ///
    /// ⚠️ `bundle:` 不能省——省了就回到 `Bundle.main`，等于没做本地化。
    ///
    /// ⚠️⚠️ **上一版把它提为 `public`，理由是一个假二选一**（第 2 轮终审 I-1）。
    /// 当时写的是「要么删掉标题缺省值、要么提 public」——**存在第三条路且是标准做法**：
    /// 把默认实参写成 `nil`（不引用任何 internal 符号），在 init 体内兜底。
    /// 公约自陈「多给扩展点不可逆」，public API 一旦发布删不掉，为一个 `nil` 能绕开的
    /// 约束付不可逆代价是亏的 ⇒ 已降回 `internal`。
    ///
    /// ⚠️ 上一版还写过「这个函数对下游也有用」——**那是错的，而且会让下游静默丢本地化**：
    /// 它把 key 绑死在本 target 的 `Bundle.module`，下游传自己的 key 必然查不到，
    /// 而查不到时 Foundation **原样返回 key、不报错**。
    static func chart(_ key: String.LocalizationValue) -> Self {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

/// a11y 描述符要的是 `String`，不是 `LocalizedStringResource`。
///
/// ⚠️ **这些字面量 `AccessibilityStringLiteralGuard` 抓不到**（评审 C-5）：该守卫
/// (`:139`) 只认 `.accessibility*(` 前缀的调用，`AXChartDescriptor` 系列构造器
/// 不在它的 modifier 列表里 ⇒ **即便 #246 把扫描根多 target 化，这里仍是盲区**。
/// 「等 #246 兜底」在这一项上是失效的记账，故本 target 自己把入口收窄到这一个函数。
func chartAXString(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

// MARK: - 空态

/// 所有图表共用的空态。⚠️ 文案是**组件自带的 chrome** ⇒ 公约 §4 **A 类**
/// ⇒ `LocalizedStringResource`（初版用 `LocalizedStringKey` + 中文字面量，两处都错）。
struct ChartEmptyState: View {
    let message: LocalizedStringResource

    var body: some View {
        Text(self.message)
            // ⚠️ 走 `.coreFont(_:)` 而不是原生 `.font(_:)`（PR #263 Copilot 第 1 轮）：
            // 空态是组件**运行期 chrome**（不是 preview），而全库文字入口统一在
            // `CoreTypography.Token` 上。两者今天取值相同，但 token 才是**唯一改点**。
            .coreFont(.footnote)
            .foregroundStyle(Color.contentTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(Text(self.message))
    }
}

// MARK: - 安全归一化

extension Collection where Element == Double {

    /// 把一组值归一化到 [0, 1]。
    ///
    /// ⚠️ **全等时返回全 0.5 而不是除零**——雷达图轴值全相等是常见输入
    /// （所有维度同分），不是错误，不该 NaN 也不该崩。
    /// ⚠️ **非有限输入是真实的**（评审 C-4 实测）：初版 `[1, .infinity]` 吐
    /// `[0, nan]`、`[1, .nan, 3]` 吐 `[0, nan, 1]`，而本文件开头的硬约束 2 与
    /// FR-19 都写着「不产生 NaN」。⇒ 非有限值**逐个夹到确定值**，且**不参与**
    /// 跨度计算（否则一个 `∞` 会把其余所有点压成 0）。
    ///
    /// 保证：返回的每个元素都是有限值且落在 `[0, 1]`。
    func normalizedSafely() -> [Double] {
        guard !self.isEmpty else { return [] }
        let finite = self.filter { $0.isFinite }
        // 全是非有限值 ⇒ 没有可用跨度，一律居中，不猜。
        guard let low = finite.min(), let high = finite.max() else {
            return self.map { _ in 0.5 }
        }
        let span = high - low
        guard span > 0 else { return self.map { $0.isFinite ? 0.5 : Self.clampNonFinite($0) } }
        return self.map { value in
            guard value.isFinite else { return Self.clampNonFinite(value) }
            return (value - low) / span
        }
    }

    /// `+∞ → 1`、`-∞ → 0`、`NaN → 0.5`。**确定性映射**，不引入随机或就近吸附。
    private static func clampNonFinite(_ value: Double) -> Double {
        if value == .infinity { return 1 }
        if value == -.infinity { return 0 }
        return 0.5          // NaN
    }
}

// MARK: - 区间构造

/// 构造一个**保证合法**的 `ClosedRange<Double>`。
///
/// ⚠️ **这不是防御性编程，是防 trap**（评审 C-4 实测）：`ClosedRange` 的
/// 前置条件在端点为 `NaN` 时**直接让进程 trap**——`0...Double.nan` 拿到的是
/// `_assertionFailure` 栈。而 `AXChartDescriptor` 的数轴要求给 range，
/// 于是「VoiceOver 一请求描述符，宿主 App 就崩」。
/// `NaN <= 0` 为假 ⇒ 调用点那句 `goal <= 0` 守卫**拦不住**。
///
/// ⚠️ **`+ 1` 在大量级上不递增**（第 3 轮 review）：`Double` 在 |x| ≥ 2^53 时
/// ULP ≥ 2 ⇒ `low + 1 == low` ⇒ 上一版那句「保证递增」的兜底本身产出**零宽区间**，
/// 恰恰是本函数存在的理由。`2^53...2^53` 不 trap，但对 `AXChartDescriptor` 是
/// 一条量程为 0 的数轴，VoiceOver 播报的位置全部退化到同一点。
/// ⇒ `+ 1` 失效时改用 `nextUp`（走一个 ULP，**总是**严格递增），
/// 而 `nextUp` 在 `.greatestFiniteMagnitude` 上会溢出成 `.infinity`
/// （端点必须有限，否则 descriptor 又拿到非有限值）⇒ 那一档改为**向下**让出一个
/// ULP。全程无 trap、无 NaN、无 ∞。
func safeRange(_ lower: Double, _ upper: Double) -> ClosedRange<Double> {
    let low = lower.isFinite ? lower : 0
    if upper.isFinite, upper > low { return low...upper }
    // 上界不可用（非有限 / 不大于下界）⇒ 自己造一个严格更大的有限上界。
    guard let high = strictlyAboveFinite(low) else {
        // `low == .greatestFiniteMagnitude`：上方已无有限值可去，改为向下让一个 ULP。
        return low.nextDown...low
    }
    return low...high
}

/// 返回一个**严格大于** `value` 的有限值；`value` 已是最大有限值时返回 `nil`。
///
/// 常规量级仍走 `+ 1`——跨度可读，且与既有取值（例如 `safeRange(0, .nan) == 0...1`）
/// 保持一致；只有 `+ 1` 被浮点舍入吃掉时才退到 `nextUp` 这一个 ULP。
private func strictlyAboveFinite(_ value: Double) -> Double? {
    let stepped = value + 1
    if stepped > value { return stepped }
    let bumped = value.nextUp
    return bumped.isFinite ? bumped : nil
}
