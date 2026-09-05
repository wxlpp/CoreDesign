import SwiftUI
import CoreDesign
// ⚠️ **多 product 之后必须逐条 import**（#245 的失效形态：`App/project.yml` 只写
// `- package: CoreDesign` 时预览宿主编译得过、但画廊里的新组件 import 不到）。
// `project.yml` 那侧的四条 `product:` 与这三行是**一对**，改一边必须改另一边。
import CoreDesignCharts
import CoreDesignEffects
import CoreDesignShaders

// MARK: - ComponentCategory

enum ComponentCategory: String, CaseIterable, Identifiable {
    case button = "Button"
    case form = "Form"
    case indicator = "Indicator"
    case layout = "Layout"
    case container = "Container"
    case navigation = "Navigation"
    case feedback = "Feedback"
    /// `CoreDesignEffects` 的 36 个 API 单位（微交互 8 + 转场 16 + 庆祝与处理中 4
    /// + 文本与展示 4 + 跨平台改造 4）。
    case effect = "Effect"
    /// `CoreDesignCharts` 的 4 个图表。
    case chart = "Chart"
    /// `CoreDesignShaders` 的 9 个 API 单位（6 个自带内容的 `View` + 3 个只重采样
    /// 调用方内容层的 modifier）。
    case shader = "Shader"

    var id: String { self.rawValue }
}

// MARK: - ComponentMeta

struct ComponentMeta: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: ComponentCategory
    let preview: () -> AnyView
    let demoAction: (() -> AnyView)?

    static func == (lhs: ComponentMeta, rhs: ComponentMeta) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

    init(
        id: String,
        name: String,
        description: String,
        category: ComponentCategory,
        @ViewBuilder preview: @escaping () -> some View,
        demoAction: (() -> AnyView)? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.preview = { AnyView(preview()) }
        self.demoAction = demoAction
    }
}

// MARK: - Component Registry

extension ComponentMeta {
    @MainActor static let all: [ComponentMeta] = [
        // Button
        ComponentMeta(id: "button", name: "Button", description: "3 种 ButtonStyle：solid / light / borderless，按 role 参数化配色", category: .button) {
            ButtonPreview()
        },
        ComponentMeta(id: "float-button", name: "FloatButton", description: "悬浮按钮：ExtendedFloatButtonStyle 胶囊玻璃 + CircularGlassButtonStyle 圆形玻璃", category: .button) {
            FloatButtonPreview()
        },

        // Form
        ComponentMeta(id: "label-icon", name: "Form Icons", description: "表单图标：LabelIcon / ChevronRightIcon / DangerIcon", category: .form) {
            FormIconsPreview()
        },
        ComponentMeta(id: "segmented-control", name: "SegmentedControl", description: "分段控件，token 化配色 + 选中态", category: .form) {
            SegmentedControlPreview()
        },
        ComponentMeta(id: "search-field", name: "SearchField", description: "搜索输入框 — magnifyingglass + clear button + focus ring", category: .form) {
            SearchFieldPreview()
        },
        ComponentMeta(id: "bottom-input-bar", name: "BottomInputBar", description: "底部输入栏 modifier，带自动补全 + 提交逻辑", category: .form) {
            BottomInputBarPreview()
        },
        ComponentMeta(id: "rating", name: "Rating", description: "Binding<Double> 驱动的星级评分控件，step 参数控制步进粒度", category: .form) {
            RatingPreview()
        },
        ComponentMeta(id: "rating-display", name: "RatingDisplay", description: "只读评分展示（indicator）——无手势、不走原生 disabled 变灰", category: .form) {
            RatingDisplayPreview()
        },
        ComponentMeta(id: "pin-code", name: "PinCode", description: "验证码 / PIN 分格输入，隐藏 TextField 承接系统键盘 + iOS 单条码 OTP 自动填充", category: .form) {
            PinCodePreview()
        },
        ComponentMeta(id: "radio-group", name: "RadioGroup", description: "互斥单选组，与 CheckBox 成对的视觉语汇", category: .form) {
            RadioGroupPreview()
        },
        ComponentMeta(id: "tag-input", name: "TagInput", description: "标签输入框：Tag chip + 内联 TextField，回车/逗号提交", category: .form) {
            TagInputPreview()
        },

        // Indicator
        ComponentMeta(id: "badge", name: "Badge", description: "5 状态等级指示器：info / success / warning / danger / neutral", category: .indicator) {
            BadgePreview()
        },
        ComponentMeta(id: "tag", name: "Tag", description: "调用方自定义颜色的分类标签，支持 removable", category: .indicator) {
            TagPreview()
        },
        ComponentMeta(id: "banner", name: "Banner", description: "通知横幅，支持 info / success / warning / danger 四级", category: .indicator) {
            BannerPreview()
        },
        ComponentMeta(id: "progress-indicator", name: "ProgressIndicator", description: "通用圆形加载指示器，可选文案渲染于 spinner 下方", category: .indicator) {
            ProgressIndicatorGalleryPreview()
        },
        ComponentMeta(id: "skeleton", name: "Skeleton", description: "骨架屏容器：SkeletonLine / SkeletonRect / SkeletonCircle 占位形状 + shimmer 扫光", category: .indicator) {
            SkeletonPreview()
        },
        ComponentMeta(id: "steps", name: "Steps", description: "步骤条：4 种呈现（steps / segmentedBar / navigation / text）× 点状 / 数字指示器", category: .indicator) {
            StepsPreview()
        },
        ComponentMeta(id: "timeline", name: "Timeline", description: "时间线：4 种排布（vertical / alternate / horizontal / grouped），节点 + 连线 + 内容", category: .indicator) {
            TimelinePreview()
        },

        // Layout
        ComponentMeta(id: "avatar", name: "Avatar", description: "头像组件，按名称首字母生成", category: .layout) {
            AvatarPreview()
        },
        ComponentMeta(id: "list-row", name: "ListRow", description: "3-槽位泛型列表行：leading / label / trailing", category: .layout) {
            ListRowPreview()
        },
        ComponentMeta(id: "carousel", name: "Carousel", description: "走马灯：ScrollView 分页滚动 + 自动轮播 + 页点指示器", category: .layout) {
            CarouselPreview()
        },

        // Container（Phase 2）
        ComponentMeta(id: "settings-screen", name: "Settings Screen", description: "SC#10：仅用 CoreDesign 复刻一屏 iOS 设置页（InsetGroupedSection + SettingsRow）", category: .container) {
            SettingsScreenDemo()
        },
        ComponentMeta(id: "inset-grouped-section", name: "InsetGroupedSection", description: "iOS .insetGrouped 分组容器 + 自动分隔线 inset + 页眉页脚", category: .container) {
            InsetGroupedSectionPreview()
        },
        ComponentMeta(id: "settings-row", name: "SettingsRow", description: "设置行：图标方块 + 标题 + 副标题 + accessory（value / chevron / Toggle / 自定义）", category: .container) {
            SettingsRowPreview()
        },
        ComponentMeta(id: "settings-row-in-list", name: "SettingsRow in List", description: "AC9：SettingsRow 直接作原生 List 行 + .listRowInsets(EdgeInsets()) 消双重 inset", category: .container) {
            SettingsRowInListDemo()
        },
        ComponentMeta(id: "card", name: "Card", description: ".surface(.content) 具名封装 + 默认内边距，浮于画布之上", category: .container) {
            CardPreview()
        },
        ComponentMeta(id: "separator", name: "Separator", description: "可控 leading inset 的 hairline 分隔线，走 dividerDefault 系统色", category: .container) {
            SeparatorPreview()
        },
        ComponentMeta(id: "section-header-footer", name: "Section Header / Footer", description: "iOS 分组页眉（大写 footnote 灰）/ 页脚说明", category: .container) {
            SectionHeaderFooterPreview()
        },
        ComponentMeta(id: "descriptions", name: "Descriptions", description: "描述列表：.core LabeledContentStyle + InsetGroupedSection，1/2 列 + 大字号自动塌列", category: .container) {
            DescriptionsPreview()
        },

        // Form（Phase 2 .core style）
        ComponentMeta(id: "core-progressview", name: ".core ProgressView", description: "系统 ProgressView 的 .core style，填充走 .tint", category: .form) {
            CoreProgressViewPreview()
        },
        ComponentMeta(id: "core-label", name: ".core Label", description: "系统 Label 的 .core style，icon 走 .tint", category: .form) {
            CoreLabelPreview()
        },
        ComponentMeta(id: "core-disclosuregroup", name: ".core DisclosureGroup", description: "系统 DisclosureGroup 的 .core style，chevron 走 .tint + leading 缩进", category: .form) {
            CoreDisclosureGroupPreview()
        },

        // Navigation
        ComponentMeta(id: "sidebar", name: "Sidebar", description: "侧栏导航组件组：section / navigation / utility / document / tag row", category: .navigation) {
            SidebarPreview()
        },
        ComponentMeta(id: "underlined-tab-bar", name: "UnderlinedTabBar", description: "下划线式 TabBar，token 化配色 + 选中态指示器", category: .navigation) {
            UnderlinedTabBarPreview()
        },

        // Feedback
        ComponentMeta(id: "toast", name: "Toast", description: "Scene-scoped toast host + 队列状态机", category: .feedback, preview: {
            Text("Toast 通过 `.toastHost(edge:)` modifier 挂载到 WindowGroup 根级别")
                .font(CoreTypography.Token.footnote.font)
                .foregroundStyle(Color.contentMuted)
        }, demoAction: { AnyView(ToastDemoButton()) }),
        ComponentMeta(id: "spinning", name: "Spinning", description: "View.spinning(_:text:presentation:)：overlay 遮罩（阻塞）/ topBar / inline（非阻塞）", category: .feedback) {
            SpinningPreview()
        },
        ComponentMeta(id: "spinning-nonblocking", name: "Spinning · 非阻塞", description: "topBar 顶条 / inline 行内：不铺遮罩、不禁用交互", category: .feedback) {
            SpinningNonBlockingPreview()
        },
    ] + Self.shipSwiftEntries + Self.shaderEntries
}

