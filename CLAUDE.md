# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指引。

## 项目概述

CoreDesign 是一个以 Swift Package 形式分发的 SwiftUI 设计系统库。目标平台为 iOS 26+ / macOS 26+，采用 Swift 6 语言模式（`swiftLanguageModes: [.v6]`，开启完整严格并发检查。

## 常用命令

```bash
swift build                                  # 构建库
swift test                                   # 运行所有测试（使用 Swift Testing，而非 XCTest）
swift test --filter CoreDesignTests.example  # 按完整名称运行单个测试
swift package resolve                        # 修改 Package.swift 后刷新依赖
swift package clean                          # 缓存出问题时清除 .build/ 目录
```

测试 target 使用 Apple 的 Swift Testing 框架（`import Testing`、`@Test`、`#expect`）。除非有明确理由，否则不要引入 XCTest。SwiftUI 的 `#Preview` 块与对应组件放在同一文件中——它们不是测试，但是组件的主要视觉冒烟检查方式。

## 架构

### 分层色彩系统

颜色按四层堆叠组织——根据意图选择对应层级，不要在组件中直接使用底层原子色：

1. **资源调色板**（`Colors/ColorGrade.swift`）—— 17 种命名色相 × 10 个色阶（`brand-0`…`yellow-9`），由 `Resources.xcassets` 中的 color set 提供。通过 `Color("...", bundle: .module)` 加载。属于内部构造原料，组件代码中应避免直接使用。
2. **系统色桥接**（`Colors/SystemBackgroundColors.swift`、`SystemLabelColors.swift`）—— 通过 `#if canImport(UIKit)` / `AppKit` 把 `UIColor` / `NSColor` 系统色重新导出为 `Color`，保证同一名称在两端平台都能编译。
3. **语义化 token**——`SurfaceColors`、`ContentColors`、`BorderColors`、`FillColors`、`InteractionColors`、`StatusColors`。命名描述用途而非色相（`surfaceRaised`、`contentPrimary`、`accent`、`accentPressed`、`dangerForeground`）。
4. **功能性别名**（`Colors/FunctionalColor.swift`）—— `Color.primary/secondary/tertiary`（含 `Active`/`Disable`/`Hover` 变体）、`success`、`info`、`warning`、`danger`。这是最高层的 API 表面。

新增组件时优先使用第 3、4 层名称。如果缺少需要的语义 token，应在对应文件中补充新名称，而不是把第 1 层色相硬编码进组件。

### 按钮样式模式

所有按钮样式遵循统一形态：`*ButtonStyle: ButtonStyle` + 在 `ButtonStyle where Self == ...` 上扩展 `static func *Button(role:) -> Self`，通过单个 `ButtonRoleStyleRole` 枚举（`Components/Button/ButtonRoleStyleRole.swift`）参数化。该枚举是 `color` / `activeColor` / `disabledColor` 的唯一来源——新增 role 时应扩展此枚举，而不是为每个样式各自定义调色板。样式从 `@Environment(\.controlSize)` 读取尺寸、从 `\.isEnabled` 决定禁用配色。重度使用 iOS 26 的 `.glassEffect()`；`LightButtonStyle` 会按 `colorScheme` 分支：暗色用 `glassEffect`，亮色用柔和阴影代替。

### 组件 style 协议

需要支持多种外观的组件（目前是 `Banner`）遵循 Apple 自家 `ButtonStyle`/`ToggleStyle` 的形态：

- 公开 `BannerStyle` 协议，包含 `makeBody(configuration:)` 与 `BannerStyleConfiguration`。
- 提供具体样式实现（`PlainBannerStyle`、`BorderedBannerStyle`）。
- 通过 `EnvironmentValues` 入口（`@Entry var bannerStyle`）和 `View.bannerStyle(_:)` modifier 注入。

新增带样式的组件时复用该形态，不要另立平行模式。

### Modifier 约定

可复用的 `ViewModifier` 放在 `Modifier/` 目录下；以 `View` 扩展形式暴露（如 `.bordered(...)`），而不是要求调用方写 `.modifier(BorderModifier(...))`。通用辅助方法（如 `.getSize`、`.focusedExternally`）放在 `Utils/`。

### 资源加载

所有资源查找都必须传入 `bundle: .module`——包通过 `.process("Resources")` 处理 `Sources/CoreDesign/Resources`，SwiftUI 默认的 main bundle 查找方式找不到这些资源。

### 公开 API 表面

调用方依赖的内容必须显式标记为 `public`（包括 init）。Swift 默认可见性是 internal，漏写 `public` 会悄无声息地导致下游编译失败——新增组件时务必检查导出。现有组件展示了惯例：public 类型、public init、public `body`、private state。

## 仓库内的代码风格观察

- 即使在同一类型内访问成员也显式使用 `self.`（如 `self.controlSize`、`self.title(item)`）。修改现有文件时保持一致。
- 注释与 `// MARK: -` 标题双语混用（中文 + 英文），这是有意为之，编辑时与周围文件保持一致。部分注释是较长的设计说明（例如 `BottomInputBar.autoFocus` 解释了为何必须放在 bar 自身的 `onAppear` 中执行），编辑时予以保留。
- 组件大量使用 `iOS 26+` API：`.glassEffect`、`.safeAreaBar`、`EnvironmentValues` 上的 `@Entry`、`matchedGeometryEffect`。除非部署目标下调，否则不要为这些 API 加可用性回退。

## 工作流 skill（项目本地 `.claude/skills/`）

本仓库启用了三个工作流 skill——通过 `Skill` 工具调用，不要手动读取 SKILL.md 文件：

- **`ccpm`**——规格驱动流程（PRD → epic → 任务拆解 → GitHub Issues → 并行 agent）。当用户处理有计划的交付工作时启用；status/standup/next 这类确定性查询在 skill 的 `references/scripts/` 下已有现成的 shell 脚本，直接运行而不要重新实现。
- **`copilot-cross-review`**——CCPM 在 `.claude/prds/` 或 `.claude/epics/` 中写入/更新 PRD 或 epic 后，进入下一阶段前先运行 `copilot -p "..."` 做第二意见审查。最多 2 轮。
- **`auto-fix-pr-after-implementation`**——`superpowers:finishing-a-development-branch` 创建 PR 之后，轮询 Copilot review 并把反馈喂给 fix-pr 循环。无人值守最多自动运行 3 轮，达到上限后须由用户确认是否继续。遇到构建/测试失败或需要人工判断的 `CHANGES_REQUESTED` 时立即停止。

用户全局配置同时启用了 Context7 MCP 用于查询库文档（`mcp__context7__resolve-library-id` → `query-docs`）——查询外部库 / 框架 / SDK 时优先使用它，而不是 WebSearch。
