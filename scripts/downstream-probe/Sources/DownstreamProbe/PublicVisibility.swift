import CoreDesign
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
// 与 `readRolePalette` 同样必须 `@MainActor`——`defaultIsolation(MainActor.self)`
// 下这个方法也是 MainActor 隔离的（它读三个隔离的调色板属性）。
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
// SettingsRowMetrics 从 internal 改 public，让下游把自定义行对齐到 SettingsRow
// 网格。这是该次变更的**全部交付物**——若被改回 internal，库内 @testable 测试、
// App 宿主、既有 probe 都护不住（无一从外部包引用它）。这里从外部包消费全部 6 个
// 成员，pin 住可见性。
//
// 必须 @MainActor：`.defaultIsolation(MainActor.self)` 下两个计算属性
// （iconAlignedDividerInset / textAlignedDividerInset）是 MainActor 隔离的，四个
// static let 跨模块也非 nonisolated 可达（SE-0434 只放开模块内）——与上面
// ButtonRoleStyleRole 调色板同款「可见但非 nonisolated 可达」。
@MainActor
func consumeSettingsRowMetrics() -> [CGFloat] {
    [
        SettingsRowMetrics.iconSquareSize,
        SettingsRowMetrics.iconTitleGap,
        SettingsRowMetrics.horizontalPadding,
        SettingsRowMetrics.iconCornerRadius,
        SettingsRowMetrics.iconAlignedDividerInset,
        SettingsRowMetrics.textAlignedDividerInset,
    ]
}

// MARK: - Skeleton 取色 token（semi-mobile-components Phase 0 / Issue #161）
//
// `Color.skeletonBase` / `skeletonHighlight` 是 Phase 0 新增的公开取色面，供
// Skeleton（Issue #162）的 shimmer modifier 复用。库内 @testable 测试只能证明
// 「能编译」（internal 也可达），真正的公开可见性护栏在这里——从外部包消费它们，
// 若日后漏写/收回 `public`，四条 SwiftPM 命令仍绿而此处会炸。
// 必须 @MainActor：CoreDesign 开了 `.defaultIsolation(MainActor.self)`，这两个
// 静态计算属性跨模块非 nonisolated 可达（同 ButtonRoleStyleRole 调色板）。
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
