# 本地化 String Catalog（Issue #100 / 审计项 D2）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 oh-my-superpowers:subagent-driven-development（推荐）或 oh-my-superpowers:executing-plans 逐 task 执行本计划。步骤用 checkbox（`- [ ]`）语法追踪。

**Goal:** 把 12 处组件内部 UI 字符串（4 处硬编码中文 + 4 处已英文 + #99 新增的 4 处英文 a11y 串）纳入 `Localizable.xcstrings`（source language = en），4 处硬编码中文改英文，使 CoreDesign 全库组件内部 UI 串口径一致、具备可本地化能力，四条 SwiftPM 命令保持全绿零 warning。**主编排裁决（原 R1 范围矛盾）**：扩范围纳入 #99 的 4 处英文 a11y 串（`BottomInputBar` Suggestions/Send/Stop、`Form.DangerIcon` Alert），兑现 #99 给 D2 行加的「L10n sweep 须一并纳入」指针，使 D2 标「已修复」名副其实。

**Architecture:** 新增 `Sources/CoreDesign/Resources/Localizable.xcstrings`（随现有 `.process("Resources")` 打包），`Package.swift` 加 `defaultLocalization: "en"`（SPM 对含 `.xcstrings` 的 target 的硬性要求）。各组件调用点按调用形态传 `bundle: .module`：`Text(key, bundle:)` / `.accessibilityLabel(Text(..., bundle:))` / `.accessibilityHint(Text(..., bundle:))` / `String(localized:bundle:)`。key 用英文源串本身（现代 String Catalog 惯例）。

**Tech Stack:** SwiftPM package trait 构建、SwiftUI（iOS 26+ / macOS 26+）、Swift 6 language mode、Swift Testing（`import Testing`）、String Catalog（`.xcstrings`）。

## Global Constraints

- **越界红线**：本任务只允许改动这些文件——`Package.swift`、`Sources/CoreDesign/Resources/Localizable.xcstrings`（新增）、`Toast.swift`、`CoreMenuButton.swift`（在 `Components/BottomInputBar/` 下）、`BottomInputBar.swift`（在 `Components/BottomInputBar/` 下，#99 的 Suggestions/Send/Stop）、`Form.swift`（#99 的 DangerIcon Alert）、`BookCover.swift`、`ProgressBar.swift`、`ProgressIndicator.swift`、`Tag.swift`、`AvatarGroup.swift`、`.claude/` 下的追踪文件（audit-checklist / progress）。**不碰任何其他 Sources / Tests**。
- **Package.swift 只加一行** `defaultLocalization: "en"`——不碰 #92 落的 `swiftSettings: [.defaultIsolation(MainActor.self)]`、`platforms`、`swiftLanguageModes`、`traits`。
- **范围：12 个组件内部 UI 串**（原 8 + #99 扩入的 4）。`#Preview` 里的演示文案（书名 / tag 名等）是示例数据，**不本地化**。CommentCard / SearchField / AsyncButton 的英文 a11y 串**不在本任务范围**（那些串各有动态插值 / 独立语义，非本次「全库组件内部 UI 串口径一致」目标所指的静态字面量）。**#99 扩入（主编排裁决）**：#99 新增的 4 处英文 a11y 串（`BottomInputBar` Suggestions/Send/Stop、`Form.DangerIcon` Alert）本次一并纳入 catalog，兑现 D2 行 #99 指针，形态同「已英文串纳入 bundle」（见 Task 3）。
- **key = 英文源串本身**。11 个唯一 key：`Untitled` / `Tap to dismiss` / `Menu` / `Loading` / `Progress` / `Remove tag` / `%lld more avatars` / `Suggestions` / `Send` / `Stop` / `Alert`（`Menu` 两处复用同一 key → 11 key / 12 调用点）。
- **所有资源查找必须传 `bundle: .module`**（CLAUDE.md 约定）；不传会在下游 app 静默回落成 key。
- **两种构建模式都要绿**：默认（`swift build` / `swift test`）与 Blossom（`swift build --traits Blossom` / `swift test --traits Blossom`），warning 数 = 0。
- **代码 / 标识符 / commit message 用英文**；注释与 `// MARK:` 保持仓库既有中英双语惯例。
- **代码风格**：同类型内成员访问也显式 `self.`（如 `self.label`、`self.style`）。
- 每个 task 末尾 commit；commit message 按仓库惯例（`feat(l10n): ...` / `refactor(l10n): ...` 等）。

## 12 处目标串一览（侦察已核对，行号为写计划时快照，执行时按符号定位）

