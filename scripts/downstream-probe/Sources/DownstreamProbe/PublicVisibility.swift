import CoreDesign
import CoreDesignCharts
import CoreDesignEffects
import Foundation
import SwiftUI

// MARK: - 公开可见性契约（Issue #94）
//
// 以下符号此前漏写 `public`，下游实测报 `cannot find in scope` /
// `initializer is inaccessible`。库内测试看不见这个问题——它们跑在 target
// 内部，internal 符号一样可达。只有从外部包才能守住这条契约。
//
// 注意本文件与同目录 `NonisolatedUsage.swift` 的分工：那边守**隔离**契约
// （函数全部 `nonisolated`），这边守**可见性**契约。CoreDesign 开了
// `.defaultIsolation(MainActor.self)`，所以这里的函数都得是 `@MainActor`
// ——包括读 `ButtonRoleStyleRole` 的调色板属性。换言之：这三个属性对下游
// **可见但不是 nonisolated 可达的**；若日后需要 nonisolated 可达，那是另一个
// 范围内的改动（给属性标 `nonisolated`），不要在本文件里顺手夹带。

@MainActor
func constructCheckBoxToggleStyle() -> CheckBoxToggleStyle {
    CheckBoxToggleStyle()
}

@MainActor
func constructBorderlessStyle() -> CoreBorderlessButtonStyle {
    let style = CoreBorderlessButtonStyle(role: .danger)
    _ = style.role
    return style
}

@MainActor
func readRolePalette(_ role: ButtonRoleStyleRole) -> [Color] {
    [role.color, role.activeColor, role.disabledColor]
}

// MARK: - 静态访问器与 style 消费路径
//
// 上面三个函数直接构造类型，但下游**实际**走的是访问器与 `.buttonStyle(...)` /
// `.toggleStyle(...)`。A3a 的结论「改名后 `App/` 与 docs 示例无需改动，因为
// `.borderless(role:)` 名称不变」正是靠 `ButtonStyle where Self == ...` 那个
// public extension 成立的——若日后有人把它的 `public` 弄丢，四条 SwiftPM 命令
// 与上面的直接构造都仍然绿，破坏只会在真实下游炸。这两个函数把访问器本身
// 也纳入契约。

@MainActor
func consumeBorderlessAccessor() -> some View {
    Button("borderless") {}
        .buttonStyle(.borderless(role: .danger))
}

@MainActor
func consumeCheckBoxToggleStyle(isOn: Binding<Bool>) -> some View {
    Toggle("checkbox", isOn: isOn)
        .toggleStyle(CheckBoxToggleStyle())
}

// MARK: - CircularGlassButtonStyle 的破坏性类型变更（Issue #96）
//
// `diameter` 从 `CGFloat` 变为 `CGFloat?`（B3e：档位改由 `size` 决定，
// `diameter` 退化为显式覆写通道）。这是**源码级破坏性变更**——下游写
// `let d: CGFloat = style.diameter` 会断。下面用 `guard let` 把这一事实固定进
// probe：日后若改回非 optional，条件绑定会编译失败。

@MainActor
func constructCircularGlass() -> CGFloat {
    let style = CircularGlassButtonStyle(size: .large, diameter: 44)
    // 必须用 `guard let` 而非「返回 `CGFloat?`」——Swift 对 `T` → `T?` 有隐式提升，
    // `return style.diameter` 在 `diameter` 改回非 optional 时**照样编译**，那样
    // 这个关卡就是空的。条件绑定对非 optional 会硬报
    // `initializer for conditional binding must have Optional type`。
    guard let diameter = style.diameter else {
        return CoreControlMetrics.height(for: style.size)
    }
    return diameter
}

// 访问器路径单独覆盖：`circularGlass(diameter:)` 是本任务未改动但公开的 API。
//
// > 必须经 `.buttonStyle(.circularGlass(...))` 的前导点推断来触达，**不能**写
// > `ButtonStyle.circularGlass(diameter:)`——该静态成员定义在
// > `extension ButtonStyle where Self == CircularGlassButtonStyle` 上，经协议
// > 元类型访问会报 `static member 'circularGlass' cannot be used on protocol
// > metatype '(any ButtonStyle).Type'`。
@MainActor
func consumeCircularGlassAccessor() -> some View {
    Button("circular") {}
        .buttonStyle(.circularGlass(diameter: 44))
}

