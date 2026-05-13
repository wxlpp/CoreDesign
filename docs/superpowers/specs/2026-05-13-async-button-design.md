# AsyncButton 设计文档

- **状态**: 已实现（PR [#71](https://github.com/wxlpp/CoreDesign/pull/71)）
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

所有闭包参数的完整类型为 `@escaping @MainActor @Sendable () async [throws] -> Void` 和 `@escaping @MainActor @Sendable (Error) -> Void`(见 §6 解释)。下面签名为可读性省略部分注解,实现时按 §6 补齐。

```swift
public struct AsyncButton<Label: View>: View {

    // 非抛错
    public init(
        action: @escaping @MainActor @Sendable () async -> Void,
        @ViewBuilder label: () -> Label
    )

    // 抛错 + 可选 onError
    public init(
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil,
        @ViewBuilder label: () -> Label
    )

    // 文本便捷重载(Label == Text),抛错版本省略,签名同上
    public init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor @Sendable () async -> Void
    ) where Label == Text

    public init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor @Sendable () async -> Void
    ) where Label == Text

    public init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) where Label == Text

    public init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) where Label == Text
}
```

`LocalizedStringKey`(而非 `LocalizedStringResource`)选择依据:`rg LocalizedStringResource Sources/CoreDesign/` 当前 0 匹配,项目尚未迁移到 String Catalog 体系,沿用 `LocalizedStringKey` 保持与既有 API(例如 `Text("...")` 调用点)一致。

### 调用示例

```swift
// 最简
AsyncButton("提交") {
    await viewModel.submit()
}
.buttonStyle(.solid())

// 错误自定义处理
AsyncButton("发布") {
    try await api.publish()
} onError: { error in
    logger.error("publish failed: \(error)")
}
.buttonStyle(.solid(role: .primary))

// 不传 onError —— 上层若已挂 .toastHost,失败自动以 .danger toast 弹出
AsyncButton("发布") {
    try await api.publish()
}
.buttonStyle(.solid(role: .primary))
// 在更上层的 scene root:.toastHost(edge: .top)

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
        guard !self.isRunning else { return }
        // 同步置 true，避免 Task 启动前的同一 runloop 内多次点击竞态——
        // .allowsHitTesting 与 guard 均依赖 isRunning，必须在创建 Task
        // *之前* 翻转。
        self.isRunning = true
        self.task = Task { @MainActor in
            defer {
                self.isRunning = false
                self.task = nil
            }
            await self.run()
        }
    } label: {
        HStack(spacing: 6) {
            if self.isRunning {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
            self.label
        }
        .accessibilityElement(children: .combine)
        .animation(.snappy(duration: 0.16), value: self.isRunning)
    }
    .allowsHitTesting(!self.isRunning)
    .modifier(LoadingAccessibilityModifier(isLoading: self.isRunning))
    .onDisappear { self.task?.cancel() }
}

// 配套 modifier:仅在 loading 时附加 accessibilityValue("Loading")，
// idle 态完全不设 value，避免 VoiceOver 朗读空字符串。
private struct LoadingAccessibilityModifier: ViewModifier {
    let isLoading: Bool
    func body(content: Content) -> some View {
        if self.isLoading {
            content.accessibilityValue(Text("Loading"))
        } else {
            content
        }
    }
}
```

状态机只有两态: `idle ⇄ running`。无 `success` / `failure` 状态。

### 关键决策

- **用 `.allowsHitTesting(!isRunning)`,不用 `.disabled(isRunning)`**:
  - 既有 4 个 ButtonStyle 在 disabled 时会把 label `foregroundStyle` 设为 `Color.contentDisabled`(见 `SolidButtonStyle.swift:40`)。如果用 `.disabled(isRunning)`,loading 期间 label 和继承 `foregroundStyle` 的 spinner 都会变灰——直接打脸下一条 "spinner 继承 ButtonStyle 配色"。
  - `.allowsHitTesting(!isRunning)` 拦掉再次点击,但不传播 `\.isEnabled`,label 保持正常色、spinner 也跟着保持正常色。
  - VoiceOver 不再把按钮报告为 "dimmed"——用 `accessibilityValue("Loading")` 补回 loading 语义。
- **额外 `guard !isRunning` 防御**:
  - `BorderlessButtonStyle` 是 `PrimitiveButtonStyle`,用 `.onTapGesture(count: 1, perform: configuration.trigger)` 触发(`BorderlessButtonStyle.swift:49`)。即使外层 `.allowsHitTesting` 拦掉了主路径,在跨平台/手势冲突的边界场景下,在 Button action 闭包内加一句 guard 是廉价兜底。
- **spinner 颜色继承 ButtonStyle**:不在 `AsyncButton` 内显式设 `.tint(...)`,让 `ProgressView` 继承外部 `ButtonStyle` 设置的 `foregroundStyle`。
  - 由于上一条选择了 `.allowsHitTesting` 而非 `.disabled`,`foregroundStyle` 不会被切到 disabled 配色,spinner 颜色正确。
  - **仍需验证**:`ProgressView(.circular)` 实际是否响应 `foregroundStyle`(底层可能是 `UIActivityIndicatorView`)。若不响应,回退:手动 `.tint(.contentOnAccent)` / `.tint(role.color)`,会引入对具体 style 的轻度耦合。Preview 实测决定。
- **不复用 `ProgressIndicator`**:该组件硬编码 `.tint(Color.accent)`,会让 spinner 始终是品牌橙,在 `.solid(role: .primary)` 的白底文字旁视觉不协调。
- **spinner 尺寸固定 `.small`**:不跟 `\.controlSize` 联动,避免 large 按钮里 spinner 喧宾夺主。
- **`.animation(.snappy(duration: 0.16))`**:与 `SolidButtonBackgroundModifier` 的 isPressed 动画同节奏。
- **不做 pre-cancel-then-restart**:旧版本写了 `task?.cancel()` 后立刻起新 task,会让旧 task 的 `defer { isRunning = false }` 与新 task 的 `isRunning = true` 竞争,UI 抖动。改为 `.allowsHitTesting` + `guard` 双保险后,正常路径下 `isRunning == true` 时根本进不来 action 闭包,无需 cancel-restart。

## 5. 错误处理与取消

### 业务错误分派优先级

抛错 init 的业务错误按下列优先级兜底,**先匹配先消费**,每个错误只走一条路径:

1. **显式 `onError`** → 调用 `onError(error)`。
2. **`onError == nil` 且环境 `\.toastHost` 存在** → `toastHost.show(error.localizedDescription, level: .danger)`。
3. **两者都没有** → 静默(匹配 Toast 系统的"未挂 host 即无声忽略"原则,见 `Toast.swift:287-289`)。

### CancellationError

`CancellationError` **始终**静默,不走上面的兜底链——它代表"视图正常消失",不是业务故障。

### 总结表

| 路径 | `CancellationError` | 业务错误 |
|---|---|---|
| `() async -> Void` | 不会发生 | 不会发生 |
| `() async throws -> Void` + onError | 静默 | `onError(error)` |
| `() async throws -> Void` + 无 onError + `\.toastHost` 已挂 | 静默 | toast `.danger` |
| `() async throws -> Void` + 无 onError + 无 host | 静默 | 静默 |

### 实现核心(`_runThrowing` 静态分派器)

```swift
@MainActor
internal static func _runThrowing(
    _ action: @MainActor @Sendable () async throws -> Void,
    onError: (@MainActor @Sendable (Error) -> Void)?,
    toastHost: ToastHost?
) async {
    do {
        try await action()
    } catch is CancellationError {
        // 静默
    } catch {
        if let onError {
            onError(error)
        } else {
            toastHost?.show(error.localizedDescription, level: .danger)
        }
    }
}
```

view body 仅负责状态机/UI,catch 分派 100% 落在这个静态函数里——便于 Swift Testing 直接 `await` 它,而不需要驱动 SwiftUI runloop。

取消时机:
1. 视图 `onDisappear` —— 唯一场景。
2. **不做** "新点击前 cancel 已有 task":`.allowsHitTesting(!isRunning)` + `guard !isRunning` 双保险,正常路径下 `isRunning == true` 时根本进不来 action 闭包,无需 cancel-restart,避免了旧/新 task 的 `isRunning` 写入竞争。

action 内部若有长循环,应自行 `try Task.checkCancellation()`;`URLSession` / `Task.sleep` 等已合作的 API 无需额外处理。

## 6. 并发与隔离

- `action` 与 `onError` 的最终类型为 `@escaping @MainActor @Sendable () async [throws] -> Void` / `@escaping @MainActor @Sendable (Error) -> Void`:
  - `@MainActor`:与 SwiftUI 视图天然在主 actor 一致。
  - `@Sendable`:`Task { @MainActor in ... }` 内捕获 `action` / `onError` 时,Swift 6 strict concurrency 要求被捕获的闭包是 `Sendable`。
  - 调用方影响:闭包内部捕获的状态(典型如 ViewModel)需要本身是 `@MainActor` 类型(项目里 `@Observable` / Toast 等组件已是这个模式),普通值类型自动 `Sendable` 不受影响。
- `Task { @MainActor in ... }` 显式声明 isolation,避免推断歧义。
- `Task<Void, Never>`:错误已在内部 catch,不向 Task 传播,避免上层 Task tree 拿到无意义的 error。
- `onDisappear` 中只 `task?.cancel()`,不 `await`。`isRunning` 会通过被取消 task 的 `defer` 自然复位;即便视图被销毁重建,`@State` 也会重置——两条路都收敛到 `idle`。

## 7. 重载消歧

`@escaping () async -> Void` 与 `@escaping () async throws -> Void` 是不同类型,但闭包字面量 `{ await foo() }` 编译器更倾向匹配非抛错版本(non-throwing 是 throwing 的子类型)。预期:

- `{ await x() }` → 命中非抛错 init。
- `{ try await x() }` → 命中抛错 init(必须 throws 才能写 try)。
- 完全空 body `{ }` → 命中非抛错(因为 Void → Void 默认非抛错)。

### 若编译器报歧义的降级路径(按优先级)

1. **保留双 init,通过 `onError` 参数的存在区分**(首选):非抛错 init 不声明 `onError`,抛错 init 必须声明 `onError` 参数(哪怕传 nil)。`onError` 的存在让重载在 trailing closure 形态下也唯一。
2. **不同参数标签**:`action:` vs `throwing:`。调用点稍变 `AsyncButton(throwing: { try await ... })`,但保留非抛错路径的零仪式调用。
3. **单 init 仅接受 throwing 闭包**(最后兜底):非抛错调用方写 `try await x()`(必然不会真的抛),损失了大量"我就是个非抛错任务"调用点的简洁性,不推荐。

**验证项**:实现时为两个版本各写一组真实调用点,确认重载解析符合预期。若 #1 已经天然成立(实际上 `onError: ... = nil` 默认值会让两个 init 完全有歧义,所以更可能需要 #2),按上述顺序选择。

## 8. 测试

文件:`Tests/CoreDesignTests/AsyncButtonTests.swift`,使用 Swift Testing。

测试用例(以实际入库为准):

1. **非抛错 init 构造编译** —— 烟雾测试,确认 view 能正常构造。
2. **`_runThrowing` 业务错误透传** —— `onError` 存在时被调用一次,错误透传相等,**不**弹 toast(即便 toastHost 已挂)。
3. **`_runThrowing` 自动 toast fallback** —— `onError == nil` + `toastHost != nil` → toast 入队一条 `.danger` level、message 等于 `error.localizedDescription`。
4. **`_runThrowing` 全静默** —— `onError == nil` + `toastHost == nil` 不调用任何回调、不崩溃。
5. **`_runThrowing` CancellationError 静默** —— action 抛 `CancellationError`,不调 onError、不弹 toast(即便两者都存在)。
6. **重载解析** —— `LocalizedStringKey` / `StringProtocol` / trailing-closure 三种形态,非抛错与抛错版本能正确编译解析。

> 关于状态机中间态测试:在 SwiftUI View body 内驱动 `@State` 变化并精确观察 `isRunning` 在 true/false 之间的瞬时,需要嵌入 SwiftUI 的 view update runloop,该项目当前没有这类基础设施;`isRunning` 的写入位置已被 §4 代码块严格定义,直接 review code path 即可,无需运行时测试。

### Snapshot

项目已有 SnapshotTests target(`b4d9137`、`97a6241` 引入)。实际入库的是 **`docs/snapshots/CoreDesignPreview_Previews.swift_AsyncButton.{png,json}`,仅 idle 态一张**——running 态 snapshot 暂缓:`#Preview` 内的 `try await Task.sleep(...)` 无法在 snapshot 渲染那一帧把 `isRunning` 锁在 `true`,需要扩张公共 API(例如暴露 `initialIsRunning:` 测试钩子)才能稳定捕捉,代价大于收益,留待后续视觉回归发现问题时再补。spinner 颜色继承的验证由 §10 风险 1 的 Xcode Canvas 人工验收兜底。

## 9. Preview

同文件内提供 4 个 `#Preview` 块:

1. **AsyncButton — 全部 ButtonStyle**: 4 个 AsyncButton 分别套 `.solid()` / `.light()` / `.borderless()` / `.circularGlass`(`.circularGlass` 是 property 形态;`.circularGlass(diameter:)` 才是函数形态),每个 action 内 `try await Task.sleep(.seconds(1.5))`,手动点击观察 spinner 表现。
2. **AsyncButton — 抛错 + onError**: 演示 onError 自定义处理(写日志/更新状态)的最小流程。
3. **AsyncButton — 抛错 + 自动 toast fallback**: 上层挂 `.toastHost(edge: .top)`,不传 onError,失败自动以 `.danger` toast 弹出。
4. **AsyncButton — disabled / running 并存**: 验证 loading 与外部 `.disabled(true)` 同时生效的视觉。

## 10. 风险与开放问题

1. `ProgressView(.circular)` 是否响应 `foregroundStyle` —— 见 §4,有降级方案;snapshot test 兜底。
2. 闭包重载是否歧义 —— 见 §7,三档降级方案已排序。
3. `BorderlessButtonStyle`(`PrimitiveButtonStyle`)的 `.onTapGesture` 是否真的被 `.allowsHitTesting(false)` 拦住 —— 实现时 Preview 实测;`guard !isRunning` 是兜底。
4. **隐式 toast fallback 的可发现性** —— 调用方不传 `onError` 时业务错误自动以 `.danger` toast 弹出,但这个行为在 init 签名上看不出来,需要靠文档/示例传达。调用方若期望"完全静默",必须显式写 `onError: { _ in }`。短期缓解:`AsyncButton` 顶部 docstring 已写出三级兜底;长期可考虑在 debug 构建给 `onError == nil && toastHost == nil` 的场景加一次 `os_log` 警告。

这些将在实现阶段 verify-before-completion,而不是设计阶段决定。

## 11. 不影响项

- 不动 `ButtonRoleStyleRole`、不动既有 4 个 ButtonStyle、不动 `ProgressIndicator`。
- 不引入新依赖。
- 公开 API 仅新增,无破坏性变更。
