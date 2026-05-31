# Blossom Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compile-time selectable theme to CoreDesign via a Swift Package Trait named `Blossom`, landing a coral-pink candy-gradient feminine palette (inspired by the 暖悦 app) while keeping the default (no-trait) build byte-for-byte identical to today.

**Architecture:** A single `Package.swift` trait `Blossom` gates `#if Blossom` branches in the lowest color layers only. The resource layer (`ColorGrade.brand0…9`) and canvas surfaces swap to new `blossom-*` asset-catalog colorsets; two semantic aliases (`secondary`, `secondaryAccent`) repoint from blue to violet; everything downstream (components) inherits automatically because it reads semantic names. A new `CoreGradient` token layer returns real `LinearGradient`s under Blossom and degrades to flat color otherwise. Status colors are untouched.

**Tech Stack:** Swift 6.3 (local toolchain confirmed), SwiftPM Package Traits (Swift 6.1+ feature), SwiftUI, Apple Swift Testing, Xcode asset catalogs (`.xcassets`).

---

## Background an executing engineer needs

- **Spec:** `docs/superpowers/specs/2026-05-31-blossom-theme-design.md` (read it first).
- **How colors load today:** every color is `Color("name", bundle: .module)` where `name` is the colorset's flat name. Asset-catalog folders (`brand/`, `canvas/`) are *visual grouping only* — they have no `Contents.json` and do **not** add a namespace. So a colorset placed at `Resources.xcassets/blossom-brand/blossom-brand-5.colorset` loads as `Color("blossom-brand-5", bundle: .module)`. **Do not** prefix with the folder name.
- **Trait conditional compilation:** a trait declared in `Package.swift` makes `#if Blossom` valid directly in this package's sources — no "local trait" mapping needed (confirmed against SE-0450).
- **Two build modes you must both keep green:**
  - Default: `swift build`, `swift test` (trait OFF — current behavior, zero regression).
  - Blossom: `swift build --traits Blossom`, `swift test --traits Blossom` (trait ON).
- **Test framework:** Apple Swift Testing (`import Testing`, `@Test`, `#expect`). Not XCTest. Existing test file is `Tests/CoreDesignTests/CoreDesignTests.swift` (currently a one-line stub).
- **Repo style:** explicit `self.`, bilingual `// MARK: -` comments, public API explicitly marked `public`.

### Colorset `Contents.json` format (the exact template)

Every colorset is a folder `<name>.colorset/` containing one `Contents.json`. Light is the appearance-less entry; dark adds `appearances: [{luminosity, dark}]`. Components are hex strings like `"0xFF"`. Worked example (`blossom-brand-5`, light `#FF6F8E` dark `#D15F82`):

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "red" : "0xFF", "green" : "0x6F", "blue" : "0x8E" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "red" : "0xD1", "green" : "0x5F", "blue" : "0x82" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

---

## Task 1: Declare the `Blossom` trait in Package.swift

**Files:**
- Modify: `Package.swift:6-32` (the `Package(...)` initializer)

- [ ] **Step 1: Add the `traits:` parameter**

Insert a `traits:` array into the `Package(...)` call. Place it right after the `platforms:` block (before `products:`):

```swift
let package = Package(
    name: "CoreDesign",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    traits: [
        .trait(name: "Blossom", description: "暖悦风格 · 珊瑚粉糖果渐变女性向主题 / Coral-pink candy-gradient feminine theme"),
        .default(enabledTraits: []),
    ],
    products: [
        .library(
            name: "CoreDesign",
            targets: ["CoreDesign"]
        ),
    ],
    targets: [
        .target(
            name: "CoreDesign",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CoreDesignTests",
            dependencies: ["CoreDesign"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Verify default build still resolves and compiles**

Run: `swift build`
Expected: Builds successfully. The empty `.default(enabledTraits: [])` means no trait is on by default, so nothing changes yet.

- [ ] **Step 3: Verify the trait is recognized by SwiftPM**

Run: `swift build --traits Blossom`
Expected: Builds successfully (no `#if Blossom` branches exist yet, so output is identical, but this proves the trait name is accepted and the manifest parses with traits).

- [ ] **Step 4: Verify default tests still pass**

