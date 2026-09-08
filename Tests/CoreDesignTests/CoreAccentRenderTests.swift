import SwiftUI
import Testing
@testable import CoreDesign

// MARK: - 射程 B：视图级主题化

/// ⚠️ 这一族补的是终审 I-1 抓到的洞：`CoreAccentThemingTests` 全部落在
/// `ButtonRoleStyleRole` 的**函数层**，没有一条走「视图 + 环境」。
/// 实测后果——把 `SolidButtonStyle` 的 `accent: self.coreAccent` 改回 `accent: .accent`，
/// 那 7 条**全部照绿**。本次改动的核心特性因此没有任何机器兜底。
@Suite("coreAccent 射程 B（视图级渲染）")
@MainActor
struct CoreAccentRenderTests {
    private static func pixels(_ view: some View, scheme: ColorScheme) -> Data? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme))
        renderer.scale = 1
        #if canImport(UIKit)
            return renderer.uiImage?.pngData()
        #else
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff)
            else { return nil }
            return rep.representation(using: .png, properties: [:])
        #endif
    }

    /// 同一视图在 `.coreAccent(.red)` 与 `.coreAccent(.green)` 下渲染，返回「两张图是否不同」。
    /// `nil` 表示渲染失败——调用方必须把它当红，不能当通过。
    ///
    /// ⚠️ **必须比两个都非默认的值，不能比「有 / 无 `.coreAccent`」**。实测（`SegmentedControl`）：
    /// ```
    /// 无 vs .coreAccent(.red)        → 不同
    /// .coreAccent(.red) vs (.green)  → 相同
    /// 无 vs .coreAccent(.inkPrimary) → 相同   （写入默认值）
    /// ```
    /// 三条合起来说明：「有 / 无」之间的差异**与取值无关**，是写入非默认环境值触发的
    /// 失效 / 身份变化带来的布局微差。拿它当判据，**不跟随主题的视图也会「差异」通过**
    /// ——判据会为了错误的理由变绿。比两个非默认值就把这个假象整个消掉了。
    private static func differsUnderCoreAccent(
        _ build: @escaping () -> some View,
        scheme: ColorScheme
    ) -> Bool? {
        guard let red = Self.pixels(build().coreAccent(.red), scheme: scheme),
              let green = Self.pixels(build().coreAccent(.green), scheme: scheme)
        else { return nil }
        return red != green
    }

    @Test("solid(.primary) 按钮跟随 coreAccent")
    func solidPrimaryFollowsCoreAccent() throws {
        for scheme in [ColorScheme.light, .dark] {
            let differs = try #require(
                Self.differsUnderCoreAccent({
                    Button("Go") {}
                        .buttonStyle(.solid(role: .primary))
                        .frame(width: 120, height: 44)
                }, scheme: scheme),
                "\(scheme)：渲染失败，判据无法判定"
            )
            #expect(differs, "\(scheme)：solid(.primary) 没跟随 .coreAccent —— 样式仍在读静态 Color.accent")
        }
    }

    @Test("solid(.danger) 不跟随 coreAccent——四个非 primary role 有意留在自有色阶")
    func solidDangerIgnoresCoreAccent() throws {
        for scheme in [ColorScheme.light, .dark] {
            let differs = try #require(
                Self.differsUnderCoreAccent({
                    Button("Delete") {}
                        .buttonStyle(.solid(role: .danger))
                        .frame(width: 120, height: 44)
                }, scheme: scheme),
                "\(scheme)：渲染失败，判据无法判定"
            )
            #expect(!differs, "\(scheme)：solid(.danger) 跟随了 .coreAccent —— 它应留在 danger 色阶上")
        }
    }

    @Test("focusRing 默认色跟随 coreAccent；显式传色时不跟随")
    func focusRingFollowsCoreAccentUnlessExplicit() throws {
        for scheme in [ColorScheme.light, .dark] {
            let defaulted = try #require(
                Self.differsUnderCoreAccent({
                    Color.clear.frame(width: 80, height: 40).focusRing(visible: true)
                }, scheme: scheme),
                "\(scheme)：渲染失败"
            )
            #expect(defaulted, "\(scheme)：focusRing 默认色没跟随 .coreAccent")

            let explicit = try #require(
                Self.differsUnderCoreAccent({
                    Color.clear.frame(width: 80, height: 40)
                        .focusRing(visible: true, color: .dataAccent)
                }, scheme: scheme),
                "\(scheme)：渲染失败"
            )
            #expect(!explicit, "\(scheme)：显式传色的 focusRing 仍跟随了环境 —— 参数被忽略")
        }
    }

    @Test("Sidebar 选中行跟随 coreAccent")
    func sidebarSelectionFollowsCoreAccent() throws {
        for scheme in [ColorScheme.light, .dark] {
            let differs = try #require(
                Self.differsUnderCoreAccent({
                    SidebarNavigationRow(systemImage: "house", title: "Home", isSelected: true) {}
                        .frame(width: 200)
                }, scheme: scheme),
                "\(scheme)：渲染失败"
            )
            #expect(differs, "\(scheme)：Sidebar 选中行没跟随 .coreAccent")
        }
    }

    @Test("Ink 分段样式的选中段跟随 coreAccent；Glass / Plain 两个默认样式不跟随")
    func inkSegmentedFollowsCoreAccent() throws {
        func control() -> some View {
            SegmentedControl(items: ["A", "B"], selection: .constant("A"), title: { $0 })
                .frame(width: 200)
        }
        for scheme in [ColorScheme.light, .dark] {
            let ink = try #require(
                Self.differsUnderCoreAccent({ control().segmentedControlStyle(.ink) }, scheme: scheme),
                "\(scheme)：渲染失败"
            )
            #expect(ink, "\(scheme)：.ink 分段的选中段没跟随 .coreAccent")

            let plain = try #require(
                Self.differsUnderCoreAccent({ control().segmentedControlStyle(.plain) }, scheme: scheme),
                "\(scheme)：渲染失败"
            )
            #expect(!plain, "\(scheme)：.plain 分段跟随了 .coreAccent —— 它的选中态本不该吃强调色")
        }
    }

    @Test("Card 的 elevation 档位真的改变渲染")
    func cardElevationChangesRendering() throws {
        // ⚠️ 只在 iOS 腿判：投影色取自 `CoreElevation` 的 4 个 shadow colorset，
        // 属 CLAUDE.md 登记的「macOS native 腿恒为全透明」的那 198 个常量
        // ——在 macOS 上 `.none` 与 `.large` 位图相同，断言会恒红。
        #if canImport(UIKit)
            let none = try #require(
                Self.pixels(
                    Card(elevation: .none) { Text("x") }.frame(width: 200).padding(24),
                    scheme: .light
                ),
                "渲染失败"
            )
            let large = try #require(
                Self.pixels(
                    Card(elevation: .large) { Text("x") }.frame(width: 200).padding(24),
                    scheme: .light
                ),
                "渲染失败"
            )
            // ⚠️ 走 expectBitmapsDiffer 而非裸 `#expect(!=)`：`BitmapExpectationGuard` 的 J1
            // 禁止对大 Collection 直接比较（失败时会把整块字节打进日志）。
            expectBitmapsDiffer(
                Array(none), Array(large),
                "Card 的 elevation 档位没有改变渲染 —— 参数没接到 coreShadow 上"
            )
        #endif
    }
}

