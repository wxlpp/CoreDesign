import Testing
import SwiftUI
@testable import CoreDesign

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// `SidebarUtilityRowPresentation`（#64，公约 §2 形态 D2）的**渲染护栏**。
//
// ⚠️ **本 suite 里相等类与不等类的位图断言互为对方的「非退化前置」，不得单独删除或
// 单腿门控**（PR #209 复审 S-3）：
//   · `textOnlyIgnoresSystemImage`（三张位图**相等**）的退化路径是「三张全是空图 ⇒ 恒真」,
//     由 `leadingGlyphIsDrivenBySystemImage` 证明 gearshape/trash 在本平台**确能**产生差异来兜住；
//   · `leadingGlyphIsDrivenBySystemImage`（两张位图**不等**）的退化路径是「渲染非确定性 ⇒
//     任意两图恒不等」，由本 suite 三条相等断言从反面兜住。
// 这个互锁是**隐式**的 —— 删掉或 iOS-gate 其中一半，另一半会**静默**退化成恒真。
//
// ⚠️ **本 suite 是跨平台的**，与仓内其余 5 个 **iOS-only** 的 `ImageRenderer` suite
// （`TouchTargetTests` / `DynamicTypeLayoutTests` / `SpinningModifierSizeTests` /
// `SettingsRowHeightTests` / `CardVisibilityTests`）**不同** —— 它们全部包在 `#if os(iOS)` 里。
// （这 5 个是按「iOS-only」分的类。按「读不读几何尺寸」再分是另一个口径，见 `pixels(_:)`
//  的 DocC —— 两处数目不同不是笔误。）
// 独占一个文件正是为了不被后人顺手包进 `#if os(iOS)`、让护栏静默变单腿。
//
// ⚠️ **与 `SpinningModifierTests.swift:11-12` 那条相反先例对账**：那里写「只在 iOS 腿跑
// （macOS 无 WindowServer 会塌缩系统色/材质）」—— 那句讲的是**颜色 / 材质**，**不是布局 frame**。
// 本 suite 量的是布局尺寸，macOS 实测可行（`nsImage` 返回非 nil，量得 111.0 / 83.0 / 50.0）。
//
// ⚠️ **这条护栏守的是判定法层面的结论**：`docs/component-contract.md` 的候选 2 覆盖论证
// （见 `oh-my-story` 的 `64-spec.md` §3.3 / §5.1.4）以「`.textOnly` 的排布事实是
// `[title][Spacer][glyph]`」为前提。若 leading 位仍占着地方，实际是
// `[gap][title][Spacer][glyph]` ⇒ **排布事实不一致 ⇒ 覆盖论证当场失效**。
// ⇒ 本文件是那条论证的机器护栏，不是普通的样式测试。
@Suite("SidebarUtilityRow leading 槽渲染护栏（#64）")
@MainActor
struct SidebarLeadingSlotRenderTests {
    /// a11y 命中目标下限。⚠️ **字面量 44，不写 `CoreControlMetrics.height(for: .large)`** ——
    /// 被测代码（`Sidebar.swift` 的 `SidebarRow`）用的就是后者，写它就**同源** ⇒ 改 token 时
    /// 双向移动、**永不判红**（恒真守卫，本 epic 在 `90a09fb` 逐字登记过该病型）。
    /// 44 是**外部 a11y 契约数**、不由本仓 token 决定；先例 `TouchTargetTests.swift:61` 同款。
    private static let minimumHitTarget: CGFloat = 44

