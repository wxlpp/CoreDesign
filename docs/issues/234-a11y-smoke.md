# a11y 运行期冒烟记录

承接 [#234](https://github.com/wxlpp/CoreDesign/issues/234)（`#99` 列的 VoiceOver 运行时冒烟）。

**日期**：2026-09-07 · **器材**：iPhone 17 Pro / iOS 26.4 模拟器，预览宿主
（`scripts/run-preview.sh`）· **工具**：`axe describe-ui`（AXe 1.7.1）

## ⚠️⚠️ 先说这份记录**不是**什么

**它不是 VoiceOver 冒烟。VoiceOver 在 iOS 模拟器上起不来。**

实测过的路子（全部无效，登记免得下一个人重走）：

```bash
xcrun simctl spawn <udid> defaults write com.apple.Accessibility ApplicationAccessibilityEnabled -int 1
xcrun simctl spawn <udid> defaults write com.apple.Accessibility VoiceOverTouchEnabled -int 1
xcrun simctl spawn <udid> defaults write com.apple.Accessibility VoiceOverTouchCaptionPanelEnabled -int 1
xcrun simctl spawn <udid> launchctl kickstart -k system/com.apple.SpringBoard
```

`defaults read com.apple.Accessibility` 确认三个键都写进去了（`VoiceOverTouchEnabled = 1`），
respring 后重启 App **仍然没有 VoiceOver 光标、没有字幕面板**。

⚠️ **这不是「试出来的经验」，是设计如此**：iOS Simulator 本就不带 VoiceOver。

⚠️⚠️ **Apple 官方的那条替代路本记录没走**：**Accessibility Inspector 可以直接以 Simulator
为目标**，它能读 Label / Value / **Traits**，还能 Speak。它正好补上下面三个盲区
（状态型 trait、`Rating` 的 `nan`、朗读）。**没走的原因只是它不可脚本化**，不是它不行
——⇒ 下面「剩下的缺口」里凡写「需要真 VoiceOver」的，都应先试 Accessibility Inspector
——**手势那条除外**（三指滚动 / 双击激活 / 可调元素上下滑，Inspector 做不到）。

本记录走的是 `axe describe-ui`——它读的是**与 VoiceOver 同一棵 AX 树**，但只给出**一个投影**
（16 个字段，见下表），不是那棵树的全部。

### 这个替代覆盖什么、不覆盖什么

| | 覆盖 | 依据 |
|---|---|---|
| `accessibilityLabel` | ✅ | `AXLabel` |
| `accessibilityValue` | ✅ | `AXValue` |
| 元素角色（heading / switch / text field / tab / slider / button） | ✅ | `role_description` |
| `accessibilityHint` | ✅ | `help` |
| 自定义动作 | ✅ | `custom_actions` |
| 启用 / 禁用 | ✅ | `enabled` |
| **角色型 trait**（`.isHeader` / `.isButton` / adjustable） | ✅ | 经 `role` / `role_description` 透出。实测：`[heading] label='NOTIFICATIONS'` 来自 `SectionHeader.swift:27` 的 `.accessibilityAddTraits(.isHeader)`；`[button] label='Menu'` 来自 `CoreMenuButton.swift:143` 的 `.accessibilityAddTraits(.isButton)`（它不是 `Button`）；`[slider]` 来自 `.accessibilityAdjustableAction` |
| **状态型 trait**（`.isSelected` / `.updatesFrequently`） | ❌ | AXe 的 JSON **没有 traits 字段**（实测字段全集 16 个：`AXFrame` `AXLabel` `AXUniqueId` `AXValue` `children` `content_required` `custom_actions` `enabled` `frame` `help` `pid` `role` `role_description` `subrole` `title` `type`） |

⚠️ **这个二分要限定射程**（第 2 轮 S-3）：更准的说法是「AXe 只透出被投影到
`role` / `role_description` / `AXValue` / `enabled` 的语义」。两面反例：
`.disabled` 产生的状态**能**看到（`enabled=false`）；而**既非角色也非状态**的 trait
（`.allowsDirectInteraction` / `.causesPageTurn` / `.isModal` 等）两行都不覆盖——本仓没用到，
所以上表只对**本仓用到的 trait** 成立。
⚠️ **最好的例证是 `Radio.swift:82` 与 `Carousel.swift:115`**：它们一次调用里传
`[.isButton, .isSelected]` ⇒ **同一次调用一半可见、一半不可见**。
| **朗读顺序 / 分组 / 转子** | ❌ | 需要真 VoiceOver |
| **实际读出的语音** | ❌ | 同上 |

⚠️ **状态型 trait 那一格有个反例陷阱**：`UnderlinedTabBar` 的 tab 在树里是光秃秃的
`[button] label='Tab 1'`，看着像「没有选中态」。实测点了 Tab 2 再 dump，树里**除约 1.3 pt 的
宽度变化外无任何差异**（Tab 1 63→61.67、Tab 2 64→65.33）。

**但不能据此判缺陷**：源码 `UnderlinedTabBar.swift` 里逐字写着
`.accessibilityAddTraits(self.isSelected ? .isSelected : [])`。
⚠️ **也不能据此判「没缺陷」**——源码只证明**声明**存在，不证明它落进了 AX 树。
本方法对这一层**两个方向都判不了**。
**最强的对照就在同一个组件上** ⚠️（**这一对取自 `issue-233-thumb-slide-proof` 构建的预览宿主**
——`main` 的画廊里 `SegmentedControl` 只有默认 style 一个控件，
`grep PlainSegmentedControlStyle App/` 零命中。要在 `main` 上复现，需给第二个
`SegmentedControl` 加 `.segmentedControlStyle(PlainSegmentedControlStyle())`）：
`SegmentedControl` 默认的 `GlassSegmentedControlStyle`
在 iOS 走原生 `UISegmentedControl`，树里是 `[tab] label='One' value=1`——选中态经 `AXValue`
透出来了，那是**系统控件自带的语义**；而同一组件的 `PlainSegmentedControlStyle`
（走 SwiftUI + `SegmentedControl.swift:147` 的 `.isSelected`）dump 出来是光秃秃的
`[button] label='One'`、**无 value** ⇒ 与 `UnderlinedTabBar` 同一个盲区。
**同一组件、两种 style，一种透出一种不透出。**

⚠️ **同形态还有六处**，本记录一律判不了：`PinCode.swift:106`（文档下面那段 PinCode dump
同样看不到当前格的 `.isSelected`）、`SegmentedControl.swift:147`、`Sidebar.swift:109`、
`BottomInputBar.swift:151`、`Radio.swift:82`、`Carousel.swift:115`。

**可用的证实手段**（本次都没走，登记）：Accessibility Inspector 以 Simulator 为目标
（直接显示 `Button, Selected`）；或加一个 UI test target 用 `XCUIElement.isSelected`
（`App/project.yml` 目前只有 `bundle.unit-test` 的 `SnapshotTests`）。
⚠️ **走不通的那条也登记**：拿 macOS `AXUIElement` 遍历 `Simulator.app` 的窗口
——iOS 的内容**不在那棵树里**（实测 433 个元素、0 命中）。

## 覆盖面

`#234` 点名的三处：`BottomInputBar` · `UnderlinedTabBar` · Form（按画廊的 `Form`
分类 + `Settings Screen` 这个 form 形状的容器取样）。

## 结论 1 ⚠️ catalog 那条路径，这次冒烟**给不出增量证据**

`#222` 把三处 a11y 串改成经 `String(localized:bundle:.module)` 加载，`#234` 要求覆盖这条
读出路径。**本记录的第一版声称覆盖到了，那是错的。**

第一版的推理是：`SearchField` 读出 `[button] label='Clear Search'`，键是 `"Clear %@"`
⇒ 插值执行了 ⇒ catalog 命中；「格式化失败的形态会是字面量 `Clear %@`」。

⚠️⚠️ **那句话实测为假**：`String(localized:)` 在键**未命中**时**同样对回退串做插值**。
探针（一个没有任何 strings 表的 CLI）：

```swift
String(localized: "Clear \(target)", bundle: .main)   // ⇒ "Clear Search"
String(localized: "\(42) of \(5)", bundle: .main)      // ⇒ "42 of 5"
```

而本仓的表是 `Sources/CoreDesign/Resources/en.lproj/Localizable.strings`，
`"Clear %@" = "Clear %@";`，且**只有 `en.lproj` 一个目录** ⇒ 表里**每一个键**都是
「值 = 键 + 唯一语言」，**命中与回退在运行期逐字相同、不可区分**。
第一版说「`"Search"` 这类键判不出来、能判的是带插值的那条」——**前半句对，后半句错**：
判不出来的是**整张表**。

⚠️ 顺带更正 `#234` 正文的一个前提：它写「catalog 加载失败的失败形态是读出键名」。
对本仓不准——`bundle: .module` 找不到资源 bundle 时是 **`fatalError`**，不是回退键名。

### 那这次冒烟到底证明了什么

只证明这两件**弱得多**的事：

1. **运行期 `.module` 可解析**（否则首次访问资源即 `fatalError`）；
2. **`#222` 的四个字面量里，本次运行期只碰到了 `"Clear %@"` 一条**，它的读出路径出现在树里。

```
SearchField 详情页
  [text field] label='Search'         value='filter results'
  [button]     label='Clear Search'      ← 只有这一条走了 String(localized:)
```

⚠️⚠️ **`[text field] label='Search'` 不是 catalog 的 `"Search"` 键**（第 2 轮 I-1）：
画廊是 `SearchField(text: self.$text)`（`App/Sources/ComponentData.swift:418`），
吃的是 init 的**默认参数** `placeholder: String = "Search"`（`SearchField.swift:18`，
**普通字面量**）。`SearchField.swift:40` 那条 `String(localized: "Search", bundle: .module)`
**只在 `placeholder.isEmpty` 时才走**，画廊没触发。
内层的 `"search"`（`:91`）同理没触发——`Clear Search` 里那个大写 `Search` 是**调用方传的值**。
⇒ `#222` 那**四个字面量**里，`"Search"` 与内层 `"search"` 两个**本次都没碰到**（`"%@ complete"` 属 `ProgressBar`，画廊无条目）。

⚠️ **`PinCode` 那组与 `#222` 无关**：`"Verification code"` / `"%@ of %@"` 是 Phase 0 键，
不在 `#222` 的射程里。它出现在树里只能作 `.module` 可解析的**旁证**：

```
PinCode 详情页
  [button] label='Verification code' value='1 of 6, 1'
  [button] label='Verification code' value='2 of 6, 2'
```

**「键真的注册进了 catalog」那一层由单测证明，不由本记录证明**：
`ProgressBarL10nTests.newKeysExistInCatalog`（`Tests/CoreDesignTests/ProgressBarTests.swift`）
用 `__MISSING__` 哨兵调 `Bundle.module.localizedString(forKey:value:table:)`
——**那个 `value:` 哨兵正是区分命中与回退的唯一办法**，运行期读出的字符串做不到。

⚠️ **`ProgressBar` 的 `"%@ complete"` 这条读出路径本次没冒到**：该组件已弃用、画廊里没有条目。
它的字符串由上面那条单测覆盖（`#235` 在 PR #329 里另加了逐 locale 断言，⚠️ 那条 PR **尚未合入**）。

## 结论 2 ✅ 三处目标的树形态

**`BottomInputBar`**（`#221` 提为 public 后画廊可交互）：

```
[switch]     label='模拟运行中（发送按钮变停止）' value='0'
[button]     label='换一批'   （内含 [image] label='Refresh'）
[button]     label='Menu'
[Group]      value='说点什么'
[button]     label='Suggestions'
```

⚠️ **两处措辞值得后续考虑**（不是本次的判定，登记）：
`[button] label='Menu'` 是输入框左侧那个「魔杖」按钮，读出来只有「Menu」、不说它做什么；
输入框本身是 `[Group] value='说点什么'`，**没有 label**，读出来只有占位文案。

**`UnderlinedTabBar`**：三个 `[button] label='Tab N'`，选中态见上文 traits 那条说明。

**Form / `Settings Screen`**（`InsetGroupedSection` + `SettingsRow` 复刻的设置页）：

```
[text]    label='Airplane Mode'
[switch]  label='Airplane Mode' value='0'
[heading] label='NOTIFICATIONS'
[switch]  label='Notifications'  value='1'
[heading] label='ABOUT'
[text]    label='Version' / [text] label='0.4.0'
```

分组标题走 `[heading]` ✅（VoiceOver 的标题转子能用），开关 label + value 齐全 ✅。

## 结论 3 ⚠️ `Rating` 的可调元素，`AXValue` 投影里不是字符串而是 `nan`

```
Rating 详情页
  [slider] label='Rating' value='nan'    @(133, 329)   ← Rating(value: $value /* 3.5 */, step: 0.5)
  []       label='Rating' value='4 of 5' @(133, 381)  DISABLED
                                                        ← Rating(value: .constant(4)).disabled(true)

RatingDisplay 详情页（只读）
  [] label='Rating' value='4 of 5'
  [] label='Rating' value='3.5 of 5'
```

⚠️⚠️ **本记录第一版把这两行读成「同一个元素分裂出的伴生元素」——那是对画廊的误读。**
`App/Sources/ComponentData.swift` 的 `RatingPreview` 里有**两个** `Rating` 实例：
`Rating(value: self.$value /* 3.5 */, step: 0.5)` 与 `Rating(value: .constant(4)).disabled(true)`。
两行的 **frame 不同、值也不同（4 ≠ 3.5）** ⇒ `DISABLED` 那行就是第二个实例。没有分裂，没有伴生。

**真实的观察**：启用态那个可调 `Rating`，它的 `accessibilityValue` 字符串（应为 `3.5 of 5`）
**不在 AXe 的 `AXValue` 投影里**，那一格是 `nan`。

⚠️ **措辞刻意收窄成「不在投影里」而不是「完全不存在」**（第 2 轮 I-3）：
AXe 的 `AXValue` 是**一个字段投影**，不是整棵 AX 树——文档自己在射程表里就承认它不给 traits。

| | adjustable action | `enabled` | `role` | `AXValue` |
|---|---|---|---|---|
| `Rating(value: $value /* 3.5 */, step: 0.5)` | 挂 | true | `slider` | **`nan`** |
| `Rating(value: .constant(4)).disabled(true)` | 不挂 | **false** | 泛型元素 | `4 of 5` ✅ |
| `RatingDisplay(value: 4)` / `(3.5)` | 不挂 | true | 泛型元素 | `4 of 5` / `3.5 of 5` ✅ |

⚠️ **这不是「单变量对照」**（第 2 轮 I-2，第一版如此写、与自己上一段「值也不同」直接冲突）：
`.disabled(true)` 相对启用态**改了四样**——不挂 `RatingAdjustableModifier`（`Rating.swift:188-197`）、
`isEnabled` 走进 `.gesture(isEnabled:)`、AX `enabled` 变 `false`、值 4 vs 3.5 / step 1 vs 0.5。
**要三行合看，逐个混杂各由哪一对打破**：

- **`enabled` 这个混杂**由第 2 行 vs 第 3 行打破 —— `RatingDisplay` 是**启用**的、不挂 action、有字符串值；
- **类型混杂**由第 1 行 vs 第 2 行打破 —— 同为 `Rating`；
- **值的混杂表里没打破**，另做了一次：把启用态那个 `Rating` 拖到 **5.0**（截图确认五颗满星），
  `AXValue` **仍是 `nan`**。

⇒ 三条合起来，**`nan` 与「挂了 adjustable action」共变**，其余三个变量各自被打破。

⚠️ **仍然不裁决。** 已排除的：
- **不是** `Rating.accessibilityValueText` 产生的 —— `Double.nan.formatted()` 是 `NaN` 不是 `nan`；
- **不是**「AXe 对一切 slider 一律填 `nan`」—— 同一份树里
  `[slider] label='Vertical scroll bar, 1 page' value='0%'` 有字符串值。

**还没排除的（三条）**：
1. SwiftUI 把 adjustable 元素桥成 AX slider 时**丢掉了字符串 value**；
2. ⚠️ **字符串 value 可能仍在，只是 AXe 对 slider 优先读了某个数值属性**
   ——`nan` 恰好是 Swift/C 对 `Double.nan` 的默认描述（探针：`"\(Double.nan)"` ⇒ `nan`、
   `String(format: "%f", .nan)` ⇒ `nan`），与「AXe 侧把 NaN 插值进字符串」高度吻合。
   上面第一条排除项只排除了**我们这边**产生 `nan`，没排除 AXe 那边。
3. **VoiceOver 实际会读什么。**

⇒ 先试 **Accessibility Inspector**（可直接以 Simulator 为目标，能读 Traits 也能 Speak）。

⇒ **不改代码**，已开 [#332](https://github.com/wxlpp/CoreDesign/issues/332) 承接。
⚠️ `docs/components/rating.md` 的 Accessibility 一节写着「半星精确播报…如『2.5 of 5』」
——**那句在启用态上未经证实**，已就地加指针。

## 剩下的缺口（本记录关不掉的）

1. **实际朗读**（语音、顺序、分组、转子、hint 是否被念）—— 需要 VoiceOver；
   ⚠️ **先试 Accessibility Inspector**（可直接以 Simulator 为目标，能 Speak），再谈真机。
2. **状态型 traits** —— AXe 的树不给。`.isSelected` **七处**（`UnderlinedTabBar:128` / `PinCode:106` /
   `SegmentedControl:147` / `Sidebar:109` / `BottomInputBar:151` / `Radio:82` / `Carousel:115`）
   加 `.updatesFrequently` 一处（`SpinningModifier.swift:128`）＝ **八处**。
   可用手段：Accessibility Inspector / UI test 里的 `XCUIElement.isSelected`。
   ⚠️ **走不通的那条也登记**：拿 macOS `AXUIElement` 遍历 `Simulator.app` 窗口读不到 iOS 内容。
3. **手势交互**（三指滚动、双击激活、可调元素的上下滑）—— 需要真 VoiceOver。

⇒ **第 1–3 条已开 [#334](https://github.com/wxlpp/CoreDesign/issues/334) 承接**
（用 Accessibility Inspector 以 Simulator 为目标补 traits + Speak）。第 4 条由单测覆盖，
第 5 条随 `ProgressBar` 弃用一并消失。
4. **catalog 命中 vs 回退**——本仓表里值 = 键、且只有 `en.lproj` ⇒ **运行期读出的字符串
   永远区分不了**（结论 1）。只能由带哨兵的单测覆盖，冒烟关不掉。
5. `ProgressBar` 的 `"%@ complete"` 读出路径（组件已弃用、画廊无条目）。
