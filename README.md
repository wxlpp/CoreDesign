# OhMyDesign

iOS 26+ / macOS 26+ SwiftUI design system library, distributed as a Swift Package.

## Documentation

See the [Component Index](docs/README.md) for a reference of all 34 documented components plus 3 `.core` control styles and 1 loading-overlay modifier (`View.spinning(_:text:)`), organized by category.

## Quick Start

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/wxlpp/oh-my-design", from: "0.10.0"),
]
```

```swift
import OhMyDesign
import SwiftUI

Button("Press Me") {}
    .buttonStyle(.solidButton(role: .primary))
```

本包提供三个 library product，按需选取：

| product | 内容 | 状态 |
|---|---|---|
| `OhMyDesign` | 组件、四层色彩、token、modifier | 主体 |
| `OhMyDesignEffects` | 表达性视觉层（微交互 / 转场 / 动效） | **骨架**，组件由 epic `#242` 下的 `#250`–`#254` 落地 |
| `OhMyDesignCharts` | Swift Charts 原生画不出来的四类图表 | **骨架**，组件由 epic `#242` 下的 `#255` 落地 |

后两个依赖 `OhMyDesign`；`OhMyDesign` 不反向依赖它们，只 `import OhMyDesign` 不会把它们拖进来。

## Development

```bash
swift build          # Build the library
swift test           # Run tests
```

### Preview App

```bash
scripts/run-preview.sh     # Build and launch OhMyDesignPreview in Simulator
scripts/run-snapshots.sh   # Generate component snapshot PNGs
```