// MARK: - Issue #96 新增的公开面

// `TelegramGlassButtonModifier` 的默认值契约：该类型的 doc 写明「新增参数时
// 务必保持这一契约」——两参数形态必须**永远**能编译。这句承诺此前只是注释，
// 现在由 probe 从外部视角钉住：任何人给 init 加无默认值的参数都会在此失败。
@MainActor
func consumeGlassModifierTwoArgForm() -> some View {
    Text("glass")
        .modifier(TelegramGlassButtonModifier(shape: Capsule(), isPressed: false))
}

// `ButtonRoleStyleRole.resolvedColor` 是 #96 新增的 public 方法，现为三个
// ButtonStyle 三态取色的唯一来源。`readRolePalette` 只覆盖了三个调色板属性。
// 与 `readRolePalette` 同样**必须** `@MainActor`——本次复核实测再确认一次：改成
// `nonisolated` 当场 `error: call to main actor-isolated instance method
// 'resolvedColor(isEnabled:isPressed:)' in a synchronous nonisolated context`，
// 同一次构建里 `color` / `activeColor` / `disabledColor` 另判三条同形态的红。
//
// ⚠️ **但理由不是 `defaultIsolation(MainActor.self)`——上一版这半句实测为假，照录
// 更正**（PR #304 第 2 轮终审 I-3 顺带复核）：`ButtonRoleStyleRole` 自己是
// `public nonisolated enum`，这四个成员的隔离来自它们各自**显式**标的 `@MainActor`
// （`Sources/CoreDesign/Components/Button/ButtonRoleStyleRole.swift:18/34/50/75`）。
// 「**成员级**显式 `@MainActor` 压过**类型级** `nonisolated`」正是下面
// `consumeSkeletonColorTokens` 那条更正里来源 (i) 的边界条件——两处不能混为一谈。
@MainActor
func consumeResolvedColor(_ role: ButtonRoleStyleRole) -> Color {
    role.resolvedColor(isEnabled: true, isPressed: false)
}

// 档位主通道访问器（`circularGlass(size:)`），与逃生舱 `circularGlass(diameter:)`
// 并列覆盖。
@MainActor
func consumeCircularGlassTierAccessor() -> some View {
    Button("tier") {}
        .buttonStyle(.circularGlass(size: .small))
}

// MARK: - SettingsRowMetrics 公开常量（0.6.0，item 2）
//
// ⚠️ **这里原有的 `@MainActor func consumeSettingsRowMetrics()` 已删除，别加回来**
// （PR #304 第 2 轮终审 I-4）。删的理由是它**完全冗余**，不是「用不上了」：
// 它与 `NonisolatedUsage.swift:useSettingsRowMetrics()` 读的是**逐字相同、顺序相同**
// 的同 6 个成员（`iconSquareSize` / `iconTitleGap` / `horizontalPadding` /
// `iconCornerRadius` / `iconAlignedDividerInset` / `textAlignedDividerInset`），
// 且两者同在 `DownstreamProbe` 这**一个**外部 target 里 ⇒ 可见性覆盖 **100% 重叠**：
// `public` 被收回时先炸的就是那一条，这一条提供不了任何增量；而隔离那一侧它还**更弱**
// （`SettingsRowMetrics` 被改回 MainActor 隔离时，`@MainActor` 版本不会红）。
// ⇒ 严格被支配。
//
// ⚠️ 上一版这段注释里那句「两处有意并存、不重叠」与「作为可见性 pin 仍有价值」
// **实测为假**（同上），照录于此。该 pin 的交付物说明与它头上的 F-5 更正记录
// 已并入 `NonisolatedUsage.swift` 的 `useSettingsRowMetrics()`。

