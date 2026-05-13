# AsyncButton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个 SwiftUI `AsyncButton`,把"接收 async 闭包 + loading 期间显示 spinner + 防双击 + 视图消失自动取消 Task"的模板内聚到组件里,正交于既有 4 个 `ButtonStyle`。

**Architecture:** 单文件视图组件,wrapping `Button`。内部 `@State` 持有 `Task<Void, Never>?` 和 `isRunning: Bool`;loading 期间用 `.allowsHitTesting(!isRunning)` 拦截点击(不用 `.disabled`,避免触发既有 style 的 disabled 配色把 label/spinner 染灰),用 `accessibilityValue("Loading")` 补回 VoiceOver 语义。`onDisappear` 取消 Task。`Button` action 闭包内 `guard !isRunning` 兜底 `BorderlessButtonStyle` 这种 `PrimitiveButtonStyle` 不被 `\.isEnabled` 自动 gate 的边界。

**Tech Stack:** Swift 6 (strict concurrency, `@MainActor @Sendable`),SwiftUI iOS 26+ / macOS 26+,Swift Testing(`@Suite` / `@Test` / `#expect`),SnapshotPreviews (EmergeTools, `#Preview` 自动生成 PNG)。

**Spec:** `docs/superpowers/specs/2026-05-13-async-button-design.md`

---

## File Structure

- **Create**: `Sources/CoreDesign/Components/Button/AsyncButton.swift`
  - 公开 `struct AsyncButton<Label: View>: View`
  - 两个核心 init(非抛错 / 抛错 + onError)
  - 四个文本便捷 init(`where Label == Text` 扩展)
  - 内部 `wrapThrowingAction(_:onError:)` 辅助
  - 三个开发用 `#Preview`(全 style / 抛错+onError / disabled 与 running 并存)
- **Create**: `Tests/CoreDesignTests/AsyncButtonTests.swift`
  - 5 个 `@Test`:wrapping 业务错误路径 / CancellationError 静默 / onError nil 安全 / 非抛错路径 / 重载解析编译期检查
- **Modify**: `App/Sources/Previews.swift`
  - 末尾追加 `#Preview("AsyncButton")` 一项,展示 4 个 style 的 idle-state AsyncButton

---

## Task 1: AsyncButton 骨架 + 非抛错 init + 状态机渲染

**Files:**
- Create: `Sources/CoreDesign/Components/Button/AsyncButton.swift`
- Test: `Tests/CoreDesignTests/AsyncButtonTests.swift`

- [ ] **Step 1.1: 写第一个失败测试 —— 实例化烟雾测试**

创建 `Tests/CoreDesignTests/AsyncButtonTests.swift`:

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AsyncButton")
@MainActor
struct AsyncButtonTests {

    @Test("非抛错 init 能正常构造")
    func nonThrowingInitCompiles() {
        _ = AsyncButton(action: { }) {
            Text("Tap")
        }
    }
}
```

- [ ] **Step 1.2: 跑测试确认失败**

```bash
swift test --filter CoreDesignTests.AsyncButton
```

预期:`error: cannot find 'AsyncButton' in scope`(或类似未定义错误)。

- [ ] **Step 1.3: 创建 AsyncButton.swift 最小实现**

创建 `Sources/CoreDesign/Components/Button/AsyncButton.swift`:

```swift
//
//  AsyncButton.swift
//  CoreDesign
//

import SwiftUI

// MARK: - AsyncButton

/// 把 async 闭包封装成按钮的视图组件。
///
/// 自动管理 loading 期间的 spinner、防双击、视图消失时取消 Task。与既有 4 个
/// `ButtonStyle`(`.solid` / `.light` / `.borderless` / `.circularGlass`)正交,
/// 调用方依旧用 `.buttonStyle(...)` 设置外观。
///
/// 详细设计见 `docs/superpowers/specs/2026-05-13-async-button-design.md`。
public struct AsyncButton<Label: View>: View {

    @State private var task: Task<Void, Never>?
    @State private var isRunning = false

    private let action: @MainActor @Sendable () async -> Void
    private let label: Label

    /// 非抛错 init。
    public init(
        action: @escaping @MainActor @Sendable () async -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.action = action
        self.label = label()
    }

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
                await self.action()
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
}