// MARK: - `shipswift-effects` epic 的 40 个 API 单位（#256 串行合并）
//
// ⚠️⚠️ **本数组是本 epic 唯一的画廊写入窗口**：`epic.md`《Implementation Strategy》把
// `ComponentData.swift` 列为并行冲突面，task 001–006 只产出片段、**由本 task 统一合并**；
// `shipswift-shaders` 的 B-4 复用同一窗口（追加自己的分节，不要重排本节）。
//
// ⚠️ 与主数组分成两个 `static let` 是有意的：40 条追加进上面那个字面量会让整个
// `all` 的类型检查退化（SwiftUI 的 `some View` 闭包 + 40 元素数组字面量），
// 且合并冲突面会从「本节」扩大到「整个 all」。
//
// ⚠️ **"可用"的第 ③ 条（有 `#Preview` 且进画廊）在本仓分两处兑现**：`#Preview` 在
// 各自的 `Sources/CoreDesign*/…` 源文件里（库内视觉冒烟），画廊条目在这里。
//
// ⚠️ **本节有意不补 `App/Sources/Previews.swift` 的宿主 `#Preview`**，两条理由：
// ① 这批 API 单位绝大多数是**只在值变化 / 进出那一瞬间**才有东西可看的动效，
//    静止帧与未加修饰的内容像素级相同，收进 `docs/snapshots` 只是噪声；
// ② 提交态的快照按**产地**收（只收 `CoreDesignPreview_*`），而库内 `#Preview`
//    一律不入库 —— 规则与三次全量渲染的实测证据写在
//    `scripts/run-snapshots.sh` 默认模式那段注释里，判据在
//    `Tests/CoreDesignTests/SnapshotArtifactGuard.swift`。
extension ComponentMeta {

