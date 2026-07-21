# Dynamic Type 改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use oh-my-superpowers:subagent-driven-development (recommended) or oh-my-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `CoreTypography` 的字号第一次真正随 Dynamic Type 缩放（当前 `relativeTo:` 全库 0 次），同时保住 Primer 精确基准字号，并为「大字号下不裁切」这类断言建立第一个能真正通电的验证层。

**Architecture:** `CoreTypography` 从一堆 `Font` 常量升级为 `CoreTypography.Token` 枚举 + `.coreFont(_:)` modifier。缩放靠 `@ScaledMetric`——它需要 View 上下文，所以必须是 modifier 而非 `Font` 常量。字号、lineSpacing 同步缩放；tracking 不缩放。

**Tech Stack:** SwiftPM / Swift 6 / SwiftUI，验证靠四条 SwiftPM 命令 + **第 5 条 `xcodebuild` iOS Simulator**（布局断言层只在 iOS 下有意义，见下）。

## Global Constraints

- 前四条 SwiftPM 命令绿且不新增 warning。**warning 采集前 `swift package clean`**（热构建不重放诊断，#94/#96/#97 的教训）。
- **第 5 条命令是本任务独有的硬性验收**：`xcodebuild test -scheme CoreDesign -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skip-testing:CoreDesignTests/BlossomAssetTests -skip-testing:CoreDesignTests/ToastHostTests CODE_SIGNING_ALLOWED=NO`（与 CI `ci.yml:110` 逐字一致）。布局断言必须在其下**真正执行**（用**显示名子串** grep 确认，非空转——Swift Testing 打印显示名不打印函数名）。
- **macOS 无 Dynamic Type**：`@ScaledMetric(wrappedValue: 16, relativeTo: .body)` 在 macOS `swift test` 宿主下全 12 档**恒返回 16.0**（`NSFont.preferredFont(.body).pointSize` 恒为 13）。所以布局断言必须 `#if os(iOS)` 包住——四条 SwiftPM 命令下它是**空转的**。这本身是个假绿点：SwiftPM 全绿不代表布局断言过。
- **不依赖颜色**：`swift test` 下 asset 颜色解析为 `(0,0,0,0)`（SwiftPM 不调 `actool`）。布局断言只测尺寸，不测色。
- 代码风格：显式 `self.`、中英双语注释、`// MARK: -`、`Modifier/` 下以 `View` 扩展暴露。
- **注释里只写今天成立的理由**（#96 的教训：B2b 注释写「大字号下不裁切」而当时字号根本不缩放）。本任务落地后这类断言才第一次通电——写注释时确认「大字号」这条路径 iOS 下真的走通了。

## 已实测的前置事实（不要重新推导）

| 事实 | 影响 |
|---|---|
| 基线绿：101 tests / 33 → **31 suites** passed（#97 后） | 起点干净 |
| `CoreTypography` 有 **10 个 font token**，各带 `*Font` / `*LineSpacing` / `*Tracking` 三件套；`relativeTo:` 出现 **0 次** | 全库字号不缩放 |
| **`captionSmallFont`（9pt）有明确注释「故意不参与 Dynamic Type 缩放」**（`CoreTypography.swift:172-181`）——9pt chrome（tab 角标、status bar）缩放会撑爆 | 与 AC「10 个全缩放」冲突，见《判断 1》 |
| `CoreTypography.` 全库 **19 文件 / 69 处** 消费 | 迁移面 |
| `CoreControlMetrics.font(for:)`（`:171`）返回 5 个 token 之一，消费点仅 **2 处**：`ButtonChromeModifier.swift:25`、`SearchField.swift:98`（#96 已把按钮体系收敛到 1 处） | SC-3 |
| mono 消费点 **4 处 / 2 组件**：`RefPill.swift:37,40,45` + **`ListRow.swift:273`**（`.caption.monospaced()`，95.md 漏列） | 新增 mono token |
| 既有 Dynamic Type 适配 2 处：`CoreMenuButton.swift:67` 的 `@ScaledMetric size`（**图标**尺寸，范围外）、`SegmentedControl.swift:246` 的 `UIFontMetrics`（原生控件标题） | 图标不纳入；SegmentedControl 见《判断 3》 |
| `Sidebar` 四处已是 `minHeight`（#96 完成），四 row 的 `CoreTypography` 引用降到 8 处 | 布局断言的守护对象已就绪 |

## D3 的范围边界（逐处实测，7 处迁移 + 明确排除）

**迁移（文本字号绕过 token）：**

| 位置 | 现状 | 目标 token |
|---|---|---|
| `AvatarGroup.swift:59` | `.caption2` | 见迁移映射 |
| `StatusRow.swift:46` | `.caption` | |
| `StateLabel.swift:50` | `.caption2` | |
| `CommentCard.swift:56` | `.caption2` | role badge |
| `RefPill.swift:34,37,40,42,45` | `.caption2` ×2 + `.caption.monospaced()` ×3 | 含 mono 变体 |
| `ListRow.swift:273` | `.caption.monospaced()` | mono 变体 |
| `BottomInputBar.swift:500` | `.subheadline`（chip，#97 已收敛成一处） | NFR 例外，见下 |

