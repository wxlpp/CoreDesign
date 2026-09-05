import CoreDesign
import SwiftUI

@main
struct CoreDesignPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            // NFR-1 帧率基准（#256）：带 `--perf-benchmark` 启动参数时不进画廊,
            // 改把三个被测视图逐个放进**真实的**渲染循环里采样、打印结果后自行退出。
            // ⚠️ 必须跑在 App 里、不能写成 unit test —— 理由（含实测输出）见
            // `PerformanceBenchmark.swift` 文件头《为什么基准住在 App target》。
            if PerformanceBenchmark.isRequested {
                PerformanceBenchmarkRunner()
            } else if let id = ProcessInfo.processInfo.environment["PREVIEW_COMPONENT_ID"],
                      let comp = ComponentMeta.all.first(where: { $0.id == id }) {
                Self.directPreview(id: id, comp: comp)
            } else {
                ContentView()
                    .toastHost(edge: .top)
            }
        }
    }

    /// 视觉终审（#144）自动截图用:设 launch 环境变量 PREVIEW_COMPONENT_ID
    /// 直达某个组件的 preview 全屏渲染,免去 UI 导航;未设时正常显示组件浏览器。
    @ViewBuilder
    private static func directPreview(id: String, comp: ComponentMeta) -> some View {
        // 整屏 demo（设置页）自带内边距、全出血渲染;其余是小组件 demo,直达全屏
        // 时补水平边距,避免内容贴屏边、trailing accessory 被裁（视觉终审 #144）。
        let fullBleed = (id == "settings-screen" || id == "settings-row-in-list")
        comp.preview()
            .padding(.horizontal, fullBleed ? 0 : CoreSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: fullBleed ? .top : .center)
            .background(Color.surfaceCanvas)
            .toastHost(edge: .top)
    }
}
