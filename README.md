# CoreDesign

iOS 26+ / macOS 26+ SwiftUI design system library, distributed as a Swift Package.

## Documentation

See the [Component Index](docs/README.md) for a reference of all 16 components organized by category, with thumbnail previews (generated via `scripts/run-snapshots.sh`).

## Quick Start

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/wxlpp/CoreDesign", branch: "main"),
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

