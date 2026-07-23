# Plan: Issue #118 删除 Blossom trait 与 CoreGradient

## 范围
1. `Package.swift`：删除 `traits:` 声明整块。
2. Sources 内 8 处 `#if Blossom` 分流：
   - `Colors/ColorGrade.swift:12`（brand 色阶 Blossom/默认双分支）→ 只保留默认分支。
   - `Colors/InteractionColors.swift:10`（secondaryAccent 系列）→ 只保留默认分支。
   - `Colors/SurfaceColors.swift:50/62/74`（surfaceCanvas 三个 var）→ 只保留默认分支。
   - `Tokens/CoreGradient.swift:22/38/54` → 整个文件删除（含 `CoreGradient+Preview.swift`）。
3. 资源：删除 `Resources.xcassets/blossom-brand/`、`blossom-canvas/` 两个目录。
4. 测试：
   - 删除 `Tests/CoreDesignTests/BlossomColorDivergenceTests.swift` 整个文件。
   - `Tests/CoreDesignTests/CoreDesignTests.swift`：删除 `BlossomAssetTests` suite 与其专属 helper
     （`xcassetsURL`/`colorsetExists`），删除 `CoreGradientTests` suite（含 `#if Blossom` 渐变退化断言）。
5. `CommentCard.swift`：唯一的 `CoreGradient` 生产消费点。默认主题下 `CoreGradient.brand ==
   AnyShapeStyle(Color.accent)`，改为直接 `.foregroundStyle(Color.accent)`，同步更新注释（该组件
   本身在 Issue #117 里会被整体删除，此处只保证本分支独立可编译）。
6. CI `.github/workflows/ci.yml`：
   - `swiftpm` job：删 `matrix: mode: [default, blossom]`，Build/Test 步骤的 if/else 骨架收敛为单一
     `swift build` / `swift test`。
   - `simulator` job：删 `-skip-testing:CoreDesignTests/BlossomAssetTests` 及其说明注释段落（保留
     ToastHostTests 相关的第 2 条说明）。
   - `downstream-probe` job：删注释里提及 Blossom trait 探针场景的部分。
7. `App/project.yml`：删 `traits: ["Blossom"]` 行与其上方注释；用 `xcodegen generate` 重新生成
   `App/CoreDesignPreview.xcodeproj`。
8. 顺带清理：`Colors/BorderColors.swift:43/48` 两处注释提到"随 Blossom trait 自动继承"/"Blossom 下
   跟随珊瑚粉"，Blossom 移除后陈述失实，做小幅措辞更新（不改变代码行为）。

## 不在范围内
- `StatusRow.swift:41` 注释是对 Issue #93 历史 bug 的说明（引用了当时 `.secondary` 会解析到的两种
  trait 下的别名），保留作历史记录，不强改。
- `CommentCard` 组件本体的存废由 Issue #117 处理，这里只做最小引用修复。

## 验证
- `swift build`
- `swift test`（基线 95 tests，减去 `BlossomAssetTests`(3) + `CoreGradientTests`(1) + 
  `BlossomColorDivergenceTests`(1) = 5 个 test，预期 90 tests 全绿，0 failure）
- `grep -rn "#if Blossom" Sources Tests App` → 0 行
- `grep -rn "CoreGradient" Sources Tests App` → 0 行
- `xcodegen generate` 在 `App/` 下重新生成 pbxproj，确认无残留 `Blossom` trait 引用
