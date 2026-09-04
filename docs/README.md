# CoreDesign 组件库 / Component Library

iOS 26+ / macOS 26+ SwiftUI 设计系统，含 35 个 Apple HIG 对齐组件（其中 `ProgressBar` 自 `0.6.0` 起弃用）+ 3 个系统控件 `.core` style + 1 个加载遮罩 modifier（`View.spinning(_:text:)`）。

自 `#245` 起本包有**三个 product**：主 target `CoreDesign`（下面的组件索引）、
表达性视觉层 `CoreDesignEffects`、图表层 `CoreDesignCharts`。
后两者的 40 个 API 单位索引在文末的
[动效与图表索引 / Effects & Charts Index](#动效与图表索引--effects--charts-index)。

> 新增或改造组件前先读 [`component-contract.md`](component-contract.md)——
> 判定法、样式扩展点、配置开关的替代路径。

## 组件索引 / Component Index

### Button 按钮

| 组件 | 预览 | 文档 |
|---|---|---|
| Button | [<img src="snapshots/CoreDesignPreview_Previews.swift_Button.png" width="200">](components/button.md) | [button.md](components/button.md) |
| FloatButton（ExtendedFloatButtonStyle / CircularGlassButtonStyle） | [<img src="snapshots/CoreDesignPreview_Previews.swift_Float_Button.png" width="200">](components/float-button.md) | [float-button.md](components/float-button.md) |

### Form 表单

| 组件 | 预览 | 文档 |
|---|---|---|
| SegmentedControl | [<img src="snapshots/CoreDesignPreview_Previews.swift_SegmentedControl.png" width="200">](components/segmented-control.md) | [segmented-control.md](components/segmented-control.md) |
| SearchField | [<img src="snapshots/CoreDesignPreview_Previews.swift_SearchField.png" width="200">](components/search-field.md) | [search-field.md](components/search-field.md) |
| BottomInputBar | [<img src="snapshots/CoreDesignPreview_Previews.swift_BottomInputBar.png" width="200">](components/bottom-input-bar.md) | [bottom-input-bar.md](components/bottom-input-bar.md) |
| LabelIcon / ChevronRightIcon / DangerIcon | [<img src="snapshots/CoreDesignPreview_Previews.swift_Form_Icons.png" width="200">](components/form-icons.md) | [form-icons.md](components/form-icons.md) |
| `.core` Control Styles（ProgressView / Label / DisclosureGroup）| [<img src="snapshots/CoreDesignPreview_Previews.swift_Core_Control_Styles.png" width="200">](components/core-control-styles.md) | [core-control-styles.md](components/core-control-styles.md) |
| Rating | [<img src="snapshots/CoreDesignPreview_Previews.swift_Rating.png" width="200">](components/rating.md) | [rating.md](components/rating.md) |
| RatingDisplay | [<img src="snapshots/CoreDesignPreview_Previews.swift_RatingDisplay.png" width="200">](components/rating-display.md) | [rating-display.md](components/rating-display.md) |
| PinCode | [<img src="snapshots/CoreDesignPreview_Previews.swift_PinCode.png" width="200">](components/pin-code.md) | [pin-code.md](components/pin-code.md) |
| RadioGroup / RadioOption | [<img src="snapshots/CoreDesignPreview_Previews.swift_Radio_Group.png" width="200">](components/radio.md) | [radio.md](components/radio.md) |
| TagInput | [<img src="snapshots/CoreDesignPreview_Previews.swift_TagInput.png" width="200">](components/tag-input.md) | [tag-input.md](components/tag-input.md) |
| ~~Typography~~ | _未实现，parity 已由 `.coreFont(_:)` + 原生 `Text` modifier 达成_ | [typography.md](components/typography.md)（墓碑 + 迁移指引） |

### Indicator 指示器

| 组件 | 预览 | 文档 |
|---|---|---|
| Badge | [<img src="snapshots/CoreDesignPreview_Previews.swift_Badge.png" width="200">](components/badge.md) | [badge.md](components/badge.md) |
| Tag | [<img src="snapshots/CoreDesignPreview_Previews.swift_Tag.png" width="200">](components/tag.md) | [tag.md](components/tag.md) |
| Banner | [<img src="snapshots/CoreDesignPreview_Previews.swift_Banner.png" width="200">](components/banner.md) | [banner.md](components/banner.md) |
| StateLabel | [<img src="snapshots/CoreDesignPreview_Previews.swift_StateLabel.png" width="200">](components/state-label.md) | [state-label.md](components/state-label.md) |
| ProgressIndicator（含 `text:` 文案 init） | [<img src="snapshots/CoreDesignPreview_Previews.swift_ProgressIndicator.png" width="200">](components/progress-indicator.md) | [progress-indicator.md](components/progress-indicator.md) |
| ~~ProgressBar~~（`0.6.0` 起弃用） | _改用 `ProgressView().progressViewStyle(.core)`_ | [progress-bar.md](components/progress-bar.md)（弃用 + 迁移指引） |
| Skeleton（SkeletonLine / SkeletonRect / SkeletonCircle） | [<img src="snapshots/CoreDesignPreview_Previews.swift_Skeleton.png" width="200">](components/skeleton.md) | [skeleton.md](components/skeleton.md) |
| Steps | [<img src="snapshots/CoreDesignPreview_Previews.swift_Steps.png" width="200">](components/steps.md) | [steps.md](components/steps.md) |
| Timeline | [<img src="snapshots/CoreDesignPreview_Previews.swift_Timeline.png" width="200">](components/timeline.md) | [timeline.md](components/timeline.md) |

### Layout 布局

| 组件 | 预览 | 文档 |
|---|---|---|
| Avatar | [<img src="snapshots/CoreDesignPreview_Previews.swift_Avatar.png" width="200">](components/avatar.md) | [avatar.md](components/avatar.md) |
| AvatarGroup | [<img src="snapshots/CoreDesignPreview_Previews.swift_AvatarGroup.png" width="200">](components/avatar-group.md) | [avatar-group.md](components/avatar-group.md) |
| ListRow | [<img src="snapshots/CoreDesignPreview_Previews.swift_ListRow.png" width="200">](components/list-row.md) | [list-row.md](components/list-row.md) |
| FlowLayout | [<img src="snapshots/CoreDesignPreview_Previews.swift_FlowLayout.png" width="200">](components/flow-layout.md) | [flow-layout.md](components/flow-layout.md) |
| Carousel | [<img src="snapshots/CoreDesignPreview_Previews.swift_Carousel.png" width="200">](components/carousel.md) | [carousel.md](components/carousel.md) |

### Container 容器（Phase 2 · `0.4.0`）

| 组件 | 预览 | 文档 |
|---|---|---|
| Card | [<img src="snapshots/CoreDesignPreview_Previews.swift_Card.png" width="200">](components/card.md) | [card.md](components/card.md) |
| Separator | [<img src="snapshots/CoreDesignPreview_Previews.swift_Separator.png" width="200">](components/separator.md) | [separator.md](components/separator.md) |
| SectionHeader / SectionFooter | [<img src="snapshots/CoreDesignPreview_Previews.swift_Section_Header_Footer.png" width="200">](components/section-header-footer.md) | [section-header-footer.md](components/section-header-footer.md) |
| InsetGroupedSection | [<img src="snapshots/CoreDesignPreview_Previews.swift_InsetGroupedSection.png" width="200">](components/inset-grouped-section.md) | [inset-grouped-section.md](components/inset-grouped-section.md) |
| SettingsRow | [<img src="snapshots/CoreDesignPreview_Previews.swift_SettingsRow.png" width="200">](components/settings-row.md) | [settings-row.md](components/settings-row.md) |
| Descriptions | [<img src="snapshots/CoreDesignPreview_Previews.swift_Descriptions.png" width="200">](components/descriptions.md) | [descriptions.md](components/descriptions.md) |

### Navigation 导航

| 组件 | 预览 | 文档 |
|---|---|---|
| Sidebar | [<img src="snapshots/CoreDesignPreview_Previews.swift_Sidebar.png" width="200">](components/sidebar.md) | [sidebar.md](components/sidebar.md) |
| UnderlinedTabBar | [<img src="snapshots/CoreDesignPreview_Previews.swift_UnderlinedTabBar.png" width="200">](components/underlined-tab-bar.md) | [underlined-tab-bar.md](components/underlined-tab-bar.md) |

### Feedback 反馈

| 组件 | 预览 | 文档 |
|---|---|---|
| Toast | [<img src="snapshots/CoreDesignPreview_Previews.swift_Toast.png" width="200">](components/toast.md) | [toast.md](components/toast.md) |
| ~~EmptyState~~ | _已于 #97 移除 — 改用 SwiftUI [`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview)_ | [empty-state.md](components/empty-state.md)（墓碑 + 迁移指引） |
| spinning（`View.spinning(_:text:)` modifier） | [<img src="snapshots/CoreDesignPreview_Previews.swift_Spinning.png" width="200">](components/spinning.md) | [spinning.md](components/spinning.md) |

## 生成预览图 / Generating Snapshots

运行 `scripts/run-snapshots.sh` 重新生成所有已收录 `#Preview` 宏的组件 PNG 预览图，输出到 `docs/snapshots/`。

Run `scripts/run-snapshots.sh` to regenerate preview PNGs for all components with `#Preview` macros, output to `docs/snapshots/`.

## 动效与图表索引 / Effects & Charts Index

`CoreDesignEffects`（36 个）与 `CoreDesignCharts`（4 个）的 API 单位。由
`shipswift-effects` epic（#242）落地，逐单位说明见各自的 `components/*.md`。

> ⚠️ **落点说明（`#256`）**：本节**刻意不在上面的「## 组件索引」小节之内**，
> 与 AD-4《下游连锁三》写的「三个 target 全部进主索引」不同 —— **那条的前提没有兑现**。
> AD-4 那句话建立在「Charts 走路线 b（进 `component-registry.json` 的 `components` 数组）」
> 之上；而 `#255` 落地时**没有**扩 `ComponentRegistryGuard.coreDesignSources` 的扫描根，
> 登记表至今仍是 `coredesign` 47 条、扫描根仍是单根 `Sources/CoreDesign`。
> ⇒ 这 40 个单位**不是登记条目**，把它们写进「## 组件索引」会让
> `ComponentRegistryGuard.readmeIndexReconcilesWithRegistry` 当场判红
> （该判据要求该小节里每个候选名都能落进登记表 / styleImpls / 墓碑 / 排除等桶）。
> 而 `readmeIndexRows` 的解析范围恰好止于 `## 生成预览图`，本节在其之后 ⇒ 不进定义域。
> **要把本节并进主索引，前置动作是先把这两个 target 纳入登记表**（AD-4《下游连锁一》
> 列了那条链会顶动的一串断言），那是一次独立的裁决与批量改动，不在 `#256` 射程内。

> ⚠️ **本节没有预览图**：这 40 个单位的 `#Preview` 都住在库内源文件里，而提交态的快照
> 只收宿主 `App/Sources/Previews.swift` 驱动的产物（产地规则见
> `scripts/run-snapshots.sh` 与 `Tests/CoreDesignTests/SnapshotArtifactGuard.swift`）。
> 它们的评审面是**可交互的画廊**：`./scripts/run-preview.sh`，侧栏 `Effect` / `Chart` 两组。

### 微交互 / Micro-interactions（`import CoreDesignEffects`）

| 单位 | 入口 | 文档 |
|---|---|---|
| shake | `View.shake(trigger:strength:)` | [shake.md](components/shake.md) |
| jump | `View.jump(trigger:strength:)` | [jump.md](components/jump.md) |
| spin | `View.spin(trigger:direction:)` | [spin.md](components/spin.md) |
| ping | `View.ping(trigger:strength:color:)` | [ping.md](components/ping.md) |
| spray | `View.spray(trigger:symbol:strength:colors:)` | [spray.md](components/spray.md) |
| rise | `View.rise(trigger:text:strength:color:)` | [rise.md](components/rise.md) |
| haptic | `View.haptic(_:trigger:)` | [haptic.md](components/haptic.md) |
| shine | `View.shine(trigger:highlight:)` | [shine.md](components/shine.md) |

### 转场 / Transitions（16 种）

| 单位 | 入口 | 文档 |
|---|---|---|
| blur | `.transition(.blur)` / `.blur(radius:)` | [blur-transition.md](components/blur-transition.md) |
| filmExposure | `.transition(.filmExposure)` / `.filmExposure(intensity:)` | [film-exposure-transition.md](components/film-exposure-transition.md) |
| snapshot | `.transition(.snapshot)` / `.snapshot(intensity:)` | [snapshot-transition.md](components/snapshot-transition.md) |
| flicker | `.transition(.flicker)` / `.flicker(cycles:)` | [flicker-transition.md](components/flicker-transition.md) |
| flip | `.transition(.flip)` / `.flip(axis:)` | [flip-transition.md](components/flip-transition.md) |
| rotate3D | `.transition(.rotate3D)` / `.rotate3D(angle:axis:)` | [rotate3d-transition.md](components/rotate3d-transition.md) |
| swoosh | `.transition(.swoosh)` / `.swoosh(edge:travel:)` | [swoosh-transition.md](components/swoosh-transition.md) |
| boing | `.transition(.boing)` / `.boing(strength:)` | [boing-transition.md](components/boing-transition.md) |
| skid | `.transition(.skid)` / `.skid(edge:travel:)` | [skid-transition.md](components/skid-transition.md) |
| move（极坐标） | `.transition(.move)` / `.move(angle:distance:)` | [move-transition.md](components/move-transition.md) |
| iris / wipe / blinds / clock / glare / dissolve | `.transition(.iris)` … 六种各有无参与含参两个入口 | [mask-reveal-transitions.md](components/mask-reveal-transitions.md) |

> ⚠️ `.move` 与 SwiftUI 自带的 `.move(edge:)` 是**重载**而不是覆盖（本仓的类型叫
> `PolarMoveTransition`，不叫 `MoveTransition`）。这条契约由
> `scripts/downstream-probe/Sources/DownstreamProbe/TransitionClusterProbe.swift` 守，
> 库内守不住 —— 理由见该文件。
> 3D 与弹性那一簇（flip / rotate3D / swoosh / boing / skid / move）另有一份合并说明：
> [transition-cluster-3d-elastic.md](components/transition-cluster-3d-elastic.md)。
>
> ⚠️ **`particle` 按入口是转场，但它归在下面的「文本与展示」组里数**（PR #294 终审 S-4）。
> 上一版把它**同时**列进本表与「文本与展示」⇒ 本表标题写「16 种」而实际列了 17 个单位，
> 且与 `ACKNOWLEDGEMENTS.md`《逐单位归档》的分组（转场 16 / 文本与展示 4，
> `ParticleTransition` 在后者）对不上。而「36 + 4 = 40」这个算术在本 epic 里是承重的
> ——两处重复计一个单位会把 40 变成 41。⇒ 以归档表为准，本表只列 16 种。

### 庆祝与处理中 / Celebration & processing

| 单位 | 入口 | 文档 |
|---|---|---|
| Confetti | `View.confetti(trigger:strength:colors:)` | [confetti.md](components/confetti.md) |
| ScanningOverlay | `ScanningOverlay { }` | [scanning-overlay.md](components/scanning-overlay.md) |
| GlowSweep | `GlowSweep { }` | [glow-sweep.md](components/glow-sweep.md) |
| LightSweep | `LightSweep { }` | [light-sweep.md](components/light-sweep.md) |

### 文本与展示 / Text & display

| 单位 | 入口 | 文档 |
|---|---|---|
| TypewriterText | `TypewriterText(_:speed:)` / `TypewriterText(verbatim:speed:)` | [typewriter-text.md](components/typewriter-text.md) |
| AnimatedMeshGradient | `AnimatedMeshGradient(colors:alternateColors:)` | [animated-mesh-gradient.md](components/animated-mesh-gradient.md) |
| BeforeAfterSlider | `BeforeAfterSlider(labels:before:after:)` | [before-after-slider.md](components/before-after-slider.md) |
| ParticleTransition | `.transition(.particle)` / `.particle(count:colors:)` | [particle-transition.md](components/particle-transition.md) |

### 跨平台改造 / Cross-platform rewrites（AD-E）

| 单位 | 入口 | 文档 |
|---|---|---|
| OrbitingLogos | `OrbitingLogos(_:logo:center:)` | [orbiting-logos.md](components/orbiting-logos.md) |
| DotSphere | `DotSphere(count:colors:rotationPeriod:)` | [dot-sphere.md](components/dot-sphere.md) |
| CharSphere | `CharSphere(_:count:colors:rotationPeriod:)` | [char-sphere.md](components/char-sphere.md) |
| FullScreenButton | `FullScreenButton(destination:label:)` | [full-screen-button.md](components/full-screen-button.md) |

### 图表 / Charts（`import CoreDesignCharts`）

| 单位 | 入口 | 文档 |
|---|---|---|
| RadarChart | `RadarChart(_:title:tint:)` | [radar-chart.md](components/radar-chart.md) |
| RingChart | `RingChart(_:goal:title:tint:)` | [ring-chart.md](components/ring-chart.md) |
| ActivityHeatmap | `ActivityHeatmap(_:title:tint:calendar:)` | [activity-heatmap.md](components/activity-heatmap.md) |
| NetworkGraph | `NetworkGraph(nodes:edges:title:tint:)` | [network-graph.md](components/network-graph.md) |

## NFR-1 帧率基准 / Frame-rate benchmark

`./scripts/run-perf-benchmark.sh` 把 Confetti（默认粒子数）与 NetworkGraph（声明的节点 /
边上限）放进**真实运行的 App** 里，用 `CADisplayLink` 采样帧间隔并按「掉帧率 ≤ 5%」判定。
第一条腿是**对照组**（每帧主线程死等 40 ms），它必须被判为掉帧 —— 否则这把秤是坏的。

每条 `[perf]` 行带三样必须连带看的读数（PR #294 终审 C-1 / C-2 / I-1）：

- `bodyEvaluations=` / `drawnFrames=` —— 被测对象在窗口内**真的干了活**的次数。
  低于下限直接判红。⚠️ 它存在的理由是一次实测：上一版把 `.confetti(trigger:)` 删掉、
  把 NetworkGraph 宿主换成 `Color.clear`，同一个脚本**照样三条全 PASS**。
- `budget=` / `threshold=` —— **运行时实测**的帧预算与门槛（取 `CADisplayLink.duration`），
  不再写死 1/60。
- `graph-input: … uniqueUndirected=` —— NetworkGraph 那条腿真的喂进了 600 条**不重复的
  无向边**（`NetworkGraph` 按无向去重且先于一切进行；上一版的生成式在 mod 150 下
  实际只有 147 条唯一边）。输入退化会在开跑之前判红。

⚠️ **Simulator 上跑绿不构成 NFR-1 达标证据**（PRD 钉的是「iPhone 15 满帧」，
Simulator 没有真实 GPU 调度）。真机跑法见脚本头部注释。
⚠️ **截至 `#256` 合入，真机那一次尚未执行。**
⚠️ **本脚本不在任何 CI 腿里**（`App/` 整个不在 CI 里，见 `.github/workflows/ci.yml`）
—— 上面那类回归只能靠有人手跑它才会被发现。

## 运行演示应用 / Running the Preview App

运行 `scripts/run-preview.sh` 在模拟器中构建并启动 CoreDesignPreview 应用。

Run `scripts/run-preview.sh` to build and launch the CoreDesignPreview app in the Simulator.