Run: `swift test`
Expected: PASS (the existing `example()` test).

- [ ] **Step 5: Commit**

```bash
git add Package.swift
git commit -m "Add Blossom package trait declaration"
```

---

## Task 2: Generate the Blossom asset-catalog colorsets

This task creates 13 colorsets (10 brand + 3 canvas) as data files. Because they are near-identical JSON, use a generator script with an inline value table — every value is fully specified, nothing is left to interpretation.

**Files:**
- Create: `Resources.xcassets/blossom-brand/blossom-brand-0.colorset/Contents.json` … `blossom-brand-9.colorset/Contents.json` (10)
- Create: `Resources.xcassets/blossom-canvas/blossom-canvas-default.colorset/Contents.json`, `…-subtle…`, `…-inset…` (3)
- (All under `Sources/CoreDesign/Resources/Resources.xcassets/`)

- [ ] **Step 1: Write the generator script**

Create a throwaway script at repo root, `scripts/gen-blossom-colorsets.py`:

```python
#!/usr/bin/env python3
import json, os

ROOT = "Sources/CoreDesign/Resources/Resources.xcassets"

# (colorset_name, light_hex, dark_hex)
BRAND = [
    ("blossom-brand-0", "FFF0F4", "2A1119"),
    ("blossom-brand-1", "FFDCE6", "3D1824"),
    ("blossom-brand-2", "FFC2D2", "5A2233"),
    ("blossom-brand-3", "FFA0B9", "7C3047"),
    ("blossom-brand-4", "FF85A4", "A1405E"),
    ("blossom-brand-5", "FF6F8E", "D15F82"),
    ("blossom-brand-6", "F0577A", "E07F9C"),
    ("blossom-brand-7", "D43E62", "EBA0B6"),
    ("blossom-brand-8", "A52B49", "F3C2D0"),
    ("blossom-brand-9", "6E1B30", "FADEE6"),
]
CANVAS = [
    ("blossom-canvas-default", "FFFBFC", "160F12"),
    ("blossom-canvas-subtle",  "FAF1F3", "1E141A"),
    ("blossom-canvas-inset",   "FCF6F7", "120D10"),
]

def comp(hex6):
    return {
        "alpha": "1.000",
        "red":   "0x" + hex6[0:2].upper(),
        "green": "0x" + hex6[2:4].upper(),
        "blue":  "0x" + hex6[4:6].upper(),
    }

def contents(light, dark):
    return {
        "colors": [
            {"color": {"color-space": "srgb", "components": comp(light)}, "idiom": "universal"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "color": {"color-space": "srgb", "components": comp(dark)}, "idiom": "universal"},
        ],
        "info": {"author": "xcode", "version": 1},
    }

GROUP_CONTENTS = {"info": {"author": "xcode", "version": 1}}

def write(group, items):
    group_dir = os.path.join(ROOT, group)
    os.makedirs(group_dir, exist_ok=True)
    # Group-folder Contents.json (matches existing brand/ canvas/ groups).
    with open(os.path.join(group_dir, "Contents.json"), "w") as f:
        json.dump(GROUP_CONTENTS, f, indent=2)
        f.write("\n")
    for name, light, dark in items:
        d = os.path.join(group_dir, name + ".colorset")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "Contents.json"), "w") as f:
            json.dump(contents(light, dark), f, indent=2)
            f.write("\n")

write("blossom-brand", BRAND)
write("blossom-canvas", CANVAS)
print("wrote", len(BRAND) + len(CANVAS), "colorsets")
```

- [ ] **Step 2: Run the generator**

Run: `python3 scripts/gen-blossom-colorsets.py`
Expected output: `wrote 13 colorsets`

- [ ] **Step 3: Verify the files and one sample's content**

Run: `find Sources/CoreDesign/Resources/Resources.xcassets/blossom-brand Sources/CoreDesign/Resources/Resources.xcassets/blossom-canvas -name Contents.json | sort && echo "---" && cat Sources/CoreDesign/Resources/Resources.xcassets/blossom-brand/blossom-brand-5.colorset/Contents.json`
Expected: 13 `Contents.json` paths listed; the `blossom-brand-5` JSON shows light `red 0xFF green 0x6F blue 0x8E` and dark `red 0xD1 green 0x5F blue 0x82`.