**明确排除（不是 D3）：**
- `AsyncButton.swift:245`（`.caption`）——在 `#Preview("抛错 + onError")` 内（`:228` 起）。
- `TimelineItem.swift:105,112`（`.caption` / `.subheadline`）——都在 `#Preview` 内。
- `BookCover.swift:164`（`.system(size: proxy.size.width * 0.13)`）——封面字母，按容器尺寸算的**图标级**字号。
- `Tag.swift:103`（`.system(size: removeIconSize)`）——删除**图标**字号。

**NFR 视觉例外**：`.subheadline` 是 15pt，`CoreTypography` 无精确对应 token（最近的是 bodyLarge 16 / caption 12）。迁移必有小幅字号变化——这是 PRD NFR 例外清单第 5 条，实施时记入 checklist。

---

## 两处必须先定的判断

### 判断 1：`captionSmall` 不缩放——与 AC「10 个 token 全部支持缩放」冲突（须上报用户）

AC 第 1 条写「10 个 token 全部支持 Dynamic Type 缩放」。但 `captionSmallFont`（9pt）的 doc 注释明确写着**故意不缩放**，理由充分（9pt 用于 tab 角标计数、status bar 指示器等紧凑 chrome，随 accessibility scale 放大会撑爆布局），且注释已给出替代路径（「需要跟随就用 `captionFont`」）。

这不是疏忽，是既有的设计约束。实际是 **9 个缩放 + captionSmall 固定**。

处置：`coreFont` **支持** `captionSmall`（统一入口），但它走固定路径（`spec.scales == false`）。AC 改为「9 个 token 缩放 + `captionSmall` 明确固定（保留 `CoreTypography.swift:172` 的既有设计约束）」。**这改的是验收标准，须经用户确认**（与 #96 SC-8、#97 B8d 同类）。

### 判断 2：mono 变体是**新增一个 token**，不是给现有 token 加开关

RefPill（3 处）+ ListRow（1 处）用 `.caption.monospaced()` = 12pt monospaced。`CoreTypography` 无 mono token。新增 `CoreTypography.Token.captionMono`（12pt，`.caption` 基准，`monospaced` 标记）。AC 的「RefPill 的 mono 变体 token 已新增」据此满足，且覆盖 ListRow（95.md 漏列的第 4 个消费点）。

新增一个 token 属「为保持现有表现所必需」（迁移不丢等宽特性），不受 Out of Scope「不做加法」约束——与 #93 status border 档同理。

---

### Task 1: `CoreTypography.Token` 枚举 + `.coreFont(_:)` modifier（B2a 核心）

**Files:**
- Modify: `Sources/CoreDesign/Tokens/CoreTypography.swift`（加 `Token` 枚举 + spec）
- Create: `Sources/CoreDesign/Modifier/CoreFontModifier.swift`
- Create: `Tests/CoreDesignTests/CoreTypographyTokenTests.swift`

**Interfaces:**
- Produces: `public enum CoreTypography.Token`（11 case：10 标准 + `captionMono`）、`View.coreFont(_ token: CoreTypography.Token) -> some View`

- [ ] **Step 1: 先写 token 值测试（TDD 红）**

每个 token 的基准 pt / weight / 是否缩放是 Primer 契约，先钉死：

```swift
import Testing
import SwiftUI
@testable import CoreDesign

@Suite("CoreTypography.Token")
struct CoreTypographyTokenTests {
    @Test("基准字号与 Primer 对齐，且未漂移")
    func baseSizes() {
        #expect(CoreTypography.Token.displayLarge.spec.size == 40)
        #expect(CoreTypography.Token.titleLarge.spec.size == 32)
        #expect(CoreTypography.Token.titleMedium.spec.size == 20)
        #expect(CoreTypography.Token.titleSmall.spec.size == 16)
        #expect(CoreTypography.Token.subtitle.spec.size == 20)
        #expect(CoreTypography.Token.bodyLarge.spec.size == 16)
        #expect(CoreTypography.Token.bodyMedium.spec.size == 14)
        #expect(CoreTypography.Token.bodySmall.spec.size == 12)
        #expect(CoreTypography.Token.caption.spec.size == 12)
        #expect(CoreTypography.Token.captionMono.spec.size == 12)
        #expect(CoreTypography.Token.captionSmall.spec.size == 9)
    }

    @Test("captionSmall 明确不缩放，其余缩放")
    func scalingFlags() {
        #expect(CoreTypography.Token.captionSmall.spec.scales == false)
        for t in CoreTypography.Token.allCases where t != .captionSmall {
            #expect(t.spec.scales == true, "\(t) 应缩放")
        }
    }

    @Test("captionMono 是等宽")
    func monoFlag() {
        #expect(CoreTypography.Token.captionMono.spec.monospaced == true)
        #expect(CoreTypography.Token.caption.spec.monospaced == false)
    }
}
```

Run: `swift test --filter CoreTypographyToken`
Expected: 编译失败（`Token` 未定义）。

- [ ] **Step 2: 加 `Token` 枚举 + `Spec`（TDD 绿）**

在 `CoreTypography.swift` 加（保留现有 `*Font` 常量不动——Task 4 迁移完消费点后再判断死活）：

