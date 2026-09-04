//
//  FullScreenButton.swift
//  CoreDesignEffects
//
//  卡片放大成整屏的按钮 / A card that expands into a full-screen destination.
//

import CoreDesign
import SwiftUI

/// 一张可点的卡片，点开时**几何匹配地放大成整屏**——App Store / 照片 / 音乐里
/// 那种"卡片自己长成一页"的效果，而不是从底部滑上来一个模态。
///
/// ```swift
/// NavigationStack {
///     FullScreenButton {
///         ArticleDetail(article)          // 目的地
///     } label: {
///         ArticleCard(article)            // collapsed 状态的卡片
///     }
/// }
/// ```
///
/// ⚠️ **必须包在 `NavigationStack` 里**：它本体是一个 `NavigationLink`。
/// 不在导航容器里时点击无效（SwiftUI 的既有行为，本件不另加断言——库代码
/// 对宿主结构抛断言就是让宿主 App crash）。
///
/// ## ⚠️⚠️ 平台支持（AD-E）：**四件里唯一走"隔离 + 文档标注"的一件**
///
/// | 平台 | 转场 |
/// |---|---|
/// | iOS | `.navigationTransition(.zoom(sourceID:in:))` —— 几何匹配放大 |
/// | macOS | **系统默认推入转场**（`.zoom` 在 macOS 上不可用） |
///
/// 实测编译错误逐字：`'zoom(sourceID:in:)' is unavailable in macOS`
/// ——它不是"macOS 上没效果"，是**编译不过**。⇒ `#if os(iOS)` 只包住
/// `.navigationTransition(.zoom(...))` 那一行；其余（`NavigationLink`、
/// `matchedTransitionSource(id:in:)`、按钮样式、a11y）两端**完全一致**，
/// 且 `matchedTransitionSource` 本身在 macOS 上编译得过（实测），
/// 留着它是为了将来 Apple 补上 macOS 的 zoom 时只需删掉那道 `#if`。
///
/// ⇒ **macOS 上本件仍然可用**：卡片照常可点、目的地照常推入，
/// 差别只在"放大"这一层观感。这条限制同时写在 `docs/components/full-screen-button.md`
/// 里（AD-E 第 2 轮评审 S-2：平台限制不能只活在代码的 `#if` 里，调用方看不见）。
///
/// ## ⚠️⚠️ 已知限度：zoom 转场**零运行期证据**（PR #274 终审 S-6）
///
/// 本仓在 macOS 上开发，`.zoom` 那条分支在 macOS 单测里**结构上不可达**：
/// `FullScreenTransitionPlanTests` 钉的是纯函数的真值表、`zoomIsFencedToIOS` 钉的是
/// 围栏形态、`fullScreenButtonRenders` 只断言折叠态卡片非空白。
/// ⇒ **"iOS 上 zoom 真的触发了"这件事目前只由"它能编译"背书**，没有任何判据看得见它。
/// 需要人工在 iOS 模拟器上确认一次（并把结论写回本节）：点开卡片是否真的几何放大成整屏。
/// 若不是，本件在 iOS 上会静默退化成普通 push，而**全套判据仍然绿**。
///
/// ## Reduce Motion
///
/// `.zoom` 是一次几何放大（卡片长到整屏），正是 FR-11 要去掉的那类运动
/// ⇒ 开启"减弱动态效果"时**两端都退到系统默认转场**。
/// ⚠️ 不是 no-op：目的地照常推入，用户仍然知道"换页了"。
/// 裁决点是纯函数 `FullScreenTransitionPlan.resolve(reduceMotion:platformSupportsZoom:)`
/// ——**唯一**一处判定，判据 `FullScreenTransitionPlanTests` 逐条钉住四种输入组合。
///
/// ## a11y（FR-13）
///
/// 本件是**交互控件**，不是装饰层 ⇒ **不** `accessibilityHidden`。
/// 它对外的可访问性完全由调用方的 `label` 提供（`NavigationLink` 会把 label
/// 的语义原样带上）：需要 VoiceOver 读出"打开某某"的，请在自己的 label 上写
/// `.accessibilityLabel(_:)`。**本件不代劳、也不猜文案**（FR-7：组件不自带 UI 文案）。
public struct FullScreenButton<Label: View, Destination: View>: View {

