import SwiftUI
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

// MARK: - Surface Colors / 表面颜色
//
// `surfaceCanvas` 指向 `systemGroupedBackground`，随系统浅色/深色自动更新；与
// 已存在、同样指向 `systemGroupedBackground` 的 `surfaceGrouped` 是刻意的双轨
// 命名（两个名字指向同一系统色），与本文件内 `borderStrong`/`dividerOpaque`
// 等既有的双轨别名模式一致。
//
// `surfaceRaised` / `surfaceElevated` 与 `surfaceCanvas` 同走 grouped 族的二/三级
// （`secondarySystemGroupedBackground` / `tertiarySystemGroupedBackground`），
// 使 `surfaceCanvas → surfaceRaised → surfaceElevated` 与
// `surfaceGrouped → surfaceGroupedRaised → surfaceGroupedElevated` 保持同一族
// 三档的一致关系（两者数值因此完全相同——这是刻意的双轨命名，不是重复劳动）。
//
// `surfaceCanvasInset` 指向 `FillColors.tertiaryFill`：其官方 HIG 语义
// （输入字段/搜索栏/按钮）与本 token 的实际消费点（头像环、进度条轨道，以及经
// `surfaceInteractive` 别名服务的 `SearchField` / `SegmentedControl` /
// `LightButtonStyle` / `CircularGlassButtonStyle`）精确对应。
//
// `surfaceSidebar` 走 `surfaceElevated`（= `tertiarySystemGroupedBackground`，Issue #220
// 起；此前走 `surfaceCanvasSubtle`）：侧栏容器需要与主画布**和**内容表面都区隔开。
//
// ⚠️ **实际消费点只有 App 预览宿主的分栏布局三处**（`ContentView.swift` /
// `Previews.swift` / `ComponentData.swift` 各一处 `Color.surfaceSidebar`）。
// 库内 `Sidebar` 组件**不消费本 token**、也不调 `.surface(.sidebar)`——旧注释
// 把它列为消费点是失真，#220 更正。iOS 深色下三档因此各得一色
// （画布 `#000000` / 内容 `#1C1C1E` / 侧栏 `#2C2C2E`）；iOS 浅色与 macOS 下受系统色族
// 取值数限制会与其中一档同值，属物理下限，见该 token 的 doc comment。
//
// `surfacePanel` / `surfaceOverlay` 走**填充族**（`quaternaryFill` / `secondaryFill`）
// 而非背景族：它们服务的 `.panel` / `.overlay` / `.floating` 都是**叠在别人之上**的表面，
// 按 #122 裁决应取半透明填充色。详见各自 doc comment 与 `Badge.swift` 的完整论证。
public extension Color {
    static var surfaceBase: Color {
        .systemBackground
    }

    static var surfaceRaised: Color {
        .secondarySystemGroupedBackground
    }

    static var surfaceElevated: Color {
        .tertiarySystemGroupedBackground
    }

    static var surfaceGrouped: Color {
        .systemGroupedBackground
    }

    static var surfaceGroupedRaised: Color {
        .secondarySystemGroupedBackground
    }

    static var surfaceGroupedElevated: Color {
        .tertiarySystemGroupedBackground
    }

    static var surfaceMuted: Color {
        .tertiaryFill
    }

    static var surfaceInteractive: Color {
        .surfaceCanvasInset
    }

