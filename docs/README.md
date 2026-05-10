# CoreDesign 组件库 / Component Library

iOS 26+ / macOS 26+ SwiftUI 设计系统，含 16 个 Primer 对齐组件。

## 组件索引 / Component Index

### Button 按钮

| 组件 | 预览 | 文档 |
|---|---|---|
| Button | [<img src="snapshots/CoreDesignPreview_Previews.swift_Button_Light.png" width="200" alt="Button">](components/button.md) | [button.md](components/button.md) |

### Form 表单

| 组件 | 预览 | 文档 |
|---|---|---|
| SegmentedControl | [<img src="snapshots/CoreDesignPreview_Previews.swift_SegmentedControl_Light.png" width="200" alt="SegmentedControl">](components/segmented-control.md) | [segmented-control.md](components/segmented-control.md) |
| SearchField | [<img src="snapshots/CoreDesignPreview_Previews.swift_SearchField_Light.png" width="200" alt="SearchField">](components/search-field.md) | [search-field.md](components/search-field.md) |
| BottomInputBar | — | [bottom-input-bar.md](components/bottom-input-bar.md) |
| CheckBox | — | [checkbox.md](components/checkbox.md) |
| LabelIcon / ChevronRightIcon / DangerIcon | [<img src="snapshots/CoreDesignPreview_Previews.swift_Form%20Icons_Light.png" width="200" alt="Form Icons">](components/form-icons.md) | [form-icons.md](components/form-icons.md) |

### Indicator 指示器

| 组件 | 预览 | 文档 |
|---|---|---|
| Badge | [<img src="snapshots/CoreDesignPreview_Previews.swift_Badge_Light.png" width="200" alt="Badge">](components/badge.md) | [badge.md](components/badge.md) |
| Tag | [<img src="snapshots/CoreDesignPreview_Previews.swift_Tag_Light.png" width="200" alt="Tag">](components/tag.md) | [tag.md](components/tag.md) |
| Banner | [<img src="snapshots/CoreDesignPreview_Previews.swift_Banner_Light.png" width="200" alt="Banner">](components/banner.md) | [banner.md](components/banner.md) |

### Layout 布局

| 组件 | 预览 | 文档 |
|---|---|---|
| Avatar | [<img src="snapshots/CoreDesignPreview_Previews.swift_Avatar_Light.png" width="200" alt="Avatar">](components/avatar.md) | [avatar.md](components/avatar.md) |
| BookCover | [<img src="snapshots/CoreDesignPreview_Previews.swift_BookCover_Light.png" width="200" alt="BookCover">](components/book-cover.md) | [book-cover.md](components/book-cover.md) |
| EmptyState | [<img src="snapshots/CoreDesignPreview_Previews.swift_EmptyState_Light.png" width="200" alt="EmptyState">](components/empty-state.md) | [empty-state.md](components/empty-state.md) |
| ListRow | [<img src="snapshots/CoreDesignPreview_Previews.swift_ListRow_Light.png" width="200" alt="ListRow">](components/list-row.md) | [list-row.md](components/list-row.md) |

### Navigation 导航

| 组件 | 预览 | 文档 |
|---|---|---|
| SidebarRow | [<img src="snapshots/CoreDesignPreview_Previews.swift_SidebarRow_Light.png" width="200" alt="SidebarRow">](components/sidebar-row.md) | [sidebar-row.md](components/sidebar-row.md) |
| UnderlinedTabBar | [<img src="snapshots/CoreDesignPreview_Previews.swift_UnderlinedTabBar_Light.png" width="200" alt="UnderlinedTabBar">](components/underlined-tab-bar.md) | [underlined-tab-bar.md](components/underlined-tab-bar.md) |

### Feedback 反馈

| 组件 | 预览 | 文档 |
|---|---|---|
| Toast | — | [toast.md](components/toast.md) |

## 生成预览图 / Generating Snapshots

运行 `scripts/run-snapshots.sh` 生成所有已收录 `#Preview` 宏的组件 PNG 预览图，输出到 `docs/snapshots/`。生成的 PNG 不检入版本库，须本地运行脚本后才能看到缩略图。

Run `scripts/run-snapshots.sh` to generate preview PNGs for all components with `#Preview` macros, output to `docs/snapshots/`. PNGs are not checked in — run the script locally to populate thumbnails.

## 运行演示应用 / Running the Preview App

运行 `scripts/run-preview.sh` 在模拟器中构建并启动 CoreDesignPreview 应用。

Run `scripts/run-preview.sh` to build and launch the CoreDesignPreview app in the Simulator.