```swift
public extension CoreTypography {
    /// 排版 token / Typography token。携带 Primer 基准规格，经 `.coreFont(_:)` 施加。
    enum Token: CaseIterable {
        case displayLarge, titleLarge, titleMedium, titleSmall, subtitle
        case bodyLarge, bodyMedium, bodySmall, caption, captionMono, captionSmall

        public struct Spec {
            public let size: CGFloat
            public let weight: Font.Weight
            /// Dynamic Type 缩放基准；`scales == false` 时忽略。
            public let textStyle: Font.TextStyle
            public let lineSpacing: CGFloat
            public let tracking: CGFloat
            public let scales: Bool
            public let monospaced: Bool
        }

        public var spec: Spec {
            switch self {
            // size / weight / textStyle 基准 / lineSpacing / tracking / scales / mono
            case .displayLarge: Spec(size: 40, weight: .medium,    textStyle: .largeTitle, lineSpacing: 15,   tracking: 0, scales: true,  monospaced: false)
            case .titleLarge:   Spec(size: 32, weight: .semibold,  textStyle: .title,      lineSpacing: 16,   tracking: 0, scales: true,  monospaced: false)
            case .titleMedium:  Spec(size: 20, weight: .semibold,  textStyle: .title2,     lineSpacing: 12.5, tracking: 0, scales: true,  monospaced: false)
            case .titleSmall:   Spec(size: 16, weight: .semibold,  textStyle: .headline,   lineSpacing: 8,    tracking: 0, scales: true,  monospaced: false)
            case .subtitle:     Spec(size: 20, weight: .regular,   textStyle: .title3,     lineSpacing: 12.5, tracking: 0, scales: true,  monospaced: false)
            case .bodyLarge:    Spec(size: 16, weight: .regular,   textStyle: .body,       lineSpacing: 8,    tracking: 0, scales: true,  monospaced: false)
            case .bodyMedium:   Spec(size: 14, weight: .regular,   textStyle: .callout,    lineSpacing: 7,    tracking: 0, scales: true,  monospaced: false)
            case .bodySmall:    Spec(size: 12, weight: .regular,   textStyle: .caption,    lineSpacing: 7.5,  tracking: 0, scales: true,  monospaced: false)
            case .caption:      Spec(size: 12, weight: .regular,   textStyle: .caption,    lineSpacing: 3,    tracking: 0, scales: true,  monospaced: false)
            case .captionMono:  Spec(size: 12, weight: .regular,   textStyle: .caption,    lineSpacing: 3,    tracking: 0, scales: true,  monospaced: true)
            case .captionSmall: Spec(size: 9,  weight: .regular,   textStyle: .caption2,   lineSpacing: 0,    tracking: 0, scales: false, monospaced: false)
            }
        }
    }
}
```

> **textStyle 基准的取值依据**：`relativeTo:` 决定缩放曲线，选**标准尺寸最接近该 pt 的 TextStyle**（`.body`≈17、`.callout`≈16、`.caption`≈12、`.title2`≈22、`.title3`≈20、`.headline`≈17、`.largeTitle`≈34、`.title`≈28）。基准 pt 保持 Primer 精确值（40/32/…），只借 TextStyle 的缩放**斜率**。实施后在 iOS Simulator 下实看几档，若某 token 缩放过陡/过缓再调 textStyle。

- [ ] **Step 3: 建 `CoreFontModifier`（TDD 绿的实现侧）**

```swift
//
//  CoreFontModifier.swift
//  CoreDesign
//

import SwiftUI

// MARK: - CoreFontModifier

/// 施加一个 `CoreTypography.Token`：字号 + lineSpacing 随 Dynamic Type 缩放，tracking 固定。
///
/// 为何是 modifier 而非 `Font` 常量：缩放靠 `@ScaledMetric`，它需要 View 上下文。
/// 旧的 `CoreTypography.*Font`（`.system(size:)` 固定值）**不缩放**——那正是 B2a 要修的。
private struct CoreFontModifier: ViewModifier {
    let token: CoreTypography.Token
    @ScaledMetric private var scaledSize: CGFloat
    @ScaledMetric private var scaledLineSpacing: CGFloat

    init(_ token: CoreTypography.Token) {
        self.token = token
        let spec = token.spec
        // 缩放档：以 token 基准 pt 为「标准尺寸下的值」，随 spec.textStyle 的曲线缩放。
        // 固定档（captionSmall）：ScaledMetric 照存但 body 不读它，用 spec.size 原值。
        self._scaledSize = ScaledMetric(wrappedValue: spec.size, relativeTo: spec.textStyle)
        self._scaledLineSpacing = ScaledMetric(wrappedValue: spec.lineSpacing, relativeTo: spec.textStyle)
    }

    func body(content: Content) -> some View {
        let spec = self.token.spec
        let size = spec.scales ? self.scaledSize : spec.size
        let lineSpacing = spec.scales ? self.scaledLineSpacing : spec.lineSpacing
        let font: Font = spec.monospaced
            ? .system(size: size, weight: spec.weight).monospaced()
            : .system(size: size, weight: spec.weight)
        return content
            .font(font)
            .lineSpacing(lineSpacing)
            .tracking(spec.tracking)
    }
}

// MARK: - View extension

public extension View {
    /// 施加 CoreDesign 排版 token（字号 + lineSpacing 随 Dynamic Type 缩放）。
    ///
    /// 取代旧的 `.font(CoreTypography.xxxFont)` + 手写 `.lineSpacing()`——三件套
    /// （font / lineSpacing / tracking）收进单一调用点。
    func coreFont(_ token: CoreTypography.Token) -> some View {
        self.modifier(CoreFontModifier(token))
    }
}
```

