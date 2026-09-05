//
//  ScanningOverlay.swift
//  CoreDesignEffects
//

import CoreDesign
import SwiftUI

/// `ScanningOverlay { }` —— 一道横向光束在内容上**上下往复扫描**，表示"正在识别 / 正在处理"。
///
/// ```swift
/// ScanningOverlay {
///     Image(uiImage: document).resizable().scaledToFit()
/// }
/// .tint(.green)
/// ```
///
/// ## 取色
///
/// 光束色**取调用方的 `.tint`**，本组件不自带颜色（FR-8：颜色只能来自调用方参数 /
/// `.tint` / 语义 token）。
///
/// ## a11y 分工（FR-13）
///
/// 光束层是**纯装饰**，已 `accessibilityHidden(true)`。
/// ⚠️ **"正在扫描"这个状态由调用方通告**（`accessibilityLabel` /
/// `AccessibilityNotification.Announcement`），本组件不替调用方播报——
/// 它不知道被包裹的是什么，也不知道这次处理什么时候结束。
///
/// ## Reduce Motion
///
/// 不往复，光束**静止停在内容中央**（降级形态 2：保留"长什么样"，去掉运动）。
///
/// ## 后台 / 低电量（NFR-7）
///
/// - 场景进入 `.inactive` / `.background` ⇒ **整层不建**，驱动它的 `TimelineView` 不存在；
/// - 低电量模式 ⇒ 降到 15 fps 并去掉离屏模糊的光晕。
///
/// 两个信号都可经 `\.scenePhaseOverride` / `\.lowPowerModeOverride` 注入（默认从系统读）。
///
/// ⚠️ **本类型是薄封装**：驱动与绘制全在 `ProcessingSweep.swift`，
/// 容器**不得**自建第二套动画——否则 Reduce Motion 与能耗降级只覆盖驱动层、不覆盖容器
/// （判据见 `ProcessingSweepTests.containersDelegateToDriver`）。
public struct ScanningOverlay<Content: View>: View {

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        self.content.overlay { ProcessingSweepDriver(kind: .scanning) }
    }
}

#Preview("ScanningOverlay") {
    ScanningOverlay {
        RoundedRectangle(cornerRadius: CoreRadius.large, style: .continuous)
            .fill(Color.surfaceRaised)
            .frame(width: 240, height: 150)
            .overlay { Image(systemName: "doc.text.viewfinder").font(.system(size: 44)) }
    }
    .tint(.accent)
    .padding(40)
}
