import SwiftUI

// MARK: - Surface Colors / 表面颜色
//
// Issue #120 完整映射表（第 3 层 SurfaceColors 全部 token）：
//
// | token                    | 旧值                          | 新值                              | 判定 |
// |--------------------------|--------------------------------|------------------------------------|------|
// | surfaceBase              | systemBackground                | 不变                                | 保持现值——已是系统色 |
// | surfaceRaised            | secondarySystemBackground       | secondarySystemGroupedBackground   | 改值——并入 grouped 族，与新 surfaceCanvas 同族 |
// | surfaceElevated          | tertiarySystemBackground        | tertiarySystemGroupedBackground    | 改值——同上，保持三档一致的族 |
// | surfaceGrouped           | systemGroupedBackground         | 不变                                | 保持现值——已是系统色 |
// | surfaceGroupedRaised     | secondarySystemGroupedBackground| 不变                                | 保持现值——已是系统色 |
// | surfaceGroupedElevated   | tertiarySystemGroupedBackground | 不变                                | 保持现值——已是系统色 |
// | surfaceMuted             | tertiaryFill                    | 不变                                | 保持现值——已是系统色 |
// | surfaceInteractive       | 别名 surfaceCanvasInset         | 不变（别名），底层值随 surfaceCanvasInset 改变 | 保持现值——别名关系不变 |
// | surfaceOverlay           | 别名 surfacePanel               | 不变（别名）                        | 保持现值——别名关系不变 |
// | surfaceCanvas            | 自定义 colorset `canvas-default`| systemGroupedBackground             | **改值**——核心映射，见下方详注 |
// | surfaceCanvasSubtle      | 自定义 colorset `canvas-subtle` | secondarySystemGroupedBackground    | **改值**——原文档注释自称「接近现有 surfaceRaised」，此处让它真的同值 |
// | surfaceCanvasInset       | 自定义 colorset `canvas-inset`  | tertiaryFill                       | **改值**——实测消费场景（搜索框/分段控件轨道/头像环）与 `FillColors.tertiaryFill` 的 HIG 语义（输入字段/搜索栏/按钮）吻合 |
// | surfacePanel             | 别名 surfaceCanvasSubtle        | 不变（别名），底层值随之改变          | 保持现值——别名关系不变 |
// | surfaceSidebar           | 别名 surfaceCanvasSubtle        | 不变（别名），底层值随之改变          | 保持现值——见下方关于文档注释的说明 |
// | surfaceCard              | 别名 surfaceCanvas              | 不变（别名），底层值随之改变          | 保持现值——原文档注释本就要求「卡片保持接近画布」 |
//
// 核心映射详注：
//
// - `surfaceCanvas` 此前是一个专为「Craft 工作台」暖色调手工调的 colorset
//   （light `#FCFBF7` / dark `#11110F`），与系统外观脱钩——用户切换系统浅色/深色，
//   这个值只在两个写死的色号间跳，不会响应任何系统级的强调 / 对比度调整。
//   改指 `systemGroupedBackground` 后，画布背景与「跟随系统外观」的整个 epic 目标
//   对齐，且与已存在、同样指向 `systemGroupedBackground` 的 `surfaceGrouped` 形成
//   刻意的双轨命名（Primer 风格命名 `surfaceCanvas` / Apple 原生命名 `surfaceGrouped`
//   指向同一系统色），与本文件内 `borderStrong`/`dividerOpaque` 等既有的双轨别名
//   模式一致。
// - `surfaceRaised` / `surfaceElevated` 原本走的是「plain」系统背景族
//   （`systemBackground` 的二/三级），与 `surfaceCanvas` 所在的「grouped」族是两条
//   平行谱系。`surfaceCanvas` 改到 grouped 族后，若 `surfaceRaised` 继续留在 plain
//   族，两者会在同一套 UI 层级里混用两条不同色阶谱系，在标准 List/分组内容场景下
//   与 `surfaceCanvas` 配对使用时层级观感不可预期。故一并改为 grouped 族的二/三级，
//   使 `surfaceCanvas → surfaceRaised → surfaceElevated` 与
//   `surfaceGrouped → surfaceGroupedRaised → surfaceGroupedElevated` 保持同一族三档
//   的一致关系（两者数值也因此完全相同——这是刻意的双轨命名，不是重复劳动）。
// - `surfaceCanvasSubtle` 原文档注释自称「接近现有 surfaceRaised」，但两者此前分别
//   指向一个自定义 colorset 和一个「plain」族系统色，并不真的相等。让它真的等于新
//   `surfaceRaised`（= `secondarySystemGroupedBackground`）是把既有文档承诺兑现，
//   而非引入新行为。
// - `surfaceCanvasInset` 原注释写「现有 token 中无对应项，必须用新 colorset」——这在
//   引入 `FillColors` 系统填充色桥接之前是真的。现在看它的实际消费点
//   （`AvatarGroup` 头像环底色、`ProgressBar` 轨道、经 `surfaceInteractive` 别名
//   服务的 `SearchField` / `SegmentedControl` / `LightButtonStyle` /
//   `CircularGlassButtonStyle`），与 `FillColors.tertiaryFill` 的官方 HIG 描述
//   ——"使用此颜色填充大型形状，例如输入字段、搜索栏或按钮"——精确对应，因此确实
//   已有系统对应物，只是分散在另一层文件里未被认领。
//
// `surfaceSidebar` 的文档注释历史遗留说明：原注释写「接近现有 surfaceGrouped」，
// 但实现走的是 `surfaceCanvasSubtle`（现为 `secondarySystemGroupedBackground`），
// 与 `surfaceGrouped`（`systemGroupedBackground`）并不相等——这处文档与实现的偏差
// 在本次改动前就存在。本任务保留既有实现路径（不改为字面对齐 `surfaceGrouped`），
// 因为侧栏在实际消费点（`Sidebar`、`App` 宿主的分栏布局）里需要与主画布区隔开的
// 「次级面板」观感：macOS 降级后 `surfaceGrouped`/`surfaceCanvas` 落
// `windowBackgroundColor`（画布本体），`surfaceCanvasSubtle` 落
// `controlBackgroundColor`（可辨识的次级背景）——后者更符合「侧栏应与画布区隔」
// 的实际使用场景。这是一次显式复核后的保留决定，不是照抄。
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

    // MARK: - Primer-aligned semantic surfaces / Primer 对齐语义表面

    /// 页面级最底层背景。Issue #120 前为 Craft 工作台专用暖色调 colorset
    /// （light `#FCFBF7` / dark `#11110F`），与系统外观脱钩；现改指
    /// `systemGroupedBackground`，随系统浅色/深色与未来的外观调整自动更新。
    /// 与 `surfaceGrouped` 同值——刻意的双轨命名，见文件顶部映射表详注。
    static var surfaceCanvas: Color {
        .systemGroupedBackground
    }

    /// 次级内容区背景（侧栏 / 表格头）。Issue #120 前为自定义 colorset
    /// `canvas-subtle`；现改指 `secondarySystemGroupedBackground`，与
    /// `surfaceRaised` 同值，兑现原文档注释「接近现有 surfaceRaised」的承诺。
    static var surfaceCanvasSubtle: Color {
        .secondarySystemGroupedBackground
    }

    /// 凹陷 well / 输入框内底色。Issue #120 前为自定义 colorset `canvas-inset`；
    /// 现改指 `FillColors.tertiaryFill`——其官方 HIG 语义（输入字段/搜索栏/按钮）
    /// 与本 token 的实际消费点（头像环、进度条轨道、经 `surfaceInteractive`
    /// 服务的搜索框/分段控件/按钮背景）精确对应。
    static var surfaceCanvasInset: Color {
        .tertiaryFill
    }

    /// 卡片群之上的面板容器；接近现有 `surfaceGroupedRaised`，与其别名目标
    /// `surfaceCanvasSubtle` 同值。
    static var surfacePanel: Color {
        .surfaceCanvasSubtle
    }

    /// 侧栏 / 导航容器背景。见文件顶部关于本 token 文档注释历史偏差的说明——
    /// 本任务复核后保留既有实现路径（走 `surfaceCanvasSubtle`，不改为
    /// `surfaceGrouped`），因为它在 macOS 降级后能与画布本体形成可辨识的
    /// 次级背景层级。
    static var surfaceSidebar: Color {
        .surfaceCanvasSubtle
    }

    /// 卡片容器背景。Craft workbench 风格下卡片刻意保持接近画布，只靠边框和
    /// 相邻 panel 拉开层级——本任务不改变这一设计决定，`surfaceCard` 继续
    /// 别名到 `surfaceCanvas`，随其改指系统色。
    static var surfaceCard: Color {
        .surfaceCanvas
    }
}