// MARK: - LoadingAccessibilityModifier

/// 仅在 loading 期间附加 `accessibilityValue("Loading")`；idle 态完全不设 value，
/// 避免 VoiceOver 朗读空字符串或多一次停顿。
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

- [ ] **Step 1.4: 跑测试确认通过**

```bash
swift test --filter CoreDesignTests.AsyncButton
```

预期:1 passed。

- [ ] **Step 1.5: 跑完整测试套确认无回归**

```bash
swift test
```

预期:所有既有测试继续通过。

- [ ] **Step 1.6: Commit**

```bash
git add Sources/CoreDesign/Components/Button/AsyncButton.swift \
        Tests/CoreDesignTests/AsyncButtonTests.swift
git commit -m "$(cat <<'EOF'
feat(AsyncButton): 基础骨架,非抛错 init + 状态机渲染

实现 spec §3/§4 的非抛错路径:.allowsHitTesting(!isRunning) +
guard !isRunning + .onDisappear 取消 Task。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 抛错 init + onError + CancellationError 静默

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/AsyncButton.swift`
- Modify: `Tests/CoreDesignTests/AsyncButtonTests.swift`

> **Plan amendment (R4+, 2026-05-13)**:Task 2 在 PR #71 review 过程中演进——
> 原方案在 init 里同步把 throwing closure 包装成 non-throwing,函数名
> `_wrapThrowingAction`;后改为在 view body 里 lazy resolve(用 enum `ActionKind`
> 存 `(action, onError)`,body 读 `@Environment(\.toastHost)` 后再分派),
> 静态分派器更名 `_runThrowing`。Spec §5 同步加入 onError → toastHost
> → silent 三级兜底。下面 Step 2.1–2.5 已按最终方案重写。

- [ ] **Step 2.1: 写失败测试 —— `_runThrowing` 业务错误调用 onError**

把测试文件追加为:

```swift
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("AsyncButton")
@MainActor
struct AsyncButtonTests {

    private struct DemoError: Error, Equatable {
        let code: Int
    }

    @Test("非抛错 init 能正常构造")
    func nonThrowingInitCompiles() {
        _ = AsyncButton(action: { }) { Text("Tap") }
    }

    @Test("_runThrowing:业务错误透传给 onError(不弹 toast)")
    func runThrowingBusinessErrorCallsOnError() async {
        let host = ToastHost()
        var captured: Error?
        await AsyncButton<Text>._runThrowing(
            { throw DemoError(code: 42) },
            onError: { captured = $0 },
            toastHost: host
        )
        #expect((captured as? DemoError) == DemoError(code: 42))
        #expect(host.queue.isEmpty)
    }

    @Test("_runThrowing:onError nil + toastHost 存在 → 自动弹 .danger toast")
    func runThrowingFallsBackToToast() async {
        let host = ToastHost()
        await AsyncButton<Text>._runThrowing(
            {
                struct AutoToastError: LocalizedError {
                    var errorDescription: String? { "Demo failure" }
                }
                throw AutoToastError()
            },
            onError: nil,
            toastHost: host
        )
        #expect(host.queue.count == 1)
        #expect(host.queue.first?.level == .danger)
    }

    @Test("_runThrowing:onError nil + toastHost nil → 静默,不崩")
    func runThrowingSilentWithoutHandlers() async {
        await AsyncButton<Text>._runThrowing(
            { throw DemoError(code: 1) },
            onError: nil,
            toastHost: nil
        )
    }

    @Test("_runThrowing:CancellationError 静默 — 不调 onError、不弹 toast")
    func runThrowingCancellationSilent() async {
        let host = ToastHost()
        var onErrorCalled = false
        await AsyncButton<Text>._runThrowing(
            { throw CancellationError() },
            onError: { _ in onErrorCalled = true },
            toastHost: host
        )
        #expect(onErrorCalled == false)
        #expect(host.queue.isEmpty)
    }
}
```

- [ ] **Step 2.2: 跑测试确认失败**

```bash
swift test --filter CoreDesignTests.AsyncButton
```

预期:`error: type 'AsyncButton<Text>' has no member '_runThrowing'`。

- [ ] **Step 2.3: 实现 ActionKind + lazy-resolve body + `_runThrowing`**