Run: `swift test --filter CoreTypographyToken`
Expected: 3 个测试 PASS。

Run: `swift build`
Expected: EXIT=0。

- [ ] **Step 4: Blossom 早筛 + iOS 缩放 spike（Task 5 的命脉，现在就证实）**

排版不碰 color/trait，但顺手筛一次 Blossom，别拖到最后：
```bash
swift build --traits Blossom > /tmp/t1bb.log 2>&1; echo "blossom EXIT=$?"
```

**更重要——先证明 `ImageRenderer` 尊重注入的 `dynamicTypeSize`**，这是 Task 5 整层押注的机制。**直接建 `Tests/CoreDesignTests/DynamicTypeLayoutTests.swift`**（就是 Task 5 的文件），内容先放 `#if os(iOS)` suite + `renderedHeight` helper + 这一个 spike 用例（形态与 Task 5 Step 1 的「完整文件形态」一致，只是暂时只有 spike 这一个 `@Test`）：

```swift
import Testing
import SwiftUI
@testable import CoreDesign

// macOS 无 Dynamic Type：ScaledMetric 恒返回 wrappedValue（NSFont.preferredFont(.body)
// 恒 13pt）。故整套断言 #if os(iOS)，只在第 5 条 xcodebuild iOS Simulator 命令下执行；
// 四条 SwiftPM 命令下本 suite 为空，不构成假绿——凡改本文件覆盖的组件都须跑第 5 条命令。
#if os(iOS)
@Suite("Dynamic Type 布局")
@MainActor
struct DynamicTypeLayoutTests {
    /// 在给定 Dynamic Type 尺寸下渲染并量高度。
    /// 用 ImageRenderer（不依赖颜色——asset 色在测试下解析为透明，本处只读尺寸）。
    private func renderedHeight<V: View>(
        _ view: V,
        at size: DynamicTypeSize
    ) -> CGFloat {
        let renderer = ImageRenderer(
            content: view
                .environment(\.dynamicTypeSize, size)
                .frame(width: 320)   // 固定宽度，让高度反映字号/换行
        )
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    // Task 1 Step 4 的 spike，保留作机制回归锚点（改用 renderedHeight）。
    @Test("spike：ImageRenderer 尊重注入的 dynamicTypeSize")
    func imageRendererRespectsDynamicType() {
        let text = Text("Ag").coreFont(.bodyLarge)
        #expect(self.renderedHeight(text, at: .accessibility5) > self.renderedHeight(text, at: .large),
                "ImageRenderer 未按注入档缩放——Task 5 的整套断言不成立")
    }
}
#endif
```

（Task 5 Step 1 会在同一 struct 内追加另外三个 `@Test`——`renderedHeight` 与顶部注释块与此处**逐字相同**，只多三个方法。）

跑第 5 条命令（Task 5 Step 2 的 `xcodebuild -scheme CoreDesign`）确认这一个 spike 过。**若它红了，Task 5 的方案要换（回退到 UIFontMetrics 直接量或注入 UITraitCollection），不要盲目往下铺三个断言。**

spike 用例**留在** `DynamicTypeLayoutTests.swift` 里（不删、不复制），Task 1 Step 5 一并 commit 该文件；Task 5 Step 1 在其上追加另外三个断言。spike 与 Task 5 的 `coreFontActuallyScales` 语义重叠（都断言 `.bodyLarge` 在 ax5 > large），**保留 spike 作机制回归锚点**——不是为避免重复。

- [ ] **Step 5: 提交**

```bash
git add Sources/CoreDesign/Tokens/CoreTypography.swift Sources/CoreDesign/Modifier/CoreFontModifier.swift
git add Tests/CoreDesignTests/CoreTypographyTokenTests.swift Tests/CoreDesignTests/DynamicTypeLayoutTests.swift
git commit -m "feat: CoreTypography.Token 枚举 + .coreFont() modifier + ImageRenderer spike（B2a）"
```

---

### Task 2: `CoreControlMetrics.font(for:)` → `fontToken(for:)`（SC-3）

**Files:**
- Modify: `Sources/CoreDesign/Tokens/CoreControlMetrics.swift`
- Modify: `Sources/CoreDesign/Modifier/ButtonChromeModifier.swift`、`Sources/CoreDesign/Components/SearchField/SearchField.swift`

- [ ] **Step 1: 改签名**

`CoreControlMetrics.swift:171` 的 `func font(for:) -> Font` 改为：

