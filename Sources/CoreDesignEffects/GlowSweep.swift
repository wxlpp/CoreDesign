//
//  GlowSweep.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// `GlowSweep { }` —— 一段辉光**沿内容边框转圈**，表示"正在生成 / 正在思考"。
///
/// ```swift
/// GlowSweep {
///     Card { answerText }
/// }
/// .tint(.accent)
/// ```
///
/// ## 与 `ScanningOverlay` / `LightSweep` 的分工
///
/// 三者都是"处理中"的常驻呈现，落点不同：
///
/// - `ScanningOverlay`：光束**穿过内容**——"正在读这块内容"（识别、解析）。
/// - `GlowSweep`：辉光**沿边框转**——"这块内容正在被生成"，内容本身不被遮挡。
/// - `LightSweep`：光带**掠过表面**——"这块内容正在等待/传输"，比前两者更轻。
///
/// ## 取色
///
/// 辉光色**取调用方的 `.tint`**，本组件不自带颜色（FR-8）。
///
/// ## a11y 分工（FR-13）
///
/// 辉光层是**纯装饰**，已 `accessibilityHidden(true)`；"正在生成"由调用方通告。
///
/// ## Reduce Motion
///
/// 不转圈，辉光弧**静止停在一个固定角度**（降级形态 2）。
///
/// ## 后台 / 低电量（NFR-7）
///
/// 与 `ScanningOverlay` 同：后台/非活跃 ⇒ 整层不建；低电量 ⇒ 降帧并去掉离屏模糊。
/// 两个信号可经 `\.scenePhaseOverride` / `\.lowPowerModeOverride` 注入（默认从系统读）。
///
/// ⚠️ **本类型是薄封装**，理由与判据见 `ScanningOverlay`。
public struct GlowSweep<Content: View>: View {

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        self.content.overlay { ProcessingSweepDriver(kind: .glow) }
    }
}

#Preview("GlowSweep") {
    GlowSweep {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 120)
            .overlay { Image(systemName: "sparkles").font(.system(size: 40)) }
    }
    .tint(.accent)
    .padding(40)
}