    /// 浮层表面背景（服务 `.surface(.floating)`：toast、浮动工具栏、底部栏）。
    ///
    /// ## ⚠️ 按外观分道——本仓第一个动态 token，理由必须写清楚
    ///
    /// **Issue #220 曾让本 token 两种外观都走 `secondaryFill`（填充族），
    /// 被 #225 视觉终审逐像素证伪**：
    ///
    /// - **深色**下填充叠加使表面**变亮** → 读作「浮起」，语义成立。
    /// - **浅色**下填充叠加使表面**变暗**（实测底 `#F2F2F7` → 卡 `#DEDEE4`，
    ///   Δ≈20 灰阶；叠在 `#FFFFFF` 上 → `#E9E9E9`，Δ≈22），且无阴影、无模糊、
    ///   仅 hairline 描边 —— 这在 iOS 浅色语言里正是**搜索框 / 输入井的凹陷配方**。
    ///
    /// **代码自证（这条比观感直觉更硬）**：本文件下方 `surfaceCanvasInset` 把
    /// 同族的 `tertiaryFill` 定义为「**凹陷 well** / 输入框内底色」——
    /// **fill 族在本库自己的词汇里就是「凹」的视觉语言**。`.floating` 取
    /// `secondaryFill` 只是同族更浓一档，凹得更狠。语义（浮在内容之上）与观感
    /// （陷进去）方向相反。
    ///
    /// ⚠️ `SurfaceContrastTests` 的逐位判据对此**结构性失明**：三档 α 不同即算
    /// distinct，全绿。它只担保「解析值不同」，答不了「浮没浮起来」——
    /// 那个问题只有 #225 的截图能回答，而它的答案是「浅色下没有」。
    ///
    /// ## 分道取值
    ///
    /// | 外观 | 取值 | 为什么读作浮起 |
    /// |---|---|---|
    /// | 浅色 | `systemBackground`（`#FFFFFF`，浅色可用的**最亮值**） | 浅色下「更亮的不透明面」= 抬起 |
    /// | 深色 | `secondaryFill`（半透明填充） | 深色下「叠加提亮」= 抬起 |
    ///
    /// 两侧都往**变亮**的方向走，方向一致——这才是「浮起」在两种外观下的共同表达。
    /// UIKit 自己的 elevated 背景（`systemBackground` 在深色下随层级提亮）就是
    /// 按外观分道的先例，本条不是发明新概念。
    ///
    /// ## ⚠️ 浅色下的结构性天花板（实测发现，必须如实记录）
    ///
    /// 初版分道曾取 `secondarySystemBackground`，**实测它在浅色下就是 `#F2F2F7`、
    /// 与 `surfaceCanvas` 同值**，根本不是「更亮」。改取 `systemBackground`
    /// （`#FFFFFF`）后：
    ///
    /// - 叠在 `.canvas`（`#F2F2F7`）上 → 更亮，**读作抬起** ✅
    /// - 叠在 `.content`（`#FFFFFF`）上 → **同值，颜色上完全不可辨** ⚠️
    ///
    /// **这不是调参没调好，是结构性上限**：浅色下 `.content` 已经是纯白，
    /// **不存在比它更亮的不透明色**。iOS 在浅色下表达抬起靠的是**阴影**，
    /// 而 `SurfaceKind.background` 只返回一个 `Color`、结构上表达不了阴影
    /// （`SurfaceModifier` 明确把 shadow 留给调用方追加）。
    ///
    /// ⇒ **`.floating` 叠在浅色 `.content` 之上时，必须由调用方补
    /// `.coreShadow(_:)` 或改用 `floatingGlass`**；只靠 `.surface(.floating)`
    /// 的底色是浮不起来的。这条限制已钉进 `SurfaceContrastTests` 的相等断言。
    ///
    /// - Note: 不改 `SurfaceModifier` 的 switch、不改任何公开 API 签名 ——
    ///   分道完全封装在本 token 内部。
    /// - Warning: 深色分支**半透明**，其下内容会透出；也**不宜再叠
    ///   `.coreShadow(_:)`**（阴影会从半透明背景透上来把表面压脏）。
    ///   需要材质浮层请用 `floatingGlass`。
    static var surfaceOverlay: Color {
        #if canImport(UIKit)
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.secondarySystemFill
                    : UIColor.systemBackground
            })
        #else
            // ⚠️ **AppKit 侧也要真分道**。初版这里取不透明的 `surfaceBase`，实测
            // 撞车：macOS 上 `systemBackground` 与 `systemGroupedBackground` 双双
            // 降级到 `windowBackgroundColor` ⇒ `.floating` 与 `.canvas` 同值——
            // 正是 PRD v1 那个「`.floating == .canvas` on macOS」塌缩被重新引入。
            //
            // AppKit 有等价入口 `NSColor(name:dynamicProvider:)`，据此做同样的分道。
            Color(nsColor: NSColor(name: "surfaceOverlay") { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return isDark ? .secondarySystemFill : .controlBackgroundColor
            })
        #endif
    }

    // MARK: - Semantic surface variants / 语义表面变体

    /// 页面级最底层背景。指向 `systemGroupedBackground`，随系统浅色/深色与未来的
    /// 外观调整自动更新。与 `surfaceGrouped` 同值——刻意的双轨命名，见文件顶部说明。
    static var surfaceCanvas: Color {
        .systemGroupedBackground
    }

    /// 次级内容区背景（侧栏 / 表格头）。指向 `secondarySystemGroupedBackground`，
    /// 与 `surfaceRaised` 同值。
    static var surfaceCanvasSubtle: Color {
        .secondarySystemGroupedBackground
    }

    /// 凹陷 well / 输入框内底色。指向 `FillColors.tertiaryFill`——其官方 HIG 语义
    /// （输入字段/搜索栏/按钮）与本 token 的实际消费点（头像环、进度条轨道、经
    /// `surfaceInteractive` 服务的搜索框/分段控件/按钮背景）精确对应。
    static var surfaceCanvasInset: Color {
        .tertiaryFill
    }

    /// 面板 / 覆盖层容器背景（服务 `.surface(.panel)` 与 `.surface(.overlay)`）。
    ///
    /// **走填充族而非背景族**（Issue #220）：菜单、popover、面板是**叠在别的内容之上**的
    /// 大区域容器，按 #122 的裁决（`Badge.swift` 有完整论证）——叠加层该用 `FillColors`
    /// （半透明、专为叠加设计），充当底层的才用 `SurfaceColors`。取 `quaternaryFill`
    /// （HIG 语义「大区域复杂内容」），是四档填充里最克制的一档。
    ///
    /// - Note: `.panel` 与 `.overlay` 走**同一个** token（见 `SurfaceModifier.swift` 的
    ///   switch），且 border 与 cornerRadius 也完全相同——二者今天就是全等的两个 case，
    ///   `.panel` 的 doc comment 本就写着「兼容别名」。该恒等是**结构性**的
    ///   （同一 token、同一 switch 分支形态），**没有测试守卫**：switch 在
    ///   `private extension`、`@testable` 够不到，token 层只能写出恒真断言。
    ///   kind→token 映射归视觉复核（Issue #225）覆盖。
    /// - Warning: 本档**半透明**，其下内容会透出。需要不透明浮层请用 `floatingGlass`
    ///   或 `.surface(.content)`；也**不宜再叠 `.coreShadow(_:)`**——阴影会从半透明
    ///   背景透上来把表面压脏。
    static var surfacePanel: Color {
        .quaternaryFill
    }

    /// 侧栏 / 导航容器背景。走 `surfaceElevated`（= `tertiarySystemGroupedBackground`），
    /// 使它在 **iOS 深色**下与画布（`#000000`）、内容表面（`#1C1C1E`）三档分开
    /// （侧栏得 `#2C2C2E`）。
    ///
    /// - Note: **iOS 浅色下与 `surfaceCanvas` 同值**（一级与三级 grouped 背景在浅色
    ///   下同为 `#F2F2F7`）；**macOS 下与 `surfaceCard` 同值**（AppKit 无 grouped
    ///   三级族，二/三级双双落 `controlBackgroundColor`）。两处均为系统色族的物理
    ///   下限、非本库缺陷，已分别在 `SurfaceContrastTests` 与
    ///   `SystemBackgroundColorsMacOSTests` 钉成显式相等断言。
    static var surfaceSidebar: Color {
        .surfaceElevated
    }

    /// 卡片容器背景。Phase 1 曾让卡片刻意贴近画布、只靠边框拉开层级
    /// （`surfaceCard` 别名 `surfaceCanvas`）；Phase 2 视觉终审（#125/#136）
    /// 推翻了这一判断——深色模式下卡片与页面画布完全同色、无描边时视觉塌缩、
    /// 隐形。现改为浮在画布之上：`surfaceCard` 别名 `surfaceRaised`
    /// （= `secondarySystemGroupedBackground`），符合 iOS 分组容器（列表/卡片
    /// 浮于分组画布之上）的系统惯例。
    static var surfaceCard: Color {
        .surfaceRaised
    }
}
