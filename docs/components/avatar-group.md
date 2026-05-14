# AvatarGroup

堆叠头像组 / Stacked avatar group.

前 N 个 avatar 交叠显示，超出 `max` 的部分汇总为 "+N" 计数 pill。子视图通过 `Group(subviews:)` 遍历，调用方传入任意 `View` 作 avatar。`max` 在初始化时 clamp 到 `>= 0`。

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| max | Int | 3 | 最多直接显示的 avatar 数量；超出走 "+N" pill，负值会被 clamp 到 0 |
| avatars | () -> some View | - | `@ViewBuilder`，每个子 View 作为一个 avatar |

## 预览 / Preview

运行 `scripts/run-snapshots.sh` 后，预览图将生成于 `docs/snapshots/`。

## 使用示例 / Usage

```swift
AvatarGroup {
    Avatar(name: "Evan")
    Avatar(name: "Renovate")
    Avatar(name: "Copilot")
    Avatar(name: "Ada")
    Avatar(name: "Linus")  // 第 5 个：进入 "+2" pill
}

// 自定义 max + 自定义 avatar shape
AvatarGroup(max: 2) {
    Circle().fill(.blue).frame(width: 24, height: 24)
    Circle().fill(.green).frame(width: 24, height: 24)
    Circle().fill(.red).frame(width: 24, height: 24)
}
```

## 视觉 Token

- 形状：`Circle`，描边 `Color.systemBackground` / `CoreBorderWidth.thin` 用作 stacking 间隔
- 重叠偏移：`-6` (mini/small) / `-8` (regular) / `-10` (large+)
- 头像尺寸：mini 20 / small 24 / regular 32 / large 40 / extraLarge 48
- "+N" pill：`Color.surfaceCanvasInset` 填充 + `Color.borderMuted` 描边，文字 `.caption2`
- 可访问性：每个 avatar 保留自身可访问性；"+N" 读 `"<N> more avatars"`