// MARK: - Skeleton 取色 token（semi-mobile-components Phase 0 / Issue #161）
//
// `Color.skeletonBase` / `skeletonHighlight` 是 Phase 0 新增的公开取色面，供
// Skeleton（Issue #162）的 shimmer modifier 复用。库内 @testable 测试只能证明
// 「能编译」（internal 也可达），真正的公开可见性护栏在这里——从外部包消费它们，
// 若日后漏写/收回 `public`，四条 SwiftPM 命令仍绿而此处会炸。
//
// ⚠️ **上一版这里写「必须 @MainActor：CoreDesign 开了 `.defaultIsolation(MainActor.self)`，
// 这两个静态计算属性跨模块非 nonisolated 可达（同 ButtonRoleStyleRole 调色板）」
// ——实测为假，照录更正**（PR #304 第 2 轮终审 I-3）：
// · 把 `nonisolated func { [Color.skeletonBase, Color.skeletonHighlight] }` 放进本 target
//   （即跨模块读），`swift build -Xswiftc -warnings-as-errors` **零诊断，Build complete**。
// · 「同 `ButtonRoleStyleRole` 调色板」这个类比是**反的**：同一次构建里那几条
//   （`color` / `activeColor` / `disabledColor` / `resolvedColor`）**全部判红**。
//   两组行为相反，不能互相引证。
//
// ⚠️ **判别式（不再写「当且仅当」——上一版那句实测为假，照录更正）**
// （PR #304 第 3 轮终审 C-1。终审搭了 **11 个跨模块 cell + 9 个模块内对照**；本轮落件时
// 又独立复跑了其中 4 个跨模块 cell（外部类型扩展无标注 / 自有 enum 无标注 /
// 自有类型的 extension 无标注 / 自有 `public nonisolated enum`）与 2 个模块内对照。
// 这是一份**枚举**，不是穷举证明。）
//
// 上一版写的是：「可达 **当且仅当** ① 没有显式隔离标注 **且** ② 声明在一个本模块之外的
// 类型的扩展上」。**① 与 ② 都为假**，两个反例就在本仓树里：
// · 反证 ①：`SettingsRowMetrics`（`Sources/CoreDesign/Components/SettingsRow/SettingsRow.swift:17`）
//   是 `public nonisolated enum` —— 它**有**显式标注、而且**不是**任何扩展 —— 而
//   `NonisolatedUsage.swift:useSettingsRowMetrics()` 跨模块把它 6 个成员逐条读、干净编译。
// · 反证 ②（「extension 这个词选错了」）：本模块**自有类型的 extension** 上的无标注 static
//   计算属性，跨模块判**红**（`error: main actor-isolated static property 'extValue' can not
//   be referenced from a nonisolated context`），而同样自有、只是**不在** extension 上的
//   `SettingsRowMetrics` 判**绿** ⇒ 起作用的不是「是不是 extension」，
//   而是**被扩展的类型来自哪个模块**。
//
// ⇒ 本次观察到的规律：从**外部包的 nonisolated 上下文**可达 ⇔ 该成员**对外呈现为
// nonisolated**。观察到两条来源：
//
//   **(i)** 成员自己显式 `nonisolated`，或其**所属类型**显式 `nonisolated` 且成员没有再
//   标 `@MainActor`（**成员级标注压过类型级**——`ButtonRoleStyleRole` 正是活例：enum 本体
//   是 `public nonisolated`，但四个调色板成员各自显式 `@MainActor` ⇒ 判红，见上面 `:104` 那条）。
//   这条**模块内外都成立**：`SettingsRowMetrics.iconAlignedDividerInset` 从 CoreDesign
//   **模块内**的 `nonisolated func` 读，同样干净编译。
//
//   **(ii)** 成员声明在**另一个模块声明的、本身 nonisolated 的类型**的扩展上
//   （`SwiftUI.Color`、`CoreGraphics.CGFloat`），**且未显式标 `@MainActor`**。
//   `defaultIsolation` 在模块内仍把它推成 MainActor —— 同一个 `Color.specularHighlight`
//   从 CoreDesign **模块内**的 `nonisolated func` 读会硬报
//   `error: main actor-isolated static property 'specularHighlight' can not be referenced
//   from a nonisolated context` —— 但**这份推断没有被序列化进 swiftmodule 接口**，
//   于是下游看到的是 nonisolated。这条**只对下游成立**。
//
// 显式 `@MainActor` 一律红；自有类型（**含其 extension**）无显式 `nonisolated` 一律红，
// 且**模块内外一致**。
// ⇒ static/实例、计算/存储、property/func **都不是**判别项。
//
// ⚠️ 因此上一版那句「**而且这条可达性只对下游成立**」也必须收窄：它对来源 (ii) 成立，
// 对来源 (i) **不成立**（`SettingsRowMetrics` 模块内同样读得到）。来源 (ii) 与
// `NonisolatedUsage.swift` 里 F-2 那条更正（「第 3/4 层色彩 token 跨模块反而 nonisolated
// 可达，MainActor 只在模块内成立」）是**同一个事实的两个方向**。
//
// ⚠️ 这一类的**空间是开放的**：以上只是本次跑到的 cell 里读得出的规律，不排除还有第三条
// 来源（`@preconcurrency` 导入、`@_spi` 等形态本次**没有测**）。别把它当成完备判别式用。
//
// ⇒ 这里的 `@MainActor` **不是「必须」，只是无害**。保留它只因为本函数的交付物是
// 「从外部包消费这两个 token」的可见性 pin，与隔离无关；下面紧邻的
// `consumeSpecularHighlightToken()` 就是同类 token 的**无标注**版本（本包没有开
// `defaultIsolation`，未标注的顶层 func 本身就是 nonisolated 上下文）——它一直是绿的，
// 正是来源 (ii) 的一条既有活证据。
@MainActor
func consumeSkeletonColorTokens() -> [Color] {
    [Color.skeletonBase, Color.skeletonHighlight]
}

