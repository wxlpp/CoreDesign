//
//  LightSweep.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// `LightSweep { }` —— 一道斜向光带在内容**表面左右掠过**，表示"正在等待 / 正在传输"。
///
/// ```swift
/// LightSweep {
///     ListRow(title: "Syncing…")
/// }
/// ```
///
/// ## 与 `.shine(trigger:)` / `.skeletonShimmer()` 的区别（三者都是"扫光"）
///
/// - `.shine(trigger:)`：**一次性**，由 `trigger` 驱动，遮罩到**内容形状**——"这件事刚发生"。
/// - `LightSweep { }`：**常驻**，无 trigger，裁到内容**外接矩形**——"这件事正在进行"。
/// - `CoreDesign` 的 `.skeletonShimmer()`：骨架屏专用，扫的是占位块而不是真内容。
///
/// ⚠️ **裁矩形而不是 `.mask(content)` 是有意的**：后者会把被包裹内容**实例化两次**
/// （`.shine(trigger:)` 逐字记着这条限度，它会让内容里的 `onAppear` / `task {}` 跑两遍）。
/// 容器形态天生包着别人的视图树，把那个陷阱继承进来不可接受。
/// 代价：光带不贴合内容的圆角与异形轮廓，只贴合它的外接矩形。
///
/// ## 取色
///
/// 光带色**取调用方的 `.tint`**，本组件不自带颜色（FR-8）。
///
/// ## a11y 分工（FR-13）
///
/// 光带层是**纯装饰**，已 `accessibilityHidden(true)`；"正在传输"由调用方通告。
///
/// ## Reduce Motion
///
/// 不掠过，光带**静止停在内容中线**（降级形态 2）。
///
/// ## 后台 / 低电量（NFR-7）
///
/// 与 `ScanningOverlay` 同：后台/非活跃 ⇒ 整层不建；低电量 ⇒ 降帧并去掉离屏模糊。
/// 两个信号可经 `\.effectsScenePhase` / `\.effectsPowerMode` 注入（默认从系统读）。
///
/// ⚠️ **本类型是薄封装**，理由与判据见 `ScanningOverlay`。
public struct LightSweep<Content: View>: View {

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        self.content.overlay { ProcessingSweepDriver(kind: .light) }
    }
}

#Preview("LightSweep") {
    LightSweep {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 90)
            .overlay { Image(systemName: "arrow.trianglehead.2.clockwise").font(.system(size: 34)) }
    }
    .tint(.accent)
    .padding(40)
}