- [ ] **Step 4: Remove the throwaway script and verify assets ship in both build modes**

```bash
rm scripts/gen-blossom-colorsets.py
rmdir scripts 2>/dev/null || true
```

Run: `swift build && swift build --traits Blossom`
Expected: both succeed (assets are processed into the module bundle regardless of trait; the colorsets are present but not yet referenced by code).

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Resources/Resources.xcassets/blossom-brand Sources/CoreDesign/Resources/Resources.xcassets/blossom-canvas
git commit -m "Add Blossom coral-pink brand and canvas colorsets"
```

---

## Task 3: Test that Blossom assets are present, then wire ColorGrade brand ramp

Asset presence is testable in *any* trait mode (the colorsets always ship), so we TDD it here. Then we branch `ColorGrade`.

**Files:**
- Modify: `Tests/CoreDesignTests/CoreDesignTests.swift`
- Modify: `Sources/CoreDesign/Colors/ColorGrade.swift:11-23` (the `brand` extension)

- [ ] **Step 1: Write the failing test for asset presence**

Replace the contents of `Tests/CoreDesignTests/CoreDesignTests.swift` with:

```swift
import Testing
import SwiftUI
@testable import CoreDesign

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Resolves a named color from the module bundle to the platform color type,
/// returning nil if the asset is missing. Trait-independent: the asset ships
/// regardless of which trait is enabled.
private func moduleColorExists(_ name: String) -> Bool {
    #if canImport(UIKit)
    return UIColor(named: name, in: .module, compatibleWith: nil) != nil
    #elseif canImport(AppKit)
    return NSColor(named: name, bundle: .module) != nil
    #else
    return false
    #endif
}

@Suite("Blossom assets")
struct BlossomAssetTests {
    @Test("all blossom-brand colorsets are present")
    func brandColorsetsPresent() {
        for i in 0...9 {
            #expect(moduleColorExists("blossom-brand-\(i)"), "missing blossom-brand-\(i)")
        }
    }

    @Test("all blossom-canvas colorsets are present")
    func canvasColorsetsPresent() {
        for name in ["blossom-canvas-default", "blossom-canvas-subtle", "blossom-canvas-inset"] {
            #expect(moduleColorExists(name), "missing \(name)")
        }
    }
}
```

- [ ] **Step 2: Run the test to confirm it passes (assets exist from Task 2)**

Run: `swift test --filter BlossomAssetTests`
Expected: PASS — both tests green. (This is a guard test; it confirms Task 2 shipped the assets correctly. If it fails, the colorsets are misnamed or missing.)

- [ ] **Step 3: Branch the brand ramp in ColorGrade**

In `Sources/CoreDesign/Colors/ColorGrade.swift`, replace the `brand` extension (currently lines 11-23) with a `#if Blossom` branch. Both branches list all ten:

```swift
/// brand
#if Blossom
public extension Color {
    static let brand0 = Color("blossom-brand-0", bundle: .module)
    static let brand1 = Color("blossom-brand-1", bundle: .module)
    static let brand2 = Color("blossom-brand-2", bundle: .module)
    static let brand3 = Color("blossom-brand-3", bundle: .module)
    static let brand4 = Color("blossom-brand-4", bundle: .module)
    static let brand5 = Color("blossom-brand-5", bundle: .module)
    static let brand6 = Color("blossom-brand-6", bundle: .module)
    static let brand7 = Color("blossom-brand-7", bundle: .module)
    static let brand8 = Color("blossom-brand-8", bundle: .module)
    static let brand9 = Color("blossom-brand-9", bundle: .module)
}
#else
public extension Color {
    static let brand0 = Color("brand-0", bundle: .module)
    static let brand1 = Color("brand-1", bundle: .module)
    static let brand2 = Color("brand-2", bundle: .module)
    static let brand3 = Color("brand-3", bundle: .module)
    static let brand4 = Color("brand-4", bundle: .module)
    static let brand5 = Color("brand-5", bundle: .module)
    static let brand6 = Color("brand-6", bundle: .module)
    static let brand7 = Color("brand-7", bundle: .module)
    static let brand8 = Color("brand-8", bundle: .module)
    static let brand9 = Color("brand-9", bundle: .module)
}
#endif
```

