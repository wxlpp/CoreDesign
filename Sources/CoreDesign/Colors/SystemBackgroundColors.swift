import SwiftUI

public extension Color {
    /// 界面主背景的颜色。
    /// ⚠️ macOS 无分层背景 API，本文件 6 个 token 在那里**全部同值**（实测 `windowBackgroundColor`
    /// 与 `controlBackgroundColor` 取值相同）——分层效果只在 iOS 上成立。
    static var systemBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// 主要背景上层内容的颜色。
    /// ⚠️ macOS 无分层背景 API，本文件 6 个 token 在那里**全部同值**（实测 `windowBackgroundColor`
    /// 与 `controlBackgroundColor` 取值相同）——分层效果只在 iOS 上成立。
    static var secondarySystemBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondarySystemBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 次要背景上层内容的颜色。
    /// ⚠️ macOS 无分层背景 API，本文件 6 个 token 在那里**全部同值**（实测 `windowBackgroundColor`
    /// 与 `controlBackgroundColor` 取值相同）——分层效果只在 iOS 上成立。
    static var tertiarySystemBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .tertiarySystemBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 分组界面的主要背景颜色。
    /// ⚠️ macOS 无分层背景 API，本文件 6 个 token 在那里**全部同值**（实测 `windowBackgroundColor`
    /// 与 `controlBackgroundColor` 取值相同）——分层效果只在 iOS 上成立。
    static var systemGroupedBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemGroupedBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// 分组界面主要背景上层内容的颜色。
    /// ⚠️ macOS 无分层背景 API，本文件 6 个 token 在那里**全部同值**（实测 `windowBackgroundColor`
    /// 与 `controlBackgroundColor` 取值相同）——分层效果只在 iOS 上成立。
    static var secondarySystemGroupedBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondarySystemGroupedBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 内容层叠在分组界面次要背景之上的颜色。
    /// ⚠️ macOS 无分层背景 API，本文件 6 个 token 在那里**全部同值**（实测 `windowBackgroundColor`
    /// 与 `controlBackgroundColor` 取值相同）——分层效果只在 iOS 上成立。
    static var tertiarySystemGroupedBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .tertiarySystemGroupedBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
