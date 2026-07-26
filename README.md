# CoreDesign

iOS 26+ / macOS 26+ SwiftUI design system library, distributed as a Swift Package.

## Documentation

See the [Component Index](docs/README.md) for a reference of all 34 documented components plus 3 `.core` control styles and 1 loading-overlay modifier (`View.spinning(_:text:)`), organized by category.

## Quick Start

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/wxlpp/CoreDesign", from: "0.7.0"),
]
```

```swift
import CoreDesign
import SwiftUI

Button("Press Me") {}
    .buttonStyle(.solidButton(role: .primary))
```

## Development

```bash
swift build          # Build the library
swift test           # Run tests
```

### Preview App

```bash
scripts/run-preview.sh     # Build and launch CoreDesignPreview in Simulator
scripts/run-snapshots.sh   # Generate component snapshot PNGs
```