    @MainActor static let shipSwiftEntries: [ComponentMeta] = [
        // MARK: 微交互 8 个（#250）
        ComponentMeta(id: "effect-shake", name: ".shake(trigger:)", description: "trigger 值变化时左右抖动；承载「输入错误」这类状态语义，a11y 通告由调用方提供", category: .effect) {
            MicroInteractionDemo(label: "抖一下", symbol: "exclamationmark.triangle.fill") { view, fire in
                view.shake(trigger: fire)
            }
        },
        ComponentMeta(id: "effect-jump", name: ".jump(trigger:)", description: "trigger 值变化时上跳并带 squash / stretch；Reduce Motion 下降级为无位移", category: .effect) {
            MicroInteractionDemo(label: "跳一下", symbol: "arrow.up.circle.fill") { view, fire in
                view.jump(trigger: fire)
            }
        },
        ComponentMeta(id: "effect-spin", name: ".spin(trigger:)", description: "trigger 值变化时单次整圈旋转，方向由 SpinDirection 决定（不是 clockwise: Bool）", category: .effect) {
            MicroInteractionDemo(label: "转一圈", symbol: "arrow.triangle.2.circlepath") { view, fire in
                view.spin(trigger: fire, direction: .counterClockwise)
            }
        },
        ComponentMeta(id: "effect-ping", name: ".ping(trigger:)", description: "trigger 值变化时在内容背后扩散同心圆环；装饰层已 accessibilityHidden(true)", category: .effect) {
            MicroInteractionDemo(label: "扩散一次", symbol: "dot.radiowaves.left.and.right") { view, fire in
                view.ping(trigger: fire)
            }
        },
        ComponentMeta(id: "effect-spray", name: ".spray(trigger:symbol:)", description: "trigger 值变化时喷出 SF Symbol 粒子；colors 默认空数组 ⇒ 取调用方 .tint", category: .effect) {
            MicroInteractionDemo(label: "喷一次", symbol: "heart.fill") { view, fire in
                view.spray(trigger: fire, symbol: "heart.fill", strength: .pronounced)
            }
        },
        ComponentMeta(id: "effect-rise", name: ".rise(trigger:text:)", description: "trigger 值变化时浮起一段文字；text 是 LocalizedStringKey（公约 B 类）", category: .effect) {
            MicroInteractionDemo(label: "+1", symbol: "star.fill") { view, fire in
                view.rise(trigger: fire, text: "+1")
            }
        },
        ComponentMeta(id: "effect-haptic", name: ".haptic(_:trigger:)", description: "对 sensoryFeedback 的薄封装，提升可发现性；⚠️ 模拟器上没有触感硬件，只能在真机上感知", category: .effect) {
            MicroInteractionDemo(label: "触感（真机可感）", symbol: "iphone.radiowaves.left.and.right") { view, fire in
                view.haptic(.success, trigger: fire)
            }
        },
        ComponentMeta(id: "effect-shine", name: ".shine(trigger:)", description: "trigger 值变化时一道高光扫过内容形状；高光色取 Color.specularHighlight 而非写死白色", category: .effect) {
            MicroInteractionDemo(label: "扫一道光", symbol: "sparkles") { view, fire in
                view.shine(trigger: fire)
            }
        },

        // MARK: 转场簇 A · 滤镜类 4 种（#266）
        ComponentMeta(id: "effect-transition-blur", name: "Transition .blur", description: "进出时内容失焦并淡出；hasMotion == false，无位移", category: .effect) {
            TransitionDemo(transition: .blur)
        },
        ComponentMeta(id: "effect-transition-film-exposure", name: "Transition .filmExposure", description: "像一格胶片被过度曝光：亮度冲高、饱和度与对比度洗白", category: .effect) {
            TransitionDemo(transition: .filmExposure)
        },
        ComponentMeta(id: "effect-transition-snapshot", name: "Transition .snapshot", description: "像即显相纸：一下快门白场，随后从低对比逐渐显影", category: .effect) {
            TransitionDemo(transition: .snapshot)
        },
        ComponentMeta(id: "effect-transition-flicker", name: "Transition .flicker", description: "像接触不良的灯管忽明忽暗；频率钉在 WCAG 的 3 次/秒线下", category: .effect) {
            TransitionDemo(transition: .flicker)
        },

        // MARK: 转场簇 B · 3D 与弹性 6 种（#267）
        ComponentMeta(id: "effect-transition-flip", name: "Transition .flip", description: "卡片翻面：带透视的 3D 旋转（两端 ±90°）+ 淡入淡出", category: .effect) {
            TransitionDemo(transition: .flip)
        },
        ComponentMeta(id: "effect-transition-rotate3d", name: "Transition .rotate3D", description: "绕任意轴翻滚并向纵深退一点；默认 75°，与 flip 钉死的 90° 有意错开", category: .effect) {
            TransitionDemo(transition: .rotate3D)
        },
        ComponentMeta(id: "effect-transition-swoosh", name: "Transition .swoosh", description: "穿行转场：从 edge 进、朝对侧出，途中带动态模糊与沿运动方向的拉伸", category: .effect) {
            TransitionDemo(transition: .swoosh)
        },
        ComponentMeta(id: "effect-transition-boing", name: "Transition .boing", description: "弹性缩放：从小放大、越过原尺寸再回落坐定", category: .effect) {
            TransitionDemo(transition: .boing(strength: .pronounced))
        },
        ComponentMeta(id: "effect-transition-skid", name: "Transition .skid", description: "刹车打滑：从 edge 滑进来、冲过头再刹住，车身跟着甩一个小角度", category: .effect) {
            TransitionDemo(transition: .skid)
        },
        ComponentMeta(id: "effect-transition-move", name: "Transition .move（极坐标）", description: "沿任意极角平移进出；与 SwiftUI 自带的 .move(edge:) 是重载而非覆盖", category: .effect) {
            TransitionDemo(transition: .move(angle: .degrees(-45), distance: 60))
        },

        // MARK: 转场簇 C · mask reveal 6 种（#268）
        ComponentMeta(id: "effect-transition-iris", name: "Transition .iris", description: "圆形光圈从 anchor 向外张开，半径自动取到最远角", category: .effect) {
            TransitionDemo(transition: .iris)
        },
        ComponentMeta(id: "effect-transition-wipe", name: "Transition .wipe", description: "一条直边沿指定角度扫过（默认 0°，左→右）", category: .effect) {
            TransitionDemo(transition: .wipe)
        },
        ComponentMeta(id: "effect-transition-blinds", name: "Transition .blinds", description: "若干条横向百叶各自从自己的中线向上下张开，默认 8 条", category: .effect) {
            TransitionDemo(transition: .blinds)
        },
        ComponentMeta(id: "effect-transition-clock", name: "Transition .clock", description: "扇形扫针从 12 点扫一圈，方向由 SpinDirection 决定", category: .effect) {
            TransitionDemo(transition: .clock)
        },
        ComponentMeta(id: "effect-transition-glare", name: "Transition .glare", description: "斜掠的直边扫过（默认 35°），揭示边上骑一条柔光带", category: .effect) {
            TransitionDemo(transition: .glare)
        },
        ComponentMeta(id: "effect-transition-dissolve", name: "Transition .dissolve", description: "网格逐格按确定性伪随机次序浮现，默认格边长 24pt", category: .effect) {
            TransitionDemo(transition: .dissolve)
        },

        // MARK: 庆祝与处理中 4 个（#252）
        ComponentMeta(id: "effect-confetti", name: ".confetti(trigger:)", description: "trigger 值变化时喷发一次彩纸；后台不画、低电量减半（NFR-7）", category: .effect) {
            ConfettiDemo()
        },
        ComponentMeta(id: "effect-scanning-overlay", name: "ScanningOverlay", description: "上下往复的扫描光带，表示「正在识别 / 处理」；常驻渲染，受能耗闸管辖", category: .effect) {
            ScanningOverlayDemo()
        },
        ComponentMeta(id: "effect-glow-sweep", name: "GlowSweep", description: "沿内容轮廓环绕的辉光扫针；低电量下不画辉光（policy.usesGlow）", category: .effect) {
            GlowSweepDemo()
        },
        ComponentMeta(id: "effect-light-sweep", name: "LightSweep", description: "横向往复的柔光带，表示「后台仍在工作」", category: .effect) {
            LightSweepDemo()
        },

        // MARK: 文本与展示 4 个（#253）
        ComponentMeta(id: "effect-typewriter-text", name: "TypewriterText", description: "逐字打字机；两个 init 分别收 LocalizedStringResource 与 verbatim 流式文本", category: .effect) {
            TypewriterTextDemo()
        },
        ComponentMeta(id: "effect-animated-mesh-gradient", name: "AnimatedMeshGradient", description: "MeshGradient 控制点缓慢漂移；colors 默认空数组 ⇒ 取语义 token", category: .effect) {
            AnimatedMeshGradientDemo()
        },
        ComponentMeta(id: "effect-before-after-slider", name: "BeforeAfterSlider", description: "拖动分隔线对比两张内容；labels 是语义枚举（.shown / .hidden），不是 Bool", category: .effect) {
            BeforeAfterSliderDemo()
        },
        ComponentMeta(id: "effect-particle-transition", name: "Transition .particle", description: "进出时内容轻微缩放淡出、一圈粒子向外飞散", category: .effect) {
            TransitionDemo(transition: .particle)
        },

        // MARK: 跨平台改造 4 个（#254）
        ComponentMeta(id: "effect-orbiting-logos", name: "OrbitingLogos", description: "环形轨道上的点阵与 logo；上游用 SpriteKit，本仓重写为纯 SwiftUI（AD-E）", category: .effect) {
            OrbitingLogosDemo()
        },
        ComponentMeta(id: "effect-dot-sphere", name: "DotSphere", description: "自转的点阵球；上游 import UIKit，本仓重写为跨平台 Canvas（AD-E）", category: .effect) {
            DotSphereDemo()
        },
        ComponentMeta(id: "effect-char-sphere", name: "CharSphere", description: "自转的字符球，字形由确定性散列分配（不是 Int.random）", category: .effect) {
            CharSphereDemo()
        },
        ComponentMeta(id: "effect-full-screen-button", name: "FullScreenButton", description: "点开为全屏详情；zoom 转场是 iOS-only，其它平台按 FullScreenTransitionPlan 降级（AD-E）", category: .effect) {
            FullScreenButtonDemo()
        },

        // MARK: 四个图表（#255）
        ComponentMeta(id: "chart-radar", name: "RadarChart", description: "多维雷达图；轴少于 3 条 / 含非有限值时渲染空态而不是 crash（AD-F）", category: .chart) {
            RadarChartDemo()
        },
        ComponentMeta(id: "chart-ring", name: "RingChart", description: "同心活动环；goal ≤ 0 或非有限时渲染空态，建议环数上限 6", category: .chart) {
            RingChartDemo()
        },
        ComponentMeta(id: "chart-activity-heatmap", name: "ActivityHeatmap", description: "贡献热力图；日期归一化由注入的 Calendar 决定，上限 1830 天", category: .chart) {
            ActivityHeatmapDemo()
        },
        ComponentMeta(id: "chart-network-graph", name: "NetworkGraph", description: "力导向关系图；超过 150 节点 / 600 边时截断 + 降级 + 标注，不抛断言（AD-F）", category: .chart) {
            NetworkGraphDemo()
        },
    ]
}