    /// 内容固有尺寸。
    ///
    /// ⚠️ **限度自陈（PR #209 终审 I1）**：骨架 `SidebarRow` 内层的 `.frame(width: iconSize)`
    /// 把 leading 闭包的产物**钳成恰好 20pt、与内容无关** ⇒ 用本 helper 算出的差值实际是一个
    /// **布尔量**（leading 闭包空 / 非空），**不是任何度量**。leading 里换成 `Color.clear` /
    /// `.hidden()` / 写死的字形，差值都仍是 28。
    /// ⇒ 「槽里画的是不是真由 `systemImage` 决定」由 `leadingGlyphIsDrivenBySystemImage`
    /// 的**位图对比**承担，两条各挡一半。
    ///
    /// ⚠️ **永不接受宽度约束** —— 被测视图一旦被钉成固定宽度，两个变体的
    /// 宽度就都等于那个值、**差值恒 0**，护栏静默失效且不会红。
    /// （`TouchTargetTests.renderedHeight` 的默认参数是 `width: 320`，**不要复用它**。）
    private func intrinsicSize(_ view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        // scale 影响绝对值（实测 1 → 111.0 / 2 → 110.5 / 3 → 110.333）。
        // 仓内用 `ImageRenderer` 的 suite **除 `RatingStyleTests` 外都显式设 `scale = 1`**
        // （那一个不读尺寸、只借渲染触发 body 求值，故不关心 scale）。
        // ⚠️ 这里**不写「共 N 个」** —— 本文件落地当天那个数就已经变了（复审 S-2）。
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.size ?? .zero
        #else
        return renderer.nsImage?.size ?? .zero
        #endif
    }