/// ⚠️ **新增公开 token 必须在这里被消费**（PR #262 第 3 轮终审 I-2）：本文件
/// `:154-159` 自己写着「下游对新符号**零引用**时，probe 对它们**恒绿**」。
/// `specularHighlight` 落地时漏了这一步 ⇒ 验证清单里的「probe 通过」
/// 对本次唯一新增的公开面**不构成任何证据**。`skeletonBase` / `skeletonHighlight`
/// 当初是两处都补的（probe + 库内可引用性测试），本 token 补齐。
func consumeSpecularHighlightToken() -> Color {
    Color.specularHighlight
}

// MARK: - semi-mobile-components epic 全部新增公开面（Phase 3 / #173）
//
// Phase 1（002–012）10 个组件 + Phase 0 骨架屏取色 token（上面已覆盖）在各自 Issue 里
// 有意不改本文件——173.md AC 明确要求本次统一追加，避免「downstream-probe 构建通过」
// 被误当成「新公开类型的可见性契约已被验证」（下游对新符号零引用时，probe 对它们
// 恒绿，见 #175 Radio 评审 suggestion 5）。以下按组件分节，每节至少覆盖一个公开
// 类型/init 的实际消费路径。

// MARK: RadioGroup / RadioOption（Issue #167）

@MainActor
func consumeRadioGroup() -> some View {
    RadioGroup(
        selection: .constant("basic"),
        options: [
            RadioOption(value: "basic", title: "Basic"),
            RadioOption(value: "pro", title: "Pro"),
        ],
        axis: .horizontal,
        spacing: CoreSpacing.sm
    )
}

// MARK: Skeleton（Issue #162）——占位形状树 + shimmer modifier

@MainActor
func consumeSkeletonShapes() -> some View {
    Skeleton(isLoading: true) {
        HStack {
            SkeletonCircle(diameter: 40)
            SkeletonLine(lineCount: 2)
            SkeletonRect(width: 80, height: 40)
        }
        .skeletonShimmer()
    } content: {
        Text("content")
    }
}

// MARK: Rating（Issue #165）

@MainActor
func consumeRating() -> some View {
    Rating(value: .constant(3.5), count: 5, step: 0.5)
}

// MARK: RatingDisplay（Issue #41 裁决 4b）

@MainActor
func consumeRatingDisplay() -> some View {
    RatingDisplay(value: 3.5, count: 5)
}

// MARK: RatingStyle（Issue #41 裁决 4c）

@MainActor
func consumeRatingStyle() -> some View {
    Rating(value: .constant(3), count: 5).ratingStyle(StarRatingStyle())
}

// MARK: Steps（Issue #163）

@MainActor
func consumeSteps() -> some View {
    Steps(
        items: [StepItem(title: "Cart", description: "Review", isError: false)],
        currentIndex: 0,
        axis: .vertical,
        indicatorStyle: .numbered
    )
}