在 `AsyncButton.swift` 顶部增加 `@Environment(\.toastHost)`,把 init 的存储从
`action: () async -> Void` 改成 `kind: ActionKind`,然后追加 `_runThrowing` 静态
分派器与抛错 init。最终结构对齐 §4 / §5,核心片段:

```swift
@Environment(\.toastHost) private var toastHost
private let kind: ActionKind

public init(
    action: @escaping @MainActor @Sendable () async throws -> Void,
    onError: (@MainActor @Sendable (Error) -> Void)? = nil,
    @ViewBuilder label: () -> Label
) {
    self.kind = .throwing(action: action, onError: onError)
    self.label = label()
}

@MainActor
private func run() async {
    switch self.kind {
    case .nonThrowing(let action):
        await action()
    case .throwing(let action, let onError):
        await Self._runThrowing(
            action,
            onError: onError,
            toastHost: self.toastHost
        )
    }
}

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

private enum ActionKind {
    case nonThrowing(@MainActor @Sendable () async -> Void)
    case throwing(
        action: @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)?
    )
}
```

- [ ] **Step 2.4: 跑测试确认通过**

```bash
swift test --filter CoreDesignTests.AsyncButton
```

预期:5 passed(原 1 + 新增 4 个:onError 透传、toast fallback、双 nil 静默、Cancellation 静默)。

- [ ] **Step 2.5: Commit**

```bash
git add Sources/CoreDesign/Components/Button/AsyncButton.swift \
        Tests/CoreDesignTests/AsyncButtonTests.swift
git commit -m "$(cat <<'EOF'
feat(AsyncButton): 抛错 init + 错误三级兜底(onError → toastHost → silent)

新增 init(action: () async throws -> Void, onError:..) 与内部
_runThrowing 静态分派器。CancellationError 静默;业务错误优先调
onError,若 nil 则尝试 @Environment(\.toastHost) 自动以 .danger
弹 toast,host 不存在则静默(匹配 Toast 系统的"未挂 host 即无声忽略"
原则)。spec §5。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 文本便捷 init + 重载解析编译期检查

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/AsyncButton.swift`
- Modify: `Tests/CoreDesignTests/AsyncButtonTests.swift`

- [ ] **Step 3.1: 写失败测试 —— 重载解析(编译即通过)**

在 `AsyncButtonTests.swift` 的 `struct AsyncButtonTests {` 内追加:

```swift
    @Test("重载解析:非抛错文本 init 编译")
    func nonThrowingTextInitsCompile() {
        // LocalizedStringKey 重载
        _ = AsyncButton("Submit", action: { })
        // StringProtocol 重载
        let title: String = "Submit"
        _ = AsyncButton(title, action: { })
    }

    @Test("重载解析:抛错文本 init 编译")
    func throwingTextInitsCompile() {
        struct DemoError: Error {}
        _ = AsyncButton("Submit",
                        action: { throw DemoError() },
                        onError: { _ in })
        let title: String = "Submit"
        _ = AsyncButton(title,
                        action: { throw DemoError() },
                        onError: { _ in })
        // onError 省略
        _ = AsyncButton("Submit", action: { throw DemoError() })
    }
```

- [ ] **Step 3.2: 跑测试确认失败**

```bash
swift test --filter CoreDesignTests.AsyncButton
```

预期:`error: extra argument 'action' in call`(或类似——文本 init 还没实现)。

- [ ] **Step 3.3: 实现四个文本便捷 init**

在 `AsyncButton.swift` 文件底部、`}` 关闭 `AsyncButton` 之后、`#Preview` 之前追加:

```swift
// MARK: - Text label conveniences

public extension AsyncButton where Label == Text {

    /// LocalizedStringKey + 非抛错。
    init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.init(action: action) { Text(titleKey) }
    }

    /// StringProtocol + 非抛错。
    init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.init(action: action) { Text(title) }
    }

    /// LocalizedStringKey + 抛错 + 可选 onError。
    init(
        _ titleKey: LocalizedStringKey,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        self.init(action: action, onError: onError) { Text(titleKey) }
    }

    /// StringProtocol + 抛错 + 可选 onError。
    init<S: StringProtocol>(
        _ title: S,
        action: @escaping @MainActor @Sendable () async throws -> Void,
        onError: (@MainActor @Sendable (Error) -> Void)? = nil
    ) {
        self.init(action: action, onError: onError) { Text(title) }
    }
}
```

