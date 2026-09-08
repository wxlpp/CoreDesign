# SegmentedControl

Token 化的分段控件 / Token-styled segmented control.

## API

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| items | [Item] | - | 选项数据源，Item 需 Hashable |
| selection | Binding<Item> | - | 当前选中项的双向绑定 |
| title | (Item) -> String | - | 选项到显示文字的映射 |

支持 `View.segmentedControlStyle(_:)` 注入外观，内置**三个** style，各有静态入口：

| 入口 | style | 外观 |
|---|---|---|
| `.glass`（默认） | `GlassSegmentedControlStyle` | Liquid Glass 外壳；iOS 走原生 `UISegmentedControl` + `UIGlassEffect` |
| `.plain` | `PlainSegmentedControlStyle` | 纯色外壳 |
| `.ink` | `InkSegmentedControlStyle` | 选中段是实心 `coreAccent` 胶囊 + 反色文字 |

⚠️ **`.ink` 不是默认**：web 版设计系统用墨色胶囊是因为浏览器渲染不了 Liquid Glass，
那是渲染基座的代偿而非升级。⚠️ `.ink` 走 SwiftUI 回退路径，**不走** iOS 的原生控件
——后者选中态只有 `selectedSegmentTintColor` 一个入口，塞不进「实心填充 + 反色文字」。
⚠️ 三个静态入口与三个 style 的 `public init()` 都标了 `nonisolated`（本包开了
`.defaultIsolation(MainActor.self)`，只加在 static 上编译不过）。

## 预览 / Preview

运行 `scripts/run-snapshots.sh`（默认模式）后，预览图落地 `docs/snapshots/`——但前提是该组件已在 `App/Sources/Previews.swift` 注册（导出文件名形如 `CoreDesignPreview_<组件名>.png`）；组件源码内自带的 `#Preview` 仅用于开发期本地预览，或经 `KEEP_LIBRARY_SNAPSHOTS=1 scripts/run-snapshots.sh` 导出到本地 scratch 目录做逐组件视觉核对（不写入 docs/snapshots，见 `.claude/epics/semi-mobile-components/phase0-decisions.md` §3）。

## 使用示例 / Usage

```swift
@State private var selection = "A"

SegmentedControl(
    items: ["A", "B", "C"],
    selection: $selection,
    title: { $0 }
)
```

## 视觉 Token

⚠️⚠️ **本节必须分两条路读** —— `SegmentedControl` 在 iOS 的**默认样式下根本不是 SwiftUI 画的**：
`GlassSegmentedControlStyle`（默认）在 `#if os(iOS)` 下走 `NativeGlassSegmentedControl`
= UIKit `UISegmentedControl` + `UIGlassEffect`。下面这些 token **只对 SwiftUI 那条路成立**。

| | iOS 默认（`GlassSegmentedControlStyle`） | SwiftUI 回退（`PlainSegmentedControlStyle` 全平台；`Glass` 在非 iOS） |
|---|---|---|
| 实现 | UIKit `UISegmentedControl` + `UIGlassEffect` | `SwiftUISegmentedControl` |
| 外框形状 | `glassView.cornerConfiguration = .capsule()`（`:320`，设的是**外框** `UIVisualEffectView`） | `Capsule(style: .continuous)` |
| thumb 形状 | `UISegmentedControl` 自带的选中指示器，**本仓从未配置** | `Capsule(style: .continuous)` |
| thumb 填充 | `selectedSegmentTintColor` = `.label` 8%（浅）/ 15%（深） | `Color.surfaceCanvasSubtle` |
| 外框填充 | 玻璃 | `Capsule` 填 `Color.surfaceInteractive` + `borderSubtle` hairline |
| segment 间距 | 无（a11y 实测三段连续：30 → 144 → 258 pt，宽 114） | `CoreSpacing.xxs`（实测有 2 pt 缝：142.67 → 144.67） |
| 字号 | `systemFont(ofSize: 15)` 经 `UIFontMetrics(.body)` | `.coreFont(.callout)` |
| 切换动画 | UIKit 自己的 | `.easeInOut(duration: 0.18)` + `matchedGeometryEffect` |
| thumb 与轨道的明暗 | thumb **更暗**（浅色实测 231 vs 251） | thumb **更亮**（浅色实测 255 vs 228） |