Leave the other 16 hue families (amber, blue, …) below it untouched.

- [ ] **Step 4: Verify both build modes compile**

Run: `swift build && swift build --traits Blossom`
Expected: both succeed.

- [ ] **Step 5: Verify default tests + Blossom tests pass**

Run: `swift test && swift test --traits Blossom`
Expected: both runs PASS (asset-presence tests are trait-independent and stay green either way).

- [ ] **Step 6: Commit**

```bash
git add Tests/CoreDesignTests/CoreDesignTests.swift Sources/CoreDesign/Colors/ColorGrade.swift
git commit -m "Swap brand ramp to Blossom colorsets under #if Blossom"
```

---

## Task 4: Branch the canvas surfaces in SurfaceColors

`surfaceCanvas` / `surfaceCanvasSubtle` / `surfaceCanvasInset` are the three computed properties that load `canvas-*` assets directly. The dependent surfaces (`surfacePanel`, `surfaceSidebar`, `surfaceCard`) reference these three, so they inherit automatically and need no change.

**Files:**
- Modify: `Sources/CoreDesign/Colors/SurfaceColors.swift:49-67` (the three `surfaceCanvas*` computed vars)

- [ ] **Step 1: Branch the three canvas tokens**

In `Sources/CoreDesign/Colors/SurfaceColors.swift`, replace the three computed properties `surfaceCanvas`, `surfaceCanvasSubtle`, `surfaceCanvasInset` (keep their existing doc comments above each) so each returns the Blossom colorset under the trait. The bodies become:

```swift
    static var surfaceCanvas: Color {
        #if Blossom
        Color("blossom-canvas-default", bundle: .module)
        #else
        Color("canvas-default", bundle: .module)
        #endif
    }
```

```swift
    static var surfaceCanvasSubtle: Color {
        #if Blossom
        Color("blossom-canvas-subtle", bundle: .module)
        #else
        Color("canvas-subtle", bundle: .module)
        #endif
    }
```

```swift
    static var surfaceCanvasInset: Color {
        #if Blossom
        Color("blossom-canvas-inset", bundle: .module)
        #else
        Color("canvas-inset", bundle: .module)
        #endif
    }
```

Do **not** touch `surfacePanel`, `surfaceSidebar`, `surfaceCard` — they delegate to the above and inherit the swap.

- [ ] **Step 2: Verify both build modes compile**

Run: `swift build && swift build --traits Blossom`
Expected: both succeed.

- [ ] **Step 3: Verify tests pass in both modes**

Run: `swift test && swift test --traits Blossom`
Expected: both PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/CoreDesign/Colors/SurfaceColors.swift
git commit -m "Swap canvas surfaces to Blossom warm-pink under #if Blossom"
```

---

## Task 5: Repoint secondary aliases to violet under Blossom

In Blossom, the second accent becomes candy violet (matching the 暖悦 ovulation/AI purple). Two files hold the secondary aliases. `accent`/`primary` already point at `brand5` and inherit the coral swap from Task 3, so they need no change.

**Files:**
- Modify: `Sources/CoreDesign/Colors/FunctionalColor.swift:17-20` (the `secondary*` group)
- Modify: `Sources/CoreDesign/Colors/InteractionColors.swift:10-13` (the `secondaryAccent*` group)

- [ ] **Step 1: Branch the `secondary*` group in FunctionalColor**

In `Sources/CoreDesign/Colors/FunctionalColor.swift`, replace these four lines:

```swift
    static let secondary: Color = .lightBlue5
    static let secondaryActive: Color = .lightBlue7
    static let secondaryDisable: Color = .lightBlue2
    static let secondaryHover: Color = .lightBlue6
```

with:

```swift
    #if Blossom
    static let secondary: Color = .violet5
    static let secondaryActive: Color = .violet7
    static let secondaryDisable: Color = .violet2
    static let secondaryHover: Color = .violet6
    #else
    static let secondary: Color = .lightBlue5
    static let secondaryActive: Color = .lightBlue7
    static let secondaryDisable: Color = .lightBlue2
    static let secondaryHover: Color = .lightBlue6
    #endif