| # | 文件:行 | 当前 | 处理 | key |
|---|---|---|---|---|
| 1 | `BookCover.swift:23` | `title.isEmpty ? "未命名" : title`（`bookCoverDisplayTitle` 返回 String） | 中→英 + catalog | `Untitled` |
| 2 | `Toast.swift:422` | `.accessibilityHint(Text("点击关闭"))` | 中→英 + catalog | `Tap to dismiss` |
| 3 | `CoreMenuButton.swift:131` | `Text("菜单")` | 中→英 + catalog | `Menu` |
| 4 | `CoreMenuButton.swift:161` | `.accessibilityLabel("菜单")` | 中→英 + catalog | `Menu`（复用） |
| 5 | `ProgressIndicator.swift:34` | `.accessibilityLabel("Loading")` | 已英，纳入 catalog | `Loading` |
| 6 | `ProgressBar.swift:57` | `.accessibilityLabel(self.label ?? "Progress")` | 仅默认值 `?? "Progress"` 纳入；`self.label` 是用户动态串（verbatim，不本地化） | `Progress` |
| 7 | `Tag.swift:110` | `.accessibilityLabel(Text("Remove tag"))` | 已英，纳入 catalog | `Remove tag` |
| 8 | `AvatarGroup.swift:89–90` | `AvatarGroupAccessibility.overflowLabel(for:)` 返回 `"\(count) more avatars"` | 已英（插值），纳入 catalog | `%lld more avatars` |
| 9 | `BottomInputBar.swift:152` | `.accessibilityLabel("Suggestions")`（#99） | 已英，纳入 catalog | `Suggestions` |
| 10 | `BottomInputBar.swift:168` | `.accessibilityLabel("Send")`（#99） | 已英，纳入 catalog | `Send` |
| 11 | `BottomInputBar.swift:181` | `.accessibilityLabel("Stop")`（#99） | 已英，纳入 catalog | `Stop` |
| 12 | `Form.swift:115` | `.accessibilityLabel("Alert")`（#99，`DangerIcon`） | 已英，纳入 catalog；en 下仍念 "Alert"（#99 spoken-label 预期不变） | `Alert` |

---

## Task 1: 建 `Localizable.xcstrings` + `Package.swift` 加 `defaultLocalization` + 打包 wiring spike

先把本地化资源与 SPM 声明落地，并用一个 throwaway spike **实证** `.xcstrings` 经 `.process` 打包后、`String(localized:bundle:)` 在 `swift test` 下能真正取到 en 值——**再铺开后面的改动点**。

> **为何需要 spike（关键 gotcha）**：`String(localized:key, bundle: .module)` 在**未命中**时会返回 key 本身（对纯英文 key 而言 key==值，回落与命中肉眼无法区分；对插值 key `%lld more avatars`，`String(localized: "\(2) more avatars")` 命中与回落都渲染 "2 more avatars"）。因此只有让 key ≠ 值 的探针才能证明「bundle 真被查了」。**更隐蔽的坑**：`Bundle.module` 在**测试 target** 里指向 `CoreDesignTests` 的资源 bundle，**不是** CoreDesign 的——测试里直接 `String(localized:bundle:.module)` 永远查不到本地化。所以探针必须是**跑在 CoreDesign 模块内**的代码（真实 API 也都在模块内用 `.module`，故运行期正确）。

**Files:**
- Modify: `Package.swift`（`name:` 后加 `defaultLocalization: "en",`）
- Create: `Sources/CoreDesign/Resources/Localizable.xcstrings`
- Create（throwaway，本 task 末删除）：`Sources/CoreDesign/_L10nWiringProbe.swift`
- Create（throwaway，本 task 末删除）：`Tests/CoreDesignTests/_L10nWiringSpikeTests.swift`

**Interfaces:**
- Produces: `Localizable.xcstrings` 内 11 个 key（`Untitled` / `Tap to dismiss` / `Menu` / `Loading` / `Progress` / `Remove tag` / `%lld more avatars` / `Suggestions` / `Send` / `Stop` / `Alert`），供 Task 2/3 各调用点引用。
- Produces: `Package.defaultLocalization == "en"`（Task 4 越界核查会确认它是唯一新增行）。

- [ ] **Step 1: Package.swift 加 `defaultLocalization`**

`defaultLocalization: LanguageTag?` 是 `Package.init` 的**第 2 位置参数**（`name` 之后、`platforms` 之前）。

Before（`Package.swift` 第 6–11 行）:

```swift
let package = Package(
    name: "CoreDesign",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
```

After:

```swift
let package = Package(
    name: "CoreDesign",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
```

- [ ] **Step 2: 创建 `Localizable.xcstrings`（含 11 正式 key + 1 临时探针 key）**

手写 JSON。探针 key `l10n.spike.probe` 值 `WIRED`（key≠值，用于 Step 4 证明打包 wiring），Step 5 删除。

Create `Sources/CoreDesign/Resources/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "%lld more avatars" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%lld more avatars"
          }
        }
      }
    },
    "l10n.spike.probe" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "WIRED"
          }
        }
      }
    },
    "Alert" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Alert"
          }
        }
      }
    },
    "Loading" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Loading"
          }
        }
      }
    },
    "Menu" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Menu"
          }
        }
      }
    },
    "Progress" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Progress"
          }
        }
      }
    },
    "Remove tag" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Remove tag"
          }
        }
      }
    },
    "Send" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Send"
          }
        }
      }
    },
    "Stop" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Stop"
          }
        }
      }
    },
    "Suggestions" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Suggestions"
          }
        }
      }
    },
    "Tap to dismiss" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Tap to dismiss"
          }
        }
      }
    },
    "Untitled" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Untitled"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 3: 写 throwaway 探针源 + spike 测试**

探针必须在 CoreDesign 模块内用 `.module`（见本 task 顶部 gotcha）。

Create `Sources/CoreDesign/_L10nWiringProbe.swift`:

```swift
//  Throwaway — Task 1 打包 wiring spike。验证后删除。
import Foundation

