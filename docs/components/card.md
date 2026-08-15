# Card

内容容器的最薄外壳 / Thinnest content-container shell.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| padding | CGFloat | CoreSpacing.lg | 内容四周内边距（16pt，对齐 iOS 分组卡片惯例） |
| alignment | Alignment | .leading | 撑满宽度内的内容对齐 |
| kind | CardKind | .content | 容器观感：`.content` 背景 + 描边 + 圆角；`.grouped` 去描边、靠填充色对比定界（与 `InsetGroupedSection` 一致） |
| content | () -> Content | - | 卡片内容 |

`Card` 不引入平行的容器体系：`content` → `.padding(padding)` → `.surface(.content)` 或 `.surface(.grouped)`（由 `kind` 二选一；背景 / 描边 / 圆角均由 `SurfaceModifier` 提供，不重新实现）。默认**撑满父容器宽度**（`maxWidth: .infinity`），需要「hug 自身内容尺寸」的非撑满场景应直接用 `View.surface(.content)` 而非 `Card`。

> **#41 破坏性变更**：`bordered: Bool` 已删除。迁移 `Card(bordered: false)` → `Card(kind: .grouped)`，`Card(bordered: true)` → `Card()`。`kind` 的取值域**刻意只有两个 case**（不暴露完整 `SurfaceKind`）——`Card` 是薄封装，开放 `.canvas` / `.sidebar` 会把它拓宽成万能容器，且 `Card(kind: .canvas)` 正是 Issue #140 卡片塌缩的形态。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
Card {
    VStack(alignment: .leading, spacing: CoreSpacing.sm) {
        Text("Title").coreFont(.headline)
        Text("Body").coreFont(.subheadline).foregroundStyle(.secondary)
    }
}

Card(alignment: .center) {
    ContentUnavailableView("No Results", systemImage: "magnifyingglass")  // 居中内容的空态卡片
}

Card(padding: CoreSpacing.md) {
    Text("紧凑内边距")
}

Card(kind: .grouped) {
    Text("无描边的分组容器观感")
}
```

## 视觉 Token

- 背景：`.content` 与 `.grouped` 两种 `kind` 同取 `.surface(.content)` / `.surface(.grouped)` 的背景 token，都指向 `surfaceRaised`（`secondarySystemGroupedBackground`）——浮于画布之上，深浅双模式下都与 `Color.surfaceCanvas` 拉开。二者背景**完全相同**，`.grouped` 唯一的区别是不描边（靠填充色对比定界，与 `InsetGroupedSection` 一致，见上方 API 表）
- 内边距：默认 `CoreSpacing.lg`
- 圆角 / 描边：由 `SurfaceModifier` 统一提供，不在 `Card` 自身重复定义；`.content` 有描边，`.grouped` 无描边
