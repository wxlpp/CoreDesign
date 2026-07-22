//
//  Toast.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ToastItem

/// 单条 Toast 的数据载体。`ToastHost` 内部以 `[ToastItem]` 维护队列。
///
/// Sendable：所有字段皆为 Sendable 值类型；可在跨 actor 边界传递（譬如后台
/// 任务完成后 `await MainActor.run { host.show(item) }`）。
///
/// - `id`：每个 item 的 stable identity，由 `init` 默认生成；调用方一般不需要手传。
///   `dismiss(_:)` 通过该 id 精确定位排队中或正在显示的 item。
/// - `message`：toast 文本内容。当前实现固定单行 `Text`；多行 / 富文本未来扩展。
/// - `level`：见 `StatusLevel`。决定 icon + 前景色。
/// - `duration`：自动消失前的显示时长（秒）。**计时从 toast 开始显示起算**，
///   不是 enqueue 起算（详见 `ToastHost` 文档的 "dismiss timing" 段）。
public nonisolated struct ToastItem: Identifiable, Sendable {
    public let id: UUID
    public let message: String
    public let level: StatusLevel
    public let duration: TimeInterval

    /// 创建一条 ToastItem。
    ///
    /// - Parameters:
    ///   - id: stable identity；缺省时由 `UUID()` 生成。
    ///   - message: toast 文本。
    ///   - level: 语义等级，决定 icon 与前景色，缺省 `.info`。
    ///   - duration: 显示时长（秒），缺省 3 秒。计时从开始显示起算。
    public init(
        id: UUID = UUID(),
        message: String,
        level: StatusLevel = .info,
        duration: TimeInterval = ToastDefaults.duration
    ) {
        self.id = id
        self.message = message
        self.level = level
        self.duration = duration
    }
}

// MARK: - ToastDefaults

/// Toast 行为的默认值常量集合。集中此处避免 magic numbers 散落。
///
/// > Note: 这些是 toast 行为相关的默认值（duration / 动画时长），不是布局尺寸；
/// > 布局走 `CoreSpacing.*` / `CoreRadius.*` 等 token，与此处无关。
public nonisolated enum ToastDefaults {
    /// `ToastItem.init` / `ToastHost.show(_:level:duration:)` 的缺省 duration（秒）。
    /// 取 3 秒贴合 Apple HIG / Material Design 对短提示的常见取值。
    public static let duration: TimeInterval = 3

    /// dismiss 动画时长（秒）。状态机用此值等待动画完成后再渲染下一条。
    static let dismissAnimationDuration: TimeInterval = 0.25

    /// 滑动手势触发 dismiss 的位移阈值（pt）。
    /// 用 `CoreSpacing.xxl` (32) 而非裸 32：与设计 token 一致。
    static let swipeDismissThreshold: CGFloat = CoreSpacing.xxl

    /// 反方向拖拽阻尼系数。非 edge 方向拖拽时位移乘以 0.5，避免 toast 被拽到屏幕中央。
    static let reverseDragDamping: CGFloat = 0.5

    /// dismiss 动画滑出距离（pt）。朝 edge 方向滑出 60pt 后与 opacity 淡出叠加。
    static let dismissSlideDistance: CGFloat = 60
}

// MARK: - ToastHost