```

- [ ] **Step 2: Branch the `secondaryAccent*` group in InteractionColors**

In `Sources/CoreDesign/Colors/InteractionColors.swift`, replace these four lines:

```swift
    static let secondaryAccent = Color.lightBlue5
    static let secondaryAccentHover = Color.lightBlue6
    static let secondaryAccentPressed = Color.lightBlue7
    static let secondaryAccentDisabled = Color.lightBlue2
```

with:

```swift
    #if Blossom
    static let secondaryAccent = Color.violet5
    static let secondaryAccentHover = Color.violet6
    static let secondaryAccentPressed = Color.violet7
    static let secondaryAccentDisabled = Color.violet2
    #else
    static let secondaryAccent = Color.lightBlue5
    static let secondaryAccentHover = Color.lightBlue6
    static let secondaryAccentPressed = Color.lightBlue7
    static let secondaryAccentDisabled = Color.lightBlue2
    #endif
```

- [ ] **Step 3: Verify both build modes compile**

Run: `swift build && swift build --traits Blossom`
Expected: both succeed (`violet0…9` already exist in `ColorGrade.swift`).

- [ ] **Step 4: Verify tests pass in both modes**

Run: `swift test && swift test --traits Blossom`
Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CoreDesign/Colors/FunctionalColor.swift Sources/CoreDesign/Colors/InteractionColors.swift
git commit -m "Repoint secondary accent to violet under #if Blossom"
```

---

## Task 6: Add the CoreGradient token layer

A new public `CoreGradient` enum exposes three `AnyShapeStyle` tokens. Under Blossom they are real gradients; otherwise they degrade to the matching flat color so the default look is unchanged and callers can always use `.background(CoreGradient.canvas)` / `.fill(CoreGradient.cta)`.

**Files:**
- Create: `Sources/CoreDesign/Colors/CoreGradient.swift`
- Modify: `Tests/CoreDesignTests/CoreDesignTests.swift` (add a suite)

- [ ] **Step 1: Write the failing test referencing the tokens**

Append this suite to `Tests/CoreDesignTests/CoreDesignTests.swift` (after the existing `BlossomAssetTests`):

```swift
@Suite("CoreGradient tokens")
struct CoreGradientTests {
    // AnyShapeStyle is a non-optional value type; the meaningful coverage here is
    // that all three public tokens exist and compile in whichever trait mode the
    // test run uses. Constructing them must not trap.
    @Test("all gradient tokens are constructible")
    func tokensConstructible() {
        _ = CoreGradient.brand
        _ = CoreGradient.cta
        _ = CoreGradient.canvas
        #expect(Bool(true))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails to compile**

Run: `swift test --filter CoreGradientTests`
Expected: FAIL — compile error "cannot find 'CoreGradient' in scope".

- [ ] **Step 3: Create the CoreGradient file**

Create `Sources/CoreDesign/Colors/CoreGradient.swift`:

```swift
//
//  CoreGradient.swift
//  CoreDesign
//

import SwiftUI

// MARK: - Gradient Tokens / 渐变 token
//
// 暖悦风格的灵魂在渐变。本层以 `AnyShapeStyle` 统一返回类型，使纯色与渐变可
// 互换：调用方写 `.background(CoreGradient.canvas)` / `.fill(CoreGradient.cta)`
// 在两种主题下都成立。
//
// - Blossom trait 开启时：返回真实多色 `LinearGradient`。
// - 默认主题：退化为对应纯色，现有观感零变化。

public enum CoreGradient {