⚠️ **本节此前的四条与源码不符**，`#233` 顺带更正（逐条对着
`Sources/CoreDesign/Components/SegmentedControl/SegmentedControl.swift` 核过）：
外框背景写的是 `surfaceMuted`（实为 `surfaceInteractive`，`:430`）、thumb 写的是
`surfaceRaised`（实为 `surfaceCanvasSubtle`，`:158`）、两处圆角写的是 `CoreRadius.medium` /
`.small`（**实为 `Capsule`，不走 `CoreRadius`**，`:115` / `:152`）、字号写的是
`CoreTypography.bodyMediumFont`（实为 `.coreFont(.callout)`，`:134`）。
⚠️ **第三条不只是换个名字**：那四条一起读会让人以为 thumb 是个圆角矩形，而它是胶囊。

其余（两条路都成立）：选中文字 `Color.contentPrimary` + `.semibold`、非选中
`Color.contentSecondary` + `.regular`（`contentPrimary` / `contentSecondary` 与原生用的
`UIColor.label` / `.secondaryLabel` 同源）；外框 padding `CoreSpacing.xxs`；
高度 `CoreControlMetrics.height(for: .regular)`；触感 `.sensoryFeedback(.selection)`。

## thumb 滑动的运行期证据（`#233`，2026-09-07 实测）

`#115` 把 thumb 滑动列为「视觉复核」项，`#225` 视觉终审如实记为**「无法用现有手段证实」**
——光栅快照证不了动画在动。`#233` 就是那个缺口。

**担心的失效形态**：`matchedGeometryEffect` 跨 `AnyView`（`SegmentedControl.body` 末尾
`return AnyView(self.style.makeBody(configuration:))`）+ `@Namespace` 边界时可能**退化成
snap** —— thumb 在旧位置消失、在新位置出现，中间没有任何一帧。

⚠️⚠️ **这条担心只对 SwiftUI 那条路成立**。第一版录的是画廊默认那个 demo，
而它在 iOS 上是**原生 `UISegmentedControl`**，那条路径里**根本没有 `matchedGeometryEffect`**
——录到的滑动是 UIKit 的，**对 `#233` 没有证据力**。⇒ 画廊已加一个显式注入
`.segmentedControlStyle(PlainSegmentedControlStyle())` 的第二个 demo，本节的结论录自它。

**结论 ✅ SwiftUI 那条路的 thumb 真的在滑，不是 snap。**

器材：iPhone 17 Pro / iOS 26.4 模拟器 + 预览宿主，`scripts/motion-proof/extract-frames.swift`
逐样本解码，`scripts/motion-proof/measure-thumb.py` 做模板相关。

**几何**（从 a11y 树量的，**不是猜的**）：plain 那条的三个 segment 是 `Button`，
x = 30 / 144.67 / 259.33 pt、宽 112.67 pt ⇒ @3x 中心 **259 / 603 / 947 px**、thumb 宽 **338 px**。
⚠️ 原生那条是 `RadioButton`、x = 30 / 144 / 258 pt、宽 114 pt（thumb 342 px）——**两条路的
几何不同**，第一版拿原生的数去解释 plain 的轨迹，是错的。

录「从 `One` 点到 `Three`」，31 帧**全表**（不是手选子集）：

| 帧 | s000 | s001 | s002–s008 | s009–s010 | s011 | s012 | s013 | s014–s030 |
|---|---|---|---|---|---|---|---|---|
| thumb 中心 x | **257** ⚠️钳 | 559 | 668 | 746 | 819 | 908 | 940 | **949** ⚠️钳 |

横向行程 692 px，**中间位置 11 帧 / 4 个不同位置**：`[559, 668, 746, 819]`（脚本直接打印，非手抄）。

⚠️ **两端那两个数（257 / 949）是「窗口被钳在裁剪区边界」的值，不是 thumb 真实中心**
——thumb 停在控件最左 / 最右时，滑窗必然顶到裁剪边界。⇒ **行程 692 = 裁剪宽 − thumb 宽**，
是个结构常数，**不承重**。承重的是中间那 4 个不同位置：它们都没被钳，
且 559 / 668 / 746 跨在中间那个 segment 的中心（603）两侧。
⚠️ **「11 帧」被录屏过采样抬高**（s002–s008 七个样本挤在 13 ms 内、同在 668）
⇒ 判 snap-vs-slide 靠的是**4 个不同位置**，不是 11。

