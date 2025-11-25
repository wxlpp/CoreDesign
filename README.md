# CoreDesign

![GitHub tag (latest SemVer)](https://github.com/wxlpp/CoreDesign/actions/workflows/ci.yml/badge.svg?branch=main)

<a href="https://placehold.it/400?text=Screen+shot"><img width=200 height=200 src="https://placehold.it/400?text=Screen+shot" alt="Screenshot" /></a>

CoreDesign 是一个 SwiftUI 设计系统库，提供了一套统一的颜色、组件和布局工具，帮助开发者快速构建美观一致的用户界面。

## 特性

- 🎨 **系统颜色扩展**: 提供跨平台（iOS/macOS）的系统颜色支持
- 🧩 **UI 组件**: 包含 Avatar、Button、CheckBox 等常用组件
- 📐 **布局工具**: 提供 EqualWidthVStack、OverlayHStack 等布局组件
- 🎯 **形状**: 内置 StarShape 等自定义形状
- 🔧 **扩展**: Color 和 Font 的实用扩展

## 安装

### Swift Package Manager

在 Xcode 中：File > Swift Packages > Add Package Dependency...

```
https://github.com/wxlpp/CoreDesign.git
```

或者在 Package.swift 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/wxlpp/CoreDesign.git", from: "1.0.0")
]
```

## 使用

### 颜色

```swift
import SwiftUI
import CoreDesign

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello World")
                .foregroundColor(.label)
                .background(Color.systemBackground)
        }
        .background(Color.secondarySystemBackground)
    }
}
```

### 组件

```swift
import SwiftUI
import CoreDesign

struct ProfileView: View {
    var body: some View {
        VStack {
            Avatar(name: "John Doe")
                .frame(width: 100, height: 100)
                .clipShape(Circle())

            CheckBox()
        }
    }
}
```

### 布局

```swift
import SwiftUI
import CoreDesign

struct LayoutView: View {
    var body: some View {
        EqualWidthVStack {
            Text("Item 1")
            Text("Longer Item 2")
            Text("Item 3")
        }
    }
}
```

## 示例

要运行示例项目，克隆此仓库，然后从 Example 目录打开 Example.xcodeproj。

## 要求

- iOS 18.0+
- macOS 15.0+
- Swift 6.0+

## 作者

Evan wang

## 许可证

CoreDesign 使用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。