// MARK: Timeline（Issue #164）——两个 designated init 都需覆盖

@MainActor
func consumeTimeline() -> some View {
    Timeline(items: [
        TimelineItem(status: .success) { Text("默认圆点节点") },
        TimelineItem(status: .info) {
            Image(systemName: "star")
        } content: {
            Text("自定义节点")
        },
    ])
}

// MARK: PinCode（Issue #166）

@MainActor
func consumePinCode() -> some View {
    PinCode(value: .constant("123"), length: 6, isSecure: true, onComplete: { _ in })
}

// MARK: TagInput（Issue #168）

@MainActor
func consumeTagInput() -> some View {
    TagInput(
        tags: .constant(["bug"]),
        placeholder: "Add tag",
        tagColor: .contentSecondary,
        allowDuplicates: false,
        onCommit: { _ in }
    )
}

// MARK: Descriptions（Issue #169）

@MainActor
func consumeDescriptions() -> some View {
    Descriptions(columns: .one, dividerDensity: .none, header: "Order") {
        LabeledContent("Status") { Text("Active") }
    }
}

// MARK: Carousel（Issue #171）

private struct DownstreamProbeCarouselItem: Identifiable {
    let id: Int
}

@MainActor
func consumeCarousel() -> some View {
    Carousel([DownstreamProbeCarouselItem(id: 0)], autoAdvance: false, interval: .seconds(4)) { item in
        Text("\(item.id)")
    }
}

// MARK: ExtendedFloatButtonStyle（Issue #170）——静态工厂 + 档位工厂两条访问器路径

@MainActor
func consumeExtendedFloatAccessor() -> some View {
    Button("float") {}
        .buttonStyle(.extendedFloat)
}

@MainActor
func consumeExtendedFloatTierAccessor() -> some View {
    Button("float") {}
        .buttonStyle(.extendedFloat(size: .regular))
}

// `.extendedFloat` 工厂经 opaque 传递会强制类型 public，但 `init(size:)` 的可见性回退抓不到——
// 直接构造 + 读 `.size` 把 init 与属性也钉进契约。
@MainActor
func consumeExtendedFloatButtonStyleType() -> ControlSize {
    ExtendedFloatButtonStyle(size: .large).size
}

// MARK: SpinningModifier / View.spinning(_:text:)（Issue #172）

@MainActor
func consumeSpinningModifier() -> some View {
    Text("content")
        .spinning(true, text: "Refreshing…")
}

// `.spinning(...)` 返回 opaque `some View`，`SpinningModifier` 类型/init/属性即使回退成 internal
// 也照样编译——直接 `.modifier(SpinningModifier(...))` + 读两个 public 属性，把类型契约真正钉住
// （AC #173：probe 须覆盖 SpinningModifier 本身，防「恒绿、契约形同虚设」）。
@MainActor
func consumeSpinningModifierType() -> (Bool, LocalizedStringKey?) {
    let modifier = SpinningModifier(isActive: true, text: "Refreshing…")
    return (modifier.isActive, modifier.text)
}

// MARK: ProgressIndicator(text:) 两个新 init（Issue #172，NFR-6：原 init() 无破坏未变，不在此重复覆盖）

@MainActor
func consumeProgressIndicatorLocalizedText() -> some View {
    ProgressIndicator(text: "Loading…")
}

@MainActor
func consumeProgressIndicatorVerbatimText(_ status: String) -> some View {
    ProgressIndicator(text: status)
}

// MARK: - NFR-7 的两个可注入能耗环境键：**不在本文件**（Issue #252）
//
// `\.lowPowerModeOverride` / `\.scenePhaseOverride` 已从 `CoreDesignEffects` 下沉到
// `CoreDesign`（PR #269 终审 S-2 的已裁决处置），它们的跨模块证明随之搬到**另一个
// target**：`CoreDesignOnlyProbe`（只接 `CoreDesign` 一个 product）。
//
// ⚠️ **不能留在本 target**，哪怕单开一个"只写 `import CoreDesign`"的文件——
// 变异实证现场抓到的：Swift 对**扩展成员**的名字查找是**逐模块**而不是逐文件的，
// 本文件顶上这句 `import CoreDesignEffects` 会让 Effects 挂在 `EnvironmentValues`
// 上的成员在同 target 的**其它文件里也可见**。⇒ 那样的"证明"在"键搬回 Effects"
// 这枚变异下照样全绿，是摆设。理由全文见 `CoreDesignOnlyProbe` 的文件头与
// `Package.swift` 里那个 target 的注释。