    /// 渲染成位图并取原始字节。
    ///
    /// 仓内先例：`CoreControlStyleTintTests`（取像素平均色验 `.tint` 真的接上）与
    /// `RatingStyleTests`（借渲染触发 `makeBody` 求值）已确立「用 `ImageRenderer` 取真实
    /// 位图作证」的惯例，且这两个 suite **是跨平台的**（无 `#if os(iOS)`）。
    ///
    /// ⚠️ **但别把这条先例读成「ImageRenderer 在本仓一向跨平台」**（PR #209 终审 S3 /
    /// 复审 I-1）：上面那两个**都不量几何**。真正读出**尺寸**的先例是 **4** 个 ——
    /// `DynamicTypeLayoutTests` / `SettingsRowHeightTests` / `TouchTargetTests` 读
    /// `uiImage?.size`，`SpinningModifierSizeTests` 读 `cgImage.width/height`；
    /// **四个全部 iOS-only**。
    /// ⚠️ **`CardVisibilityTests` 不在此列** —— 它虽然 iOS-only 且用 `ImageRenderer`，
    /// 但只取**中心像素**验背景对比、不读尺寸，与上面那两个跨平台先例同类。
    /// （终审 S3 那版把它算进「尺寸测量」得出 5，是错的。）
    /// ⇒ 本 suite 做的是尺寸测量却选择跨平台，因此是**该类里的头一个**，不是「随大流」。
    ///
    /// ⚠️ **位图字节比较的已知脆弱面**（PR #209 Copilot CLI 复审提出，本轮未观察到）：
    /// macOS 的 `tiffRepresentation` 可能嵌入色彩配置 / 压缩元数据，若将来 ImageIO 的
    /// 默认设置变了，**相等**类断言可能在 macOS 腿上变脆。真出现时**先查元数据差异**
    /// （而不是先改成宽松比较）—— 正确修法是比较解码后的像素缓冲，不是加容差。
    private func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #else
        guard let rep = renderer.nsImage?.tiffRepresentation else { return nil }
        return rep
        #endif
    }

    private func row(
        _ presentation: SidebarUtilityRowPresentation,
        trailing: String? = nil,
        systemImage: String = "gearshape"
    ) -> some View {
        SidebarUtilityRow(
            systemImage: systemImage,
            title: "Settings",
            trailingSystemImage: trailing,
            presentation: presentation
        ) {}
    }

    @Test("承重：.textOnly 不渲染 leading 槽、也不占位")
    func textOnlyDropsLeadingSlot() {
        let iconLeading = self.intrinsicSize(self.row(.iconLeading))
        let textOnly = self.intrinsicSize(self.row(.textOnly))

        // ⚠️ 非空断言先行（仓内明文纪律）：只断差值时，「两边同时偏移」不会被发现；
        // 且 `nsImage` / `uiImage` 为 nil 时必须**判红**，不得静默跳过。
        #expect(iconLeading.width > 0, "渲染失败（尺寸为零）—— 本平台无法量测，不得当作通过")
        #expect(textOnly.width > 0, "渲染失败（尺寸为零）")

        // ⚠️ **为什么用严格 `==` 而不是带容差的近似比较**（PR #209 Copilot review 提出，实测后未采纳）：
        // 期望值 `iconSize(.large) + CoreSpacing.sm` = 20 + 8 = **28，两个常量都是整数**；
        // `renderer.scale = 1` 已钉死 ⇒ 位图像素数即 pt 数，取整不会污染**差值**。
        // 实测两条腿都精确相等，且**本 suite 在两边都真的跑了**（不是空 suite 假绿）。
        // ⚠️ 这里**不写测试总数**（PR #209 终审 S4）：那个数每加一个测试就腐一次，
        // 且它证不了本 suite 跑没跑。要复核请按**显示名** grep 上面那行 @Test 的标题，
        // 而不是看总数 —— 参见 CLAUDE.md「验证边界」：空 suite 会静默全绿。
        // ⚠️ **grep 显示名时必须从本文件复制真名，不能凭记忆敲**：写错一个字就命中 0，
        // 而「命中 0」与「这条没跑」在输出上完全一样（本 PR 终审验证时刚栽过一次）。
        // ⚠️ 且**容差会削弱护栏** —— 它要挡的是「leading 位仍占着地方」，那是**整格 20pt 或
        // 8pt 间距**的偏差；一旦允许 ±ε，将来「差值 27.5」这类真实的小偏移就会被放过。
        // ⇒ 若某天它在某平台上真的出现亚像素差异，**正确处置是查清那个平台为何不同**
        // （多半是 scale 或字体度量被改了），而不是加容差把信号盖掉。
        //
        // ⚠️ 期望值用 **token 表达式**（与高度那条相反，见文件末尾的「同源」说明）：
        // 变异「乙′」改的是「组件用哪个 token」而这里写死 `.large` ⇒ 两边不同源 ⇒ 判红成立。
        let expected = CoreControlMetrics.iconSize(for: .large) + CoreSpacing.sm
        #expect(iconLeading.width - textOnly.width == expected,
                "leading 槽未被拆掉：实测差 \(iconLeading.width - textOnly.width)，期望 \(expected)")
    }

    @Test("承重：leading 字形真的由 systemImage 决定（组件不得忽略该入参）")
    func leadingGlyphIsDrivenBySystemImage() {
        // ⚠️ **这条堵的是差值断言的结构性盲区**（PR #209 终审 I1 实测抓到）：
        // 骨架 `SidebarRow` 的 `.frame(width: iconSize)` 把 leading 闭包的产物**钳成恰好 20pt、
        // 与内容无关** ⇒ 上面那条差值断言实际测的是一个**布尔量**（leading 闭包空 / 非空），
        // **不是任何度量**。实测：把 `Image(systemName: self.systemImage)` 写死成
        // `Image(systemName: "gearshape")`（组件彻底忽略入参）后，**全仓 419 tests 无一判红**。
        //
        // ⚠️ 而 `systemImage` 必填无默认正是 `#59` 判本组件「槽」的**第 1 个承重合取项** ——
        // 在此之前它只是登记表 `notes` 里的一句话，没有任何机器判据绑住它。本条把它变成判据。
        let a = self.pixels(self.row(.iconLeading))
        let b = self.pixels(
            SidebarUtilityRow(systemImage: "trash", title: "Settings", presentation: .iconLeading) {}
        )
        #expect(a != nil && b != nil, "渲染失败 —— 本平台无法量测，不得当作通过")
        #expect(a != b, "换了 systemImage 但渲染逐字节相同 ⇒ 组件忽略了该入参（或 leading 根本没画字形）")

        // ⚠️ 本条**同时**挡住「leading 画的是空白但仍占位」那一类（`Color.clear` / `.hidden()` /
        // `Text("")`）—— 实测那些变异下两次渲染同样逐字节相同，本断言照红。
        // ⇒ 差值断言管「槽在不在」，本条管「槽里画的是不是真由入参决定的字形」，两条各挡一半。
    }

    @Test("全部呈现组合的命中高度均 ≥ 44pt")
    func allPresentationsMeetMinimumTouchTarget() {
        // ⚠️ 与 `rowHeightMatchesCurrentToken` 同样遍历 `allCases`（复审 S5）—— 上一版这里
        // 硬编码了三个组合，加第三个 case 时不会自动覆盖。
        for presentation in SidebarUtilityRowPresentation.allCases {
            for trailing in [nil, "chevron.forward"] as [String?] {
                let size = self.intrinsicSize(self.row(presentation, trailing: trailing))
                #expect(size.height >= Self.minimumHitTarget,
                        "\(presentation) trailing=\(trailing ?? "nil") 实测高度 \(size.height)pt < \(Self.minimumHitTarget)pt")
            }
        }
    }

    @Test("现状钉：全部呈现组合的高度互等且为 50（≠ a11y 契约，改 token 时须回来改这个数）")
    func rowHeightMatchesCurrentToken() {
        // ⚠️ **本条与上面的 ≥44pt 是两件事，不要合并**（PR #209 终审 I2）：
        // `≥ 44` 是**外部 a11y 契约**的地板，因此那条必须写字面量 44、且不能收紧；
        // 但它留下一个 **44–49pt 的死区** —— 把骨架 `minHeight` 从 `.large`(50) 降一档到
        // `.regular`(44)，四条兄弟行同时矮 6pt，而 `≥ 44` 仍然成立 ⇒ **全仓无一处判红**（实测）。
        //
        // ⇒ 本条钉的是**现状值**，不是契约：改 `SidebarRow` 的 minHeight token 时**必须回来
        // 改这个数**，那正是它存在的意义（强制那次改动被人看见）。
        // ⚠️ 同样写字面量 `50` 而非 `CoreControlMetrics.height(for: .large)` —— 后者与被测
        // 代码同源 ⇒ 改 token 时双向移动、恒真（同 `minimumHitTarget` 那条的理由）。
        // ⚠️ 遍历 `allCases` 而非硬编码两个 case（PR #209 终审 S5）：将来加第三种呈现时
        // 本条**自动覆盖它**，不需要有人记得回来补。
        for presentation in SidebarUtilityRowPresentation.allCases {
            for trailing in [nil, "chevron.forward"] as [String?] {
                let size = self.intrinsicSize(self.row(presentation, trailing: trailing))
                #expect(size.height == 50,
                        "行高偏离现状值：\(presentation) trailing=\(trailing ?? "nil") 实测 \(size.height)，现状 50")
            }
        }
    }

    @Test("承重：.textOnly 完全忽略 systemImage —— 故写 \"\" 的约定不承重")
    func textOnlyIgnoresSystemImage() {
        // PR #209 终审 S6：`App/Sources/ComponentData.swift` 与 `docs/components/sidebar.md`
        // 约定「`.textOnly` 时 systemImage 统一写 `""`」，但那是**人读的约定、无机器强制**
        // —— `systemImage` 是必填 `String`，库这一侧拦不住调用方传别的值。
        //
        // ⇒ 与其守一条守不住的约定，不如**证明违反它没有后果**：只要 `.textOnly` 的渲染
        // 对 systemImage **完全不敏感**，那条约定就降级成卫生问题，不再是正确性依赖。
        // 对比对象特意取 `leadingGlyphIsDrivenBySystemImage` 里被证实**能**产生位图差异的
        // 那两个字形（`gearshape` / `trash`）—— 否则本条可能只是选了两个碰巧同形的图标。
        //
        // ⚠️ **强度自陈**（PR #209 Copilot CLI 复审提出，如实记下）：**相对今天的代码形态，
        // 本条接近恒真** —— 目前 `systemImage` 只在唯一那个 `if presentation == .iconLeading`
        // 分支里被用到，所以 `.textOnly` 下它当然不影响渲染。
        // ⇒ 本条挡的**不是**今天的实现，而是一类**未来回归**：有人把 `systemImage` 插进
        // `.textOnly` 也走的路径（a11y label、title 拼接、tooltip、埋点字符串……）。
        // 那时它会立刻判红，而「写 `""`」的约定就会从卫生问题变成正确性依赖。
        // ⇒ 别因为「它现在总是绿」就删掉它；也别把它当成对当前实现的有力证明。
        let blank = self.pixels(self.row(.textOnly, systemImage: ""))
        let gear = self.pixels(self.row(.textOnly, systemImage: "gearshape"))
        let trash = self.pixels(self.row(.textOnly, systemImage: "trash"))

        #expect(blank != nil, "渲染失败 —— 本平台无法量测，不得当作通过")
        #expect(blank == gear, ".textOnly 仍受 systemImage 影响：\"\" 与 gearshape 位图不同")
        #expect(blank == trash, ".textOnly 仍受 systemImage 影响：\"\" 与 trash 位图不同")
    }

    @Test("候选 2 的组合：行尾字形真的占了位，且不影响 leading 侧差值")
    func trailingGlyphOccupiesSpace() {
        let textOnly = self.intrinsicSize(self.row(.textOnly))
        let withTrailing = self.intrinsicSize(self.row(.textOnly, trailing: "chevron.forward"))
        // 候选 2 承载论证里唯一还没被任何断言碰过的事实。
        #expect(withTrailing.width > textOnly.width, "行尾字形没有占位 ⇒ 候选 2 的排布事实不成立")

        // 行尾字形不应影响 leading 侧的差值。
        let iconLeading = self.intrinsicSize(self.row(.iconLeading, trailing: "chevron.forward"))
        let expected = CoreControlMetrics.iconSize(for: .large) + CoreSpacing.sm
        #expect(iconLeading.width - withTrailing.width == expected,
                "行尾字形影响了 leading 侧差值：实测差 \(iconLeading.width - withTrailing.width)，期望 \(expected)")
    }

    @Test("兜底：SidebarUtilityRow 与 SidebarNavigationRow 同 title 时宽度逐点相等")
    func siblingRowWidthsStayAligned() {
        // ⚠️ **限度自陈**：本兜底只抓「**只影响 SidebarUtilityRow 一条行**」的改动 ——
        // 例如有人在其 body 外层加了 `.padding()` ⇒ Util ≠ Nav ⇒ 本条红，而承重差值断言
        // （两个变体等量受影响）**不会**红。
        // ⚠️ 反过来，对**四条兄弟行一起变**的**骨架级**改动本条**结构性失明** —— 因为它断的是
        // 两条行「相对相等」，而 `SidebarRow` 是共用骨架、改动对两条等量生效。
        // 实测（**骨架局部变异**：改 `SidebarRow` 里用哪个 token / 写死数值，**不是**改
        // `CoreControlMetrics` 的 token 取值）：leading 那格 20→16 时 Util=Nav=107.0、
        // 间距→0 时 Util=Nav=95.0，**两次都绿**，全靠承重差值断言抓（24 / 20 ≠ 28）。
        // ⇒ 看到「承重红、兜底绿」是**预期**，别去"加强"本条。
        //
        // ⚠️ **别照字面做成「改 token 取值」的实验**（复审 I-2）：承重断言的期望值本身也是
        // token 表达式（`iconSize(for: .large) + CoreSpacing.sm`），改 `CoreControlMetrics`
        // 的返回值会让**期望值同步移动** ⇒ 承重也绿。这是那条断言的**已知双向移动面**，
        // 由 `rowHeightMatchesCurrentToken` 的字面量 `50` 从另一侧兜住。
        let util = self.intrinsicSize(self.row(.iconLeading))
        let nav = self.intrinsicSize(
            SidebarNavigationRow(systemImage: "gearshape", title: "Settings", isSelected: false) {}
        )
        #expect(util.width > 0)
        #expect(util.width == nav.width,
                "两者走同一骨架、同 titleLineLimit、同 isSelected: false、trailing 皆空 ⇒ 宽度应相等；实测 Util=\(util.width) / Nav=\(nav.width)")
    }
}