```swift
    /// 控件尺寸档对应的排版 token / Typography token for a control size。
    ///
    /// 返回 `Token` 而非 `Font`——`Font` 是固定值不缩放，而 `.coreFont(token)` 才走
    /// Dynamic Type（SC-3：本类型不再暴露返回 `Font` 的 API）。
    public static func fontToken(for controlSize: ControlSize) -> CoreTypography.Token {
        switch controlSize {
        case .mini:       .bodySmall
        case .small:      .bodySmall
        case .regular:    .bodyMedium
        case .large:      .bodyLarge
        case .extraLarge: .titleMedium
        @unknown default: .bodyMedium
        }
    }
```

同步 `:25` 的 doc 注释示例。**另 `ButtonChromeModifier.swift:16` 的 doc 注释也引用了 `CoreControlMetrics.font(for:)`**（实测），改名后成死注释，一并改写为 `fontToken(for:)`。

- [ ] **Step 2: 两个消费点改用 `coreFont`**

`ButtonChromeModifier.swift:25`：`.font(CoreControlMetrics.font(for: self.controlSize))` → `.coreFont(CoreControlMetrics.fontToken(for: self.controlSize))`。

> ⚠️ `ButtonChromeModifier` 现在同时施加 `.coreFont`（含 `.font` + `.lineSpacing` + `.tracking`）与它自己的 padding/contentShape。确认 `coreFont` 的 `.lineSpacing` 对按钮 label 无副作用（单行 label 无影响）——iOS Simulator 冒烟时看一眼按钮。

`SearchField.swift:98`：`.font(CoreControlMetrics.font(for: .regular))` → `.coreFont(CoreControlMetrics.fontToken(for: .regular))`。

- [ ] **Step 3: SC-3 验证**

```bash
grep -n '\-> Font' Sources/CoreDesign/Tokens/CoreControlMetrics.swift
```
Expected: 无输出（SC-3 后半：本类型不再暴露返回 `Font` 的 API）。

Run: `swift build --build-tests`
Expected: EXIT=0。

- [ ] **Step 4: 提交**

```bash
git add Sources/CoreDesign/Tokens/CoreControlMetrics.swift Sources/CoreDesign/Modifier/ButtonChromeModifier.swift Sources/CoreDesign/Components/SearchField/SearchField.swift
git commit -m "refactor!: CoreControlMetrics.font(for:) → fontToken(for:)，不再暴露 Font（SC-3）"
```

---

### Task 3: 迁移 `CoreTypography` 的 69 处消费到 `.coreFont`

**Files:** 19 个组件文件（`grep -rl 'CoreTypography\.' Sources/CoreDesign/Components`）

这是最大的机械改写。统一 pattern：

```swift
// 前
.font(CoreTypography.bodyLargeFont)
.lineSpacing(CoreTypography.bodyLargeLineSpacing)   // 若有
// 后
.coreFont(.bodyLarge)
```

- [ ] **Step 1: 逐文件迁移**

按文件分批，每批改完 `swift build --build-tests` 确认编译。**注意三种情况：**

1. **只有 `.font(CoreTypography.xxxFont)`、无手写 lineSpacing**：直接换 `.coreFont(.xxx)`——这会**新增** lineSpacing（token 自带）。多数是单行文本，无视觉影响；多行文本会有行距变化，iOS 冒烟时看。
2. **`.font` + 手写 `.lineSpacing(CoreTypography.xxxLineSpacing)`**：两行一起换成一个 `.coreFont(.xxx)`。
3. **`CoreTypography.xxxFont` 用在需要 `Font` 值的位置**（如作为参数传递，而非 `.font()` modifier）：`coreFont` 是 View modifier，替代不了。这类**保留** `CoreTypography.xxxFont` 常量。逐处判断。

映射表（token 名一一对应）：`displayLargeFont`→`.displayLarge`、`titleLargeFont`→`.titleLarge`、…、`captionSmallFont`→`.captionSmall`。

- [ ] **Step 2: 判断旧 `*Font` / `*LineSpacing` / `*Tracking` 常量的死活**

迁移完 grep 每个常量的剩余引用：