// MARK: - Component Previews

private struct ButtonPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Button("Solid") {}.buttonStyle(.solid(role: .primary))
            Button("Light") {}.buttonStyle(.light(role: .primary))
            Button("Borderless") {}.buttonStyle(.borderless(role: .primary))
        }
    }
}

private struct FormIconsPreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.md) {
            LabelIcon(systemName: "person.fill", backgroundColor: .blue)
            LabelIcon(systemName: "star.fill", backgroundColor: .yellow)
            ChevronRightIcon()
            DangerIcon()
        }
    }
}

private struct SegmentedControlPreview: View {
    let items = ["One", "Two", "Three"]
    @State private var selection = "One"
    var body: some View {
        SegmentedControl(items: self.items, selection: self.$selection, title: { $0 })
    }
}

private struct SearchFieldPreview: View {
    @State private var text = "filter results"
    var body: some View { SearchField(text: self.$text) }
}

/// BottomInputBar 的可交互演示宿主。
///
/// ⚠️ **#221 之前这里是一句占位文本**（「通过 `.bottomInputBar` modifier 使用，
/// 非独立 View」），使 BottomInputBar 成为本库**唯一在 demo 里看不到的组件**。
///
/// ⚠️ **演示走 modifier 而不是直接构造 struct**——这是有意的，理由是
/// **suggestions 只存在于 modifier 面**：`BottomInputBarModifier` 才渲染
/// `BottomInputBarSuggestionsView`，`BottomInputBar.body` 只有 `mainRow`。
/// 直接构造 struct 时 `isShowingSuggestions` 只影响魔杖按钮的 a11y traits，
/// **视觉上不会有任何建议条出现或消失**。任务书要求 demo「非空 suggestions +
/// 能看到显隐」，只有 modifier 面兑现得了。
struct BottomInputBarPreview: View {
    @State private var submitted: [String] = []
    @State private var isRunning = false

    private static let suggestions = ["续写下一段", "换个风格", "润色文字", "生成对话"]

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            if self.submitted.isEmpty {
                Text("点输入框左侧的魔杖按钮可展开 / 收起建议条；输入并提交后内容会列在这里。")
                    .font(CoreTypography.Token.footnote.font)
                    .foregroundStyle(Color.contentMuted)
            } else {
                ForEach(Array(self.submitted.enumerated()), id: \.offset) { _, line in
                    Text(line).font(CoreTypography.Token.footnote.font)
                }
            }

            Toggle("模拟运行中（发送按钮变停止）", isOn: self.$isRunning)
                .font(CoreTypography.Token.footnote.font)

            Spacer(minLength: CoreSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .bottomInputBar(
            suggestions: Self.suggestions,
            placeholder: "说点什么",
            autoShowSuggestions: true,
            isRunning: self.isRunning,
            onStop: { self.isRunning = false },
            onSubmit: { text in
                guard text.isEmpty == false else { return }
                self.submitted.append(text)
            }
        )
    }
}

private struct BadgePreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Badge("Info", variant: .info)
            Badge("Success", variant: .success)
            Badge("Warning", variant: .warning)
            Badge("Danger", variant: .danger)
            Badge("Neutral")
        }
    }
}

private struct TagPreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            Tag("bug", color: .red)
            Tag("enhancement", color: .blue)
            Tag("good first issue", color: .purple)
            Tag("doc", color: .cyan, removable: true, onRemove: {})
        }
    }
}

private struct BannerPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.sm) {
            Banner(level: .info) { Text("Info message") }
            Banner(level: .success) { Text("Success message") }
            Banner(level: .warning) { Text("Warning message") }
            Banner(level: .danger) { Text("Danger message") }
        }
    }
}

private struct AvatarPreview: View {
    var body: some View {
        HStack(spacing: CoreSpacing.md) {
            Avatar(name: "Evan")
            Avatar(name: "CoreDesign")
        }
    }
}

private struct ListRowPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ListRow(label: { Text("Full row").foregroundStyle(Color.contentPrimary) })
            ListRow(
                leading: { Image(systemName: "doc.text").foregroundStyle(Color.contentMuted) },
                label: { Text("With icon").foregroundStyle(Color.contentPrimary) },
                trailing: { Image(systemName: "chevron.forward").foregroundStyle(Color.contentMuted) }
            )
        }
    }
}

private struct SidebarPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            SidebarSection(title: "Core", showsChevron: false) {
                SidebarNavigationRow(systemImage: "calendar", title: "Today", isSelected: true) {}
                SidebarNavigationRow(systemImage: "tray.full", title: "Inbox", isSelected: false) {}
            }

            SidebarSection(title: "Library") {
                SidebarDocumentRow(systemImage: "doc.text", title: "Exam Sprint", detail: "47 days") {}
                SidebarTagRow(title: "Math") {}
            }

            SidebarSection(title: "Tools", showsChevron: false) {
                SidebarUtilityRow(systemImage: "gearshape", title: "Settings") {}
                SidebarUtilityRow(systemImage: "trash", title: "Trash", trailingSystemImage: "arrow.up.right") {}
                // `#64` 形态 D2：`.textOnly` 拆掉 leading 槽；候选 2 = 本 case + 既有尾图标参数。
                // ⚠️ `.textOnly` 下 systemImage 不渲染 ⇒ 约定统一写 ""（见 docs/components/sidebar.md）。
                // 该约定**不承重**：`SidebarLeadingSlotRenderTests.textOnlyIgnoresSystemImage`
                // 以位图证明取任何值渲染都相同，写 "" 只是卫生。
                SidebarUtilityRow(systemImage: "", title: "Archive", presentation: .textOnly) {}
                SidebarUtilityRow(systemImage: "", title: "Settings", trailingSystemImage: "chevron.forward", presentation: .textOnly) {}
            }

            SidebarStatusFooter(title: "Synced", detail: "Updated just now")
        }
        .background(Color.surfaceSidebar)
    }
}