enum L10nWiringProbe {
    /// 命中返回 "WIRED"；未命中（bundle 没被查到）返回 key "l10n.spike.probe"。
    static var probeValue: String {
        String(localized: "l10n.spike.probe", bundle: .module)
    }

    /// 插值 key 冒烟：命中或回落都应渲染 "2 more avatars"。
    static var pluralValue: String {
        String(localized: "\(2) more avatars", bundle: .module)
    }
}
```

Create `Tests/CoreDesignTests/_L10nWiringSpikeTests.swift`:

```swift
//  Throwaway — Task 1 打包 wiring spike。验证后删除。
import Testing
@testable import CoreDesign

@Suite("L10nWiringSpike")
struct L10nWiringSpikeTests {
    @Test("xcstrings 经 .process 打包后 String(localized:bundle:.module) 在 CoreDesign 模块内命中 en 值")
    func probeIsWired() {
        #expect(L10nWiringProbe.probeValue == "WIRED")
    }

    @Test("插值 key 渲染实参")
    func pluralRenders() {
        #expect(L10nWiringProbe.pluralValue == "2 more avatars")
    }
}
```

- [ ] **Step 4: 冷跑 spike（clean 后，首次引入本地化资源保险起见）**

`.xcstrings` 非 colorset，理论上不必 clean；但**首次引入本地化资源**，冷跑排除增量构建不拷贝新资源目录的干扰（CLAUDE.md 记录的 macOS SPM 目录式 `.xcassets` 增量坑同理适用于新资源）。

Run:

```bash
swift package clean && swift test --filter L10nWiringSpike
```

Expected: 2 tests PASS。
- 若 `probeIsWired` FAIL 且实际值为 `"l10n.spike.probe"` → **打包 wiring 没生效，停下排查**（检查 `defaultLocalization` 是否落对、`.xcstrings` 是否在 `Resources/` 下、JSON 是否合法），**不要继续 Task 2/3**。
- 若 `pluralRenders` FAIL → 插值 key 形态有误，排查 `String(localized:)` 插值写法。

- [ ] **Step 5: 删除探针 key + throwaway 源 + spike 测试**

从 `Localizable.xcstrings` 的 `"strings"` 对象中删除整个 `"l10n.spike.probe"` 键值块（连同前后逗号，保持 JSON 合法）。

Run:

```bash
rm Sources/CoreDesign/_L10nWiringProbe.swift Tests/CoreDesignTests/_L10nWiringSpikeTests.swift
```

删除后 `Localizable.xcstrings` 应只剩 11 个正式 key。

- [ ] **Step 6: 校验 JSON 合法 + 构建绿**

Run:

```bash
python3 -c "import json,sys; d=json.load(open('Sources/CoreDesign/Resources/Localizable.xcstrings')); ks=sorted(d['strings'].keys()); print(ks); assert ks==['%lld more avatars','Alert','Loading','Menu','Progress','Remove tag','Send','Stop','Suggestions','Tap to dismiss','Untitled'], ks; print('OK 11 keys')"
swift build
```

Expected: 打印 `OK 11 keys`；`swift build` — `Build complete!`，0 warning。

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/CoreDesign/Resources/Localizable.xcstrings
git commit -m "feat(l10n): add Localizable.xcstrings + defaultLocalization (D2)"
```

（`git add` 不含已删的 throwaway 文件；确认 `git status` 干净，无 `_L10n*` 残留。）

---

## Task 2: 4 处中文串改英文 + 走 bundle 形态

**Files:**
- Modify: `Sources/CoreDesign/Components/BookCover/BookCover.swift`（`bookCoverDisplayTitle` 第 23 行 + 两处注释引用第 21、127 行）
- Modify: `Sources/CoreDesign/Components/Toast/Toast.swift`（`.accessibilityHint`）
- Modify: `Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift`（`Text("菜单")` + `.accessibilityLabel("菜单")`）

**Interfaces:**
- Consumes: Task 1 的 `Untitled` / `Tap to dismiss` / `Menu` key。
- Produces: `bookCoverDisplayTitle(_:) -> String` 返回本地化后的 String（签名不变，仍供 `BookCover.body` L88 `Text(...)` 与 `BookCoverPlaceholder` L149/163/178 复用）。

- [ ] **Step 1: BookCover — `bookCoverDisplayTitle` 返回本地化 String**

函数返回 String（既用于 `Text(...)` 渲染又用于 `accessibilityLabel`），故用 `String(localized:bundle:)`。

Before（`BookCover.swift` 第 22–24 行）:

```swift
private func bookCoverDisplayTitle(_ title: String) -> String {
    title.isEmpty ? "未命名" : title
}
```

After:

```swift
private func bookCoverDisplayTitle(_ title: String) -> String {
    title.isEmpty ? String(localized: "Untitled", bundle: .module) : title
}
```

- [ ] **Step 2: BookCover — 同步两处注释里的中文字面量引用（避免 stale 文档 + 保 grep 判据干净）**

