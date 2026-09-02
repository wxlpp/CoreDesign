//
//  ProgressBar.swift
//  CoreDesign
//

import SwiftUI

// MARK: - ProgressBar

/// **材质层**: 内容. **表面角色**: 内容.
///
/// 水平进度条。
///
/// 实用可读性优先于装饰：轨道与填充都是实心圆角矩形，**无玻璃、无渐变**。
/// value 会被钳到 `0...1`，非有限输入归零。
///
/// 灰色底轨 + 可配置彩色填充 + 可选左侧 label 文本。
///
/// > **已弃用（0.6.0 起）**：改用系统 `ProgressView(value:)` + `.progressViewStyle(.core)`。
/// > 二者视觉几乎一致，但 `.core` **响应环境 `.tint`**（`ProgressBar` 反之——它有意
/// > 拒绝环境 tint、只认自己的 `tint:` 参数），且走系统控件、无障碍与 Dynamic Type
/// > 更完整。留下 `ProgressBar` 只为下游平滑迁移，后续版本移除。
@available(*, deprecated, message: "改用 ProgressView(value:).progressViewStyle(.core)——.core 响应环境 .tint，走系统控件。见 docs/components/core-control-styles.md")
public struct ProgressBar: View {
    let value: Double  // 0.0...1.0
    let tint: Color?
    let label: String?

    public init(value: Double, tint: Color? = nil, label: String? = nil) {
        // 非有限输入 (NaN / ±infinity) 直接归 0，避免后续 layout / accessibility 计算 trap。
        let sanitized = value.isFinite ? value : 0
        self.value = min(max(sanitized, 0), 1)
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        HStack(spacing: CoreSpacing.sm) {
            if let label = self.label {
                Text(label)
                    .coreFont(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // track 高度固定 `CoreSpacing.xs`(4pt)，小于
                    // `CoreRadius.small`(6pt) 的直径——SwiftUI 会把圆角自动 clamp 到
                    // `min(width, height)/2`，实际渲染半径恒为 2pt（= height/2，胶囊
                    // 观感），3→6pt 的换值在这两处**不产生任何可见差异**。
                    CoreShape.rounded(CoreRadius.small)
                        .fill(Color.surfaceCanvasInset)
                    CoreShape.rounded(CoreRadius.small)
                        // 显式 `Color.accent`——避免在 `.fill(_:)` 的 ShapeStyle
                        // 上下文里解析到 SwiftUI 环境 accent。
                        .fill(self.tint ?? Color.accent)
                        .frame(width: geometry.size.width * CGFloat(self.value))
                }
            }
            .frame(height: CoreSpacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.label.map(Text.init(verbatim:)) ?? Text("Progress", bundle: .module))
        // 百分比整体作为一个 `%@` 参数传入（键为 `"%@ complete"`），
        // **刻意不写 `"%lld%% complete"`**：那需要在 `.strings` 里转义百分号，
        // 而转义写错的失败形态是渲染出字面量 `%%`、肉眼不易察觉。
        // 把 `%` 留在 Swift 侧拼接，格式串里就不出现需转义的字符。
        .accessibilityValue(Self.percentValue(self.value))
    }

    /// 进度的可访问值。百分号在 Swift 侧拼进参数，格式串只剩 `"%@ complete"`。
    ///
    /// ⚠️ **未认领的 l10n 代价（Issue #222 评审 I-6）**：本写法把**百分号相对数字的
    /// 位置写死在 Swift 侧**。土耳其语写 `%50`、法语写 `50 %`（数字与 % 之间有空格），
    /// `"%lld%% complete"` 方案里译者能经格式串控制这一层，本写法不能。
    ///
    /// 之所以仍取本写法：转义方案的失败形态是**渲染出字面量 `%%`**——肉眼不易察觉、
    /// 编译不红、测试不红。两害相权取「百分号位置不可译」而非「可能静默渲染出 %%」。
    ///
    /// **正解是走 locale 感知的百分比格式**（`value.formatted(.percent)` 一族），
    /// 由它同时管住数值格式与百分号位置。未在本轮做：那会改变可访问值的既有文案形态
    /// （`.percent` 会带 locale 的分组符与小数策略），属独立的行为变更，
    /// 归属：随 a11y 文案的下一轮统一改造。
    static func percentValue(_ value: Double) -> String {
        let pct = "\(Int(value * 100))%"
        return String(localized: "\(pct) complete", bundle: .module)
    }
}

// #Preview 已随弃用移除——迁移期请参考 `.core ProgressView`
// （见 `docs/components/core-control-styles.md` 与 App 预览宿主的 ".core ProgressView"）。