// MARK: - CoreDesignEffects：#252 的四个 API 单位

@MainActor
func consumeCelebrationAndProcessingEffects() -> some View {
    VStack {
        ScanningOverlay { Text("scanning") }
        GlowSweep { Text("glow") }
        LightSweep { Text("light") }
    }
    .confetti(trigger: 1)
}

// MARK: - CoreDesignEffects：#253 的四个 API 单位

// ⚠️ 三个 View 与一个 `Transition` 静态成员落在**本文件**而不是
// `EffectsNonisolatedUsage.swift`——分流理由见那份文件的文件头：本包开了
// `.defaultIsolation(MainActor.self)`，View 的 `init` 天然 MainActor 隔离，
// 从 `nonisolated func` 里构造它们必然编译失败。
// 值类型那一档（`TypewriterSpeed` / `ParticleTransition.defaultCount`）在那边。
@MainActor
func consumeTextAndDisplayEffects(streamed: String) -> some View {
    VStack {
        TypewriterText("Welcome aboard", speed: .slow)
        TypewriterText(verbatim: streamed)
        AnimatedMeshGradient()
        AnimatedMeshGradient(colors: [.surfaceRaised], alternateColors: [.secondaryFill])
        BeforeAfterSlider(labels: .shown(before: "Draft", after: "Final")) {
            Text("before")
        } after: {
            Text("after")
        }
        BeforeAfterSlider(labels: .hidden) {
            Text("before")
        } after: {
            Text("after")
        }
        Text("badge").transition(.particle)
        Text("badge").transition(.particle(count: 8, colors: [.surfaceRaised]))
    }
}

// MARK: - CoreDesignEffects：#254 的四个 API 单位（跨平台改造）

// ⚠️ 四件都是 `View` struct ⇒ 全部落在**本文件**（`@MainActor`），
// `EffectsNonisolatedUsage.swift` 那边只放值类型 —— 分流理由见那份文件的文件头。
//
// ⚠️⚠️ **本函数同时是"macOS 支持没被降低"的跨模块证据**：
// probe 是一个独立 SwiftPM 包，`swift build` 在 macOS 上编译它。若哪天有人把
// `FullScreenButton` 整个塞进 `#if os(iOS)`（"让库编译得过"的那种改法），
// 本仓的 `swift build` 仍然全绿，而**这里会当场编译红**——那正是下游 macOS App
// 会遇到的形态。`PlatformSupportGuard.zoomIsFencedToIOS` 从源码那一侧守同一件事。
@MainActor
func consumeCrossPlatformEffects(brands: [CrossPlatformProbeItem]) -> some View {
    VStack {
        DotSphere()
        DotSphere(count: 200, colors: [.surfaceRaised], rotationPeriod: 8)
        CharSphere(["道", "德"])
        CharSphere(["S", "h"], count: 120, colors: [.secondaryFill], rotationPeriod: 6)
        OrbitingLogos(brands) { item in
            Text(verbatim: item.name)
        } center: {
            Text(verbatim: "core")
        }
        NavigationStack {
            FullScreenButton {
                Text(verbatim: "expanded")
            } label: {
                Text(verbatim: "card")
            }
        }
    }
}

/// probe 侧的示例数据类型：`OrbitingLogos` 的入参是**泛型集合 + `Identifiable`**，
/// 不绑定具体模型 ⇒ 下游用自己的模型也接得上，这一条只有跨模块调用点看得见。
struct CrossPlatformProbeItem: Identifiable {
    let id: Int
    let name: String
}

// MARK: - CoreDesignEffects：#266 的四种滤镜类转场