- [ ] **Step 3.4: 跑测试确认通过**

```bash
swift test --filter CoreDesignTests.AsyncButton
```

预期:6 passed。**若编译报 "ambiguous use of init"**,按 spec §7 的降级路径处理:首选给抛错重载的 `action` / `onError` 改成具名标签 `throwing:` / `catch:`,把 plan 的后续 step 也对齐修订。这是 spec §10 风险 2 的兜底。

- [ ] **Step 3.5: Commit**

```bash
git add Sources/CoreDesign/Components/Button/AsyncButton.swift \
        Tests/CoreDesignTests/AsyncButtonTests.swift
git commit -m "$(cat <<'EOF'
feat(AsyncButton): 文本便捷 init + 重载解析编译期检查

新增 4 个 init(LocalizedStringKey/StringProtocol × 非抛错/抛错)
作为 AsyncButton where Label == Text 扩展。重载解析依赖闭包
throwing 属性的 subtype 关系——非抛错闭包字面量优先匹配非抛错
init。spec §3 / §7。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 库内 `#Preview` 块(开发可视化)

**Files:**
- Modify: `Sources/CoreDesign/Components/Button/AsyncButton.swift`

库文件内的 `#Preview` 用于开发期在 Xcode Canvas 实测视觉与交互。snapshot 脚本会删除 `CoreDesign_*.png`,这些 preview 不入库。

- [ ] **Step 4.1: 追加三个 `#Preview` 块到 AsyncButton.swift 末尾**

```swift
// MARK: - Previews (development only — snapshot 脚本会删除 CoreDesign_*.png)

#Preview("AsyncButton — 全部 ButtonStyle") {
    VStack(spacing: 12) {
        AsyncButton("Solid") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.solid())

        AsyncButton("Light") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.light())

        AsyncButton("Borderless") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.borderless())

        AsyncButton {
            try? await Task.sleep(for: .seconds(1.5))
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.circularGlass)
    }
    .padding()
}

#Preview("AsyncButton — 抛错 + onError") {
    struct Harness: View {
        @State private var lastError: String = "(none)"
        var body: some View {
            VStack(spacing: 12) {
                AsyncButton("Throws") {
                    try await Task.sleep(for: .seconds(0.6))
                    struct DemoError: LocalizedError {
                        var errorDescription: String? { "Demo failure" }
                    }
                    throw DemoError()
                } onError: { error in
                    self.lastError = error.localizedDescription
                }
                .buttonStyle(.solid(role: .primary))

                Text("Last error: \(self.lastError)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    return Harness()
}

#Preview("AsyncButton — disabled / running 并存") {
    VStack(spacing: 12) {
        AsyncButton("Always disabled") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.solid())
        .disabled(true)

        AsyncButton("Normal") {
            try? await Task.sleep(for: .seconds(1.5))
        }
        .buttonStyle(.solid())
    }
    .padding()
}
```

- [ ] **Step 4.2: 在 Xcode 中打开 AsyncButton.swift,启动 Canvas Preview**

打开 `Sources/CoreDesign/Components/Button/AsyncButton.swift` 在 Xcode 中,激活 Canvas(Cmd-Option-Return),勾选 Live Preview(Cmd-Option-P 或 Resume)。

**手动验证清单**(每条都要在 Canvas 里点一下确认):
- [ ] **Preview 1 全部 style**:点 Solid 按钮 → spinner 出现在 "Solid" 文字左侧,白色;0.16s 内 label 不抖动;1.5s 后回到 idle。
- [ ] **Preview 1 颜色**:Light / Borderless 的 spinner 颜色与 label 文字一致(role color),不是品牌橙。**这是 spec §10 风险 1 的现场验证**。若 spinner 是橙色或灰色,说明 `ProgressView(.circular)` 不响应 `foregroundStyle`,回退到 spec §4 列出的手动 `.tint(...)` 方案——回到 Task 1 给 `ProgressView` 加按 style 路由的 tint。
- [ ] **Preview 1 防双击**:loading 中再点 → 不重复触发(spinner 不闪也不并行)。
- [ ] **Preview 1 圆形**:CircularGlass 按钮 spinner 居中,不撑破圆形外壳。
- [ ] **Preview 2 抛错**:点按钮,0.6s 后 spinner 消失,下方 Text 显示 "Last error: Demo failure"。
- [ ] **Preview 3 disabled**:第一个按钮 disabled 灰色不可点;第二个正常运行。两者并存视觉对比正常(disabled label 灰,running label 不灰)。