第 21 行与第 127 行注释仍写着 `"未命名"`，改后行为已是 "Untitled"，须同步（否则文档撒谎，且 Task 4 的 `"未命名"` grep 判据会误命中注释）。只改被引号包住的字面量，中文散文保留。

Before（第 21 行）:

```swift
/// 空标题朗读为 "未命名"。集中在此避免双处分叉。
```

After:

```swift
/// 空标题朗读为 "Untitled"。集中在此避免双处分叉。
```

Before（第 127 行）:

```swift
/// - `title`：书名；空字符串时显示 "未命名"。书名同时是渐变背景色的算法种子
```

After:

```swift
/// - `title`：书名；空字符串时显示 "Untitled"。书名同时是渐变背景色的算法种子
```

- [ ] **Step 3: Toast — `.accessibilityHint` 走 Text + bundle**

`.accessibilityHint(Text(..., bundle:))`（Text 重载；直接传字符串字面量会走 main bundle 取不到译文）。

Before（`Toast.swift` 第 422 行）:

```swift
        .accessibilityHint(Text("点击关闭"))
```

After:

```swift
        .accessibilityHint(Text("Tap to dismiss", bundle: .module))
```

- [ ] **Step 4: CoreMenuButton — 可见 `Text("菜单")` 走 bundle**

Before（`CoreMenuButton.swift` 第 130–132 行）:

```swift
            if self.style == .labeled {
                Text("菜单")
            }
```

After:

```swift
            if self.style == .labeled {
                Text("Menu", bundle: .module)
            }
```

- [ ] **Step 5: CoreMenuButton — `.accessibilityLabel("菜单")` 走 Text + bundle（复用 `Menu` key）**

Before（`CoreMenuButton.swift` 第 161 行）:

```swift
            .accessibilityLabel("菜单")
```

After:

```swift
            .accessibilityLabel(Text("Menu", bundle: .module))
```

- [ ] **Step 6: 构建 + 默认测试绿**

Run:

```bash
swift build && swift test
```

Expected: `Build complete!`，0 warning；测试全过（本 task 未触碰任何断言字符串，现有测试不受影响）。

- [ ] **Step 7: Commit**

```bash
git add Sources/CoreDesign/Components/BookCover/BookCover.swift Sources/CoreDesign/Components/Toast/Toast.swift Sources/CoreDesign/Components/BottomInputBar/CoreMenuButton.swift
git commit -m "feat(l10n): localize 4 zh UI strings to en via bundle (D2)"
```

---

## Task 3: 8 处已英文串纳入 bundle 形态（含 ProgressBar / AvatarGroup 的 tricky 形态 + #99 的 BottomInputBar/Form a11y 串）

原 4 处已英文串 + #99 扩入的 4 处英文 a11y 串（`BottomInputBar` Suggestions/Send/Stop、`Form.DangerIcon` Alert）形态一致——都是把 `.accessibilityLabel(英文字面量)` 改为 `.accessibilityLabel(Text(..., bundle: .module))`，故合并到本 task。

**Files:**
- Modify: `Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift`
- Modify: `Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift`
- Modify: `Sources/CoreDesign/Components/Tag/Tag.swift`
- Modify: `Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift`
- Modify: `Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift`（#99 的 Suggestions/Send/Stop）
- Modify: `Sources/CoreDesign/Components/Form/Form.swift`（#99 的 DangerIcon Alert）
- Test（保绿，不改）：`Tests/CoreDesignTests/AvatarGroupTests.swift`

**Interfaces:**
- Consumes: Task 1 的 `Loading` / `Progress` / `Remove tag` / `%lld more avatars` / `Suggestions` / `Send` / `Stop` / `Alert` key。
- Produces: `AvatarGroupAccessibility.overflowLabel(for:) -> String` 签名不变（现有测试 `overflowLabel(for: 2) == "2 more avatars"` 须继续通过）。

- [ ] **Step 1: ProgressIndicator — `.accessibilityLabel` 走 Text + bundle**

Before（`ProgressIndicator.swift` 第 34 行）:

```swift
            .accessibilityLabel("Loading")
```

After:

```swift
            .accessibilityLabel(Text("Loading", bundle: .module))
```

- [ ] **Step 2: ProgressBar — 只本地化默认值，`self.label` 保持 verbatim**

`self.label` 是用户提供的动态串——**不能**当 LocalizedStringKey（否则用户传的文本会被拿去查表）。写成 `self.label.map(Text.init(verbatim:)) ?? Text("Progress", bundle: .module)`：有 label 时 verbatim（等价于原 `StringProtocol` 重载的 verbatim 行为，不破坏），无 label 时默认值走 bundle。

Before（`ProgressBar.swift` 第 56–58 行）:

```swift
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.label ?? "Progress")
        .accessibilityValue("\(Int(self.value * 100))% complete")
```

After:

```swift
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.label.map(Text.init(verbatim:)) ?? Text("Progress", bundle: .module))
        .accessibilityValue("\(Int(self.value * 100))% complete")
```

> 说明：可见的 `Text(label)`（第 37 行）本就是 `Text(_ content: some StringProtocol)` verbatim 初始化器（变量而非字面量，不查表），是用户串的正确渲染，**保持不动**。`"\(Int(...))% complete"` 是纯数值格式串，不在本任务 catalog 范围，保持不动。