private struct UnderlinedTabBarPreview: View {
    let items = ["Tab 1", "Tab 2", "Tab 3"]
    @State private var selection = "Tab 1"
    var body: some View {
        UnderlinedTabBar(items: self.items, selection: self.$selection, title: { $0 })
    }
}

// MARK: - ToastDemoButton

/// Subview to read `\.toastHost` inside the scope where `.toastHost(edge:)` is applied.
/// Referenced by `ComponentMeta.all` via `demoAction` closure.
private struct ToastDemoButton: View {
    @Environment(\.toastHost) private var toast

    var body: some View {
        Button("Show Demo Toast") {
            self.toast?.show("Toast message", level: .info)
        }
        .buttonStyle(.solid(role: .primary))
    }
}

// MARK: - Phase 2 Container Previews

private struct CardPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Card {
                VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                    Text("Card 标题").coreFont(.headline)
                    Text("卡片浮于画布之上，深浅双模式都与背景拉开。")
                        .coreFont(.subheadline)
                        .foregroundStyle(Color.contentSecondary)
                }
            }
            Card(padding: CoreSpacing.md, alignment: .center) {
                Text("居中 + 紧凑内边距").coreFont(.subheadline)
            }
        }
    }
}

private struct SeparatorPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Text("贯穿").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
            Separator()
            Text("leading 缩进（58pt，对齐设置行标题）").coreFont(.footnote).foregroundStyle(Color.contentSecondary)
            Separator(inset: .leading(58))
        }
    }
}

private struct SectionHeaderFooterPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            SectionHeader("General")
            Card { Text("分组内容").coreFont(.body) }
            SectionFooter("Applies to all accounts on this device.")
        }
    }
}

private struct SettingsRowPreview: View {
    @State private var on = true
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: .init(systemName: "wifi", background: .blue),
                title: "Wi-Fi",
                subtitle: "HomeNetwork"
            ) {
                Text("On").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            Separator(inset: .leading(58))
            SettingsRow(
                icon: .init(systemName: "bell.badge.fill", background: .red),
                title: "Notifications"
            ) {
                Toggle("Notifications", isOn: self.$on).labelsHidden()
            }
            .tint(.green)
        }
        .background(Color.surfaceCard)
        .clipShape(CoreShape.rounded(CoreRadius.medium))
    }
}

private struct InsetGroupedSectionPreview: View {
    @State private var airplane = false
    var body: some View {
        InsetGroupedSection(header: "Connectivity", footer: "Airplane Mode disables Wi-Fi and Bluetooth.") {
            SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
                Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
            }
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
        }
        .tint(.green)
    }
}

private struct CoreProgressViewPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            ProgressView(value: 0.6, label: { Text("Downloading") }, currentValueLabel: { Text("60%") })
                .progressViewStyle(.core)
            ProgressView(value: 0.6)
                .progressViewStyle(.core)
                .tint(.red)
        }
    }
}

private struct CoreLabelPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Label("Sync", systemImage: "arrow.triangle.2.circlepath").labelStyle(.core)
            Label("Delete", systemImage: "trash.fill").labelStyle(.core).tint(.red)
        }
    }
}

private struct CoreDisclosureGroupPreview: View {
    @State private var expanded = true
    var body: some View {
        DisclosureGroup("Details", isExpanded: self.$expanded) {
            Text("Additional information goes here.").foregroundStyle(Color.contentSecondary)
        }
        .disclosureGroupStyle(.core)
        .tint(.red)
    }
}

// MARK: - SettingsRow in native List（AC9 验证）

/// SettingsRow 直接作原生 List 的行,配 .listRowInsets(EdgeInsets()) 清零 List 侧
/// inset,由 SettingsRow 独占 16pt 内边距——验证无双重 inset。
private struct SettingsRowInListDemo: View {
    @State private var on = true
    var body: some View {
        List {
            SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                SettingsRowChevron()
            }
            .listRowInsets(EdgeInsets())
            SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: "Notifications") {
                Toggle("Notifications", isOn: self.$on).labelsHidden()
            }
            .listRowInsets(EdgeInsets())
            .tint(.green)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Settings Screen Demo（Success Criteria #10）

/// 仅用 CoreDesign 组件复刻一屏 iOS 设置页——不写任何 CoreDesign 之外的样式代码。
private struct SettingsScreenDemo: View {
    @State private var airplane = false
    @State private var wifiOn = true
    @State private var bluetoothOn = true
    @State private var notificationsOn = true

    var body: some View {
        ScrollView {
            VStack(spacing: CoreSpacing.xl) {
                InsetGroupedSection {
                    SettingsRow(icon: .init(systemName: "airplane", background: .orange), title: "Airplane Mode") {
                        Toggle("Airplane Mode", isOn: self.$airplane).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "wifi", background: .blue), title: "Wi-Fi") {
                        Text("HomeNetwork").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "personalhotspot", background: .green), title: "Personal Hotspot") {
                        Text("Off").foregroundStyle(Color.contentSecondary)
                        SettingsRowChevron()
                    }
                }

                InsetGroupedSection(header: "Notifications", footer: "Choose how you receive alerts from apps.") {
                    SettingsRow(icon: .init(systemName: "bell.badge.fill", background: .red), title: "Notifications") {
                        Toggle("Notifications", isOn: self.$notificationsOn).labelsHidden()
                    }
                    SettingsRow(icon: .init(systemName: "speaker.wave.2.fill", background: .pink), title: "Sounds & Haptics") {
                        SettingsRowChevron()
                    }
                    SettingsRow(icon: .init(systemName: "moon.fill", background: .indigo), title: "Focus", subtitle: "Do Not Disturb") {
                        SettingsRowChevron()
                    }
                }
                .tint(.green)

                InsetGroupedSection(header: "About", dividerInset: .textAligned) {
                    SettingsRow(title: "Version") {
                        Text("0.4.0").foregroundStyle(Color.contentSecondary)
                    }
                    SettingsRow(title: "Legal") {
                        SettingsRowChevron()
                    }
                }
            }
            .padding()
        }
        .background(Color.surfaceCanvas)
    }
}

// MARK: - Phase 3 Previews（semi-mobile-components epic，0.7.0）

private struct FloatButtonPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(CoreShape.rounded(CoreRadius.medium))

            HStack(spacing: CoreSpacing.lg) {
                Button {} label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.extendedFloat(size: .regular))
                .foregroundStyle(.white)

                Button {} label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: CoreControlMetrics.iconSize(for: .regular), weight: .semibold))
                }
                .buttonStyle(.circularGlass(size: .regular))
                .foregroundStyle(.white)
            }
            .padding(CoreSpacing.xl)
        }
    }
}

private struct RatingPreview: View {
    @State private var value: Double = 3.5
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            Rating(value: self.$value, step: 0.5)
            Rating(value: .constant(4))
                .disabled(true)
        }
    }
}

