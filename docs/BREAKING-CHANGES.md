# Breaking Changes

本库当前无外部版本 tag，破坏性变更按 Issue 记录在此。下游升级前请对照。

## Issue #97（epic coredesign-audit-remediation，2026-07-21）

### 删除的公开符号

| 删除 | 替代 |
|---|---|
| `EmptyState`（组件） | SwiftUI `ContentUnavailableView` / UIKit `UIContentUnavailableView`（见 [components/empty-state.md](components/empty-state.md)） |
| `KeyboardReadable` 协议及其默认实现 | 无 CoreDesign 替代；键盘高度用 `keyboardLayoutGuide` 或自建 publisher |
| `View.dismissKeyboardOnTap(enabled:onKeyboardDismissed:)` | 同上 |
| `HideKeyboardOnTapGesture` | 同上 |
| `View.resignFirstResponder()` / `View.becomeFirstResponder()` | 直接用 UIKit/AppKit 的 first responder API |
| `anyWriterFirstResponderNotification`（= 字符串 `"io.platform.inputView.becomeFirstResponder"`） | **字符串键契约**：若下游用字面量 observe 该通知，符号 grep 查不到，请手动核对 |
| `CoreRadius.full`（= 9999） | pill 形态用 `Capsule()`，不要用大 `cornerRadius` |
| `bordered(color:width:)` 重载 | `bordered(style:width:shape:)`（`Color` 已 conform `ShapeStyle`，直接传） |

### 签名变更（源码兼容，追加带默认值的参数）

| 变更 | 说明 |
|---|---|
| `bordered(style:width:)` → `bordered(style:width:shape:)` | 新增 `shape` 参数（默认 `Rectangle()`）；同时描边从 `stroke` 改 `strokeBorder`，边框向内收 `width/2` |

> **零引用验证**：上述删除的符号已在真实下游 `any-writer` 实测零引用（排除其 vendored CoreDesign 副本）。唯一无法用 grep 覆盖的是 `anyWriterFirstResponderNotification` 的**字符串键**——已单独在上表标注。
