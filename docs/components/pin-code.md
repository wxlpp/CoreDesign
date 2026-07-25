# PinCode

`Binding<String>` 驱动的验证码 / PIN 分格输入组件 / PIN & OTP entry control driven by a
`Binding<String>`，固定格数。

渲染层是 `length` 个独立格子，按下标把 `value` 拆成单字符展示；输入层复用**单一隐藏
`TextField`** 捕获系统键盘输入（常见 OTP 实现手法）——两端天然获得同一套光标跟随 /
退格删除上一位 / 粘贴多位数字 / iOS 单条码 OTP 自动填充横幅行为，不需要每格各自
`FocusState` + 手写前后跳转逻辑。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| value | Binding\<String\> | - | 当前验证码文本，双向绑定；组件内部过滤非数字字符并 clamp 到 `length` |
| length | Int | - | 固定格数；非正数会被 clamp 到 1 |
| isSecure | Bool | false | 掩码显示是否开启；开启后各格以圆点（`•`）替代实际字符 |
| onComplete | ((String) -> Void)? | nil | 输入填满 `length` 格时触发，参数为最终值 |

## 双端实现差异（NFR-2：不留单端公开符号）

公开 API（类型 / init / 参数）在 iOS 与 macOS 两端完全一致；平台差异全部封装在隐藏
`TextField` 实现内部的 `#if os(iOS)` 分支：

```swift
TextField("", text: $value)
    #if os(iOS)
    .textContentType(.oneTimeCode)  // 触发系统单条码 OTP 自动填充
    .keyboardType(.numberPad)       // 数字键盘；该 API 在 macOS 不存在
    #endif
```

- **iOS**：追加 `.textContentType(.oneTimeCode)` + `.keyboardType(.numberPad)`。
- **macOS**：复用同一个 `TextField`，跳过以上两个 modifier——`.keyboardType` 在 macOS
  上不存在，`.textContentType(.oneTimeCode)` 在 macOS 上无实际效果。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。同文件 `#Preview`
覆盖 Light / Dark 两份画廊：空态 / 部分填充 / 填满态 / `isSecure: true`（4 位 PIN）/
覆盖 `.tint` / `.disabled(true)`。

## 使用示例 / Usage

```swift
@State private var code: String = ""

PinCode(value: $code, length: 6) { completed in
    verify(completed)
}

// 掩码显示（PIN 场景）
PinCode(value: $pin, length: 4, isSecure: true)

// 覆盖强调色——焦点格边框走 `.tint`，不写死 `Color.accent`
PinCode(value: $code, length: 6)
    .tint(.orange)
```

## 受控逻辑

每次 `value` 变化都经 `sanitizedValue(from:length:)` 过滤非数字字符（仅保留 ASCII
`0`–`9`）并 clamp 长度，结果写回 `Binding`。`onComplete` **仅在「未满 → 满」的转变沿**
触发（比对 `onChange` 提供的击键前旧值 vs 清洗后新值）——满态后继续输入、写回引发的第二轮
变化、以及挂载重放都不会重复触发；删一位再补回最后一位会正确再次触发。

> **挂载语义**：组件挂载（`onAppear`）时会先规整初始 `value`（去非数字/截断），但**不触发
> `onComplete`**——「初值即完成」不是一次「填满」事件，且若触发，在 `NavigationStack` 里
> `onComplete` 跳转 → 用户 pop 返回 → 再次挂载会形成 push→pop→再 push 循环。若调用方需要
> 「预填初值也回调一次」，请在自己的 `.task`/`.onAppear` 里显式调用。
>
> **验证失败后请清空 `value`**：满态下自动填充/粘贴整体**替换**成另一个完整码会正常再次触发
> `onComplete`；但若替换是**追加**（罕见），超长部分会被 `prefix(length)` 吞掉、值不变、无反馈。
> 统一的稳妥做法是——验证失败后把 `value` 清空，让下一个码走干净的「空 → 满」路径。

## 视觉 Token

- 格子背景：`Color.surfaceInteractive`
- 焦点格边框：`.tint`（`TintShapeStyle`，响应环境 `.tint(_:)`，未显式设置时解析为宿主
  App 的 `Color.accentColor`），`CoreBorderWidth.thick`
- 非焦点格边框：`Color.borderMuted`，`CoreBorderWidth.thin`
- 禁用态文字：`Color.contentDisabled`；正常态：`Color.contentPrimary`
- 圆角：`CoreRadius.medium`
- 格间距：`CoreSpacing.sm`
- 格尺寸：`CoreControlMetrics.height(for: controlSize)`（正方形），随 `\.controlSize`
  环境值变化

## Accessibility

- 每格是独立的 accessibility element：
  - label：Phase 0 预登记键 `"Verification code"`
  - value：位置键 `"%@ of %@"`，经
    `String(localized: "\(index.formatted()) of \(count.formatted())", bundle: .module)`
    组装（`PinCode.positionText(index:count:)`），`index` 为 1-based，如「3 of 6」
  - 当前焦点格额外带 `.isSelected` trait
- 真正承接键盘输入的隐藏 `TextField` 对 accessibility 树隐藏
  （`.accessibilityHidden(true)`）——避免与逐格 element 重复播报；VoiceOver 双击某一格时
  经 `.accessibilityAction` 把内部 `isFocused` 设为 `true`，转发到隐藏字段唤起键盘。
- 无第 1 层色相硬编码、无字面 `Color.accent`。
