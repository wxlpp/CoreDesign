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
`0`–`9`）并 clamp 长度，结果写回 `Binding`；当结果字符数等于 `length` 时触发
`onComplete?(value)`。组件挂载时（`onAppear`）也会先跑一遍同一套处理流水线——若调用方
传入的初始 `value` 本身带有非数字字符或超出 `length`，格子渲染前先规整。

> **已知取舍**：在「已填满后又输入被过滤掉的噪声字符」这类边缘场景下，可能因为一次
> 「写回清洗值 → 触发下一轮变化处理」的连锁反应而对同一次用户操作调用 `onComplete`
> 两次（两次参数相同、幂等）。未做额外去重状态跟踪——验收标准只要求「输入填满时触发
> 回调」，不要求「每次填满事件严格恰好触发一次」。

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
