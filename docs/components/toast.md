# Toast

Scene 级 Toast 通知 / Scene-scoped toast notification.

## API

### ToastHost (通过 Environment 获取)

`ToastHost` 是 `@Observable` 类，非 View，通过 `@Environment(\.toastHost)` 获取，不直接放入视图层级。

```swift
@Observable final class ToastHost { ... }
```

| 方法 | 说明 |
|---|---|
| `show(_ message: String, level: StatusLevel = .info, duration: TimeInterval = ToastDefaults.duration)` | 入队一条 toast（level 缺省 `.info`，duration 缺省 3 秒） |
| `show(_ item: ToastItem)` | 入队预构造的 ToastItem |
| `dismiss(_ id: ToastItem.ID)` | 取消指定 toast |

StatusLevel: info / success / warning / danger。

## 预览 / Preview

此组件依赖 Scene 级 context，需运行 App 后在界面中触发。运行 `scripts/run-preview.sh` 启动预览 App 体验效果。

### View Modifier

| 方法 | 说明 |
|---|---|
| `.toastHost(edge: VerticalEdge, presentation: ToastPresentation)` | 在 view 子树挂载 ToastHost |

默认 edge: `.top`，默认 presentation: `.floatingCapsule`，默认定时: 3 秒。

### ToastPresentation（呈现形态，`#65`）

公约 §2 形态 D2「配置枚举」。三个 case 对应三种**业界真实存在的布局骨架**，
不是同一骨架换画法：

| case | 形态 | 具名来源 | 挂载方式 | 占宽 |
|---|---|---|---|---|
| `.floatingCapsule`（默认） | 边缘悬浮胶囊 | 现状形态 | `safeAreaInset(edge:)` | 撑满减两侧 16pt |
| `.fullWidthBanner` | 全宽横幅条 | Android Snackbar / in-app banner | `safeAreaInset(edge:)` | **撑满、触边** |
| `.centeredHUD` | 居中 HUD | 经典 UIKit toast / HUD | **`.overlay(alignment: .center)`** | **收缩为内容宽** |

⚠️ **`edge` 在 `.centeredHUD` 下不生效** —— 居中浮层没有「贴哪边」可言。受影响的有
贴边内边距、方向性入/出场、朝 `edge` 滑出的 dismiss 位移、滑动手势方向，四条都不适用。
这是**有意的静默**：传了不生效不是错误、只是无效，因此**不加运行期断言**，本文档即约定
（与 `StepsPresentation` 对 `indicatorStyle` 的处置同源）。

⚠️ `.centeredHUD` 下**滑动 dismiss 关闭、只保留点击 dismiss**。⚠️ 这只关**手势层** ——
自动 dismiss 计时（`ToastHost.scheduleDismiss`）不受影响，三个形态都照常。

## 使用示例 / Usage

```swift
// App 入口挂 host
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toastHost(edge: .top)
        }
    }
}

// 子 view 触发
struct DetailView: View {
    @Environment(\.toastHost) private var toast
    var body: some View {
        Button("Save") {
            toast?.show("Saved.", level: .success)
        }
    }
}
```

## 视觉 Token

- 容器：`.floatingGlass(in: Capsule(style: .continuous), isInteractive: false)`——iOS 26 液态玻璃浮起外壳，不消费 `.surface(.card)`（Phase 3A 迁移，见 `ToastView`）
- 字号：`CoreTypography.bodyMediumFont`
- 内边距：`CoreSpacing.md`
- Icon / 前景色：按 `StatusLevel` 走 status color token（`statusAccentForeground` / `statusSuccessForeground` / `statusAttentionForeground` / `statusDangerForeground`）
- 入场/出场动画：从 `edge` 方向滑入 + 淡入（⚠️ `.centeredHUD` 例外：改用不依赖方向的
  缩放 + 淡入淡出）
- 滑动手势：向 edge 方向滑动超过 `CoreSpacing.xxl`（32pt）触发 dismiss
  （⚠️ `.centeredHUD` 例外：关闭滑动，只保留点击）
- 容器形状：`.floatingCapsule` 用 `Capsule`、`.fullWidthBanner` 用 `Rectangle`、
  `.centeredHUD` 用 `RoundedRectangle(cornerRadius: CoreRadius.large)`；三者共用
  `CoreSpacing.md` 的内容内边距（内容留白不是三形态的差异所在）
- z-order：通过 `safeAreaInset` 实现，不覆盖 sheet / fullScreenCover，每个 scene 需独立挂载 host