/// Scene 级的浮层 toast 队列与调度器。
/// 内部把每个 `ToastItem` 渲染为 `ToastView`，其容器在 `Capsule(style: .continuous)`
/// 外壳上施加 `View.floatingGlass(in:isInteractive:)`——让 toast 读起来像**浮起的
/// 系统反馈**，而不是内容自身的 chrome。公开 API（`show` / `dismiss`）与队列
/// state machine are unchanged.
///
/// **Material layer**: floating. **Surface role**: floating.
///
/// Scene-scoped Toast 宿主：维护 toast 队列状态机 + 自动 dismiss 调度。
///
/// ## 架构 / Architecture
///
/// 每个 scene 持有**独立**的 `ToastHost` 实例，通过 `EnvironmentValues.toastHost`
/// 注入到 view tree。**不是 singleton**——多 scene / sheet / 独立 window 各自隔离，
/// 避免状态耦合（譬如某个 sheet 内的 toast 出现在主 scene 顶部）。这是刻意的设计
/// 取舍：全局 singleton 虽然实现更简单，但会让不同 scene / sheet 的 toast 状态
/// 互相干扰，与"toast 应归属于触发它的那个上下文"的直觉相悖。
///
/// 调用方使用：
///
/// ```swift
/// // Scene root：挂 host
/// ContentView()
///     .toastHost(edge: .top)
///
/// // 子 view：从 environment 取出 host 触发 toast
/// struct DetailView: View {
///     @Environment(\.toastHost) private var toast
///     var body: some View {
///         Button("Save") {
///             toast?.show("Saved.", level: .success)
///         }
///     }
/// }
/// ```
///
/// ## 状态机 / State machine
///
/// - **dismiss timing**：`duration` 从 toast **开始显示**起算（**不是** enqueue），
///   通过 `Task.sleep(...) + cancel` 实现；每次切换 toast 前 `dismissTask?.cancel()`，
///   保证不 double-fire。
/// - **append 行为**：当前 toast 正在 dismiss 动画中时新 `show(...)` 进队列尾，
///   **不打断**、**不 replace**；正在显示时 `show(...)` 同样 append；空队列时
///   `show(...)` 立即开始显示。
/// - **dismiss 行为**：`dismiss(id)` 对**排队中**的 item 直接从队列移除；对**正在
///   显示**的 item 立即触发 dismiss 动画，动画完成后渲染下一条。
/// - **重复触发不 double-fire**：连续 `dismiss(id)` 不引发崩溃 / 重复动画
///   （由 `dismissTask` 单实例 + 状态判断保证）。
///
/// ## z-order 限制
///
/// `safeAreaInset(edge:)` 仅在挂 `.toastHost(edge:)` 那层 view 树内可见；**不**
/// 覆盖 sheet / `fullScreenCover` / 独立 window。每个 sheet root 需单独挂
/// `.toastHost(...)` 才能让 sheet 内触发的 toast 显示。这是 scene-scoped 架构
/// 的直接后果——singleton 全局覆盖**不被采纳**（见上方"架构"一节的取舍说明）。
///
/// Swift 6 strict concurrency：
///
/// `@MainActor` 隔离保证 `[ToastItem]` 队列与 `dismissTask` 句柄的所有读写都在
/// 主 actor；`@Observable` 自动生成的 keypath observation 同样运行在主 actor。
/// 类型本身**不需要** `Sendable` 显式约束（`@MainActor` 已隐式提供线程安全）。
///
/// 暗色模式行为：内部 `ToastView` 使用 `.floatingGlass(in: Capsule(style: .continuous),
/// isInteractive: false)`（玻璃材质 + strokeBorder overlay 自动 light/dark 适配），
/// floating 层不再叠加独立阴影。
@MainActor
@Observable
public final class ToastHost {
    /// 当前队列。约定：
    /// - `queue.first` 即正在显示的 toast（如果非空且非 dismiss 中）。
    /// - 视图层渲染时只读取 `queue.first`，渲染单条。
    public private(set) var queue: [ToastItem] = []

    /// 当前 toast 是否正处于 dismiss 动画中。`true` 时新 `show(...)` append 到队尾，
    /// 不打断当前正在退场的 toast；动画完成后 `advance()` 取下一条。
    public private(set) var isDismissing: Bool = false

    /// 持有当前 sleep + dismiss 调度任务。重新调度前必须 `cancel()` 已存在的句柄，
    /// 避免上一条 toast 的 sleep 倒计时触发本条的 dismiss（double-fire）。
    private var dismissTask: Task<Void, Never>?

    /// 创建一个新的 ToastHost。每个 scene 应持有独立实例；不要共享。
    ///
    /// host 释放时，pending 的 scheduleDismiss / beginDismissCurrent task 通过
    /// `[weak self]` 捕获自动变为 nil，guard 会提前返回。短 duration toast 下
    /// `Task.sleep` 的短暂残留开销可忽略。
    public init() {}

    // MARK: Public API

    /// 入队一条 toast（便利重载）。语义等同 `show(ToastItem(message:level:duration:))`。
    ///
    /// - Parameters:
    ///   - message: toast 文本。
    ///   - level: 语义等级，缺省 `.info`。
    ///   - duration: 显示时长（秒），缺省 `ToastDefaults.duration` (3s)；计时从开始显示起算。
    public func show(
        _ message: String,
        level: StatusLevel = .info,
        duration: TimeInterval = ToastDefaults.duration
    ) {
        self.show(ToastItem(message: message, level: level, duration: duration))
    }