- [ ] **Step 4.3: 命令行确认 swift build 通过**

```bash
swift build
```

预期:Build complete!,无 warning。

- [ ] **Step 4.4: Commit**

```bash
git add Sources/CoreDesign/Components/Button/AsyncButton.swift
git commit -m "$(cat <<'EOF'
feat(AsyncButton): 库内 #Preview 块(开发可视化)

三个 #Preview:全 style / 抛错+onError / disabled+running 并存。
这些 preview 的 PNG 由 snapshot 脚本扫描并删除,不入库,只用于
Xcode Canvas 开发期实测。Snapshot 入库的版本在 App/Sources/Previews.swift。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: App snapshot entry + 重新生成 + 入库

**Files:**
- Modify: `App/Sources/Previews.swift`
- Create (regenerated): `docs/snapshots/CoreDesignPreview_Previews.swift_AsyncButton.png` 及对应 `.json` sidecar(实际 EmergeTools SnapshotPreviews 产出的命名,与既有所有组件一致;**plan 早期版本误写为 `_Light/_Dark.png` 后缀,以本节为准**)

- [ ] **Step 5.1: 在 `App/Sources/Previews.swift` 追加 `#Preview("AsyncButton")`**

打开 `App/Sources/Previews.swift`,在 "Three-in-one components" 一节下方或文件末尾追加:

```swift
#Preview("AsyncButton") {
    VStack(spacing: CoreSpacing.sm) {
        AsyncButton("Solid Primary") { }.buttonStyle(.solid(role: .primary))
        AsyncButton("Light Secondary") { }.buttonStyle(.light(role: .secondary))
        AsyncButton("Borderless Danger") { }.buttonStyle(.borderless(role: .danger))
        AsyncButton {
            // idle 态 snapshot,这里无需真的 sleep
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.circularGlass)   // 注意:property 形态,不带括号(.circularGlass(diameter:) 才是函数形态)
    }
    .padding()
}
```

**Snapshot 范围限制说明**:仅 idle 态。Running 态 snapshot 需要扩张 AsyncButton 公共 API(例如加 `autoTriggerOnAppear` 参数,或暴露 `internal` 测试入口),计划主动避开。Idle 态 snapshot 能锁住:(a)四种 style 的 idle 渲染没有 layout 异常,(b)`HStack(spacing: 6)` 在 spinner 缺席时不引入额外 spacing,(c)4 种 style 都能接受 AsyncButton 作为内容容器。Running 态视觉验证由 Task 4 的 Xcode Canvas 手动 check 兜底。

- [ ] **Step 5.2: 重新生成 snapshots**

```bash
./scripts/run-snapshots.sh
```

预期:`X PNGs generated`(应比上次多 1 张:`CoreDesignPreview_Previews.swift_AsyncButton.png`,加上 1 个对应的 `.json` sidecar)。

- [ ] **Step 5.3: 视觉抽查新生成的 PNG**

```bash
open docs/snapshots/CoreDesignPreview_Previews.swift_AsyncButton.png
```

**核对清单**:
- [ ] 4 个按钮垂直排列,无 layout 错位
- [ ] 文字与背景对比度正常
- [ ] `.solid` 玻璃效果可见,`.circularGlass` 圆形外壳清晰
- [ ] 无 spinner(idle 态)

- [ ] **Step 5.4: Commit snapshot 与 Previews.swift 修改**

