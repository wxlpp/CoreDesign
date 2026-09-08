import SwiftUI

// MARK: - coreAccent 环境入口 / Themeable accent

public extension EnvironmentValues {
    /// 子树的强调色。默认 `Color.inkPrimary`（墨色：浅色下黑、深色下白）。
    ///
    /// 组件应读本键而非静态的 `Color.accent`——后者是环境不可达时的回退值，不跟随主题。
    ///
    /// ⚠️ 在 `View` 内部**不要**把注入属性也命名为 `coreAccent`——`self.coreAccent`
    /// 会解析到下面的 `View.coreAccent(_:)` modifier 而非本属性。用别的名字
    /// （本仓用 `resolvedAccent`）。`ButtonStyle` 不是 `View`，不受影响。
    @Entry var coreAccent: Color = .inkPrimary
}

public extension View {
    /// 为子树设置强调色，`accentHover` / `accentPressed` / `accentDisabled` /
    /// `accentSubtleBackground` 四个派生态自动跟随。
    ///
    /// ⚠️ 本 modifier **不设** `.tint(_:)`：`.core` 系统控件 style（`ProgressView` /
    /// `Label` / `DisclosureGroup`）走 `.tint` 通路，两条通路刻意分开，调用方要同时
    /// 改就写两个 modifier。
    ///
    /// ⚠️ **主题色应为近单色（黑 / 白极性）**。`contentOnAccent` 取 `systemBackground`，
    /// 在墨色 accent 上正确；若传入饱和色，深色模式下前景会是近黑色压在该饱和色上。
    /// 本版本不提供 on-accent 的环境钩子——后续处置见 `#357`。
    ///
    /// - Parameter color: 新的强调色。
    func coreAccent(_ color: Color) -> some View {
        self.environment(\.coreAccent, color)
    }
}
