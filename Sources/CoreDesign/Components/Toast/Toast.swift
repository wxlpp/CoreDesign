import SwiftUI

// MARK: - ToastItem

/// 单条 Toast 的数据载体。`ToastHost` 内部以 `[ToastItem]` 维护队列。
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

// MARK: - ToastPresentation

/// `Toast` 的**呈现形态**（公约 §2 形态 D2「配置枚举」，`wxlpp/oh-my-story#65`）。
public enum ToastPresentation: Sendable, Equatable, CaseIterable {
    /// 现状形态：`safeAreaInset` 贴边 + `Capsule` 几何 + 水平内边距，读起来像系统反馈。
    case floatingCapsule
    /// 全宽横幅条（Android Snackbar / in-app banner）：贴边、横跨屏幕宽度、非胶囊。
    case fullWidthBanner
    /// 居中 HUD（经典 UIKit toast/HUD）：浮于屏幕中央而非贴边，宽度收缩为内容宽。
    /// ⚠️ 本形态下 `edge` 不生效。
    case centeredHUD
}

// MARK: - ToastDefaults

/// Toast 行为的默认值常量集合。集中此处避免 magic numbers 散落。
public nonisolated enum ToastDefaults {
    /// `ToastItem.init` / `ToastHost.show(_:level:duration:)` 的缺省 duration（秒）。
    /// 取 3 秒贴合 Apple HIG / Material Design 对短提示的常见取值。
    public static let duration: TimeInterval = 3

    static let dismissAnimationDuration: TimeInterval = 0.25

    static let swipeDismissThreshold: CGFloat = CoreSpacing.xxl

    static let reverseDragDamping: CGFloat = 0.5

    static let dismissSlideDistance: CGFloat = 60
}

// MARK: - ToastHost

/// Scene 级的浮层 toast 队列与调度器，外壳形状由 `ToastPresentation` 三选一。
@MainActor
@Observable
public final class ToastHost {
    /// 当前队列；`queue.first` 是正在显示的那条，视图层只渲染它。
    public private(set) var queue: [ToastItem] = []

    /// 当前 toast 是否正处于 dismiss 动画中。`true` 时新 `show(...)` append 到队尾，
    /// 不打断当前正在退场的 toast；动画完成后 `advance()` 取下一条。
    public private(set) var isDismissing: Bool = false

    private var dismissTask: Task<Void, Never>?

    /// 创建一个新的 ToastHost。每个 scene 应持有独立实例；不要共享。
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
    public func show(_ item: ToastItem) {
        let wasIdle = self.queue.isEmpty && !self.isDismissing
        self.queue.append(item)
        if wasIdle {
            self.scheduleDismiss(for: item)
        }
    }

    /// dismiss 指定 id 的 toast。
    public func dismiss(_ id: ToastItem.ID) {
        guard let index = self.queue.firstIndex(where: { $0.id == id }) else { return }
        if index == 0, !self.isDismissing {
            self.beginDismissCurrent()
        } else if index > 0 {
            self.queue.remove(at: index)
        }
    }

    // MARK: State machine

    private func scheduleDismiss(for item: ToastItem) {
        self.dismissTask?.cancel()
        self.dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(item.duration))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard self.queue.first?.id == item.id, !self.isDismissing else { return }
            self.beginDismissCurrent()
        }
    }

    private func beginDismissCurrent() {
        guard let current = self.queue.first, !self.isDismissing else { return }
        self.dismissTask?.cancel()
        self.isDismissing = true
        self.dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ToastDefaults.dismissAnimationDuration))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.queue.first?.id == current.id {
                self.queue.removeFirst()
            }
            self.isDismissing = false
            self.dismissTask = nil
            self.advance()
        }
    }

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
    @Entry public var toastHost: ToastHost? = nil
}

// MARK: - View.toastHost

public extension View {
    /// 在当前 view 子树挂载一个 scene-scoped `ToastHost`，并在 `edge` 方向以
    /// `safeAreaInset` 渲染当前队列的首条 toast。
    ///
    /// - Parameters:
    ///   - edge: toast 显示位置，缺省 `.top`。
    ///     ⚠️ **`presentation` 为 `.centeredHUD` 时本参数不生效**（居中浮层无「贴哪边」
    ///     可言）。这是有意的静默，不加运行期断言——详见 `ToastPresentation`。
    ///   - presentation: 呈现形态，缺省 `.floatingCapsule`（现状形态）
    ///     ⇒ **现有调用方零影响**。
    /// - Returns: 已挂载 host 的视图。
    func toastHost(
        edge: VerticalEdge = .top,
        presentation: ToastPresentation = .floatingCapsule
    ) -> some View {
        self.modifier(ToastHostModifier(edge: edge, presentation: presentation))
    }
}