private struct RatingDisplayPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.sm) {
            RatingDisplay(value: 4)
            RatingDisplay(value: 3.5)
        }
    }
}

private struct PinCodePreview: View {
    @State private var code = "12"
    var body: some View {
        PinCode(value: self.$code, length: 6)
    }
}

private struct RadioGroupPreview: View {
    @State private var selection = "pro"
    var body: some View {
        RadioGroup(
            selection: self.$selection,
            options: [
                RadioOption(value: "basic", title: "Basic"),
                RadioOption(value: "pro", title: "Pro"),
                RadioOption(value: "enterprise", title: "Enterprise"),
            ]
        )
    }
}

private struct TagInputPreview: View {
    @State private var tags: [String] = ["bug", "enhancement"]
    var body: some View {
        // Phase 3 / #173 视觉复查发现：默认 tagColor（.contentSecondary）经 Tag 的
        // `.opacity(0.12)` 背景公式，在暗色纯黑画布上对比度接近不可辨——这是 Tag 既有
        // 公式对中性色的固有表现，不是本次改动引入的缺陷（组件默认值本身不在本任务改动
        // 范围内）。画廊演示改用更有辨识度的 .blue，让暗色变体清晰可读；调用方仍可自由
        // 传入任意颜色，含中性色。
        TagInput(tags: self.$tags, placeholder: "Add tag", tagColor: .blue)
    }
}

private struct ProgressIndicatorGalleryPreview: View {
    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            ProgressIndicator()
                .controlSize(.regular)
            ProgressIndicator(text: "Loading…")
                .controlSize(.large)
        }
    }
}

private struct SkeletonPreview: View {
    @State private var isLoading = true
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            Toggle(isOn: self.$isLoading) { Text("isLoading") }
                .tint(Color.accent)
            Skeleton(isLoading: self.isLoading) {
                HStack(alignment: .top, spacing: CoreSpacing.md) {
                    SkeletonCircle(diameter: 40)
                    SkeletonLine(lineCount: 2)
                }
            } content: {
                HStack(alignment: .top, spacing: CoreSpacing.md) {
                    Circle().fill(Color.accent).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: CoreSpacing.xs) {
                        Text("王晓龙").coreFont(.subheadline)
                        Text("CoreDesign 维护者").coreFont(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct StepsPreview: View {
    static let items: [StepItem] = [
        StepItem(title: "Cart"),
        StepItem(title: "Shipping"),
        StepItem(title: "Payment"),
        StepItem(title: "Confirm"),
    ]
    // ⚠️ 设备端画廊是 `#Preview` 之外的**第二条**视觉通路，且是唯一跑在真机 / 模拟器上的
    // 那条（`swift test` 与 CI 都不构建 App/）。`#60` 新增的呈现必须在这里出现，否则它们在
    // 真机上零覆盖（PR #206 第 2 轮 review 抓到）。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Steps(items: Self.items, currentIndex: 1, axis: .horizontal, indicatorStyle: .numbered)
            Steps(items: Self.items, currentIndex: 2, presentation: .segmentedBar)
            Steps(items: Self.items, currentIndex: 1, presentation: .navigation)
            Steps(items: Self.items, currentIndex: 1, presentation: .text)
        }
    }
}

private struct TimelinePreview: View {
    private static var items: [TimelineItem] {
        [
            TimelineItem(status: .success) { Text("审核通过").coreFont(.callout) },
            TimelineItem(status: .warning) { Text("即将过期提醒").coreFont(.callout) },
            TimelineItem(status: .danger) { Text("处理失败").coreFont(.callout) },
        ]
    }

    // ⚠️ `.alternate` 与 `.horizontal` 的几何**只在渲染时可见**，`swift build` / `swift test`
    // 一定绿 —— 这条通路是它们在真机上唯一的检查点（PR #206 第 2 轮 review 抓到）。
    // `.alternate` 那条特意混入一个**宽内容**（固定 220pt），因为「节点恒在同一条中轴」
    // 恰恰是在内容固有宽度超过半槽时才会破。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Timeline(items: Self.items)
            Timeline(
                items: [
                    TimelineItem(status: .info) {
                        Color.statusAccentEmphasis.frame(width: 220, height: 32)
                    },
                    TimelineItem(status: .success) { Text("短").coreFont(.callout) },
                    TimelineItem(status: .warning) { Text("再一条").coreFont(.callout) },
                ],
                layout: .alternate
            )
            Timeline(items: Self.items, layout: .horizontal)
            Timeline(items: Self.items, layout: .grouped)
        }
    }
}

private struct CarouselPreviewItem: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

private struct CarouselPreview: View {
    private let cards: [CarouselPreviewItem] = [
        CarouselPreviewItem(id: 0, title: "第一页", color: .blue),
        CarouselPreviewItem(id: 1, title: "第二页", color: .purple),
        CarouselPreviewItem(id: 2, title: "第三页", color: .orange),
    ]
    var body: some View {
        Carousel(self.cards, autoAdvance: false) { item in
            CoreShape.rounded(CoreRadius.large)
                .fill(item.color.gradient)
                .overlay {
                    Text(item.title).coreFont(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                }
        }
        .frame(height: 120)
    }
}

private struct DescriptionsPreview: View {
    var body: some View {
        Descriptions(header: "Order") {
            LabeledContent("Status") { Text("Active") }
            LabeledContent("Total") { Text("$42.00") }
            LabeledContent("Placed") { Text("2026-07-20") }
        }
    }
}

private struct SpinningPreview: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: CoreSpacing.sm) {
                Text("卡片标题").coreFont(.headline)
                Text("被 spinning 遮罩覆盖时应保持自身尺寸不变。")
                    .coreFont(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
        }
        .spinning(true, text: "Refreshing…")
    }
}

private struct SpinningNonBlockingPreview: View {
    // ⚠️ `.topBar` 的扫条动画与 `.inline` 的几何只在渲染时可见（PR #206 第 2 轮 review）。
    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.lg) {
            Card {
                Text("topBar：顶边细条，内容不被遮罩、仍可交互").coreFont(.subheadline)
            }
            .spinning(true, presentation: .topBar)

            HStack(spacing: CoreSpacing.lg) {
                Text("保存中").coreFont(.callout).spinning(true, presentation: .inline)
                Text("已保存").coreFont(.callout).spinning(false, presentation: .inline)
            }
        }
    }
}

// MARK: - ShipSwift 动效与图表的画廊演示
//
// ⚠️ 本节全部是**可交互**的演示宿主，不是静态截图源：36 个动效里绝大多数只有在
// 值变化 / 插入删除的**那一瞬间**才有东西可看，静止帧与未加修饰的内容像素级相同。
// ⇒ 画廊（模拟器里点得动）才是这批 API 单位的真实评审面。

// MARK: 微交互：8 个 modifier 共用一个演示宿主

/// 8 个 `trigger:` 型微交互的共用宿主。
///
/// ⚠️ **`decorate` 收 `AnyView` 而不是泛型 `Content: View`**：8 个 modifier 的返回类型
/// 各不相同（`ModifiedContent<…, TriggerRelay<…>>` 各是一个具体类型），泛型闭包参数
/// 在调用点无法从 `{ view, fire in view.shake(trigger: fire) }` 反推出 `Content`。
/// 返回类型那一侧才是需要泛型的（`Decorated`），入参这侧擦除掉最省事。
private struct MicroInteractionDemo<Decorated: View>: View {
    let label: LocalizedStringKey
    let symbol: String
    let decorate: (AnyView, Int) -> Decorated

