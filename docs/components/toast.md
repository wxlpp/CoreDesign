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
| `show(_ message: String, level: ToastLevel = .info, duration: TimeInterval = ToastDefaults.duration)` | 入队一条 toast（level 缺省 `.info`，duration 缺省 3 秒） |
| `show(_ item: ToastItem)` | 入队预构造的 ToastItem |
| `dismiss(_ id: ToastItem.ID)` | 取消指定 toast |

ToastLevel: info / success / warning / danger。

## 预览 / Preview

此组件依赖 Scene 级 context，需运行 App 后在界面中触发。运行 `scripts/run-preview.sh` 启动预览 App 体验效果。

### View Modifier

| 方法 | 说明 |
|---|---|
| `.toastHost(edge: VerticalEdge)` | 在 view 子树挂载 ToastHost |

默认 edge: `.top`，默认定时: 3 秒。

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

- 容器：`.surface(.card)` + `.coreShadow(.medium)`
- 字号：`CoreTypography.bodyMediumFont`
- 内边距：`CoreSpacing.md`
- Icon / 前景色：按 `ToastLevel` 走 status color token（`statusAccentForeground` / `statusSuccessForeground` / `statusAttentionForeground` / `statusDangerForeground`）
- 入场/出场动画：从 `edge` 方向滑入 + 淡入
- 滑动手势：向 edge 方向滑动超过 `CoreSpacing.xxl`（32pt）触发 dismiss
- z-order：通过 `safeAreaInset` 实现，不覆盖 sheet / fullScreenCover，每个 scene 需独立挂载 host
