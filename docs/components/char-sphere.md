# CharSphere

自转的字球 / A slowly rotating sphere of glyphs.

`CharSphere`（`CoreDesignEffects/CharSphere.swift`，Issue #254）。

```swift
import CoreDesign
import CoreDesignEffects
```

⚠️ **两个 import 一个都不能少**：全仓 `@_exported` 为 0。

## API

```swift
public struct CharSphere: View {
    public static let defaultCount: Int              // 240
    public static let defaultRotationPeriod: Double  // 24（秒 / 圈）
    public init(_ characters: [String],
                count: Int = CharSphere.defaultCount,
                colors: [Color] = [],
                rotationPeriod: Double = CharSphere.defaultRotationPeriod)
}
```

```swift
CharSphere(["道", "德", "经"])
    .tint(.indigo)
    .frame(width: 280, height: 280)
```

## 平台支持

| 平台 | 行为 |
|---|---|
| iOS 26+ | 完整可用 |
| macOS 26+ | **完整可用，与 iOS 逐行同一份代码** |

理由与 `DotSphere` 逐字相同（两件共用 `SphereSurface` 这一份实现）：上游
`SWCharSphere` 的 `import UIKit` 只为把 `Color` 拆成分量做插值，改走
`Color.mix(with:by:)` 之后那个依赖消失；球面 Fibonacci 与透视投影是纯算术。
字形绘制走 `GraphicsContext.draw(_:at:)`，两端同一个 API。

⇒ macOS 上**不是"能编译但空转"**。判据：`PlatformSupportGuard.noPlatformOnlyImports`
+ `everyPlatformFenceHasAnElse`。

## 字表是**调用方的数据，不是本件的文案**（FR-7）

⚠️ `characters` **没有默认值**。上游的默认值是《道德经》第一章——那是一段**内容**决定，
与"给调用方一个好看的默认色板"是同一类越界（FR-8 已就色板立过规矩）。

- 字表为空 ⇒ **一个字都不画**（不回落到某个占位符号）；
- 类型是 `[String]` 而不是 `[LocalizedStringResource]`：公约 FR-7 的边界逐字——
  **调用方传入的数据文案是内容不是 UI 文案**，不强制本地化类型。

每个点位分到哪个字由**确定性散列**（Knuth 乘法散列）给出，不是 `Int.random`：
随机分配会让同一份输入每次渲染都不同 ⇒ 位图判据与 `run-snapshots.sh` 都拿它没办法。
也不用 `index % count`——那会让字表沿着 Vogel 螺旋整齐重复，肉眼能看出一圈圈的规律。

## 背面剔除是形态自带的，不是一个开关

上游有 `hidesBackFaces: Bool = true`。本仓不照搬这个 Bool（J-1 / AD-C）：
**字形必须剔除背面**（背面的字与正面的字叠在一起会糊成一团），**圆点不剔除**
（它们靠景深不透明度分层，剔掉背面会让球看起来像半个壳）。
⇒ 这条固化成 `SphereMark.cullsFarSide`，随形态走，不占参数面、不消耗 Bool 豁免预算。

## 取色 / Reduce Motion / 后台与低电量 / 退化输入 / a11y

与 `DotSphere` **共用同一份实现**，逐条见 [`dot-sphere.md`](dot-sphere.md)：
空色板 ⇒ 取 `.tint`；Reduce Motion ⇒ 冻结在某一帧（降级形态 2）；
`.inactive` / `.background` ⇒ 整层不建；低电量 ⇒ 降帧 + 字数减半；字球是纯装饰。

⚠️ 唯一的差别是**上限**：字形比圆点贵得多 ⇒ `count` 上限 **1000**（`DotSphere` 是 3000），
超出同样是截断而不是断言。

## ⚠️ 登记

同 `DotSphere`：不进 `components`（扫描根仍是单根 `Sources/CoreDesign`），
也没有扩展成员 ⇒ `entryPoints` 零改动。