- [ ] **Step 3: Tag — `.accessibilityLabel(Text(...))` 补 bundle**

已是 Text，仅补 `bundle: .module`。

Before（`Tag.swift` 第 110 行）:

```swift
                    .accessibilityLabel(Text("Remove tag"))
```

After:

```swift
                    .accessibilityLabel(Text("Remove tag", bundle: .module))
```

- [ ] **Step 4: AvatarGroup — `overflowLabel` 走 `String(localized:bundle:)` 插值**

`String(localized: "\(count) more avatars", bundle: .module)`——`LocalizedStringResource` 风格插值，catalog key 为 `%lld more avatars`。返回 String，签名不变，第 70 行调用点 `.accessibilityLabel(...)` 不需改。

Before（`AvatarGroup.swift` 第 88–92 行）:

```swift
enum AvatarGroupAccessibility {
    static func overflowLabel(for count: Int) -> String {
        "\(count) more avatars"
    }
}
```

After:

```swift
enum AvatarGroupAccessibility {
    static func overflowLabel(for count: Int) -> String {
        String(localized: "\(count) more avatars", bundle: .module)
    }
}
```

- [ ] **Step 5: BottomInputBar — 3 处 #99 a11y label 走 Text + bundle**

`suggestionButton` / `sendButton` / `stopButton`（#99 加在各 `Button` 上）的 `.accessibilityLabel("字面量")` → `.accessibilityLabel(Text(..., bundle: .module))`。仅改这三行，其余（`.accessibilityAddTraits` 等）不动。

Before（`BottomInputBar.swift` 第 152 行，`suggestionButton`）:

```swift
        .accessibilityLabel("Suggestions")
```

After:

```swift
        .accessibilityLabel(Text("Suggestions", bundle: .module))
```

Before（`BottomInputBar.swift` 第 168 行，`sendButton`）:

```swift
        .accessibilityLabel("Send")
```

After:

```swift
        .accessibilityLabel(Text("Send", bundle: .module))
```

Before（`BottomInputBar.swift` 第 181 行，`stopButton`）:

```swift
        .accessibilityLabel("Stop")
```

After:

```swift
        .accessibilityLabel(Text("Stop", bundle: .module))
```

- [ ] **Step 6: Form — `DangerIcon` 的 #99 a11y label 走 Text + bundle**

`.accessibilityLabel("Alert")` → `.accessibilityLabel(Text("Alert", bundle: .module))`。`Text("Alert", bundle: .module)` 在 en 下仍念 "Alert"——#99 checkpoint 记录的 spoken-label 预期（`DangerIcon` 念 "Alert"，而非 "Warning"）**不变**。上方解释 "Alert" vs "Warning" 语义选择的中文注释块保留不动。

Before（`Form.swift` 第 115 行）:

```swift
            .accessibilityLabel("Alert")
```

After:

```swift
            .accessibilityLabel(Text("Alert", bundle: .module))
```

- [ ] **Step 7: 跑 AvatarGroup 测试确认不破**

现有断言 `overflowLabel(for: 2) == "2 more avatars"`。`overflowLabel` 跑在 CoreDesign 模块内（`.module` 正确指向 CoreDesign bundle）：命中 en 值 `%lld more avatars` → 代入 2 → "2 more avatars"；即便回落，`String(localized:)` 也渲染实参 → "2 more avatars"。两路都 PASS。

Run:

```bash
swift test --filter AvatarGroup
```

Expected: `AvatarGroupTests` 3 个测试全 PASS（含 `overflowAccessibilityLabel`）。

- [ ] **Step 8: 构建 + 全量默认测试绿**

Run:

```bash
swift build && swift test
```

Expected: `Build complete!`，0 warning；全部测试 PASS。

- [ ] **Step 9: Commit**

```bash
git add Sources/CoreDesign/Components/ProgressIndicator/ProgressIndicator.swift Sources/CoreDesign/Components/ProgressBar/ProgressBar.swift Sources/CoreDesign/Components/Tag/Tag.swift Sources/CoreDesign/Components/AvatarGroup/AvatarGroup.swift Sources/CoreDesign/Components/BottomInputBar/BottomInputBar.swift Sources/CoreDesign/Components/Form/Form.swift
git commit -m "feat(l10n): route existing en UI strings through bundle catalog (D2)"
```

---

## Task 4: 全量验证（四命令冷跑 + 中文 grep 判据 + 越界 + audit-checklist + progress）

**Files:**
- Modify: `.claude/epics/coredesign-audit-remediation/audit-checklist.md`（D2 标 ✅，保 #99 指针，计数不变）
- Create: `.claude/epics/coredesign-audit-remediation/updates/100/progress.md`

- [ ] **Step 1: 四条 SwiftPM 命令冷跑全绿零 warning**

`defaultLocalization` 影响资源打包路径，Blossom 同样要验；首次引入本地化资源，先 clean 冷跑。

Run:

```bash
swift package clean
swift build
swift test
swift build --traits Blossom
swift test --traits Blossom
```

Expected: 四条命令各自 `Build complete!` / 测试全 PASS，**每条 0 warning**。任一条出现 warning 或 fail → 停下修复，不进后续步骤。

