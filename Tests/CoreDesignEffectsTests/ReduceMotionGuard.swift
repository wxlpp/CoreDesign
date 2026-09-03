import Foundation
import Testing

// ⚠️ **这条守卫是终审 I-4 的产物，也是它最值钱的一条。**
//
// 我在任务记账里写过「环境注入 + 渲染断言在 macOS 单测里不可观测」，据此把两条 AC
// 记为"结构性做不到"。**那个理由不成立**——本仓的主流测试形态本来就是**源码扫描**
//（`BoolParameterScanner` 68 KB、`BoolExemptionGuard` 55 KB、`ComponentRegistryGuard`
// 60 KB…七条以上 SwiftSyntax 守卫），完全在 macOS 射程内。
//
// ⚠️ **代价是实打实的**：这条守卫若早就存在，第 1 轮的 Jump / Spray / Shine 三条
// Reduce Motion 缺陷、以及第 2 轮的 Ping（I-1）**会被机器当场逮到**，而不是靠人眼
// 连查两轮。按"做不到"记账的后果就是下一个人不会再去尝试。
//
// ⚠️ 真正不可观测的只是**动画中间帧**（`ImageRenderer` 拍的是静态帧，本仓
// `ToastPresentationRenderTests` 已写死这条限度）。记账应当写"动画中间帧不可观测"，
// 而不是把整个 Reduce Motion 归入不可测。

@Suite("Reduce Motion 降级守卫")
struct MicroInteractionReduceMotionGuard {

    /// 会产生**运动**的 SwiftUI 变换。带 `(` 是为了避免匹配到注释里的裸词。
    static let motionCalls = ["offset(", "rotationEffect(", "scaleEffect(", "rotation3DEffect("]

    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/CoreDesignEffectsTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // 仓库根
            .appendingPathComponent("Sources/CoreDesignEffects")
    }

    static func swiftFiles() throws -> [URL] {
        let root = Self.sourceRoot
        // ⚠️ **fail-closed**：目录不存在时必须判红，不能"零文件 ⇒ 零违规 ⇒ 绿"。
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory)
        #expect(exists && isDirectory.boolValue, "扫描根不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
        guard exists else { return [] }
        return try FileManager.default
            .contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 去掉 `//` 行注释，避免注释里的示例代码被当成真调用。
    static func stripComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let r = line.range(of: "//") else { return String(line) }
                return String(line[line.startIndex..<r.lowerBound])
            }
            .joined(separator: "\n")
    }

    @Test("凡产生运动的效果文件，都必须读 accessibilityReduceMotion")
    func motionFilesReadReduceMotion() throws {
        var offenders: [String] = []
        for file in try Self.swiftFiles() {
            let raw = try String(contentsOf: file, encoding: .utf8)
            let code = Self.stripComments(raw)
            guard Self.motionCalls.contains(where: { code.contains($0) }) else { continue }
            if !code.contains("accessibilityReduceMotion") {
                offenders.append(file.lastPathComponent)
            }
        }
        #expect(offenders.isEmpty, "这些文件有运动变换却没读 Reduce Motion：\(offenders)")
    }

    @Test("凡产生运动的效果文件，都必须走两种被批准的降级形态之一")
    func motionFilesDegradeConsistently() throws {
        var offenders: [String] = []
        for file in try Self.swiftFiles() {
            let raw = try String(contentsOf: file, encoding: .utf8)
            let code = Self.stripComments(raw)
            guard Self.motionCalls.contains(where: { code.contains($0) }) else { continue }
            let form1 = code.contains("reduceMotionFallback(")
            // 形态 2 的标记刻意从**原文**里找（它就是一行注释）。
            let form2 = raw.contains("// RM-FORM-2:")
            if !form1 && !form2 {
                offenders.append(file.lastPathComponent)
            }
        }
        #expect(offenders.isEmpty,
                "这些文件有运动却既不调 reduceMotionFallback、也没标 RM-FORM-2：\(offenders)")
    }

    /// ⚠️ **防假绿**：上面两条在"零文件"或"正则失配"时都会静默变绿。
    /// 这一条钉住扫描确实命中了预期数量的文件。
    @Test("扫描确实覆盖到了运动类文件（不是零命中的假绿）")
    func scanActuallyMatches() throws {
        let files = try Self.swiftFiles()
        #expect(files.count >= 9, "只扫到 \(files.count) 个文件，疑似扫描根错了")
        let motionFiles = try files.filter { file in
            let code = Self.stripComments(try String(contentsOf: file, encoding: .utf8))
            return Self.motionCalls.contains { code.contains($0) }
        }
        // Shake / Jump / Spin / Ping / Spray / Rise 六个确实有运动变换。
        #expect(motionFiles.count >= 5,
                "只有 \(motionFiles.count) 个文件被判定为含运动 —— 判据多半失配了")
    }
}