    /// 入队一条预构造的 ToastItem。
    ///
    /// 状态机：
    /// - 队列空且未 dismiss 中 → 立即开始显示（append + 启动 dismiss 倒计时）。
    /// - 已有 toast 显示中 / dismiss 动画中 → append 到队尾，等待轮到。
    public func show(_ item: ToastItem) {
        let wasIdle = self.queue.isEmpty && !self.isDismissing
        self.queue.append(item)
        if wasIdle {
            // 空队列 → 立即开始 dismiss 倒计时（计时从此刻起算 = "开始显示"）。
            self.scheduleDismiss(for: item)
        }
        // 否则：当前 toast 正在显示或 dismiss 中，新 item 在队尾等待 advance() 取出。
    }

    /// dismiss 指定 id 的 toast。
    ///
    /// - 若 id 对应**正在显示**的 toast（`queue.first`）：cancel 倒计时 + 触发
    ///   dismiss 动画，动画完成后 `advance()` 渲染下一条。
    /// - 若 id 对应**排队中**的 toast：直接从队列移除，不影响当前显示。
    /// - 若 id 不在队列中：no-op（重复 dismiss 不崩溃 / 不重复动画）。
    public func dismiss(_ id: ToastItem.ID) {
        guard let index = self.queue.firstIndex(where: { $0.id == id }) else { return }
        if index == 0, !self.isDismissing {
            // 正在显示的那条 → 走完整 dismiss 动画路径。
            self.beginDismissCurrent()
        } else if index > 0 {
            // 排队中的 → 直接移除。
            self.queue.remove(at: index)
        }
        // index == 0 && isDismissing：已经在 dismiss 动画中，no-op（重复 dismiss 保护）。
    }

    // MARK: State machine

    /// 启动 / 重置 dismiss 倒计时。每次切换"当前显示项"前必须调用以保证
    /// 上一条 sleep 句柄被 cancel。
    private func scheduleDismiss(for item: ToastItem) {
        self.dismissTask?.cancel()
        self.dismissTask = Task { [weak self] in
            // Task.sleep 在 cancel 时 throw CancellationError，吞掉即可；非取消异常
            // 当前 API 不会触发（Duration 入参合法），保持 Task<Void, Never> 签名。
            try? await Task.sleep(for: .seconds(item.duration))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            // 验证仍是这条 toast 在显示（防御：dismiss(id:) 已先一步触发动画的边缘情况）。
            guard self.queue.first?.id == item.id, !self.isDismissing else { return }
            self.beginDismissCurrent()
        }
    }

    /// 开始 dismiss 当前正在显示的 toast：cancel 倒计时 → 标记 dismissing →
    /// 等待动画时长 → 移除该 item → 重置 dismissing → 调 `advance()` 取下一条。
    private func beginDismissCurrent() {
        guard let current = self.queue.first, !self.isDismissing else { return }
        self.dismissTask?.cancel()
        self.isDismissing = true
        // 用同一个 dismissTask 句柄持有"等待动画完成"的任务，便于统一 cancel 模型；
        // 若动画期间被 cancel（譬如 ToastHost 释放），自然中断后续状态变更。
        self.dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            // 二次确认：动画期间没被替换 / 移除掉。
            if self.queue.first?.id == current.id {
                self.queue.removeFirst()
            }
            self.isDismissing = false
            self.dismissTask = nil  // 先置空避免 advance → scheduleDismiss 自 cancel
            self.advance()
        }
    }

    /// 推进队列：当前若有下一条 item，启动其 dismiss 倒计时（= "开始显示"语义）。
    private func advance() {
        guard let next = self.queue.first else {
            self.dismissTask = nil
            return
        }
        self.scheduleDismiss(for: next)
    }
}

// MARK: - EnvironmentValues

extension EnvironmentValues {
    /// 当前 scene 的 `ToastHost`；未挂 `.toastHost(edge:)` modifier 时为 `nil`。
    ///
    /// 调用方读取后建议链式可选调用：
    ///
    /// ```swift
    /// @Environment(\.toastHost) private var toast
    /// // ...
    /// toast?.show("Saved.", level: .success)
    /// ```
    ///
    /// 设计取舍：默认 `nil` 而非懒加载 stub host——
    /// scene 没挂 host 时调用方应"无声忽略"，避免 stub 静默吞掉 toast 让人误以为
    /// host 已生效。Debug 构建可在调用点显式 `assert(toast != nil)` 提前发现错配。
    ///
    /// 显式 `public` 标注在 var 上（而不是仅靠 `public extension` 推导）：后者
    /// 由 `@Entry` 宏展开时是否继承公开访问级别是隐式行为，显式声明消除歧义
    /// 并保证下游模块可访问 `@Environment(\.toastHost)`。
    @Entry public var toastHost: ToastHost? = nil
}