- [ ] **Step 2: 中文 grep 判据（限定到 UI 字符串字面量，排除注释 / Preview）**

裸跑 AC line 32 的 `grep -rn '[\p{Han}]' ...` 会误命中约 1500+ 行注释 / MARK / Preview 演示中文，无判定力。改用两段可判定命令：

**判据 A（决定性——4 处 UI 字面量的引号形式必须清零）**：

```bash
grep -rn '"未命名"\|"点击关闭"\|"菜单"' Sources/CoreDesign --include='*.swift'
```

Expected: **零输出**（退出码 1）。改前此命令有 6 命中（BookCover 21/23/127、Toast 422、CoreMenuButton 131/161）；Task 2 删掉字面量 + 同步注释后应全清零。若仍有命中 → 有 UI 字面量或注释引用漏改。

**判据 B（人工确认——8 个改动文件里剩余中文只应是 Preview 演示数据或行尾注释）**：

```bash
rg -nP '\p{Han}' -g 'BookCover.swift' -g 'Toast.swift' -g 'CoreMenuButton.swift' -g 'ProgressBar.swift' -g 'ProgressIndicator.swift' -g 'Tag.swift' -g 'AvatarGroup.swift' Sources/CoreDesign/Components | rg -vP ':[0-9]+:\s*//'
```

Expected: 命中集合**恰好**为下列「允许项」，无任何 UI 串字面量：
- `Tag.swift:166` / `Tag.swift:192` — `#Preview("Tag · light"/"dark")` 标签
- `Toast.swift:251` — 行尾注释 `// 先置空避免 ...`
- `BookCover.swift:215` / `BookCover.swift:219` — `#Preview` 演示书名 "万历十五年" / "三体：黑暗森林"
- `BookCover.swift:284` — 行尾注释 `// 命中且字节完全一致 ...`

（改前此集合还包含 Toast:422、CoreMenuButton:131/161、BookCover:23 三处 UI 串——它们必须消失。逐条核对命中项确无 UI 字面量。）

**判据 C（已英文串纳入核对——8 处已英文串须走 `bundle: .module`，无裸字面量 a11y label 残留）**：

改前这 8 处英文串（原 4 处 + #99 扩入的 4 处）以裸字面量 / 无 bundle 的 `Text` 形式存在。改后全部应为 `Text(..., bundle: .module)` / `String(localized:bundle:)` 形态。应走 `bundle: .module` 的核对清单（逐项确认）：

- `ProgressIndicator` `Loading`、`ProgressBar` `Progress`（默认值）、`Tag` `Remove tag`、`AvatarGroup` `%lld more avatars`（插值，`String(localized:bundle:)`）
- **#99 扩入**：`BottomInputBar` `Suggestions` / `Send` / `Stop`、`Form.DangerIcon` `Alert`

判定命令（这些字符串**不应**再以裸字面量或无 bundle 的 `Text` 出现）：

```bash
grep -rn '\.accessibilityLabel("Loading")\|\.accessibilityLabel("Suggestions")\|\.accessibilityLabel("Send")\|\.accessibilityLabel("Stop")\|\.accessibilityLabel("Alert")\|\.accessibilityLabel(Text("Remove tag"))\|\.accessibilityLabel(self.label ?? "Progress")' Sources/CoreDesign --include='*.swift'
```

Expected: **零输出**（退出码 1）。改前 `ProgressIndicator:34` / `Tag:110` / `ProgressBar:57` / `BottomInputBar:152,168,181` / `Form:115` 共 7 命中（`AvatarGroup` 走 `overflowLabel` 函数体、不在此 grep 形态内，单独由 AvatarGroupTests + 判据留意）；改后全清零，证明均已改走 `Text(..., bundle: .module)`。若仍有命中 → 有已英文串漏改 bundle 形态。

- [ ] **Step 3: 越界核查（改动仅限白名单文件；Package.swift 只多一行）**

Run:

```bash
git diff --stat epic/coredesign-audit-remediation..HEAD -- Sources Package.swift Tests
git diff epic/coredesign-audit-remediation..HEAD -- Package.swift
```

Expected:
- `--stat` 只列白名单内的 10 个源文件（`BookCover` / `Toast` / `CoreMenuButton` / `ProgressIndicator` / `ProgressBar` / `Tag` / `AvatarGroup` / `BottomInputBar` / `Form` + 新增 `Localizable.xcstrings`）+ `Package.swift`；**无 Tests 改动**（AvatarGroupTests 未动），**无其他 Sources 文件**。
- `Package.swift` 的 diff **只新增 `    defaultLocalization: "en",` 一行**，未触碰 `swiftSettings` / `platforms` / `swiftLanguageModes` / `traits`。

- [ ] **Step 4: audit-checklist D2 标「已修复」（保 #99 指针，计数仍 83/79）**

只改 D2 数据行的状态描述；保留末尾 `| FR-7 | #9 |` 以维持计数（`grep -c '^| [A-D][0-9]'` 仍 = 83，`grep -oE '\| #[0-9]+ \|$'` 的 #9 仍计一次 → 79）。保留 #99 交接指针的**历史**（标注为「#99 指针已由本任务兑现」），但状态改为「已一并纳入」——本任务已实做 #99 的 4 串，**去掉**「作为已知后续项」措辞。

