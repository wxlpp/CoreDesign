# FloatButton

胶囊形悬浮按钮样式（icon + 文字）/ Capsule-shaped floating action button style (icon + label).

净新增仅 **extended 形态**（图标+文字的胶囊玻璃按钮）。icon-only FAB 场景**不重造**，
直接使用既有 `CircularGlassButtonStyle`（`.circularGlass`）。

## API

| 静态方法 | 返回类型 | 说明 |
|---|---|---|
| `.extendedFloat` | `ExtendedFloatButtonStyle` | 胶囊玻璃悬浮按钮，默认 `.large`（50pt） |
| `.extendedFloat(size:)` | `ExtendedFloatButtonStyle` | 指定尺寸档位 |

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| size | ControlSize | .large | 尺寸档位，来源与 `CircularGlassButtonStyle` 一致，走 `CoreControlMetrics.height(for:)` |

`ExtendedFloatButtonStyle` **不**引入 `ButtonRoleStyleRole` 参数化——本样式是玻璃浮层
视觉，非角色配色，与 `CircularGlassButtonStyle` 同类，不与 `LightButtonStyle` 等角色按钮
混同。

> **icon-only 场景请用 `CircularGlassButtonStyle`（`.circularGlass`）。**
> `ExtendedFloatButtonStyle` 只服务图标+文字的 extended 形态；纯 icon 场景套用本样式
> 会带着胶囊的横向 padding 冗余，观感不对。

## 使用示例 / Usage

```swift
// extended FAB：overlay 悬浮定位
ScrollView {
    // ... 页面内容 ...
}
.overlay(alignment: .bottomTrailing) {
    Button {
        // 主要动作
    } label: {
        Label("New", systemImage: "plus")
    }
    .buttonStyle(.extendedFloat)
    .padding(CoreSpacing.lg)
}

// 指定尺寸档位
Button {} label: {
    Label("生成", systemImage: "wand.and.sparkles")
}
.buttonStyle(.extendedFloat(size: .regular))

// icon-only：改用 CircularGlassButtonStyle，而非本样式
Button {} label: {
    Image(systemName: "plus")
}
.buttonStyle(.circularGlass)
```

## 定位边界说明 / Placement Guidance

FloatButton（本样式 + `.overlay`）与 `BottomInputBar` 的 `.safeAreaBar` 定位方式服务不同
场景，二者不能互换：

| 维度 | Extended FAB（本样式 + `.overlay`） | `.safeAreaBar` / `BottomInputBar` |
|---|---|---|
| 典型场景 | 页面内单一主要动作（"新建" "生成" 一类一次性操作） | 常驻输入场景（聊天输入框一类），需要持续可见 |
| 键盘适配 | 无——不参与安全区协商，键盘弹出时可能被遮挡 | 有——`.safeAreaBar(edge: .bottom)` 自动让内容 ScrollView 让出空间，并带 iOS 26 scroll edge effect |
| 是否随内容滚动 | 不随内容滚动（`overlay` 固定在容器坐标系） | 同样固定在底部，但设计目标是与输入焦点绑定 |
| 动作数量 | 单一主要动作 | 可聚合多个动作（菜单按钮、建议 chips、发送/停止按钮，见 `BottomInputBar`） |
| 典型定位 | `.overlay(alignment: .bottomTrailing)` | `.safeAreaBar(edge: .bottom)`（通过 `.bottomInputBar(...)` modifier） |

**决策规则**：

- 页面内**单一**主要动作、不需要跟随键盘、不需要与滚动内容分离出安全区 → 用
  `ExtendedFloatButtonStyle` + `.overlay(alignment: .bottomTrailing)`。
- 需要键盘适配、常驻输入、或要聚合多个动作（菜单/建议/发送）→ 用
  `.safeAreaBar` / `BottomInputBar`（详见 [`bottom-input-bar.md`](./bottom-input-bar.md)）。

两者可以共存：`BottomInputBar` 占据底部安全区时，Extended FAB 通常改用
`.bottomTrailing` 之外的位置（如页面中段的 `.overlay`），避免与输入条的命中区重叠。

## 预览 / Preview

`#Preview` 提供 extended FAB（`.large` / `.regular` 两档）+ 一个 `CircularGlassButtonStyle`
对照态，置于渐变背景上，light/dark 两份。运行 `scripts/run-snapshots.sh` 后，预览图将
生成于 `docs/snapshots/`。

## 视觉 Token

- 形状：`Capsule(style: .continuous)`
- 背景：`FloatingGlassModifier`（`.floatingGlass(in:isInteractive:)`），与 `CircularGlassButtonStyle` 同一套玻璃语汇
- 高度：`CoreControlMetrics.height(for: size)`（走 `frame(minHeight:)` 地板，不裁切）
- 横向内边距：`CoreSpacing.lg`
- 按压态：`.opacity(configuration.isPressed ? 0.9 : 1)`
- 强调色：不写死，交由调用方 `Label` 自身的 `.foregroundStyle`/`.tint`
