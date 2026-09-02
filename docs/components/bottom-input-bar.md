# BottomInputBar

> ⚠️ **Issue #221 起 `BottomInputBar` 是 `public` 类型。**
>
> 此前它是 internal，唯一的 public 表面是 `View.bottomInputBar(...)` modifier，
> `docs/component-contract.md` 的终审 C1 裁决据此把它**排除出组件登记表**。
> #221 走了该裁决自己给出的第二条出路（给它一个可登记的 public 类型表面），
> 它现已按判定法登记为 `prescriptive` / `tiebreaker`（走查过程见
> `docs/component-registry.json` 该条目 notes）。
>
> **推荐用法仍是 modifier** —— 它额外接管 suggestions 列表与显隐动画。
> 直接构造 `BottomInputBar` 适用于调用方要自己持有 `isShowingSuggestions` 的场景，
> demo app 的「BottomInputBar」条目就是这种用法的可交互示例。


底部输入栏 Modifier / Bottom input bar modifier.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| suggestions | [String] | - | 建议列表 |
| placeholder | String | "iMessage" | 占位提示 |
| autoShowSuggestions | Bool | false | 非空时自动展开建议 |
| wandEnabled | Bool | true | 是否显示建议按钮 |
| sendEnabled | Bool | true | 是否可发送 |
| showMenuButton | Bool | true | 是否显示菜单按钮 |
| isRunning | Bool | false | 是否正在运行 |
| showShuffleButton | Bool | true | 是否显示换一批按钮 |
| autoFocus | Bool | false | mount 时自动聚焦 |
| externalFocus | FocusState<Bool>.Binding? | nil | 外部 FocusState 绑定，用于外部控制聚焦 |
| onActivate | (() -> Void)? | nil | 激活输入回调 |
| onStop | (() -> Void)? | nil | 停止回调 |
| onSubmit | (String) -> Void | - | 提交回调 |

## 预览 / Preview

此组件依赖键盘交互，需运行 App 后在界面中触发。运行 `scripts/run-preview.sh` 启动预览 App 体验效果。

## 使用示例 / Usage

```swift
Color.clear
    .bottomInputBar(
        suggestions: ["续写下一段", "换个风格", "润色文字", "生成对话"],
        placeholder: "输入消息"
    ) { text in
        print("发送: \(text)")
    }
```

## 视觉 Token

- 背景：`.glassEffect(.regular, in: BottomInputBarGlassEffectShape())`
- 内边距：横向 `CoreSpacing.md`，纵向 `CoreSpacing.sm`
- TextField 内边距：纵向 `CoreSpacing.sm`，横向 `CoreSpacing.sm`
- 建议芯片：`.glassEffect(.regular, in: Capsule())`
- 发送/停止按钮：`.buttonStyle(.circularGlass)`
- 按钮字号：`CoreTypography.titleSmallFont`
- 布局间距：`CoreSpacing.sm + CoreSpacing.xxs`
- 使用 `safeAreaBar(edge: .bottom)` 提供键盘适配与 scroll edge effect
