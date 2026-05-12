# AsyncButton 设计文档

- **状态**: Draft → 待实现
- **日期**: 2026-05-13
- **作者**: Evan / Claude
- **位置**: `Sources/CoreDesign/Components/Button/AsyncButton.swift`

## 1. 背景与目标

CoreDesign 的 4 个 `ButtonStyle`(`.solid` / `.light` / `.borderless` / `.circularGlass`)只解决"外观",所有业务侧执行异步任务(提交表单、调用 API)时都得自己写 `Task { ... }` 并在外部维护 `@State isLoading`、手动 `disabled`、外挂 `ProgressView`。模板重复且容易遗漏防双击或视图消失时的取消。

`AsyncButton` 的目标是把这套模板内聚到组件里,**调用方只需提供一个 async 闭包**,无需关心 loading 状态、取消、防双击。

## 2. 范围

### 包含

- 新增一个 `AsyncButton` 视图组件,与现有 `ButtonStyle` 生态正交,可任意搭配。
- 接受 `() async -> Void` 与 `() async throws -> Void`(+ 可选 `onError`)两类闭包。
- 文本 label 的便捷 init(`LocalizedStringKey` + `StringProtocol`)。
- 内置 loading 期间的 spinner + 自动 disabled + 视图消失时自动取消。
- Swift Testing 单测 + 4 种 ButtonStyle 的 `#Preview` 视觉冒烟。

### 明确不做

- 成功 / 失败的 transient 反馈动画(✓ / ✗ 闪烁,留待后续)。
- 对外暴露 `isLoading` Binding(内聚在组件内即可)。
- 新的 `ButtonStyle` wrapper(如 `.asyncSolid()`)——与"新组件"形态冲突。
- 修改既有 4 个 `ButtonStyle`。

## 3. 公开 API

```swift
public struct AsyncButton<Label: View>: View {

    // 非抛错
    public init(
        action: @escaping @MainActor () async -> Void,
        @ViewBuilder label: () -> Label
    )

    // 抛错 + 可选 onError
    public init(
        action: @escaping @MainActor () async throws -> Void,
        onError: (@MainActor (Error) -> Void)? = nil,
        @ViewBuilder label: () -> Label
    )

    // 文本便捷重载(Label == Text)
    public init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor () async -> Void
    ) where Label == Text

    public init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor () async -> Void
    ) where Label == Text

    public init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor () async throws -> Void,
        onError: (@MainActor (Error) -> Void)? = nil
    ) where Label == Text

    public init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor () async throws -> Void,
        onError: (@MainActor (Error) -> Void)? = nil
    ) where Label == Text
}
```

### 调用示例

```swift
// 最简
AsyncButton("提交") {
    await viewModel.submit()
}
.buttonStyle(.solid())

// 错误上抛 toast
AsyncButton("发布") {
    try await api.publish()
} onError: { error in
    toast.show(error.localizedDescription)
}
.buttonStyle(.solid(role: .primary))

// 自定义 label
AsyncButton {
    try await api.refresh()
} label: {
    Label("刷新", systemImage: "arrow.clockwise")
}
.buttonStyle(.light())
```

## 4. 渲染与状态机

```swift
@State private var task: Task<Void, Never>?
@State private var isRunning = false

public var body: some View {
    Button {
        self.task?.cancel()
        self.task = Task { @MainActor in
            self.isRunning = true
            defer { self.isRunning = false }
            await self.run()
        }
    } label: {
        HStack(spacing: 6) {
            if self.isRunning {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
            self.label
        }
        .animation(.snappy(duration: 0.16), value: self.isRunning)
    }
    .disabled(self.isRunning)
    .onDisappear { self.task?.cancel() }
}
```

状态机只有两态: `idle ⇄ running`。无 `success` / `failure` 状态。

### 关键决策

- **spinner 颜色继承 ButtonStyle**: 不在 `AsyncButton` 内显式设 `.tint(...)`,让 `ProgressView` 继承外部 `ButtonStyle` 设置的 `foregroundStyle`。
  - 这能让 spinner 在 `.solid()` 白色内容上显白,在 `.light()` / `.borderless()` 上显 role 色,无需 AsyncButton 感知 style 是哪种。
  - **验证项**: 实现时需 Preview 实测 `ProgressView(.circular)` 是否真的响应 `foregroundStyle`。若不响应,回退方案:在 AsyncButton 内手动 `.tint(.contentOnAccent)` / `.tint(role.color)`——但这会引入对具体 style 的耦合,应仅作降级方案。