    @State private var fire = 0

    init(
        label: LocalizedStringKey,
        symbol: String,
        decorate: @escaping (AnyView, Int) -> Decorated
    ) {
        self.label = label
        self.symbol = symbol
        self.decorate = decorate
    }

    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            self.decorate(
                AnyView(
                    Image(systemName: self.symbol)
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                ),
                self.fire
            )
            .frame(height: 72)

            Button(self.label) { self.fire += 1 }
                .buttonStyle(.light(role: .primary))

            Text(verbatim: "trigger = \(self.fire)")
                .font(CoreTypography.Token.caption.font)
                .foregroundStyle(Color.contentSubtle)
        }
    }
}

// MARK: 转场：16 + 1 种共用一个演示宿主

/// 全部 `Transition` 入口点的共用宿主。
///
/// ⚠️ **必须由 `withAnimation` 驱动插入/删除**：`Transition` 只在视图**进出**时求值，
/// 光把它挂在一个常驻视图上什么都看不到。
private struct TransitionDemo<T: Transition>: View {
    let transition: T

    @State private var isShown = true

    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            ZStack {
                Color.clear.frame(height: 140)
                if self.isShown {
                    RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                        .fill(.tint)
                        .frame(width: 160, height: 110)
                        .overlay {
                            Text(verbatim: "Hello")
                                .font(CoreTypography.Token.headline.font)
                                .foregroundStyle(Color.surfaceCanvas)
                        }
                        .transition(self.transition)
                }
            }

            Button(self.isShown ? "移除" : "插入") {
                withAnimation(.easeInOut(duration: 0.8)) { self.isShown.toggle() }
            }
            .buttonStyle(.light(role: .primary))
        }
    }
}

// MARK: 庆祝与处理中 4 个

private struct ConfettiDemo: View {
    @State private var completed = 0

    var body: some View {
        VStack(spacing: CoreSpacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Button("完成一项") { self.completed += 1 }
                .buttonStyle(.light(role: .primary))
            Text(verbatim: "completed = \(self.completed)")
                .font(CoreTypography.Token.caption.font)
                .foregroundStyle(Color.contentSubtle)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .confetti(trigger: self.completed, strength: .pronounced)
    }
}

private struct ScanningOverlayDemo: View {
    var body: some View {
        ScanningOverlay {
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceRaised)
                .frame(height: 120)
                .overlay {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.contentMuted)
                }
        }
    }
}

private struct GlowSweepDemo: View {
    var body: some View {
        GlowSweep {
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceRaised)
                .frame(height: 100)
                .overlay {
                    Text("Thinking…").font(CoreTypography.Token.callout.font)
                }
        }
    }
}

private struct LightSweepDemo: View {
    var body: some View {
        LightSweep {
            RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                .fill(Color.surfaceRaised)
                .frame(height: 100)
                .overlay {
                    Text("Syncing…").font(CoreTypography.Token.callout.font)
                }
        }
    }
}

// MARK: 文本与展示 4 个

private struct TypewriterTextDemo: View {
    @State private var streamed = "流式文本走 verbatim init，不进本地化目录。"