// ⚠️ 四个 `Transition` 静态成员都要**经点语法**触达（`.transition(.blur)`），
// 不能写 `Transition.blur`——该静态成员定义在
// `extension Transition where Self == BlurTransition` 上，经协议元类型访问会报
// `static member 'blur' cannot be used on protocol metatype '(any Transition).Type'`
// （同本文件 `consumeCircularGlassAccessor` 记的那条）。
// ⚠️ 含参与无参两条重载**都**要覆盖：它们按 `Host.member` 去重算同一条转场，
// 但**可见性是各自独立的**——只覆盖一条，另一条漏了 `public` 时 probe 照样绿。
// 四个默认值常量（值类型那一档）在 `EffectsNonisolatedUsage.swift`。
@MainActor
func consumeFilterTransitions() -> some View {
    VStack {
        Text(verbatim: "blur").transition(.blur)
        Text(verbatim: "blur+").transition(.blur(radius: 8))
        Text(verbatim: "exposure").transition(.filmExposure)
        Text(verbatim: "exposure+").transition(.filmExposure(intensity: 0.4))
        Text(verbatim: "snapshot").transition(.snapshot)
        Text(verbatim: "snapshot+").transition(.snapshot(intensity: 0.5))
        Text(verbatim: "flicker").transition(.flicker)
        Text(verbatim: "flicker+").transition(.flicker(cycles: 4))
    }
}

// MARK: - CoreDesignEffects：#268 的六个 API 单位（mask reveal 转场簇）

// ⚠️ 六种转场各有「无参 `var`」与「含参 `func`」两个静态成员（登记表按 `Host.member`
// 去重算六条，见 `docs/component-registry.json`）——**十二个都在这里点名**，
// 因为「无参那个能编译」不蕴含「含参那个也能」：两段是各自独立的接线，
// 而含参重载的默认实参还引用了 `MaskRevealTransition.default*` 四个常量，
// 那四个常量漏 `public` 时**只有含参形态会红**。
//
// ⚠️ 它们落在**本文件**（`@MainActor`）而不是 `EffectsNonisolatedUsage.swift`：
// 按那份文件头的分流表，`Transition` 的静态成员是**转场形态**，
// `.transition(_:)` 本身是 `View` 上的 modifier ⇒ 天然 MainActor 隔离。
// 四个默认值常量是**值类型**，在那边（`readMaskRevealTransitionDefaults()`）。
//
// ⚠️⚠️ **本函数同时是「`MaskRevealTransition` 没有 public init 不算破 `CLAUDE.md`」
// 的常驻证据**（#268 终审）：那条惯例针对的是**调用方要构造的组件**；转场只经这十二个
// 静态成员消费，而这里逐个证明了「不给 public init 也够用」。
// 少了本函数，那条裁决就只有一次性的临时验证撑着。
@MainActor
func consumeMaskRevealTransitions() -> some View {
    VStack {
        Text("iris").transition(.iris)
        Text("iris(anchor:)").transition(.iris(anchor: .topLeading))
        Text("wipe").transition(.wipe)
        Text("wipe(angle:)").transition(.wipe(angle: .degrees(90)))
        Text("blinds").transition(.blinds)
        Text("blinds(count:)").transition(.blinds(count: 5))
        Text("clock").transition(.clock)
        Text("clock(direction:)").transition(.clock(direction: .counterClockwise))
        Text("glare").transition(.glare)
        Text("glare(angle:)").transition(.glare(angle: .degrees(-20)))
        Text("dissolve").transition(.dissolve)
        Text("dissolve(cellSize:)").transition(.dissolve(cellSize: 12))
    }
}

// MARK: - CoreDesignEffects：#250 的 8 个微交互 modifier