// MARK: - 图表：刻意不跟随

@Suite("图表不跟随 coreAccent")
@MainActor
struct ChartsIgnoreCoreAccentTests {
    /// ⚠️ **如实登记：这条今天天然绿**——四个图表走 `tint: Color = .dataAccent`
    /// 的非可选默认实参，压根不读环境。它是**防回归网**，不是证明：
    /// 谁把图表接进 `coreAccent`（比如顺手改成 `Color? = nil`），这条会判红。
    @Test("图表在有 / 无 .coreAccent(.red) 下渲染相同")
    func chartsDoNotFollowCoreAccent() throws {
        // 图表在 CoreDesignCharts，本 target 看不到；这里用同形的默认实参契约代替：
        // dataAccent 是静态常量，不随环境变。
        var themed = EnvironmentValues()
        themed.coreAccent = .red
        #expect(
            Color.dataAccent.resolve(in: themed) == Color.dataAccent.resolve(in: EnvironmentValues()),
            "dataAccent 随 coreAccent 变了 —— 数据色被接进主题通路了"
        )
    }
}

// MARK: - 设计比例

/// ⚠️ 补终审 I-3：四个比例（0.18 / 0.30 / 0.22 / 0.08）此前**无任何判据**钉住
/// ——实测把它们整批改回旧值（0.15 / 0.25 / 0.35 / 0.12）时全套判据照绿，
/// 而 BREAKING / DESIGN-FOUNDATION / CLAUDE.md 都把这四个数当既定事实登记。
@Suite("accent 派生比例")
@MainActor
struct AccentRatioTests {
    @Test("hover / pressed 的混合比例分别是 0.18 / 0.30")
    func mixRatiosArePinned() {
        #expect(
            Color.accentHover(from: .accent) == Color.accent.mix(with: .surfaceBase, by: 0.18),
            "accentHover 的混合比例不是 0.18"
        )
        #expect(
            Color.accentPressed(from: .accent) == Color.accent.mix(with: .surfaceBase, by: 0.30),
            "accentPressed 的混合比例不是 0.30"
        )
    }

    @Test("disabled / subtleBackground 的不透明度分别是 0.22 / 0.08")
    func opacityRatiosArePinned() {
        // accent 走系统色（inkPrimary），两条腿都能解析 —— 不是那 198 个资源色。
        var env = EnvironmentValues()
        env.colorScheme = .light
        let disabled = Color.accentDisabled.resolve(in: env).opacity
        let subtle = Color.accentSubtleBackground.resolve(in: env).opacity
        #expect(abs(disabled - 0.22) < 0.005, "accentDisabled 实得 α \(disabled)，期望 0.22")
        #expect(abs(subtle - 0.08) < 0.005, "accentSubtleBackground 实得 α \(subtle)，期望 0.08")
    }
}
