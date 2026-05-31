# Blossom 主题方案设计（暖悦风格女性向配色）

> 状态：已通过 brainstorming 收敛，待用户复核
> 日期：2026-05-31
> 机制：Swift Package Traits（编译期主题）+ 渐变 token 层

## 1. 背景与目标

CoreDesign 当前是单一视觉风格（Craft workbench，品牌色为蓝 `brand-5 = #0077FA`）的 SwiftUI 设计系统库。

目标：让**同一份 `import CoreDesign`** 能在编译期切换到不同风格方案，并落地第一个非默认主题 **Blossom**——参考 App Store「暖悦」的女性向配色：**珊瑚粉为主色、多色相糖果系、招牌柔和渐变**。

默认（不启用任何 trait）行为与现状**完全一致**，零回归。

### 非目标（本期不做）
- typography / radius / spacing / button metrics 的主题化（保持共用，后续可用同一 trait 机制扩展）
- 状态色（success/danger/warning/info）的主题化——明确保持标准语义色
- 运行时动态切换主题（本方案是编译期 trait，非运行时 Environment 注入）

## 2. 关键决策记录

| 决策点 | 选择 | 理由 |
|---|---|---|
| 选主题机制 | Package Traits（方案 A） | SPM 原生「导入即主题」，单 target 单 import，组件零改动，零运行时重复 |
| 主色方向 | 珊瑚粉糖果系（贴近真实「暖悦」截图） | 用户截图校准：比克制玫瑰更亮更暖更糖果感 |
| 主题名 / trait 名 | `Blossom` | 偏女性向意象，不绑定具体 App |
| 渐变 | 引入渐变 token 层 | 渐变是暖悦灵魂；默认主题下退化为纯色，零回归 |
| 状态色 | 保持标准语义色 | 红=危险的肌肉记忆 > 风格统一 |
| 主题范围 | 仅颜色（+渐变） | 最小可用范围，先跑通 trait 机制 |
| 色板实现 | 新增 xcassets colorset | 遵循项目「色彩由 xcassets 提供」惯例，原生 dark mode |
| 暗色模式 | 认真做 light + dark 双值 | 与现有体系一致（所有 colorset 皆双值） |

## 3. Blossom 色板（初稿，定稿前可整体调柔/调亮）

### brand 色阶（珊瑚粉）
| 阶 | Light | Dark |
|---|---|---|
| 0 | #FFF0F4 | #2A1119 |
| 1 | #FFDCE6 | #3D1824 |
| 2 | #FFC2D2 | #5A2233 |
| 3 | #FFA0B9 | #7C3047 |
| 4 | #FF85A4 | #A1405E |
| 5 (主) | #FF6F8E | #D15F82 |
| 6 | #F0577A | #E07F9C |
| 7 | #D43E62 | #EBA0B6 |
| 8 | #A52B49 | #F3C2D0 |
| 9 | #6E1B30 | #FADEE6 |

> dark 档位反转上移（浅档在暗底更亮），与现有 brand colorset 的 light/dark 处理思路一致。

### 画布（暖粉白，替换冷灰）
| token | Light | Dark |
|---|---|---|
| canvas-default | #FFFBFC | #160F12 |
| canvas-subtle | #FAF1F3 | #1E141A |
| canvas-inset | #FCF6F7 | #120D10 |

### 语义别名在 Blossom 下的重指向
- `secondary` / `secondaryAccent`：从 lightBlue 改为 violet（糖果紫，作为第二强调色，对应暖悦的排卵日/AI 紫）
- `accent` / `primary`：自动继承 brand（珊瑚粉），无需单独分流

### 渐变 token（仅 Blossom 为真渐变）
| token | Blossom | 默认主题 |
|---|---|---|
| `CoreGradient.brand` | 珊瑚粉→玫红 LinearGradient | 纯 `Color.accent` |
| `CoreGradient.cta` | 按钮渐变（#FF8FB0→#FF6F8E） | 纯 `Color.accent` |
| `CoreGradient.canvas` | 粉→薰衣草紫→青 三色渐变 | 纯 `Color.surfaceCanvas` |

## 4. 架构

### 4.1 Trait 声明（Package.swift）
```swift
traits: [
    .trait(name: "Blossom", description: "暖悦风格 · 珊瑚粉糖果渐变女性向主题"),
    .default(enabledTraits: []),
],
```
- 默认启用集合为空 → 默认即 Craft 蓝色主题。
- 调用方启用：`.package(url: "...", from: "...", traits: ["Blossom"])`，或 Xcode package trait 勾选 UI。
- 源码内用 `#if Blossom` 直接分流（已确认 trait 名可直接作为编译条件，无需映射 local trait）。

### 4.2 颜色分层与分流点（分流压到最低）