snap 的形态会是 257 → 949 之间一帧不落。
⚠️ **交叉淡变也会被本判据报成 snap**（合成实测中心一帧不落地跳过去）——本判据只保证
**不把淡变误读成滑动**，不保证能识别出淡变。

**对照：iOS 默认那条（原生 `UISegmentedControl`）也在滑** —— 同一套判据、同一次会话另录：
行程 688 px、中间位置 **9 帧 / 6 个不同位置**（390 / 478 / 541 / 835 / 836 / 843）。
⚠️ 这一行的位置列表**由脚本直接打印**，不再手抄——上一版手抄成
「279 / 329 / 390 / 478 / 541 / 836」，其中 279 / 329 落在 15% 边缘带外、**根本没被计入**，
而 835 / 843 漏了。文档刚强调「承重的是不同位置」，列出来的却不是被计的那组。
⇒ 两条路都不 snap，但**只有上面那条与 `#233` 的担心有关**。

<details>
<summary>复现步骤</summary>

```bash
SIMULATOR_ID=<udid> ./scripts/run-preview.sh
# 画廊 Form 段点开 SegmentedControl；详情页浅色那块有两个控件：
#   上 = GlassSegmentedControlStyle（iOS 默认 = 原生），下 = PlainSegmentedControlStyle
xcrun simctl io <udid> recordVideo --codec h264 --force /tmp/seg.mov &
#  ↑ 录制期间点一次 plain 那个控件的「Three」（本机是 x=315 y=459 pt），2–3 s 后 kill -INT

swiftc -O scripts/motion-proof/extract-frames.swift -o /tmp/xf
/tmp/xf /tmp/seg.mov /tmp/frames
python3 scripts/motion-proof/measure-thumb.py '/tmp/frames/*.png' \
    --y0 1330 --y1 1425 --x0 88 --x1 1118 --width 338      # 需要 numpy + Pillow
```

⚠️ 那四个窗口参数**绑死在 iPhone 17 Pro @3x 上这个画廊布局**：`--y0/--y1` 是 plain 控件的
纵向带（原生那个在 `--y0 1060 --y1 1140`），`--x0/--x1` 是控件横向范围，`--width` 是 thumb 宽。
换机型 / 换布局都要重量一遍（用 `axe describe-ui` 读 segment 的 frame）。
⚠️ 裁剪**不要放宽到整屏**：实测 `--x0 0 --x1 1206` 会让极性判不开（亮 16.5 vs 暗 12.4），
脚本会中止——那是 fail-closed 在起作用，不是 bug。

</details>

### 这条判据判不了什么

1. **判不了时长**：`easeInOut` 尾巴很长，末段每帧只挪 1 px，拿它对 `duration: 0.18` 的账会得到不稳的数。
2. **不是 CI 判据**：人工录屏 + 逐帧测量，不在任何腿上。与 `#277` 同族。
3. **单次、单向（One→Three）、仅浅色**。
4. **「0 个中间位置 = snap」的前提是采样间隔远小于动画时长**（本次 2–30 ms vs 180 ms）；
   低帧率录屏或 Reduce Motion 下会假阳性。
5. **「未观察到切换」与 snap 已分开判**，但**极性选错不会被 `score` 阈值挡下**
   ——实测反向极性 score 9.5–11.3（阈值 4.0 的 2.5 倍），会给出一条像模像样的假轨迹。
   防线是脚本的胜负比门槛（胜者 ≥ 1.5× 败者，否则中止）与那行打印，**看到打印再往下读**。
6. **`--width` 与裁剪宽的比例敏感**：实测 `--width 900`（裁剪宽 1026）产出**假 snap**、
   `--width 600` 产出方向反转的轨迹。脚本现在直接拒绝 `width > 裁剪宽/2` 并逐帧标「钳」，
   但**窗口本身选错仍需人看**。
7. **只在模拟器上录过，没上真机。**
8. **「中心挪了」≠「平移」**：合成实测，一个「从 A 拉长到覆盖 A..B 再收缩到 B」的伸缩式过渡
   会被读成滑动（中间 5 帧）。对 `#233` 无害（那条路要么滑要么 snap），但别外推。
9. **`GlassSegmentedControlStyle` 在非 iOS 上的 SwiftUI 玻璃回退未录**（`glass: true` 那条）。
10. **暗色几乎量不到**：暗色 plain 控件的 auto 分数只有 **4.8**（阈值 4.0），
    暗色录制大概率成片「量不到」。
