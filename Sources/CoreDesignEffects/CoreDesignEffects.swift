//
//  CoreDesignEffects.swift
//  CoreDesignEffects
//
//  模块标识与命名空间 / Module identity and namespace.
//
//  ⚠️ 本文件是 target 骨架，**不是组件**。本 epic（shipswift-foundation）明确
//  「不落任何一个组件」——36 个动效 API 由 `shipswift-effects` 的 #250~#255 落地。
//  这里只提供一个可被 smoke 测试触达的最小公开面，用来证明 target 真的被构建、
//  真的被测试。
//

/// `CoreDesignEffects` 的命名空间与模块标识。
///
/// ⚠️ **`nonisolated` 是有意为之，不是可以顺手删掉的修饰符**：本 package 的
/// target 都启用了 `swiftSettings: [.defaultIsolation(MainActor.self)]`，公开成员
/// 默认落在 `MainActor` 上。而 `scripts/downstream-probe` 的存在理由正是
/// 「从 **nonisolated 上下文**消费本库的公开值类型」——不标 `nonisolated`，
/// 下游 nonisolated 代码就用不了它，而那正是该 probe 唯一能看见的那类问题。
///
/// ⚠️ **今天没有任何机器判据守着这个修饰符**：probe 现在只依赖 `CoreDesign` product，
/// 零引用本模块——把 `nonisolated` 删掉，`swift build` / `swift test` / probe 全绿。
/// 接进 probe 归 `#247`；在那之前这条只靠本注释与评审。
public enum CoreDesignEffects {

    /// 模块名。供宿主 App 的组件画廊分组与调试输出使用。
    nonisolated public static let moduleName = "CoreDesignEffects"
}
