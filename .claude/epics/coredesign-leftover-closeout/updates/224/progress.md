---
issue: 224
started: 2026-09-03
completion: 100%
---

# Issue #224 进度

⚠️ **本节初版写「两处都走了 Option A、未使用 Option B」——对 SegmentedControl 那半是
失实的定性**（评审 I-7 指出，核实成立）：

| 处 | 实际路线 |
|---|---|
| `StateLabel` | **Option A**——真运行时断言，直接比对 label payload |
| `SegmentedControl` | **Option B + 一条新增的弱命题断言**。原 `plainStyleOptsOutOfGlass` 被**如实改名**为 `plainStyleModifierCompiles` 并注明能力边界，这正是任务书定义的 Option B 路线 |

产物本身没问题（测试名诚实、能力边界写在注释里），**失实的是我对它的定性**。已更正。

## 1 · `StateLabel` label payload

**可断言的依据**：`StateLabel.label` 是 internal 存储属性（`@testable` 够得到），
且 `Label == Text` 时 SwiftUI 的 `Text` 是 `Equatable`——能直接比对 payload，不必渲染。

新增三条：
- 便利 init 把自定义文案接进 label payload
- 省略 label 时回落到 `spec.defaultLabel`（遍历全部 6 个 style）
- 自定义与默认产出**不同** payload（防「恒取 defaultLabel」这类退化）

### ⚠️ 踩到的坑：`Text("字面量")` 与 `Text(变量)` 不相等

首版写 `#expect(label.label == Text("Saving…"))` **判红**。原因：
`Text("字面量")` 走 `LocalizedStringKey` init，`Text(变量)` 走 `String` init，
storage 不同（`.verbatim` vs 本地化键），`==` 为 false。
源码里是 `Text(label ?? ...)` 的变量路径，故期望值也须经 String 变量构造。
**写错方向就是个恒假断言**——已把这条写进测试注释。

## 2 · `SegmentedControl` style 四件套

原 `plainStyleOptsOutOfGlass` 函数体末尾是 `_ = styled`——纯编译检查、无运行时断言，
却顶着一个承诺行为的名字。拆成两条各自诚实的：

- **`plainStyleModifierCompiles`**：如实改名 + 注明「只能做到这一步、不验证外观」。
- **`plainStyleTakesDifferentRenderPathThanGlass`**（**iOS-only**）：iOS 上 Glass 走
  `NativeGlassSegmentedControl`（UIKit 桥接）、Plain 走 SwiftUI 回退。

  ⚠️ **初版只断言 `type(of:) !=`，被评审指为超卖**：那对**任何**结构差异都真——
  把 plain 改成「也走 `NativeGlassSegmentedControl`，只是外包一层 `.padding`」，
  类型仍不同、断言照样绿，而命题已经假了。已加强为：glass 的 body 类型**必须含**
  `NativeGlassSegmentedControl`、plain **必须不含**，把命题真正钉在类型上。

### 能力边界（已写进测试注释）

`SwiftUISegmentedControl` 与 `SegmentedControlBackgroundModifier` 都是 `private`，
`@testable` 也够不到，因此**无法直接断言 `glass == false`**。macOS 上两个 style
都回落到 `SwiftUISegmentedControl`（仅私有 `glass` 属性不同）、类型相同，故第二条
限定 iOS。玻璃材质是否真渲染出来，只有截图能回答（#225）。

## 验证

- **macOS**：`swift test --filter StateLabel` 8 tests 全绿；`--filter SegmentedControl` 4 tests 全绿
- **iOS**：`xcodebuild` 两个 suite 共 **13 tests 全绿，`** TEST SUCCEEDED **`**
  （含 iOS-only 那条）
- **变异自证**（把便利 init 的 `Text(label ?? style.spec.defaultLabel)` 改成
  `Text(style.spec.defaultLabel)`，即吞掉自定义入参）：

  ```
  ✘ 便利 init 把自定义文案接进 label payload
      (label.label → Text(storage: .verbatim("In Progress")))
      == (Text(text) → Text(storage: .verbatim("Saving…")))
  ✘ 自定义文案不会被默认文案覆盖——两条路径产出不同 payload
      (custom.label → .verbatim("In Progress")) != (defaulted.label → .verbatim("In Progress"))
  ```

  还原后恢复全绿。**变异打在「便利 init 的 payload wiring」这个目标命题上**，
  正是原测试缺失覆盖的那个洞。