// MARK: - ToastHostModifier

struct ToastHostModifier: ViewModifier {
    @State private var host: ToastHost
    let edge: VerticalEdge
    let presentation: ToastPresentation

    init(host: ToastHost? = nil, edge: VerticalEdge, presentation: ToastPresentation) {
        self._host = State(initialValue: host ?? ToastHost())
        self.edge = edge
        self.presentation = presentation
    }

    func body(content: Content) -> some View {
        let base = content.environment(\.toastHost, self.host)
        if self.presentation == .centeredHUD {
            base.overlay(alignment: .center) {
                ToastOverlay(host: self.host, edge: self.edge, presentation: self.presentation)
            }
        } else {
            base.safeAreaInset(edge: self.edge, spacing: CoreSpacing.none) {
                ToastOverlay(host: self.host, edge: self.edge, presentation: self.presentation)
            }
        }
    }
}

// MARK: - ToastOverlay

struct ToastOverlay: View {
    @Bindable var host: ToastHost
    let edge: VerticalEdge
    let presentation: ToastPresentation

    var body: some View {
        Group {
            if let current = self.host.queue.first {
                ToastView(
                    item: current,
                    edge: self.edge,
                    presentation: self.presentation,
                    isDismissing: self.host.isDismissing,
                    onDismiss: { self.host.dismiss(current.id) }
                )
                .transition(self.transition)
                .id(current.id)
                .padding(.horizontal, self.horizontalPadding)
                .padding(self.edge == .top ? .top : .bottom, self.edgePadding)
                .frame(maxWidth: self.presentation == .centeredHUD ? nil : .infinity)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .animation(.easeInOut(duration: ToastDefaults.dismissAnimationDuration), value: self.host.queue.first?.id)
        .animation(.easeInOut(duration: ToastDefaults.dismissAnimationDuration), value: self.host.isDismissing)
    }

    private var horizontalPadding: CGFloat {
        self.presentation == .fullWidthBanner ? CoreSpacing.none : CoreSpacing.lg
    }

    private var edgePadding: CGFloat {
        self.presentation == .floatingCapsule ? CoreSpacing.lg : CoreSpacing.none
    }

    private var transition: AnyTransition {
        if self.presentation == .centeredHUD {
            return .scale(scale: 0.92).combined(with: .opacity)
        }
        let move: Edge = self.edge == .top ? .top : .bottom
        return .asymmetric(
            insertion: .move(edge: move).combined(with: .opacity),
            removal: .move(edge: move).combined(with: .opacity)
        )
    }
}

// MARK: - ToastView

private struct ToastContainerDecoration: ViewModifier {
    let presentation: ToastPresentation

    @ViewBuilder
    func body(content: Content) -> some View {
        switch self.presentation {
        case .floatingCapsule:
            content.floatingGlass(in: Capsule(style: .continuous), isInteractive: false)
        case .fullWidthBanner:
            content.floatingGlass(in: Rectangle(), isInteractive: false)
        case .centeredHUD:
            content.floatingGlass(
                in: RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous),
                isInteractive: false
            )
        }
    }
}

struct ToastView: View {
    let item: ToastItem
    let edge: VerticalEdge
    let presentation: ToastPresentation
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
            if self.presentation != .centeredHUD {
                Spacer(minLength: CoreSpacing.none)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Tap to dismiss", bundle: .module))
        .padding(CoreSpacing.md)
        .modifier(ToastContainerDecoration(presentation: self.presentation))
        .offset(y: self.verticalOffset)
        .scaleEffect(self.presentation == .centeredHUD && self.isDismissing ? 0.92 : 1)
        .opacity(self.isDismissing ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { self.onDismiss() }
        .gesture(self.swipeGesture, including: self.presentation == .centeredHUD ? .subviews : .all)
        .allowsHitTesting(!self.isDismissing)
    }

    private var verticalOffset: CGFloat {
        if self.presentation == .centeredHUD {
            return self.isDismissing ? .zero : self.dragOffset
        }
        return self.isDismissing ? self.dismissOffset : self.dragOffset
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

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let dy = value.translation.height
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

    private func allowsDrag(_ dy: CGFloat) -> Bool {
        switch self.edge {
        case .top: dy <= 0
        case .bottom: dy >= 0
        }
    }

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