    /// `matchedTransitionSource` 的 id。每个实例有自己的 `@Namespace`
    /// ⇒ 同一个常量在多个实例之间不会串。
    static var sourceID: String { "coredesign.fullScreenButton" }

    private let destination: () -> Destination
    private let label: Label

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - destination: 展开后的整屏内容。
    ///   - label: collapsed 状态下的卡片。
    public init(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.destination = destination
        self.label = label()
    }

    public var body: some View {
        let plan = FullScreenTransitionPlan.resolve(
            reduceMotion: self.reduceMotion,
            platformSupportsZoom: FullScreenTransitionPlan.platformSupportsZoom
        )
        NavigationLink {
            // ⚠️ `sourceID` **由这里传下去**，目的地不再自己去取（Copilot #3930970767）：
            // 上一版写的是 `FullScreenButton<EmptyView, EmptyView>.sourceID`，
            // 它依赖"泛型类型的静态成员与泛型实参无关"这个**隐含前提**。Swift 的泛型
            // 静态成员是**按具体特化分开**的 ⇒ 一旦 `sourceID` 变成存储属性、或它的值
            // 开始依赖 `Label` / `Destination`，label 侧与 destination 侧就会拿到
            // 两个不同的 id，zoom 静默退化成普通 push，而**编译不报错、测试不变红**。
            FullScreenButtonDestination(plan: plan, sourceID: Self.sourceID, namespace: self.namespace) {
                self.destination()
            }
        } label: {
            // ⚠️ `matchedTransitionSource` 施加在 **label 构建器内部的 label 上**，
            // 这与 Apple 文档给的形态逐字一致（`NavigationLink { Detail().navigationTransition(...) }
            // label: { Image(...).matchedTransitionSource(id:in:) }`），不是本仓的发挥。
            self.label
                .matchedTransitionSource(id: Self.sourceID, in: self.namespace)
        }
        // 卡片自己就是外观，不要系统按钮样式再套一层。
        .buttonStyle(.plain)
    }
}

// MARK: - 目的地

/// 把转场裁决落到目的地上。**`#if` 只在这里出现一次。**
///
/// ⚠️ 写成独立类型而不是就地 `@ViewBuilder`：`plan` 是一个值，
/// `PlatformSupportGuard.zoomIsFencedToIOS` 要能在源码里看见"`.zoom(` 只出现在
/// `#if os(iOS)` 里面"这件事，把它挤在一长串链式调用中间既读不清也扫不准。
struct FullScreenButtonDestination<Content: View>: View {

    let plan: FullScreenTransitionPlan
    /// ⚠️ **由 `FullScreenButton` 传进来，不在这里跨泛型特化去取**——理由见调用点。
    let sourceID: String
    let namespace: Namespace.ID
    @ViewBuilder let content: Content

    var body: some View {
        // ⚠️ `.plain` 分支不是"什么都不做"——它就是系统默认的推入转场，
        // 也是 macOS 与 Reduce Motion 下的正常形态。
        if self.plan == .zoom {
            #if os(iOS)
            self.content
                .navigationTransition(.zoom(sourceID: self.sourceID, in: self.namespace))
            #else
            // macOS 上 `.zoom` 编译不过；这条分支同时也**不可达**
            //（`resolve` 在 `platformSupportsZoom == false` 时永不返回 `.zoom`）。
            self.content
            #endif
        } else {
            self.content
        }
    }
}

#Preview("FullScreenButton") {
    NavigationStack {
        FullScreenButton {
            VStack {
                Text(verbatim: "Expanded")
                    .font(.largeTitle)
                    .foregroundStyle(Color.contentPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surfaceRaised)
        } label: {
            VStack(alignment: .leading) {
                Text(verbatim: "Tap to expand")
                    .font(.headline)
                    .foregroundStyle(Color.contentPrimary)
                Text(verbatim: "FullScreenButton")
                    .font(.subheadline)
                    .foregroundStyle(Color.contentSecondary)
            }
            .padding(CoreSpacing.lg)
            .frame(width: 260, height: 200, alignment: .topLeading)
            .background(Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous))
        }
    }
}
