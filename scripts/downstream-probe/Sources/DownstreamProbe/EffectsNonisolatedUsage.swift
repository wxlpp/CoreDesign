import CoreDesignEffects
import Foundation

// `CoreDesignEffects` 的 nonisolated 消费面（#247 建结构）。
//
// ⚠️ **本文件目前只有模块标识这一条**——`CoreDesignEffects` 现在是**骨架 target**
// （#245 建，不含任何组件）。36 个动效 API 落地后，**由 `shipswift-effects` 的 A-7
// 按 API 单位清单逐个补齐调用点**。
//
// ⚠️ **A-7 的验收措辞不要写成「覆盖全部**公开**值类型」**——那是自指的：漏写
// `public` 的类型压根不算「公开」，probe 自然不覆盖它，`FR-5`（公开 API 表面必须显式
// `public`）就没人查。**按 API 单位清单点名**，漏 `public` 会在这里的编译期直接炸出来。

nonisolated func readEffectsModuleName() -> String {
    CoreDesignEffects.moduleName
}