- **不复用 `ProgressIndicator`**: 该组件硬编码 `.tint(Color.accent)`,会让 spinner 始终是品牌橙,在 `.solid(role: .primary)` 的白底文字旁视觉不协调。
- **spinner 尺寸固定 `.small`**: 不跟 `\.controlSize` 联动,避免 large 按钮里 spinner 喧宾夺主。
- **`.disabled(isRunning)`**: 自动触发既有 ButtonStyle 的 disabled 配色路径,无需额外接线。
- **`.animation(.snappy(duration: 0.16))`**: 与 `SolidButtonBackgroundModifier` 的 isPressed 动画同节奏。

## 5. 错误处理与取消

| 闭包类型 | 抛 `CancellationError` | 抛业务错误 |
|---|---|---|
| `() async -> Void` | 不会发生(无 throws) | 不会发生 |
| `() async throws -> Void` 无 onError | 静默 | 静默 |
| `() async throws -> Void` 有 onError | 静默吞掉 | 调用 `onError(error)` |

`CancellationError` 一律不上报 —— 它代表"视图正常消失",不是业务故障。

```swift
private func run() async {
    do {
        try await self.throwingAction()
    } catch is CancellationError {
        // 静默
    } catch {
        self.onError?(error)
    }
}
```

取消时机:
1. 视图 `onDisappear` —— 主要场景。
2. 新点击触发前 cancel 已有 task —— 防御性,正常被 `disabled` 拦住,此处只是兜底。

action 内部若有长循环,应自行 `try Task.checkCancellation()`;`URLSession` / `Task.sleep` 等已合作的 API 无需额外处理。

## 6. 并发与隔离

- `action`、`onError` 都标注 `@MainActor`,与 SwiftUI 视图天然在主 actor 一致,且匹配项目 Swift 6 strict concurrency 设置。
- `Task { @MainActor in ... }` 显式声明,避免 isolation 推断歧义。
- `Task<Void, Never>`: 错误已在内部 catch,不向 Task 传播,避免上层 Task tree 拿到无意义的 error。

## 7. 重载消歧

`@escaping () async -> Void` 与 `@escaping () async throws -> Void` 是不同类型,但闭包字面量 `{ await foo() }` 编译器更倾向匹配非抛错版本(non-throwing 是 throwing 的子类型)。预期:

- `{ await x() }` → 命中非抛错 init。
- `{ try await x() }` → 命中抛错 init(必须 throws 才能写 try)。
- 完全空 body `{ }` → 命中非抛错(因为 Void → Void 默认非抛错)。

**验证项**: 实现时为两个版本各写一组单测,确认重载解析符合预期;若编译器报歧义,降级为单 init 仅接受 throwing 闭包(非抛错调用方写 `try await`)。

## 8. 测试

文件: `Tests/CoreDesignTests/AsyncButtonTests.swift`,使用 Swift Testing。

测试用例:

1. **基础状态机** —— 触发后 `isRunning` 变 true,await 完成后变 false。
   - 通过把 action 拆成可控制的 `AsyncStream` / `CheckedContinuation`,精确观察中间态。
2. **抛错路径** —— 抛业务错误时 `onError` 被调用一次,且错误透传相等。
3. **CancellationError 静默** —— action 抛 `CancellationError`,`onError` 不被调用。
4. **重载解析** —— 各写一个非抛错与抛错调用点,能编译即通过(编译期保障)。

UI 层面 (`isRunning` 渲染、spinner 颜色) 通过 `#Preview` 视觉冒烟,不写自动化 snapshot。

## 9. Preview

同文件内提供 3 个 `#Preview` 块:

1. **AsyncButton — 全部 ButtonStyle**: 4 个 AsyncButton 分别套 `.solid()` / `.light()` / `.borderless()` / `.circularGlass()`,每个 action 内 `try await Task.sleep(.seconds(1.5))`,手动点击观察 spinner 与 disabled 表现。
2. **AsyncButton — 抛错 + onError**: 演示 onError 弹 toast 的最小流程。
3. **AsyncButton — disabled / running 并存**: 验证 loading 与外部 `.disabled(true)` 同时生效的视觉。

## 10. 风险与开放问题

1. `ProgressView(.circular)` 是否响应 `foregroundStyle` —— 见 §4,有降级方案。
2. 闭包重载是否歧义 —— 见 §7,有降级方案。
3. `@MainActor` 闭包的 `@escaping` 标注组合在 Swift 6 strict concurrency 下需实测,可能需要补 `@Sendable` 或调整 isolation 注解。

这些将在实现阶段 verify-before-completion,而不是设计阶段决定。

## 11. 不影响项

- 不动 `ButtonRoleStyleRole`、不动既有 4 个 ButtonStyle、不动 `ProgressIndicator`。
- 不引入新依赖。
- 公开 API 仅新增,无破坏性变更。
