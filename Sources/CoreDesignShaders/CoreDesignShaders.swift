//
//  CoreDesignShaders.swift
//  CoreDesignShaders
//
//  模块标识、命名空间，以及 **fail-closed 的 shader library 加载检查**。
//

import Metal
import SwiftUI

/// `CoreDesignShaders` 的命名空间与模块标识。
///
/// ⚠️ `nonisolated` 是有意为之：本 package 的 target 都启用了
/// `.defaultIsolation(MainActor.self)`，公开成员默认落在 `MainActor` 上，而
/// `scripts/downstream-probe` 的存在理由正是验「下游 nonisolated 上下文能不能用」。
/// 接进 probe 归 `shipswift-shaders` 的 B-4。
public enum CoreDesignShaders {

    /// 模块名。供宿主 App 的组件画廊分组与调试输出使用。
    nonisolated public static let moduleName = "CoreDesignShaders"
}

// MARK: - metallib 加载检查（fail-closed）

extension CoreDesignShaders {

    /// 加载检查失败的原因。
    public nonisolated enum ShaderLibraryError: Error, CustomStringConvertible, Sendable {
        case noMetalDevice
        case libraryMissing(String)
        case functionMissing(String)

        public var description: String {
            switch self {
            case .noMetalDevice:
                return "本机 / 本 runner 没有可用的 Metal device"
            case .libraryMissing(let detail):
                return """
                    bundle 里没有 metallib：\(detail)
                    ⚠️ 最常见的原因是**用原生 `swift build` 构建了本 target**——它不编译 \
                    `.metal`（只会把声明为资源的 `.metal` 源**拷贝**进 bundle）。\
                    须用 `swift build --build-system swiftbuild` 或 `xcodebuild`。
                    """
            case .functionMissing(let name):
                return "metallib 里没有函数：\(name)"
            }
        }
    }

    /// 断言 metallib 真的在 bundle 里、且含指定的 `[[stitchable]]` 函数。
    ///
    /// ⚠️ **不要改用 `ShaderLibrary` 做这个检查**（`shipswift-foundation` 的 #248 spike
    /// 结论）：`ShaderLibrary` 是 SwiftUI 的**惰性**入口，查不到时**不报错、只是不渲染**
    /// ——那正是本 target 最坏的失败形态（静默无渲染）。检查必须走 Metal API。
    ///
    /// ⚠️ **fail-closed**：缺 device 也抛错，**不**静默 `return`。
    ///
    /// ⚠️ **本方法是 `@MainActor`，与同文件的 `moduleName` 不同**——这不是疏忽：
    /// 它必须引用 `Bundle.module`，而 SwiftPM **合成的 `Bundle.module` 访问器
    /// 本身就落在 `MainActor` 上**（本 package 全部 target 启用
    /// `.defaultIsolation(MainActor.self)`）。标 `nonisolated` 会编译失败：
    /// `main actor-isolated static property 'module' can not be referenced
    /// from a nonisolated context`（实测）。
    /// ⇒ 加载检查是**诊断 / 测试用 API**，`MainActor` 对它没有实际约束；
    /// 真正需要 nonisolated 可达的是值类型与配置类型，那些由 B-4 接进 probe。
    @MainActor public static func assertShaderLibraryLoadable(
        functions: [String]
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ShaderLibraryError.noMetalDevice
        }
        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            throw ShaderLibraryError.libraryMissing("\(Bundle.module.bundlePath)：\(error)")
        }
        for name in functions where library.makeFunction(name: name) == nil {
            throw ShaderLibraryError.functionMissing(name)
        }
    }
}
