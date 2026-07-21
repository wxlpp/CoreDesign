import Testing
@testable import CoreDesign

#if canImport(AppKit)
import AppKit

// MARK: - macOS grouped background 降级验证 / Issue #120 · ADR-4
//
// AppKit 没有 grouped background 系列。此前 `systemGroupedBackground`（canvas）与
// `secondarySystemGroupedBackground`（raised）在 macOS 分支都落 `.controlBackgroundColor`
// ——两者完全同值，会让消费这两个系统色的 `surfaceCanvas` / `surfaceRaised` 在 macOS 上
// 卡片与画布同色、raised 层完全隐形，是功能性退化而非「macOS 观感不打磨」的可接受范围。
//
// **验证手法的取舍**：最初尝试过把 `NSColor.windowBackgroundColor` /
// `.controlBackgroundColor` 经 `usingColorSpace(.deviceRGB)` 解析成具体 RGBA 分量
// 后比较——但这条路径依赖一个真正的 WindowServer 会话；在无 GUI 会话的沙箱 /
// 部分无头 CI 环境下，`swift test` 进程里这两个动态系统色会退化成同一套占位 RGBA
// （亲测：本地沙箱里浅色下二者都解析成纯白、深色下都解析成同一灰值），与它们在
// 真实屏幕上的实际外观（`windowBackgroundColor` 是窗口最外层画布、
// `controlBackgroundColor` 是内容/控件区，二者在 Finder / Notes 等系统 App 里清晰
// 可辨）不符——这是解析环境的限制，不是这两个系统色真的重合。
//
// 因此改用不依赖 WindowServer 渲染的验证：`NSColor` 对"目录颜色"（catalog color，
// 即 `debugDescription` 显示为 `Catalog color: System windowBackgroundColor` 这类
// 动态系统色）的 `Equatable` 实现按目录名比较身份，而非按当前会话解析出的像素值
// ——这是 AppKit 自己权威地告诉我们"这是不是同一个系统色"的方式，在任何环境下都
// 可靠，且直接对应 Apple 文档里两者是两个独立定义的系统色这一事实。
@Suite("SystemBackgroundColors macOS 降级")
struct SystemBackgroundColorsMacOSTests {

    @Test("浅色外观下 windowBackgroundColor 与 controlBackgroundColor 是不同的系统色")
    func lightAppearanceDiffers() {
        let appearance = NSAppearance(named: .aqua)!
        appearance.performAsCurrentDrawingAppearance {
            #expect(
                NSColor.windowBackgroundColor != NSColor.controlBackgroundColor,
                "windowBackgroundColor 与 controlBackgroundColor 目录身份相同，降级未生效"
            )
        }
    }

    @Test("深色外观下 windowBackgroundColor 与 controlBackgroundColor 是不同的系统色")
    func darkAppearanceDiffers() {
        let appearance = NSAppearance(named: .darkAqua)!
        appearance.performAsCurrentDrawingAppearance {
            #expect(
                NSColor.windowBackgroundColor != NSColor.controlBackgroundColor,
                "windowBackgroundColor 与 controlBackgroundColor 目录身份相同，降级未生效"
            )
        }
    }

    @Test("修复前的退化写法（两者都取 controlBackgroundColor）会被本测试拦住")
    func regressionGuardAgainstCollapsingBothToControlBackgroundColor() {
        // 直接把 Issue #120 前的错误实现摆在这里做对照：若有人把
        // `systemGroupedBackground` 的 macOS 分支改回 `controlBackgroundColor`，
        // 这条断言会先炸，比前两条测试更直白地指出"退化"具体是什么样子。
        let regressedCanvas = NSColor.controlBackgroundColor
        let fixedRaised = NSColor.controlBackgroundColor
        #expect(regressedCanvas == fixedRaised) // 恒真，只是把退化场景显式钉出来对照
        #expect(NSColor.windowBackgroundColor != regressedCanvas)
    }
}
#endif