Before（`audit-checklist.md` 第 104 行）:

```
| D2 | 硬编码中文 UI 字符串，与别处英文不一致；全库无 String Catalog。**#99 交接**：#99 新增了 4 处英文 a11y 字符串（`BottomInputBar` 的 Suggestions/Send/Stop、`Form.DangerIcon` 的 Alert）——中文 grep 抓不到，L10n sweep 须一并纳入 catalog | `Toast.swift:441`、`CoreMenuButton.swift:131,161`、`BookCover.swift:23`；+#99 新增 `BottomInputBar`/`Form` 英文 a11y 串 | FR-7 | #9 |
```

After（单行，勿折行）:

```
| D2 | ✅ **已修复**（GitHub #100）——全库组件内部 UI 串（含 #99 的 4 串）纳入 `Localizable.xcstrings`（sourceLanguage=en，11 唯一 key，`Menu` 两处复用 → 12 调用点）：`BookCover` "Untitled"、`Toast` "Tap to dismiss"、`CoreMenuButton` "Menu"、`ProgressIndicator` "Loading"、`ProgressBar` "Progress"（默认值；用户传的 label 保持 verbatim）、`Tag` "Remove tag"、`AvatarGroup` "%lld more avatars"、`BottomInputBar` "Suggestions"/"Send"/"Stop"、`Form.DangerIcon` "Alert"；4 处硬编码中文改英文，各调用点走 `bundle: .module`；`Package.swift` 加 `defaultLocalization: "en"`。**#99 指针已由本任务兑现**：#99 新增的 4 处英文 a11y 串（`BottomInputBar` 的 Suggestions/Send/Stop、`Form.DangerIcon` 的 Alert）已一并纳入 catalog（原 #99 指针要求「L10n sweep 须一并纳入」）。原缺陷：硬编码中文 UI 字符串，与别处英文不一致；全库无 String Catalog | `Toast.swift`、`CoreMenuButton.swift`、`BookCover.swift`、`BottomInputBar.swift`、`Form.swift`、新增 `Localizable.xcstrings` | FR-7 | #9 |
```

核查计数不变:

```bash
cd .claude/epics/coredesign-audit-remediation
echo $(( $(grep -c '^| [A-D][0-9]' audit-checklist.md) - 4 ))   # => 83
grep -oE '\| #[0-9]+ \|$' audit-checklist.md | sort -V | uniq -c | awk '{s+=$1} END{print s}'  # => 79
cd -
```

Expected: 打印 `83` 与 `79`。

- [ ] **Step 5: 写 progress 记录**

Create `.claude/epics/coredesign-audit-remediation/updates/100/progress.md`（参照 #99 progress 形态，中文）:

```markdown
# Issue #100 本地化 String Catalog — 完成记录

分支 `issue-100-l10n`（base `epic/coredesign-audit-remediation`）。承载审计项 **D2** 1 项（Size XS）。

## 做了什么

- 新增 `Sources/CoreDesign/Resources/Localizable.xcstrings`（sourceLanguage=en，11 唯一 key，`Menu` 两处复用 → 12 调用点）。
- `Package.swift` 加 `defaultLocalization: "en"`（SPM 对含 `.xcstrings` 的 target 硬性要求；未碰 #92 的 `swiftSettings`/`platforms`/`swiftLanguageModes`）。
- 4 处硬编码中文改英文：`BookCover` "未命名"→"Untitled"、`Toast` "点击关闭"→"Tap to dismiss"、`CoreMenuButton` "菜单"→"Menu"（可见 + a11y 复用同 key）。
- 4 处已英文串纳入 catalog（口径统一）：`ProgressIndicator` "Loading"、`ProgressBar` "Progress"（仅默认值；用户 label 保持 verbatim）、`Tag` "Remove tag"、`AvatarGroup` "%lld more avatars"（插值）。
- #99 扩入的 4 处英文 a11y 串纳入 catalog（兑现 D2 行 #99 指针）：`BottomInputBar` "Suggestions"/"Send"/"Stop"、`Form.DangerIcon` "Alert"（en 下仍念 "Alert"，#99 spoken-label 预期不变）。
- 各调用点按形态传 `bundle: .module`（`Text(key,bundle:)` / `accessibilityLabel(Text(...,bundle:))` / `accessibilityHint(...)` / `String(localized:bundle:)`）。

## 验证

- 四条命令冷跑（clean 后）全绿零 warning：`swift build` / `swift test` / `swift build --traits Blossom` / `swift test --traits Blossom`。
- Task 1 打包 wiring spike（throwaway 探针 key≠值）实证 `.xcstrings` 经 `.process` 打包、`String(localized:bundle:.module)` 在模块内命中 en 值；已删除探针。
- 中文判据 A（`"未命名"|"点击关闭"|"菜单"` 引号形式）清零；判据 B 残余中文全为 `#Preview` 演示数据 / 行尾注释；判据 C（8 处已英文串裸字面量 a11y label）清零。
- AvatarGroupTests 3 测试全绿（`overflowLabel(for:2)=="2 more avatars"` 未破）。
- 越界：改动仅限白名单文件；`Package.swift` 只多 `defaultLocalization: "en"` 一行。

