import SwiftUI

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
// 起；此前走 `surfaceCanvasSubtle`）：侧栏在实际消费点（`Sidebar`、`App` 宿主的分栏
// 布局）里需要与主画布**和**内容表面都区隔开。iOS 深色下三档因此各得一色
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
    /// **走填充族而非背景族**（Issue #220，同 `surfacePanel` 的理由）。取 `secondaryFill`
    /// 而非更淡的档位，依据有二：① z 序最高的浮件需要最强的存在感；
    /// ② `Badge.swift` 已实测 `secondaryFill`（浅色 α=0.16 / 深色 α=0.32）在
    /// `surfaceBase` / `surfaceCanvas` / `surfaceRaised` 三种父容器、两种外观下**均可辨**。
    ///
    /// - Warning: 本档**半透明**，注意事项同 `surfacePanel`。
    static var surfaceOverlay: Color {
        .secondaryFill
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
    ///   `.panel` 的 doc comment 本就写着「兼容别名」。该恒等已在
    ///   `SurfaceContrastTests` 钉成显式断言，不是待修的缺陷。
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