// ⚠️ 8 个都是 `public extension View` 上的方法 ⇒ 落**本文件**（`@MainActor`）：
// 本包开了 `.defaultIsolation(MainActor.self)`，modifier 函数天然 MainActor 隔离，
// 从 `nonisolated func` 里调用必然编译失败。两个配置枚举
// （`MicroInteractionStrength` / `SpinDirection`）在 `EffectsNonisolatedUsage.swift`。
//
// ⚠️ **含默认实参的形态与显式传参的形态都要覆盖**：默认实参本身引用了
// `MicroInteractionStrength.regular` / `SpinDirection.clockwise` /
// `Color.specularHighlight` 这些公开符号，**只写默认形态时，显式传参那条重载路径
// 上的可见性回退抓不到**（与 `consumeFilterTransitions` 记的那条同型）。
//
// ⚠️ 拆成两个函数只是因为 `ViewBuilder` 一次最多接 10 个子视图。
@MainActor
func consumeMicroInteractionModifiersA(taps: Int) -> some View {
    VStack {
        Text(verbatim: "shake").shake(trigger: taps)
        Text(verbatim: "shake+").shake(trigger: taps, strength: .pronounced)
        Text(verbatim: "jump").jump(trigger: taps)
        Text(verbatim: "jump+").jump(trigger: taps, strength: .subtle)
        Text(verbatim: "spin").spin(trigger: taps)
        Text(verbatim: "spin+").spin(trigger: taps, direction: .counterClockwise)
        Text(verbatim: "ping").ping(trigger: taps)
        Text(verbatim: "ping+").ping(trigger: taps, strength: .subtle, color: .accent)
    }
}

@MainActor
func consumeMicroInteractionModifiersB(taps: Int) -> some View {
    VStack {
        Text(verbatim: "spray").spray(trigger: taps, symbol: "heart.fill")
        Text(verbatim: "spray+").spray(trigger: taps, symbol: "star.fill", strength: .pronounced, colors: [.accent])
        Text(verbatim: "rise").rise(trigger: taps, text: "+1")
        Text(verbatim: "rise+").rise(trigger: taps, text: "+1", strength: .subtle, color: .accent)
        // ⚠️ `.haptic` 是对 `sensoryFeedback` 的薄封装，**没有** strength / color 参数
        // ⇒ 只有一种形态。它的公开面就是这一行。
        Text(verbatim: "haptic").haptic(.success, trigger: taps)
        Text(verbatim: "shine").shine(trigger: taps)
        Text(verbatim: "shine+").shine(trigger: taps, highlight: .specularHighlight)
    }
}

// MARK: - CoreDesignCharts：#255 的四个图表

// ⚠️ 四个图表**本身**是 `View` struct ⇒ 落本文件（`@MainActor`），
// 数据契约（`ChartValue` / `HeatmapDay` / `GraphNode` / `GraphEdge`）与四个规模上限
// 是**值类型 / 配置**那一档，在 `ChartsNonisolatedUsage.swift`
// —— 分流理由见 `EffectsNonisolatedUsage.swift` 的文件头。
//
// ⚠️ **每个图表的 `title:` / `tint:` 缺省与显式两种形态都要覆盖**：
// `title` 的类型是 `LocalizedStringResource?`，显式传值那条路径上若哪天
// 换成一个 internal 的包装类型，只写缺省形态的 probe 照样绿。
//
// ⚠️ 本函数同时钉住「四个图表的数据入参是**泛型**」这条 AC（#255 终审 I-7）：
// 这里传进去的是 **probe 自己的**模型类型，库里没有它们的任何影子
// ——若哪天有人把入参绑回库自带的具体 struct，这里当场编译红。
@MainActor
func consumeCharts() -> some View {
    let metrics = [
        ChartsProbeMetric(id: 0, label: "速度", value: 82),
        ChartsProbeMetric(id: 1, label: "力量", value: 61),
        ChartsProbeMetric(id: 2, label: "耐力", value: 94),
    ]
    let days = (0..<7).map {
        ChartsProbeDay(id: $0, date: Date(timeIntervalSince1970: Double($0) * 86_400), count: $0)
    }
    let nodes = (0..<4).map { ChartsProbeNode(id: "n\($0)", label: "节点 \($0)") }
    let edges = [GraphEdge(from: "n0", to: "n1"), GraphEdge(from: "n1", to: "n2")]

    return VStack {
        RadarChart(metrics)
        RadarChart(metrics, title: "Radar", tint: .accent)
        RingChart(metrics, goal: 500)
        RingChart(metrics, goal: 500, title: "Rings", tint: .accent)
        ActivityHeatmap(days)
        ActivityHeatmap(days, title: "Heatmap", tint: .accent, calendar: .current)
        NetworkGraph(nodes: nodes, edges: edges)
        NetworkGraph(nodes: nodes, edges: edges, title: "Graph", tint: .accent)
    }
}