// MARK: - View.toastHost

public extension View {
    /// 在当前 view 子树挂载一个 scene-scoped `ToastHost`，并在 `edge` 方向以
    /// `safeAreaInset` 渲染当前队列的首条 toast。
    ///
    /// 调用示例：
    ///
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///                 .toastHost(edge: .top)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// z-order 限制（**重要**）：
    ///
    /// `safeAreaInset` 仅在**挂 modifier 那层 view 树**内可见；不会覆盖 sheet /
    /// `fullScreenCover` / 独立 window。需要在 sheet 内显示 toast 时，**在 sheet
    /// 的 root view 单独挂一份** `.toastHost(...)`，使用独立的 host 实例。
    /// 这是 scene-scoped 架构的直接后果（见 `ToastHost` 的"架构"一节），
    /// singleton 全局覆盖不被采纳。
    ///
    /// - Parameter edge: toast 显示位置，缺省 `.top`。
    /// - Returns: 已挂载 host 的视图。
    func toastHost(edge: VerticalEdge = .top) -> some View {
        self.modifier(ToastHostModifier(edge: edge))
    }
}

// MARK: - ToastHostModifier

/// 内部 modifier：持有 `ToastHost` 实例 + 注入 environment + 经 `safeAreaInset`
/// 在 `edge` 方向渲染队列首条 toast。
private struct ToastHostModifier: ViewModifier {
    @State private var host = ToastHost()
    let edge: VerticalEdge

    func body(content: Content) -> some View {
        content
            .environment(\.toastHost, self.host)
            .safeAreaInset(edge: self.edge, spacing: CoreSpacing.none) {
                ToastOverlay(host: self.host, edge: self.edge)
            }
    }
}

// MARK: - ToastOverlay

/// 监听 `host.queue` 与 `host.isDismissing`，按状态机渲染当前显示项；空队列时
/// 返回零尺寸 view，避免 `safeAreaInset` 永久抢占 16pt 内边距导致内容被挤压——
/// 若无论队列是否为空都施加 `.padding(.top/.bottom, lg)`，会引发视觉回归。
private struct ToastOverlay: View {
    @Bindable var host: ToastHost
    let edge: VerticalEdge

    var body: some View {
        Group {
            if let current = self.host.queue.first {
                ToastView(
                    item: current,
                    edge: self.edge,
                    isDismissing: self.host.isDismissing,
                    onDismiss: { self.host.dismiss(current.id) }
                )
                .transition(self.transition)
                .id(current.id)
                .padding(.horizontal, CoreSpacing.lg)
                .padding(self.edge == .top ? .top : .bottom, CoreSpacing.lg)
                .frame(maxWidth: .infinity)
            } else {
                // 空队列 → 零尺寸占位，让 safeAreaInset 不抢占布局空间。
                Color.clear.frame(height: 0)
            }
        }
        .animation(.easeInOut(duration: ToastDefaults.dismissAnimationDuration), value: self.host.queue.first?.id)
        .animation(.easeInOut(duration: ToastDefaults.dismissAnimationDuration), value: self.host.isDismissing)
    }

    /// 入场 / 出场动画：从 edge 方向滑入 + 淡入。
    private var transition: AnyTransition {
        let move: Edge = self.edge == .top ? .top : .bottom
        return .asymmetric(
            insertion: .move(edge: move).combined(with: .opacity),
            removal: .move(edge: move).combined(with: .opacity)
        )
    }
}

// MARK: - ToastView

/// 单条 toast 的渲染单元（internal）：icon + message + 容器装饰 + dismiss 触发。
///
/// 视觉 token：
/// - 容器：`.floatingGlass(in: Capsule(style: .continuous), isInteractive: false)`
///   浮动玻璃层，自带 strokeBorder overlay + 玻璃材质，pill 几何让 toast 读起来是系统反馈。
/// - 字号：`.coreFont(.callout)`
/// - icon / 前景色：按 `StatusLevel` 走 status color token
/// - padding：`CoreSpacing.md` 内边距
///
/// dismiss 触发：自动 / 滑动手势（向 edge 方向，阈值 `ToastDefaults.swipeDismissThreshold`）/
/// 点击。
private struct ToastView: View {
    let item: ToastItem
    let edge: VerticalEdge
    let isDismissing: Bool
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = .zero