```bash
for t in displayLarge titleLarge titleMedium titleSmall subtitle bodyLarge bodyMedium bodySmall caption captionSmall; do
  # 只看代码引用——排除 `///` / `//` / `*` 注释行（否则被文档注释污染，误判为「活」）
  n=$(grep -rn "CoreTypography.${t}Font\|CoreTypography.${t}LineSpacing\|CoreTypography.${t}Tracking" \
        Sources/CoreDesign --include='*.swift' \
      | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(///|//|\*)' | wc -l | tr -d ' ')
  echo "$t: $n 处代码引用剩余"
done
```

scope 是 `Sources/CoreDesign` 全域（不止 `Components`/`Modifier`）——Task 2 已清 `CoreControlMetrics` 的引用，但 grep scope 本身要覆盖全，别漏。

**实测有 5 处 `///` 文档注释引用这些常量**（`Toast.swift:410`、`UnderlinedTabBar.swift:41`、`Avatar.swift:29`、`Tag.swift:48`、`Badge.swift:59`）——上面的 `grep -vE` 已把它们排除出「代码引用」计数。**删除某常量时，这些悬空注释要一并改写**（指向 `.coreFont(.xxx)`），否则留下指向已删符号的死注释。

零代码引用的常量**删除**（#97 刚清完死代码，不留新的）+ 同步改写其文档注释。仍有代码引用的（情况 3：用在需要 `Font` 值而非 `.font()` modifier 的位置）保留并记录原因。

- [ ] **Step 3: 编译 + 测试**

```bash
swift build --build-tests > /tmp/t3.log 2>&1; echo "build EXIT=$?"
swift test > /tmp/t3t.log 2>&1; echo "test EXIT=$?"
```

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "refactor: 迁移全部 CoreTypography 消费点到 .coreFont（B2a）"
```

---

### Task 4: D3 的 7 处文本字号迁移 + mono 变体

**Files:** `AvatarGroup.swift`、`StatusRow.swift`、`StateLabel.swift`、`CommentCard.swift`、`RefPill.swift`、`ListRow.swift`、`BottomInputBar.swift`

- [ ] **Step 1: 逐处迁移（按《D3 范围边界》表，坐标实施前 grep 重定）**

| 位置 | `.font(...)` | → |
|---|---|---|
| `AvatarGroup.swift` | `.caption2` | `.coreFont(.captionSmall)`（caption2≈11、captionSmall 9——**这是受控变化**，或用 `.caption`=12。实施时 iOS 冒烟看哪个更贴近原视觉，记入 checklist） |
| `StatusRow.swift` | `.caption` | `.coreFont(.caption)` |
| `StateLabel.swift` | `.caption2` | 同 AvatarGroup 的判断 |
| `CommentCard.swift` | `.caption2` | 同上 |
| `RefPill.swift` | `.caption2` ×2 / `.caption.monospaced()` ×3 | `.coreFont(.caption)` / `.coreFont(.captionMono)` |
| `ListRow.swift` | `.caption.monospaced()` | `.coreFont(.captionMono)` |
| `BottomInputBar.swift:500` | `.subheadline` | `.coreFont(.bodyLarge)` 或 `.caption`——**NFR 例外**（subheadline 15pt 无精确 token），iOS 冒烟选最贴近的，记入 checklist |

> ⚠️ **`.caption2`（≈11pt）无精确 token**。`captionSmall` 是 9pt（且不缩放）、`caption` 是 12pt。两个都不等于 11。这是**多处 NFR 视觉例外**——实施时对每个 `.caption2` 消费点在 iOS 下看渲染，选更贴近的 token 并逐处记入 checklist。**不要为凑「零回归」而假装无变化。**

- [ ] **Step 2: D3 零残留验证**

```bash
grep -rn '\.font(\.caption\b\|\.font(\.caption2\|\.font(\.subheadline\|\.caption\.monospaced' Sources/CoreDesign/Components --include='*.swift' \
  | grep -v '#Preview' | cat
```
Expected: 只剩 `#Preview` 内的（`AsyncButton`、`TimelineItem`）与图标字号（`BookCover`、`Tag`），无生产文本字号。

Run: `swift build --build-tests`
Expected: EXIT=0。

- [ ] **Step 3: 提交**

```bash
git add -A
git commit -m "refactor: D3 的 7 处文本字号迁移到 coreFont，新增 captionMono 变体"
```

---

### Task 5: 布局断言层（本任务写，不在 #7）

**Files:**
- Create: `Tests/CoreDesignTests/DynamicTypeLayoutTests.swift`

安全网必须与它守护的改动同批落地。这是全新的、最易出错的一层——写详尽。

- [ ] **Step 1: 在 spike 文件上追加三个断言**

`DynamicTypeLayoutTests.swift` 已在 Task 1 Step 4 建好（含 `renderedHeight` helper + spike `imageRendererRespectsDynamicType`）。在同一 `#if os(iOS)` suite 内**追加**下面三个用例。追加后的完整文件形态（4 个 `@Test`）：

```swift
import Testing
import SwiftUI
@testable import CoreDesign

// macOS 无 Dynamic Type：ScaledMetric 恒返回 wrappedValue（NSFont.preferredFont(.body)
// 恒 13pt）。故整套断言 #if os(iOS)，只在第 5 条 xcodebuild iOS Simulator 命令下执行；
// 四条 SwiftPM 命令下本 suite 为空，不构成假绿——凡改本文件覆盖的组件都须跑第 5 条命令。
#if os(iOS)
@Suite("Dynamic Type 布局")
@MainActor
struct DynamicTypeLayoutTests {
    /// 在给定 Dynamic Type 尺寸下渲染并量高度。
    /// 用 ImageRenderer（不依赖颜色——asset 色在测试下解析为透明，本处只读尺寸）。
    private func renderedHeight<V: View>(
        _ view: V,
        at size: DynamicTypeSize
    ) -> CGFloat {
        let renderer = ImageRenderer(
            content: view
                .environment(\.dynamicTypeSize, size)
                .frame(width: 320)   // 固定宽度，让高度反映字号/换行
        )
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    // Task 1 Step 4 的 spike，保留作机制回归锚点（改用 renderedHeight）。
    @Test("spike：ImageRenderer 尊重注入的 dynamicTypeSize")
    func imageRendererRespectsDynamicType() {
        let text = Text("Ag").coreFont(.bodyLarge)
        #expect(self.renderedHeight(text, at: .accessibility5) > self.renderedHeight(text, at: .large),
                "ImageRenderer 未按注入档缩放——Task 5 的整套断言不成立")
    }

    @Test("Sidebar 四种 row 的高度随 Dynamic Type 单调不减")
    func sidebarRowsGrowWithDynamicType() {
        // 注意：本断言的高度增长依赖 `SidebarRow` 的 **title** 字号缩放（Task 3 必须
        // 已把 SidebarRow 的 title 迁到 coreFont）。若 title 仍是固定 Font，此断言不通电。
        let row = SidebarNavigationRow(systemImage: "star", title: "Long enough title to wrap at accessibility sizes", isSelected: false) {}

        let small  = self.renderedHeight(row, at: .large)          // 默认档
        let xxxl   = self.renderedHeight(row, at: .xxxLarge)
        let ax5    = self.renderedHeight(row, at: .accessibility5)

        // 主断言用**最大跨度** large vs accessibility5——`row` 有 `minHeight` 地板，
        // 相邻/近档可能都被夹到地板值（xxxLarge 若换行数不变、行高增长未超地板，
        // 会 == large == 地板，严格 `>` 假失败）。最大跨度才必然突破地板。
        #expect(ax5 > small, "accessibility5 未比 large 高——字号没缩放或被固定高度裁切")
        // 中间档单调不减（可能同值，故 >=）。
        #expect(xxxl >= small, "xxxLarge 应 ≥ large")
        #expect(ax5 >= xxxl, "accessibility5 应 ≥ xxxLarge")
    }

    @Test("coreFont 的字号在 iOS 下确实随 Dynamic Type 变化")
    func coreFontActuallyScales() {
        let text = Text("Ag").coreFont(.bodyLarge)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        #expect(ax5 > small, "coreFont 未缩放——ScaledMetric 或 textStyle 基准错了")
    }

    @Test("captionSmall 明确不缩放")
    func captionSmallDoesNotScale() {
        let text = Text("9").coreFont(.captionSmall)
        let small = self.renderedHeight(text, at: .large)
        let ax5   = self.renderedHeight(text, at: .accessibility5)
        // 相邻档用 >=（可能同值），此处断言不放大：ax5 不应显著高于 small。
        #expect(ax5 <= small + 1, "captionSmall 缩放了——违反其固定设计约束")
    }
}
#endif
```

> **断言口径（95.md 编写约束，已实测采信）：相邻档用 `>=`（iOS 上 `small`/`medium` 同为某值，严格 `>` 会假失败）；跨档（`large` vs `xxxLarge`/`accessibility5`）才用 `>`。** 上面 Sidebar 与 coreFont 用跨档 `>`，captionSmall 用 `<=`。

- [ ] **Step 2: 打通第 5 条命令（与 CI 逐字对齐）**

**命令必须是 `-scheme CoreDesign`（SwiftPM 包 scheme，跑 `CoreDesignTests` target，默认 trait），不是 `App/CoreDesignPreview.xcodeproj`。** 三条理由，逐一实测确认：
> - CI（`.github/workflows/ci.yml:110-118`）与 `95.md` DoD line 118 都是 `-scheme CoreDesign`。CI 注释明写「本 job 目前跑不到任何 `#if os(iOS)` 布局断言（由 #4 引入），#4 落地后才开始真正守护」——本 Task 就是那个 #4，断言必须在**这条**命令下通电。
> - `App/CoreDesignPreview.xcodeproj` 的 scheme 跑的是 `SnapshotTests` target（不同 target）+ `traits: ["Blossom"]`（不同 trait），与 CI 不是同一编译路径。
> - `DynamicTypeLayoutTests.swift` 用 `@testable import CoreDesign`，它是 SwiftPM `CoreDesignTests` target 成员——在 `-scheme CoreDesign` 下天然成立；在 `SnapshotTests`（把 CoreDesign 当外部包依赖）下对预编译包做 `@testable` **编译不过**。用错 scheme 连编都过不了。

不需要 `xcodegen`——CI 的 iOS job 不碰它。

```bash
set -o pipefail
xcodebuild test \
  -scheme CoreDesign \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skip-testing:CoreDesignTests/BlossomAssetTests \
  -skip-testing:CoreDesignTests/ToastHostTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "${TMPDIR:-/tmp}/ios95.log" | tail -30
echo "xcodebuild EXIT=${PIPESTATUS[0]}"
```
Expected: `TEST SUCCEEDED`。

**非空转判据（机械，不靠肉眼看末 30 行）：**

```bash
# Swift Testing 打印的是 @Test 的**显示名**（中文），不是函数名——grep 显示名子串。
# 每个 pattern **带尾引号**锚定，避免匹配到更长的同前缀显示名（见下）。
for key in '单调不减"' '确实随 Dynamic Type 变化"' 'captionSmall 明确不缩放"'; do
  n=$(grep -c "$key" "${TMPDIR:-/tmp}/ios95.log")
  echo "[$key]: $n  (预期 ≥ 1，出现即证明该断言真的跑了)"
done
```

> **尾引号锚定是必需的**：Task 1 的 token 测试有个显示名 `captionSmall 明确不缩放，其余缩放`（**不在** `#if os(iOS)`、不在 skip，xcodebuild 下照跑照打印）。裸 grep `captionSmall 明确不缩放` 会命中它，即便 iOS 布局断言 `captionSmallDoesNotScale`（显示名 `captionSmall 明确不缩放`）根本没跑——假绿。加尾引号 `captionSmall 明确不缩放"` 只匹配布局断言那条（token 测试打印的是 `...不缩放，其余缩放"`）。另两个子串本就无同前缀，加尾引号更保险。
>
> Swift Testing 的 console 输出是 `Test "<显示名>" started/passed`——已实测显示名（含中文）在 `xcodebuild` 日志里逐字出现。

**任一为 0 = 该断言被 skip / 没编进去 / 显示名被改动 = 空转**，停下查 `-skip-testing` 与显示名是否一致。

> ⚠️ **`DynamicTypeLayoutTests` 绝不能被加进 CI 的 `-skip-testing` 列表**（当前只有 `BlossomAssetTests` / `ToastHostTests`）。本 Task 无需改 `ci.yml`——CI 已按上面的命令跑，本层落地后自动通电。

- [ ] **Step 3: 提交**

```bash
git add Tests/CoreDesignTests/DynamicTypeLayoutTests.swift
git commit -m "test: Dynamic Type 布局断言层（Sidebar 不裁切 + coreFont 真缩放），#if os(iOS)（B2a）"
```

---

### Task 6: 全量验证 + 审计清单 + 交接

- [ ] **Step 1: 四条 SwiftPM 命令（clean 后冷跑）**

```bash
LOGDIR="${TMPDIR:-/tmp}/coredesign-95"; mkdir -p "$LOGDIR"
swift package clean
swift build                  > "$LOGDIR/b.log"  2>&1; echo "build          EXIT=$?"
swift test                   > "$LOGDIR/t.log"  2>&1; echo "test           EXIT=$?"
swift build --traits Blossom > "$LOGDIR/bb.log" 2>&1; echo "build-blossom  EXIT=$?"
swift test  --traits Blossom > "$LOGDIR/tb.log" 2>&1; echo "test-blossom   EXIT=$?"
(cd scripts/downstream-probe && swift package clean >/dev/null 2>&1 && swift build > "$LOGDIR/p.log" 2>&1); echo "probe(clean)   EXIT=$?"
```
warning 判据：按 message 来源过滤，四份均无非 EmptyState 的新增 warning（#97 后 EmptyState 已删，实际应为**绝对 0**）。

- [ ] **Step 2: 第 5 条命令（本任务的硬性验收）**

跑 Task 5 Step 2 的 `xcodebuild -scheme CoreDesign ...` 与其后的**显示名子串** grep（带尾引号锚定）。`TEST SUCCEEDED` 且三个显示名子串各出现 ≥ 1。

- [ ] **Step 3: SC-3 与 relativeTo 自查**

```bash
grep -n '\-> Font' Sources/CoreDesign/Tokens/CoreControlMetrics.swift   # Expected: 无输出（SC-3 满足）
grep -c 'relativeTo:' Sources/CoreDesign/Modifier/CoreFontModifier.swift   # 应 ≥ 2（size + lineSpacing）
```

- [ ] **Step 4: 视觉冒烟（iOS Simulator，本任务不可省）**

字号是纯视觉的，四条 SwiftPM 命令看不到。跑快照（绕开 `run-snapshots.sh`，#96/#97 的方式），重点看：
- 所有迁移了 `CoreTypography` 的组件默认档观感无回归
- **NFR 例外的几处**（`.caption2` → token、`.subheadline` → token）字号变化是否可接受
- `Sidebar` 在放大档不裁切（若快照支持注入 dynamicTypeSize；否则靠 Task 5 的断言）

- [ ] **Step 5: 更新审计清单 + NFR 例外清单**

B2a、D3 两项标 `✅ 已修复`。**新增的 NFR 视觉例外**（captionSmall 不缩放、`.caption2`→token 的字号变化、`.subheadline`→token）逐条记入 PRD 的 NFR 例外清单。计数校验 `echo $(( ... - 4 ))` = 83。

坐标清扫：本任务改了 19 个组件文件的行号，`audit-checklist.md` 与兄弟任务文件里指向这些文件的坐标要重算（#94/#96/#97 的教训，逐条 Read 不凭推理）。

- [ ] **Step 6: 写 `updates/95/progress.md`**

必须落进去：核心 API 设计、captionSmall 例外、textStyle 基准映射依据、全部 NFR 视觉例外、布局断言层的 macOS 空转性质（凡触及被覆盖文件的下游 Issue 须跑第 5 条命令）、给 #99/#100/#101/#102 的交接。

- [ ] **Step 7: 提交**

```bash
git add .claude/epics/coredesign-audit-remediation/
git commit -m "docs(ccpm): 更新 #95 审计清单、NFR 例外与完成记录"
```

---

## 收尾

`verification-before-completion` → `finishing-a-development-branch` Option 2 开 PR（**base = `epic/coredesign-audit-remediation`**）→ Copilot 不可用，按 §3.6 降级为 `superpowers-reviewer` 并在 PR 留顶层评论。

PR 描述必须包含：coreFont 的设计、captionSmall 例外、全部 NFR 视觉例外的截图对比、第 5 条命令的 `TEST SUCCEEDED` 与布局断言非空转的证据。
