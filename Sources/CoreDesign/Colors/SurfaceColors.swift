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
// `surfaceSidebar` 走 `surfaceCanvasSubtle`（而非字面对齐 `surfaceGrouped`）：
// 侧栏在实际消费点（`Sidebar`、`App` 宿主的分栏布局）里需要与主画布区隔开的
// "次级面板"观感——macOS 降级后 `surfaceGrouped`/`surfaceCanvas` 落
// `windowBackgroundColor`（画布本体），`surfaceCanvasSubtle` 落
// `controlBackgroundColor`（可辨识的次级背景），后者更符合"侧栏应与画布区隔"
// 的实际使用场景。
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

    static var surfaceOverlay: Color {
        .surfacePanel
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

    /// 卡片群之上的面板容器；接近现有 `surfaceGroupedRaised`，与其别名目标
    /// `surfaceCanvasSubtle` 同值。
    ///
    /// - Note: Issue #140 后，`.surface(.panel)` 的背景与 `.surface(.card)` 同值
    ///   （二者均解析到 `secondarySystemGroupedBackground`），层级差异改由**边框**
    ///   表达（panel 用 `borderDefault`、card 用 `borderMuted`），不再靠背景色区分。
    ///   9 个 `SurfaceKind` 收敛为 3 个 distinct 背景的完整数据与缓议见 issue #140。
    static var surfacePanel: Color {
        .surfaceCanvasSubtle
    }

    /// 侧栏 / 导航容器背景。走 `surfaceCanvasSubtle`（而非 `surfaceGrouped`），
    /// 因为它在 macOS 降级后能与画布本体形成可辨识的次级背景层级——见文件顶部说明。
    static var surfaceSidebar: Color {
        .surfaceCanvasSubtle
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