```bash
git add App/Sources/Previews.swift \
        docs/snapshots/CoreDesignPreview_Previews.swift_AsyncButton.png \
        docs/snapshots/CoreDesignPreview_Previews.swift_AsyncButton.json
git commit -m "$(cat <<'EOF'
test(AsyncButton): 增加 App snapshot preview(idle 态)

App/Sources/Previews.swift 增加一个 AsyncButton entry,产出
docs/snapshots/CoreDesignPreview_Previews.swift_AsyncButton.png(+.json
sidecar)用于锁住 idle 态布局。Running 态 snapshot 暂缓——需要扩张
公共 API 才能强制进入 running 态,与 spec §2 minimal API 目标冲突。
Running 态由 Task 4 的 Xcode Canvas 手动验证 + Tests/CoreDesignTests 的 Swift Testing
单测覆盖。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 最终验证 + 收尾

**Files:** (验证为主,无新增改动)

- [ ] **Step 6.1: 完整 swift build**

```bash
swift build
```

预期:Build complete!,Swift 6 strict concurrency 0 warning。**若出现 `@Sendable` 相关 warning**,回到 Task 1/2 检查闭包类型注解(spec §6 已预先收敛到 `@MainActor @Sendable`,不应出现遗漏)。

- [ ] **Step 6.2: 完整 swift test**

```bash
swift test
```

预期:全部 pass(既有测试 + 新增 6 个 AsyncButton 测试)。

- [ ] **Step 6.3: 单独跑 AsyncButton 测试看明细**

```bash
swift test --filter CoreDesignTests.AsyncButton
```

预期:6 passed in N seconds。

- [ ] **Step 6.4: 重新跑 snapshot 脚本确认无回归**

```bash
./scripts/run-snapshots.sh
git status
```

预期:`git status` 显示无 PNG diff(已 commit 的 idle-state PNG 与新生成的应字节相同)。**若有 diff**,说明 idle 态视觉不稳定 / 渲染随机性问题,调查后再决定提交 vs 还原。

- [ ] **Step 6.5: 在 Xcode 里再次开 AsyncButton.swift Canvas 跑一遍 Task 4 的手动验证清单**

依据 Task 4 Step 4.2 的清单逐条点。这是 verify-before-completion 的关键 step,因为 §10 风险 1(spinner 颜色)只能视觉验证,不能 unit test 覆盖。

- [ ] **Step 6.6: 实现完成 commit(若 step 6.1~6.5 触发任何修订)**

如果前面 step 触发任何 hotfix(例如发现 spinner 颜色不对,需要给 ProgressView 加 `.tint(...)`),把 fix 提交;否则跳过这步。

```bash
# 示例:若修订
git add Sources/CoreDesign/Components/Button/AsyncButton.swift
git commit -m "fix(AsyncButton): <具体修订>"
```

---

## Spec 偏离声明

| Spec 章节 | Plan 偏离 | 原因 |
|---|---|---|
| §8 "为 spinner-next-to-label 布局补 4 张 snapshot,running 状态各一张" | 只入库 idle 态 snapshot,running 态由 Xcode Canvas 手动 check + Swift Testing 单测兜底 | Running 态需要强制 AsyncButton 进入 isRunning,而当前 API 设计(spec §2 明确不暴露 `isLoading` Binding)没有提供 snapshot-only 入口。强行实现需要扩张 API,与 spec minimal surface 目标冲突。Plan Task 5 在 commit 信息中显式标注。 |

无其它偏离。

---

## Verify-before-completion Checklist

实现完成后,声明 "feature done" 前必须 ALL CHECKED:

- [ ] `swift build` 成功,无 warning
- [ ] `swift test` 全部通过(既有 + 新增 6 个)
- [ ] `./scripts/run-snapshots.sh` 跑通,`git status` 显示无 PNG 异动
- [ ] Xcode Canvas 上 Task 4 Step 4.2 的 7 项手动验证全部通过
- [ ] spec §10 三个风险的 verify 项都有结论(spinner 颜色 / 重载消歧 / borderless gate):
  - 风险 1 spinner 颜色:Canvas 验证通过,或已应用 `.tint(...)` 回退
  - 风险 2 重载消歧:Task 3 Step 3.4 编译通过
  - 风险 3 borderless gate:Task 4 Step 4.2 第 3 条 "loading 中再点不重复触发" 在 borderless 上也验证过

---

## Out of scope(留给后续 PR)

- Running-state snapshot 入库
- 成功 / 失败 transient 状态动画(spec §2 已声明非目标)
- 对外暴露 `isLoading` Binding(spec §2 已声明非目标)
- `.asyncSolid()` 之类的 ButtonStyle wrapper(spec §2 已声明非目标)
- AsyncButton 的 SwiftUI iOS 18 / macOS 15 回退(spec/项目锁定 iOS 26+)
