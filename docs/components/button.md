# Button

Primer 风格按钮样式 / Primer-styled button styles.

## API

| 静态方法 | 返回类型 | 说明 |
|---|---|---|
| `.solidButton(role:)` | `SolidButtonStyle` | 实色背景按钮，主要 CTA |
| `.lightButton(role:)` | `LightButtonStyle` | 轻量按钮，次要操作 |
| `.borderless(role:)` | `CoreBorderlessButtonStyle` | 无边框按钮，行内链接 |
| `.circularGlass` / `.circularGlass(size:)` | `CircularGlassButtonStyle` | 圆形玻璃浮按钮（send / stop 一类），默认 `.large` = 40pt |
| `.circularGlass(diameter:)` | 同上 | 逃生舱：绕过档位直接给直径，用于 metrics 序列覆盖不到的非标尺寸 |

> ⚠️ **`.borderless` 必须带括号。** 访问器名与 SwiftUI 自带的
> `PrimitiveButtonStyle.borderless` 重合，两者只差一对括号且都能编译、无诊断：
> `.buttonStyle(.borderless)` 拿到的是 **SwiftUI 的**样式，
> `.buttonStyle(.borderless())` 才是 CoreDesign 的。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| role | ButtonRoleStyleRole | .primary | 角色色板 |

`ButtonRoleStyleRole`: primary / secondary / tertiary / warning / danger。

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
Button("Login") {}
    .buttonStyle(.solidButton(role: .primary))
Button("Cancel") {}
    .buttonStyle(.lightButton(role: .secondary))
Button("Delete") {}
    .buttonStyle(.borderless(role: .danger))
    .disabled(true)
```

## 视觉 Token

- 圆角：`Capsule()`（pill 形态）
- 字号 / padding / icon：由 `@Environment(\.controlSize)` 通过 `CoreControlMetrics` 决定
- SolidButton 背景：`role.color` / `role.activeColor` / `role.disabledColor`
- SolidButton 阴影：`CoreElevation.small`
- LightButton 暗色：`.glassEffect(.regular)`；亮色：`Color.surfaceInteractive` + `CoreElevation.small`
- CoreBorderlessButtonStyle 无视觉容器（无背景/边框/阴影），但字号、padding 与命中区仍走 `CoreControlMetrics` token
- 颜色映射见 `ButtonRoleStyleRole`：primary → `.accent`，secondary → `.secondaryAccent`，tertiary → `.neutralAccent`，warning → `.warning`，danger → `.danger`