## #99 指针兑现

- #99 曾在 D2 行加指针「L10n sweep 须一并纳入」并新增 4 处英文 a11y 串（`BottomInputBar` Suggestions/Send/Stop、`Form.DangerIcon` Alert）。主编排裁决扩范围，本任务已一并纳入 catalog——D2 标「已修复」名副其实，全库组件内部 UI 串口径一致。
```

- [ ] **Step 6: Commit**

```bash
git add .claude/epics/coredesign-audit-remediation/audit-checklist.md .claude/epics/coredesign-audit-remediation/updates/100/progress.md
git commit -m "docs(ccpm): mark D2 fixed; #100 progress record"
```

---

## 收尾：verification → finishing → PR

- [ ] **verification-before-completion**：在给「完成」结论前，确认 Task 4 Step 1 的四条命令输出（0 warning、全 PASS）、判据 A 零输出、判据 B 残余清单核对无 UI 串、判据 C 零输出、计数 83/79 均有命令输出为证。**证据先于断言**。

- [ ] **finishing-a-development-branch（Option 2：开 PR，不合并）**：base = `epic/coredesign-audit-remediation`（**不是 main**）。PR body 覆盖：承载 D2；12 串 catalog 化（含 #99 扩入的 4 处英文 a11y 串）+ `defaultLocalization`；四命令冷跑绿证据；判据 A/B/C；#99 指针已兑现（主编排裁决扩范围）。PR body 末尾附：

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

- [ ] **PR 迭代**：刚开 PR 即进 `auto-fix-pr-after-implementation`（拉 Copilot review → 改 → threaded reply → 触发下一轮）。**Copilot 不可用时降级**：用 `Agent`（`subagent_type: superpowers-reviewer`）对完整 diff（`BASE_SHA`=epic tip / `HEAD_SHA`=PR head，节点焦点＝`finishing` 挑战式终审）做评审，并把结论以顶层评论贴到 PR。反馈按 `receiving-code-review` 处置。

---

## 计划 Self-Review

**1. Spec 覆盖（逐 AC）**：
- AC「4 处中文改英文」→ Task 2 Step 1/3/4/5。✅
- AC「grep 中文在 UI 字面量零命中」→ Task 4 Step 2 判据 A/B。✅
- AC「`Localizable.xcstrings` 含四条新英文串」→ Task 1 Step 2（11 key 含这 4 条）。✅
- AC「已英文串同纳入 catalog」→ Task 1（key）+ Task 3（调用点）。✅
- 主编排裁决「扩范围纳入 #99 的 4 处英文 a11y 串」→ Task 1 Step 2（`Suggestions`/`Send`/`Stop`/`Alert` key）+ Task 3 Step 5/6（`BottomInputBar`/`Form` 调用点）+ Task 4 判据 C。✅
- AC「`Package.swift` 声明 `defaultLocalization`」→ Task 1 Step 1。✅
- AC「四命令加 `defaultLocalization` 后仍全绿零 warning」→ Task 4 Step 1。✅
- AC「audit-checklist D2 标已修复（#99 指针兑现，计数 83/79 不变）」→ Task 4 Step 4。✅
- DoD「新增/删 colorset 需先 clean」→ 本任务不增 colorset，但仍安排 Task 1 Step 4 与 Task 4 Step 1 冷跑（首次引入本地化资源保险）。✅

**2. Placeholder 扫描**：每个改码步骤都给了完整 before/after；无 TBD / "适当处理" / "类似 Task N"。✅

**3. 类型 / 签名一致性**：`bookCoverDisplayTitle(_:) -> String`、`AvatarGroupAccessibility.overflowLabel(for:) -> String` 签名跨 task 不变；11 个 key 名在 Task 1 定义、Task 2/3 引用一致；`Text.init(verbatim:)` 作 `.map` 参数类型 `(String)->Text`、`self.label: String?` → `Text?` → `?? Text` → `Text`，与 `.accessibilityLabel(Text)` 重载吻合。✅

**4. 判据可执行性**：判据 A/B/C、计数命令、JSON 校验均为写死的确定命令 + 预期输出（含改前基线数），已在侦察中实跑过命令形态。✅

**5. 一致性核查（11 key ⇄ 12 调用点）**：11 唯一 key（`Menu` 复用）对 12 调用点——4 中文（BookCover/Toast/CoreMenuButton×2）+ 4 已英文（ProgressIndicator/ProgressBar/Tag/AvatarGroup）+ 4 个 #99（BottomInputBar×3/Form）。越界白名单含全部触及文件（9 swift + `Localizable.xcstrings` + `Package.swift`）。✅

---

## 执行交接（写完计划后由 orchestrate/用户选择）

**Plan 已保存至 `.claude/epics/coredesign-audit-remediation/100-plan.md`。两种执行方式：**

**1. Subagent-Driven（推荐）** — 每 task 派新 subagent，task 间两阶段评审，快迭代。REQUIRED SUB-SKILL：oh-my-superpowers:subagent-driven-development。

**2. Inline Execution** — 本会话内用 oh-my-superpowers:executing-plans，带 checkpoint 批执行。

选哪种？
