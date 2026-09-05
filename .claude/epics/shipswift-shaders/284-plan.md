---
name: B-4 切片 —— CoreDesignShaders 画廊接线
issue: 284（本计划只交付其 5 件交付物中的「预览宿主」一件）
created: 2026-09-06
---

# 范围

**只接画廊条目。** #284 另外 4 件（署名 / probe / 文档索引 / 性能基准）不在本次范围。

**不合 main。** epic 分支落后 main 46 个 commit，试合产生 76 个冲突文件（main 已合入
整个 Effects + Charts epic，与本分支同步过去的那份撞了）。那是 epic 集成的活，与
「能在真机上点开看 shader」正交。已实测本分支独立 `swift build` + 真机架构宿主构建全绿。

# 事实基线（本次实测）

- `App/project.yml` 已有第 4 条 `product: CoreDesignShaders`，但
  `App/Sources/ComponentData.swift` **没有对应的 `import CoreDesignShaders`**
  —— 正是该文件顶部注释警告的 `#245` 成对失效形态（product 链上、import 漏掉）。
- 公开面 9 个：6 个 `public struct: View`（`DotGrid` / `FractalClouds` / `GlassSymbol` /
  `InkSmoke` / `LiquidChrome` / `Plasma`）+ 3 个 `public extension View` modifier
  （`refractiveGlass` / `glassOrb` / `halftone`）。
- `docs/component-registry.json` 里 9 个**全部已登记**（6 components + 3 entryPoints，
  #279 / #283 做的）⇒ 本次不动登记表。
- 画廊列表行是纯文本（`ComponentRow` 只渲染 name + id），`preview()` 只在
  `ComponentDetail` 渲染。⚠️ 但 `ComponentDetail` **同屏渲染两份**（Light + Dark
  各一份，`ComponentDetail.swift:47` 与 `:70`）并包在 `ScrollView` 里
  ⇒ modifier 族每页有 2×3 = 6 条 `layerEffect` 通道，不是本计划初稿写的「不同屏」。

# 步骤

1. `ComponentData.swift` 加 `import CoreDesignShaders`（与 `project.yml` 的第 4 条 `product:` 配对）。
2. `ComponentCategory` 加 `case shader = "Shader"`。`ContentView` 按 `allCases` 分节，自动出新分区。
3. 新增 `static let shaderEntries: [ComponentMeta]`，`all` 末尾 `+ Self.shaderEntries`。
   **不动 `shipSwiftEntries`**——那一节的注释明令「追加自己的分节，不要重排本节」。
   独立数组的理由与 `shipSwiftEntries` 同：避免 `all` 字面量类型检查退化。
4. 写 9 条条目。3 个 modifier 需要被作用的内容层，各配一个最小宿主视图。
5. **不**补 `App/Sources/Previews.swift` 的宿主 `#Preview`——与 `shipSwiftEntries`
   同一条理由：动效的静止帧收进 `docs/snapshots` 只是噪声，判据在 `SnapshotArtifactGuard`。

# 验证

| 判据 | 命令 |
|---|---|
| 包编译 | `swift build` |
| 树内判据 | `swift test --skip CoreDesignShadersTests`（CI native 腿的真实调用）。`GuardScanRoots.allRoots` 只映射 `Sources/<target>` ⇒ `App/` 不在任何守卫扫描面 |
| 真机架构 | `xcodebuild -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` |
| **metallib 能在 App 语境加载** | 装 Simulator 跑起来，逐个点开 9 条截图 |

⚠️ 最后一条是本次的**承重验证**：`ShaderLibrary.bundle(.module)` 在库自己的测试里能解析，
不等于在预览宿主 App 里能解析——资源 bundle 的嵌入路径不同。构建绿 + 运行时黑屏
是这条的典型失效形态，只有真跑起来看渲染图才排得掉。