    /// 品牌渐变 / brand gradient.
    /// Blossom: 珊瑚粉 → 玫红。默认：纯 `Color.accent`。
    public static var brand: AnyShapeStyle {
        #if Blossom
        AnyShapeStyle(
            LinearGradient(
                colors: [.brand4, .brand6],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        #else
        AnyShapeStyle(Color.accent)
        #endif
    }

    /// 主操作按钮渐变 / primary CTA gradient.
    /// Blossom: 亮珊瑚 → 玫红（#FF8FB0 → #FF6F8E 区间，取自 brand 色阶）。默认：纯 `Color.accent`。
    public static var cta: AnyShapeStyle {
        #if Blossom
        AnyShapeStyle(
            LinearGradient(
                colors: [.brand3, .brand5],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        #else
        AnyShapeStyle(Color.accent)
        #endif
    }

    /// 页面画布渐变 / page canvas gradient.
    /// Blossom: 粉 → 薰衣草紫 → 青 三色柔和渐变。默认：纯 `Color.surfaceCanvas`。
    public static var canvas: AnyShapeStyle {
        #if Blossom
        AnyShapeStyle(
            LinearGradient(
                colors: [.brand1, .violet2, .cyan1],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        #else
        AnyShapeStyle(Color.surfaceCanvas)
        #endif
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter CoreGradientTests`
Expected: PASS.

- [ ] **Step 5: Verify both build modes compile and all tests pass**

Run: `swift build && swift build --traits Blossom && swift test && swift test --traits Blossom`
Expected: all four succeed.

- [ ] **Step 6: Commit**

```bash
git add Sources/CoreDesign/Colors/CoreGradient.swift Tests/CoreDesignTests/CoreDesignTests.swift
git commit -m "Add CoreGradient token layer (real gradients under Blossom)"
```

---

## Task 7: Add a Blossom visual smoke Preview

Per repo convention, `#Preview` blocks are the primary visual smoke check and live alongside components. Add a self-contained preview file that exercises coral brand, violet secondary, and the three gradients so a developer can eyeball Blossom in Xcode (select the `Blossom` trait in the scheme, or it shows the default flat fallback otherwise).

**Files:**
- Create: `Sources/CoreDesign/Colors/CoreGradient+Preview.swift`

- [ ] **Step 1: Create the preview file**

Create `Sources/CoreDesign/Colors/CoreGradient+Preview.swift`:

```swift
//
//  CoreGradient+Preview.swift
//  CoreDesign
//

import SwiftUI

// 视觉冒烟预览 / visual smoke check.
// 在 Xcode 中开启 Blossom trait 可见珊瑚粉 + 紫 + 渐变；默认主题下渐变退化为纯色。
#Preview("Theme Smoke") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accent / Secondary")
                .font(.headline)
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12).fill(Color.accent).frame(height: 56)
                RoundedRectangle(cornerRadius: 12).fill(Color.secondary).frame(height: 56)
            }

            Text("Gradients")
                .font(.headline)
            RoundedRectangle(cornerRadius: 12).fill(CoreGradient.brand).frame(height: 56)
            RoundedRectangle(cornerRadius: 12).fill(CoreGradient.cta).frame(height: 56)
            RoundedRectangle(cornerRadius: 20).fill(CoreGradient.canvas).frame(height: 120)
        }
        .padding()
    }
    .background(CoreGradient.canvas)
}
```

- [ ] **Step 2: Verify both build modes compile**

Run: `swift build && swift build --traits Blossom`
Expected: both succeed. (`#Preview` compiles into the module; it is not run by `swift test`.)

- [ ] **Step 3: Commit**

```bash
git add Sources/CoreDesign/Colors/CoreGradient+Preview.swift
git commit -m "Add Blossom theme visual smoke Preview"
```

---

## Task 8: Document the theme system in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (architecture section — add after the "分层色彩系统" section)

- [ ] **Step 1: Add a "主题系统 (Package Traits)" subsection**

In `CLAUDE.md`, locate the end of the `### 分层色彩系统` section (just before the next `###` heading). Insert this new section:

```markdown
### 主题系统（Package Traits）

CoreDesign 通过 SwiftPM **Package Trait** 在编译期切换风格方案，调用方"导入即主题"，组件代码零改动。

- `Package.swift` 声明 trait：默认 `.default(enabledTraits: [])`（= Craft 蓝色主题，零变化）；当前唯一非默认 trait 是 `Blossom`（暖悦风格 · 珊瑚粉糖果渐变女性向）。
- 调用方启用：`.package(url: "...", traits: ["Blossom"])`，或在 Xcode package 依赖的 trait 勾选 UI 中开启。
- 源码内用 `#if Blossom` 直接分流（trait 名可直接作为编译条件，无需 local trait 映射）。
- **分流点压到最低**：只有资源层 `ColorGrade.brand0…9`、`SurfaceColors` 的三个 `surfaceCanvas*`、以及 `secondary` / `secondaryAccent` 两组语义别名带 `#if Blossom`。`accent` / `primary` 指向 `brand5` 自动继承；状态色 (`StatusColors`) 不分流，保持标准语义色。
- Blossom 色板由 `Resources.xcassets/blossom-brand/*`、`blossom-canvas/*` 提供（light/dark 双值）。
- 两种构建模式都需保持绿：`swift build` / `swift test`（默认）与 `swift build --traits Blossom` / `swift test --traits Blossom`（Blossom）。Swift Testing 无法在单次运行内同时覆盖两套 trait，Blossom 分支靠 `--traits Blossom` 单独跑覆盖。

### 渐变 token 层（CoreGradient）

`Colors/CoreGradient.swift` 暴露 `CoreGradient.brand / cta / canvas`，类型为 `AnyShapeStyle`，使纯色与渐变可互换。Blossom 下为真实 `LinearGradient`，默认主题退化为对应纯色（`Color.accent` / `Color.surfaceCanvas`），现有观感零变化。组件可统一写 `.background(CoreGradient.canvas)` / `.fill(CoreGradient.cta)`。
```

- [ ] **Step 2: Verify the doc reads correctly**

Run: `grep -n "主题系统（Package Traits）\|渐变 token 层（CoreGradient）" CLAUDE.md`
Expected: both headings found.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "Document Blossom trait theme system and CoreGradient layer"
```

---

## Task 9: Final dual-mode verification

A single end-to-end gate over both trait modes before handoff.

- [ ] **Step 1: Clean build + test, default mode**

Run: `swift build && swift test`
Expected: build succeeds; all tests PASS (BlossomAssetTests, CoreGradientTests, example).

- [ ] **Step 2: Clean build + test, Blossom mode**

Run: `swift build --traits Blossom && swift test --traits Blossom`
Expected: build succeeds; all tests PASS.

- [ ] **Step 3: Confirm zero default-mode regression in the diff**

Run: `git diff main...HEAD -- Sources/CoreDesign/Colors/ColorGrade.swift Sources/CoreDesign/Colors/SurfaceColors.swift Sources/CoreDesign/Colors/FunctionalColor.swift Sources/CoreDesign/Colors/InteractionColors.swift`
Expected: every change is inside a `#if Blossom` / `#else` / `#endif` block; the `#else` branches are byte-identical to the original code (i.e. the default path is unchanged).

- [ ] **Step 4 (optional): Capture a Blossom preview screenshot**

If the user wants visual confirmation, open the package in Xcode, enable the `Blossom` trait, and view the `Theme Smoke` preview in `CoreGradient+Preview.swift`. This is a manual eyeball check, not an automated step.

---

## Self-Review (completed by plan author)

**Spec coverage:**
- §2 trait mechanism → Task 1 ✔
- §3 brand palette → Task 2 (assets) + Task 3 (wiring) ✔
- §3 canvas → Task 2 + Task 4 ✔
- §3 secondary→violet → Task 5 ✔
- §3 + §4.3 gradient layer → Task 6 ✔
- §5 colorset resources → Task 2 ✔
- §6 verification (dual-mode build/test, Swift Testing cases, Preview) → Tasks 3/6 (tests), Task 7 (Preview), Task 9 (dual-mode gate) ✔
- §7 file list → all files covered across tasks ✔ (status colors correctly left untouched per §1 non-goals)
- §7 CLAUDE.md → Task 8 ✔

**Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". Colorset generation uses an explicit inline value table (every hex specified), not a placeholder.

**Type consistency:** `CoreGradient.brand/cta/canvas : AnyShapeStyle` defined in Task 6, referenced identically in Tasks 6/7. `moduleColorExists(_:)` helper defined once in Task 3, reused conceptually only there. Colorset names (`blossom-brand-N`, `blossom-canvas-{default,subtle,inset}`) consistent between Task 2 (creation), Task 3/4 (loading), and Task 3 (asset test).

**Note on a spec simplification:** the spec text suggested changing `ColorGrade.brand0…9` from `static let` to computed `static var`. The plan keeps them as `static let` and wraps the whole block in one `#if Blossom`/`#else` — `#if` works around `static let` initializers, so this is simpler, greppable, and equally correct. No behavior difference.