    var body: some View {
        VStack(alignment: .leading, spacing: CoreSpacing.md) {
            TypewriterText("Welcome aboard", speed: .slow)
                .font(CoreTypography.Token.headline.font)
            TypewriterText(verbatim: self.streamed)
                .font(CoreTypography.Token.callout.font)
                .foregroundStyle(Color.contentSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnimatedMeshGradientDemo: View {
    var body: some View {
        AnimatedMeshGradient()
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous))
    }
}

private struct BeforeAfterSliderDemo: View {
    var body: some View {
        BeforeAfterSlider(labels: .shown(before: "Draft", after: "Final")) {
            ZStack {
                Color.secondaryFill
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.contentSubtle)
            }
        } after: {
            ZStack {
                Color.accentSubtleBackground
                Image(systemName: "photo.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous))
    }
}

// MARK: 跨平台改造 4 个

/// `OrbitingLogos` 的入参是**泛型集合 + `Identifiable`**（AD-E 重写后的形态），
/// 这里用画廊自己的模型类型接上，正是下游的用法。
private struct OrbitingBrand: Identifiable {
    let id: Int
    let symbol: String
}

private struct OrbitingLogosDemo: View {
    private static let brands = [
        OrbitingBrand(id: 0, symbol: "swift"),
        OrbitingBrand(id: 1, symbol: "applelogo"),
        OrbitingBrand(id: 2, symbol: "cloud.fill"),
        OrbitingBrand(id: 3, symbol: "bolt.fill"),
        OrbitingBrand(id: 4, symbol: "cube.fill"),
    ]

    var body: some View {
        OrbitingLogos(Self.brands) { brand in
            Image(systemName: brand.symbol)
                .font(.system(size: 18))
                .foregroundStyle(.tint)
        } center: {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.contentPrimary)
        }
        .frame(height: 220)
    }
}

private struct DotSphereDemo: View {
    var body: some View {
        DotSphere().frame(height: 200)
    }
}

private struct CharSphereDemo: View {
    var body: some View {
        CharSphere(["道", "德", "经", "S", "w", "i", "f", "t"])
            .frame(height: 200)
    }
}

private struct FullScreenButtonDemo: View {
    // ⚠️ 自带 `NavigationStack`：`navigationTransition(.zoom)` 要求源与目的地在**同一个**
    // 导航栈里，而画廊详情页把 preview 渲染两遍（Light / Dark）、本身不提供栈。
    var body: some View {
        NavigationStack {
            FullScreenButton {
                VStack(spacing: CoreSpacing.md) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text("展开后的全屏详情")
                        .font(CoreTypography.Token.headline.font)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surfaceCanvas)
            } label: {
                RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous)
                    .fill(Color.surfaceRaised)
                    .frame(height: 120)
                    .overlay {
                        Label("点开看看", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(CoreTypography.Token.callout.font)
                    }
            }
        }
        .frame(height: 200)
    }
}

// MARK: 四个图表

/// ⚠️ 三个图表的数据契约都是**泛型协议**，画廊按下游用法用自己的模型类型接上
/// （而不是库自带的具体 struct —— 那正是 `#255` 终审 I-7 要求避开的形态）。
private struct GalleryMetric: ChartValue {
    let id: Int
    let label: String
    let value: Double
}

private struct GalleryDay: HeatmapDay {
    let id: Int
    let date: Date
    let count: Int
}

private struct GalleryNode: GraphNode {
    let id: String
    let label: String
}

private struct RadarChartDemo: View {
    var body: some View {
        RadarChart([
            GalleryMetric(id: 0, label: "速度", value: 82),
            GalleryMetric(id: 1, label: "力量", value: 61),
            GalleryMetric(id: 2, label: "耐力", value: 94),
            GalleryMetric(id: 3, label: "技巧", value: 47),
            GalleryMetric(id: 4, label: "智力", value: 73),
        ])
        .frame(height: 220)
    }
}

private struct RingChartDemo: View {
    var body: some View {
        RingChart([
            GalleryMetric(id: 0, label: "活动", value: 420),
            GalleryMetric(id: 1, label: "锻炼", value: 28),
            GalleryMetric(id: 2, label: "站立", value: 9),
        ], goal: 500)
        .frame(height: 200)
    }
}

private struct ActivityHeatmapDemo: View {
    /// ⚠️ **锚定到固定日期而不是 `.now`**：`.now` 会让同一份代码每天渲出不同的日期标签
    /// ——库内那个 `#Preview` 用的正是 `.now`（视觉冒烟无所谓），而画廊要能横向对比。
    private static let anchor = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC

    private static let days: [GalleryDay] = (0..<120).map { offset in
        GalleryDay(
            id: offset,
            date: Self.anchor.addingTimeInterval(Double(offset) * 86_400),
            count: [0, 0, 1, 2, 3, 5, 8][offset % 7]
        )
    }

    var body: some View {
        ActivityHeatmap(Self.days).frame(height: 120)
    }
}

private struct NetworkGraphDemo: View {
    private static let nodes = (0..<14).map { GalleryNode(id: "n\($0)", label: "节点 \($0)") }
    private static let edges = (0..<20).map {
        GraphEdge(from: "n\($0 % 14)", to: "n\(($0 * 5 + 3) % 14)")
    }

    var body: some View {
        NetworkGraph(nodes: Self.nodes, edges: Self.edges).frame(height: 260)
    }
}

// MARK: - `shipswift-shaders` epic 的 9 个 API 单位（#284 的「预览宿主」切片）
//
// 另起分节而不并进 `shipSwiftEntries`，两条理由与那一节相同（见其注释）。
// 同样**有意不补** `App/Sources/Previews.swift` 的宿主 `#Preview`，判据见
// `SnapshotArtifactGuard`。
extension ComponentMeta {

    @MainActor static let shaderEntries: [ComponentMeta] = [
        // MARK: 自带内容的 6 个 View（#278 / #280）
        ComponentMeta(id: "shader-plasma", name: "Plasma", description: "等离子体背景；density 三档 × ShaderMotion 四档，tint 取调用方色", category: .shader) {
            ShaderStage { Plasma(density: .regular, motion: .regular) }
        },
        ComponentMeta(id: "shader-fractal-clouds", name: "FractalClouds", description: "分形噪声云层；density = soft / regular / turbulent", category: .shader) {
            ShaderStage { FractalClouds(density: .regular, motion: .calm) }
        },
        ComponentMeta(id: "shader-ink-smoke", name: "InkSmoke", description: "水墨扩散；density = faint / regular / heavy", category: .shader) {
            ShaderStage { InkSmoke(density: .regular, motion: .calm) }
        },
        ComponentMeta(id: "shader-liquid-chrome", name: "LiquidChrome", description: "液态金属条带；density = wide / regular / fine", category: .shader) {
            ShaderStage { LiquidChrome(density: .regular, motion: .regular) }
        },
        ComponentMeta(id: "shader-dot-grid", name: "DotGrid", description: "点阵背景；spacing = loose / regular / tight，motion .still 时完全静止", category: .shader) {
            ShaderStage { DotGrid(spacing: .regular, motion: .calm) }
        },
        ComponentMeta(id: "shader-glass-symbol", name: "GlassSymbol", description: "SF Symbol + 渐变背衬的折射玻璃；自带内容，故是 View 而非 modifier", category: .shader) {
            GlassSymbolDemo()
        },

        // MARK: 只重采样内容层的 3 个 modifier（#278 / #283）
        ComponentMeta(id: "shader-refractive-glass", name: ".refractiveGlass(...)", description: "折射玻璃罩：strength 三档，rim 描边默认取 .accent", category: .shader) {
            ShaderModifierDemo(labels: RefractiveGlassStrength.allCases.map { String(describing: $0) }) { content, index in
                content.refractiveGlass(strength: RefractiveGlassStrength.allCases[index])
            }
        },
        ComponentMeta(id: "shader-glass-orb", name: ".glassOrb(...)", description: "放大镜球：size 三档 × magnification 三档；焦点默认居中，可拖动（画廊页在 ScrollView 内，手势竞争未验证）", category: .shader) {
            ShaderModifierDemo(labels: GlassOrbSize.allCases.map { String(describing: $0) }) { content, index in
                content.glassOrb(size: GlassOrbSize.allCases[index], magnification: .strong)
            }
        },
        ComponentMeta(id: "shader-halftone", name: ".halftone(...)", description: "半调网屏：dot = fine / regular / coarse，ink / paper 可换色", category: .shader) {
            ShaderModifierDemo(labels: HalftoneDot.allCases.map { String(describing: $0) }, subject: .grayscale) { content, index in
                content.halftone(dot: HalftoneDot.allCases[index])
            }
        },
    ]
}

// MARK: - Shader 画廊宿主

/// 自带内容的 shader 是背景层，给一个固定高度的舞台即可。
private struct ShaderStage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        self.content
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous))
    }
}

/// modifier 族不产生内容，必须给一层被作用的内容。三档并排，便于对比。
private struct ShaderModifierDemo<Effected: View>: View {
    let labels: [String]
    /// `.halftone` 靠亮度阈值成像，要灰阶主体；另两条靠几何，用品牌色渐变更好看。
    var subject: ShaderDemoSubject = .brand
    @ViewBuilder let effect: (AnyView, Int) -> Effected

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            ForEach(Array(self.labels.enumerated()), id: \.offset) { index, label in
                self.effect(AnyView(self.subject.view), index)
                    .frame(height: 110)
                    // ⚠️ `layerEffect` 的绘制区按 `maxSampleOffset` 外扩，会溢出 `frame`：
                    // 不 clip 时三行连成一片、行距被填满（`.glassOrb` 实测最明显）。
                    .clipShape(RoundedRectangle(cornerRadius: CoreRadius.medium, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Text(label)
                            .font(CoreTypography.Token.caption.font.monospaced())
                            .foregroundStyle(Color.contentPrimary)
                            .padding(CoreSpacing.xs)
                    }
            }
        }
    }

}

/// 被 shader 作用的内容层。
private enum ShaderDemoSubject {
    case brand
    case grayscale

    @MainActor @ViewBuilder var view: some View {
        ZStack {
            switch self {
            case .brand:
                LinearGradient(colors: [.accent, .accentSubtleBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .grayscale:
                LinearGradient(colors: [.contentPrimary, .surfaceCanvas], startPoint: .leading, endPoint: .trailing)
            }
            Text(verbatim: "CoreDesign").font(.largeTitle.bold())
        }
    }
}

private struct GlassSymbolDemo: View {
    var body: some View {
        HStack(spacing: CoreSpacing.lg) {
            ForEach(Array(RefractiveGlassStrength.allCases.enumerated()), id: \.offset) { _, strength in
                VStack(spacing: CoreSpacing.xs) {
                    GlassSymbol("sparkles", strength: strength)
                        .frame(width: 88, height: 88)
                    Text(String(describing: strength))
                        .font(CoreTypography.Token.caption.font.monospaced())
                        .foregroundStyle(Color.contentSubtle)
                }
            }
        }
    }
}