```
资源层 ColorGrade.brand0…9   ──#if Blossom──▶ blossom-brand-* / 现有 brand-*
画布   SurfaceColors.canvas*  ──#if Blossom──▶ blossom-canvas-* / 现有 canvas-*
语义别名 secondary/secondaryAccent ──#if Blossom──▶ violet / lightBlue
accent / primary / surface*  ──(自动继承上层，零分流)
状态色 StatusColors           ──(不分流，保持标准)
渐变层 CoreGradient.*          ──#if Blossom──▶ 真渐变 / 纯色退化
        │
        ▼
   所有组件（Button / Banner / …）零改动，读语义名自动变色
```

实现要点：
- `ColorGrade.swift`：`brand0…9` 由 `static let` 改为 `static var` computed，内部 `#if Blossom` 切换 colorset 名。其余 16 个色相家族不变。
- `SurfaceColors.swift`：`surfaceCanvas` / `surfaceCanvasSubtle` / `surfaceCanvasInset` 三个 computed 内部 `#if Blossom` 切 colorset 名；依赖它们的 `surfacePanel`/`surfaceSidebar`/`surfaceCard` 自动继承。
- `FunctionalColor.swift`：`secondary*` 一组在 `#if Blossom` 下指向 `.violet*`。
- `InteractionColors.swift`：`secondaryAccent*` 一组在 `#if Blossom` 下指向 `.violet*`。

### 4.3 渐变 token 层（新文件 `Colors/CoreGradient.swift`）
```swift
public enum CoreGradient {
    public static var brand: AnyShapeStyle {
        #if Blossom
        AnyShapeStyle(LinearGradient(colors: [.brand4, .brand6], startPoint: .topLeading, endPoint: .bottomTrailing))
        #else
        AnyShapeStyle(Color.accent)
        #endif
    }
    public static var cta: AnyShapeStyle { /* 同形态 */ }
    public static var canvas: AnyShapeStyle { /* 同形态，默认退化为 Color.surfaceCanvas */ }
}
```
- 用 `AnyShapeStyle` 统一返回类型，使纯色与渐变可互换；调用方 `.background(CoreGradient.canvas)` / `.fill(CoreGradient.cta)` 在两种主题下都成立。
- 默认主题退化为纯色 → 现有默认观感零变化。

## 5. 资源清单（新增 colorset）
- `Resources.xcassets/blossom-brand/blossom-brand-0…9.colorset`（10 个，各 light+dark）
- `Resources.xcassets/blossom-canvas/blossom-canvas-{default,subtle,inset}.colorset`（3 个，各 light+dark）

Contents.json 结构复用现有 colorset（srgb，alpha/red/green/blue 十六进制，dark 用 `appearances: luminosity/dark`）。

## 6. 验证策略（本机 Swift 6.3，可实跑）
1. `swift build` + `swift test` → 默认主题编译/测试通过，语义色未变（回归保护）。
2. `swift build --traits Blossom` + `swift test --traits Blossom` → Blossom 分支编译通过。
3. 新增 Swift Testing 用例（`CoreDesignTests`）：
   - 断言 `CoreGradient.brand/cta/canvas` 均可构造（非 nil）。
   - 断言默认主题下若干语义色解析结果与基线一致（防止误改默认分支）。
   - 注：测试 target 默认继承 default traits（即非 Blossom），Blossom 分支主要靠 `--traits Blossom` 的 CI/手动构建覆盖。文档中记录该命令。
4. 新增/复用 `#Preview`：给关键组件加 Blossom 视觉冒烟预览（按项目惯例，预览与组件同文件）。

## 7. 改动文件清单
| 文件 | 改动 |
|---|---|
| `Package.swift` | 增加 `traits:` 声明 |
| `Resources.xcassets/blossom-brand/*`（新） | 10 colorset |
| `Resources.xcassets/blossom-canvas/*`（新） | 3 colorset |
| `Colors/ColorGrade.swift` | brand0…9 → computed + `#if Blossom` |
| `Colors/SurfaceColors.swift` | canvas 三 token `#if Blossom` |
| `Colors/FunctionalColor.swift` | secondary 组 `#if Blossom` → violet |
| `Colors/InteractionColors.swift` | secondaryAccent 组 `#if Blossom` → violet |
| `Colors/CoreGradient.swift`（新） | 渐变 token 层 |
| `CoreDesignTests/*`（新） | trait/渐变验证用例 |
| `CLAUDE.md` | 新增「主题 trait」「渐变层」架构说明 |

## 8. 风险与权衡
- **trait 测试覆盖**：Swift Testing 无法在单次测试运行内同时覆盖两套 trait；Blossom 分支需 `--traits Blossom` 单独构建/测试（CI matrix 模式）。已在验证策略中记录。
- **AnyShapeStyle 类型擦除**：轻微运行时开销，但换来纯色/渐变可互换的统一 API，值得。
- **色板初稿**：所有色值为初稿，实现阶段可整体微调；不阻塞架构落地。
- **未来扩展**：若后续要主题化 radius/typography，沿用同一 `#if Blossom` 机制即可，无需新范式。
```