    var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            self.icon
                .foregroundStyle(self.foregroundColor)
                .accessibilityHidden(true)
            Text(self.item.message)
                .coreFont(.callout)
                .foregroundStyle(Color.contentPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
            Spacer(minLength: CoreSpacing.none)
        }
        .accessibilityElement(children: .combine)
        // toast 整体可点击 dismiss，应当对 VoiceOver 暴露为 button + hint，
        // 而不是误标 `.isStaticText`——后者会告诉 VO 元素不可交互，但实际
        // onTapGesture 会触发 dismiss。
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Tap to dismiss", bundle: .module))
        .padding(CoreSpacing.md)
        .floatingGlass(
            in: Capsule(style: .continuous),
            isInteractive: false
        )
        .offset(y: self.isDismissing ? self.dismissOffset : self.dragOffset)
        .opacity(self.isDismissing ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { self.onDismiss() }
        .gesture(self.swipeGesture)
        .allowsHitTesting(!self.isDismissing)
    }

    // MARK: visuals

    private var icon: Image {
        switch self.item.level {
        case .info: Image(systemName: "info.circle")
        case .success: Image(systemName: "checkmark.circle")
        case .warning: Image(systemName: "exclamationmark.triangle")
        case .danger: Image(systemName: "exclamationmark.octagon")
        }
    }

    private var foregroundColor: Color {
        switch self.item.level {
        case .info: .statusAccentForeground
        case .success: .statusSuccessForeground
        case .warning: .statusAttentionForeground
        case .danger: .statusDangerForeground
        }
    }

    // MARK: gestures

    /// 向 edge 方向滑动超过阈值即 dismiss。`.top` host → 向上滑（dy < 0）；
    /// `.bottom` host → 向下滑（dy > 0）。
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let dy = value.translation.height
                // 只允许朝 edge 方向跟手；反方向用 damping 避免拽到屏幕中央。
                self.dragOffset = self.allowsDrag(dy) ? dy : dy * ToastDefaults.reverseDragDamping
            }
            .onEnded { value in
                let dy = value.translation.height
                let pastThreshold = abs(dy) >= ToastDefaults.swipeDismissThreshold
                if pastThreshold, self.allowsDrag(dy) {
                    self.onDismiss()
                }
                self.dragOffset = .zero
            }
    }

    /// dy 是否朝 edge 方向（top → 向上 = dy < 0；bottom → 向下 = dy > 0）。
    private func allowsDrag(_ dy: CGFloat) -> Bool {
        switch self.edge {
        case .top: dy <= 0
        case .bottom: dy >= 0
        }
    }

    /// dismiss 动画的目标偏移量：朝 edge 方向滑出。
    private var dismissOffset: CGFloat {
        switch self.edge {
        case .top: -ToastDefaults.dismissSlideDistance
        case .bottom: ToastDefaults.dismissSlideDistance
        }
    }
}

// MARK: - Previews

#Preview("Toast — Light") {
    ToastPreviewHarness()
        .preferredColorScheme(.light)
}

#Preview("Toast — Dark") {
    ToastPreviewHarness()
        .preferredColorScheme(.dark)
}

private struct ToastPreviewHarness: View {
    var body: some View {
        ToastDemoView()
            .toastHost(edge: .top)
    }
}

private struct ToastDemoView: View {
    @Environment(\.toastHost) private var toast

    private let levels: [(label: String, level: StatusLevel)] = [
        ("Info", .info),
        ("Success", .success),
        ("Warning", .warning),
        ("Danger", .danger),
    ]

    var body: some View {
        VStack(spacing: CoreSpacing.md) {
            Text("Tap a button to enqueue a toast.")
                .coreFont(.callout)
                .foregroundStyle(Color.contentMuted)
            ForEach(self.levels, id: \.label) { entry in
                Button(entry.label) {
                    self.toast?.show("\(entry.label): demo message", level: entry.level)
                }
            }
            Button("Burst (queue all 4)") {
                for entry in self.levels {
                    self.toast?.show("\(entry.label) queued.", level: entry.level)
                }
            }
        }
        .padding(CoreSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCanvas)
    }
}
