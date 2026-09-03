import Foundation
import Testing

// ⚠️ **这条守卫是 #262 终审 I-4 的产物。**
//
// 我在任务记账里写过「环境注入 + 渲染断言在 macOS 单测里不可观测」，据此把两条 AC
// 记为"结构性做不到"。**那个理由不成立**——本仓的主流测试形态本来就是**源码扫描**
//（`BoolParameterScanner` 68 KB、`BoolExemptionGuard` 55 KB、`ComponentRegistryGuard`
// 60 KB…七条以上 SwiftSyntax 守卫），完全在 macOS 射程内。
//
// ⚠️⚠️ **上一版的头注释写「这条守卫若早就存在，第 1 轮的 Jump / Spray / Shine 三条
// 缺陷会被机器当场逮到」——第 3 轮终审 C-3 实测证伪了其中 Jump 那条。**
// 评审把第 1 轮的源码取出来逐字复现判据：Jump 的缺陷是「`offset` 门控了、
// `scaleEffect` 没门控」，而文件里 `accessibilityReduceMotion` 在、
// `reduceMotionFallback(` 也在 ⇒ **上一版守卫全绿放行**。
// 逮到的只有 Spray / Shine / Ping 三条（完全没有降级的那一类）。
//
// ⇒ 本版补上第三条判据 `everyMotionCallIsGated` 直取那个盲区：
//   **不走早退的文件，每一行运动变换都必须自带门控**。它对第 1 轮的 Jump 判红。
//
// ⚠️ 真正不可观测的只是**动画中间帧**（`ImageRenderer` 拍的是静态帧，本仓
// `ToastPresentationRenderTests` 已写死这条限度）。

@Suite("Reduce Motion 降级守卫")
struct MicroInteractionReduceMotionGuard {

    /// 会产生**运动**的 SwiftUI 变换。带 `(` 是为了避免匹配到注释里的裸词。
    ///
    /// ⚠️ 第 3 轮终审 I-5 补齐：上一版缺 `.symbolEffect(` / `position(` /
    /// `transformEffect(` / `matchedGeometryEffect(`——其中 `symbolEffect` 最可能被撞上
    /// （`Spray` 整篇在用 SF Symbol，`.bounce` 就是运动）。
    static let motionCalls = [
        "offset(", "rotationEffect(", "scaleEffect(", "rotation3DEffect(",
        "symbolEffect(", "position(", "transformEffect(", "matchedGeometryEffect(",
    ]

    /// 走**降级形态 2**（保留淡入淡出 + 静止位移，不叠脉冲）的文件。
    ///
    /// ⚠️ **集中名单，不用文件内自证标记**（第 3 轮终审 I-5）：上一版只认文件里的
    /// `// RM-FORM-2:` 注释——任何人加一行注释即可放行，且那行长在**被审对象自己
    /// 文件里**，评审时没有集中位置能看见「谁又新领了一张豁免」。
    /// 本仓对同类问题的成法是集中豁免名单（`BoolExemptionGuard`）。
    /// 现在两边**双向差集**：新领一张豁免必须改本文件 ⇒ 在 diff 里必然可见。
    static let approvedFormTwo: Set<String> = ["Rise.swift"]

    /// 走**早退**（RM 下整个装饰层不构建）的文件。
    ///
    /// ⚠️ **同样必须是集中名单**（第 4 轮终审 C4-2）：上一版只认文件里出现
    /// `guard !isReduced` 这个字符串——**那和我在同一个 commit 里刚铲掉的
    /// `// RM-FORM-2:` 自证标记是同一形态，只是伪装成了代码**。
    /// 任何人在文件任意位置写下一句 `guard !isReduced`（哪怕只包住一个局部函数），
    /// 整个文件的**每一处**运动调用就全部被豁免。评审实测过这枚变异：绿。
    static let approvedEarlyExit: Set<String> = ["Ping.swift", "Spray.swift", "Shine.swift"]

    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/CoreDesignEffectsTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // 仓库根
            .appendingPathComponent("Sources/CoreDesignEffects")
    }

    /// ⚠️ **递归枚举**（第 3 轮终审 I-5）：上一版用 `contentsOfDirectory` 不递归，
    /// 把任一效果文件挪进子目录（本仓 `Sources/CoreDesign/Components/*/` 就是这么组织的）
    /// 它就不再被扫描，而计数阈值仍然通过 ⇒ 静默逃逸。
    static func swiftFiles() throws -> [URL] {
        let root = Self.sourceRoot
        // ⚠️ **fail-closed**：目录不存在时必须判红，不能"零文件 ⇒ 零违规 ⇒ 绿"。
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory)
        #expect(exists && isDirectory.boolValue,
                "扫描根不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
        guard exists, let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return [] }
        return e.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 去掉 `//` 行注释，避免注释里的示例代码被当成真调用。
    ///
    /// ⚠️ **已知：不处理 `/* */` 块注释与字符串字面量**。方向是 **fail-closed**
    /// （块注释里的 `offset(` 只会造成误报，不会漏报），故不修；写在这里免得
    /// 下一个人以为它处理了。实测本 target 当前无块注释。
    static func stripComments(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let r = line.range(of: "//") else { return String(line) }
                return String(line[line.startIndex..<r.lowerBound])
            }
            .joined(separator: "\n")
    }

    static func motionFiles() throws -> [(URL, String)] {
        try Self.swiftFiles().compactMap { url in
            let code = Self.stripComments(try String(contentsOf: url, encoding: .utf8))
            return Self.motionCalls.contains(where: { code.contains($0) }) ? (url, code) : nil
        }
    }

    @Test("凡产生运动的效果文件，都必须读 accessibilityReduceMotion")
    func motionFilesReadReduceMotion() throws {
        let offenders = try Self.motionFiles()
            .filter { !$0.1.contains("accessibilityReduceMotion") }
            .map(\.0.lastPathComponent)
        #expect(offenders.isEmpty, "这些文件有运动变换却没读 Reduce Motion：\(offenders)")
    }

    @Test("凡产生运动的效果文件，都必须走两种被批准的降级形态之一")
    func motionFilesDegradeConsistently() throws {
        let offenders = try Self.motionFiles()
            .filter { !$0.1.contains("reduceMotionFallback(")
                      && !Self.approvedFormTwo.contains($0.0.lastPathComponent) }
            .map(\.0.lastPathComponent)
        #expect(offenders.isEmpty,
                "这些文件有运动却既不调 reduceMotionFallback、也不在形态 2 名单里：\(offenders)")
    }

    /// ⚠️⚠️ **直取上一版的盲区：部分门控**（第 3 轮终审 C-3）。
    ///
    /// 「有 `accessibilityReduceMotion`、也有 `reduceMotionFallback(`」不代表**每一处**
    /// 运动都被门控——第 1 轮的 Jump 正是「`offset` 门控了、`scaleEffect` 没门控」，
    /// 上一版守卫对它全绿。这是本 issue 已经真实发生过一次、也最可能再次发生的形态。
    ///
    /// 判据：**不走早退**（没有 `guard !isReduced`）的文件，每一行含运动变换的代码
    /// 都必须自带门控标记（`isReduced` / `reduceMotion`）。走早退的文件整段已被挡在
    /// RM 之外，逐行门控没有意义。
    @Test("不走早退的文件，每一处运动变换都必须自带门控")
    func everyMotionCallIsGated() throws {
        var offenders: [String] = []
        for (url, code) in try Self.motionFiles() {
            // ⚠️ **早退只豁免 `guard` 之后的代码**（第 4 轮终审 C4-3）：
            // 上一版 `continue` 掉整个文件 ⇒ 把运动加进 **RM 降级分支内部**
            //（`guard` 的 `else { }` 块里）三条判据无一命中。评审实测：往 Shine 的
            // 降级分支加 `.rotationEffect(15°).offset(x: 20)` ⇒ 绿。
            // 那是在 Reduce Motion **开启**的路径上加运动，FR-11 的正面违反，
            // 也正是本 issue 前三轮反复出问题的方向。
            let name = url.lastPathComponent
            let guardEnd: Int? = Self.approvedEarlyExit.contains(name)
                ? Self.earlyExitBodyStart(in: code)
                : nil
            for (call, args, line) in Self.motionCallArguments(in: code) {
                // 只有落在早退 `guard` **之后**的调用才被豁免。
                if let end = guardEnd, Self.offset(ofLine: line, in: code) > end { continue }
                // ⚠️ **只看该调用自己的实参**（配对括号提取），不看行、也不看窗口。
                // 逐行会把跨行调用误判（`.scaleEffect(` 的门控写在后续实参行上）；
                // 而窗口会被**紧邻的另一个已门控调用**骗过——第 1 轮的 Jump 正是
                // `.scaleEffect(未门控)` 紧接着 `.offset(y: isReduced ? …)`，
                // 6 行窗口把后者的门控算给了前者 ⇒ 放行。实测过这两种失败。
                if !args.contains("isReduced") && !args.contains("reduceMotion") {
                    offenders.append("\(url.lastPathComponent):\(line) \(call)…")
                }
            }
        }
        #expect(offenders.isEmpty, "这些运动变换没有被 Reduce Motion 门控：\n\(offenders.joined(separator: "\n"))")
    }

    /// 早退 `guard` 语句**结束**（其 `else { }` 块闭合）后的字符偏移。
    /// 返回 `nil` 表示文件里没有早退。
    static func earlyExitBodyStart(in code: String) -> Int? {
        let chars = Array(code)
        for marker in ["guard !isReduced", "guard !self.reduceMotion"] {
            guard let r = code.range(of: marker) else { continue }
            var k = code.distance(from: code.startIndex, to: r.lowerBound)
            // 走到 `else {` 的那个 `{`，再配对到它的 `}`。
            while k < chars.count, chars[k] != "{" { k += 1 }
            var depth = 0
            while k < chars.count {
                if chars[k] == "{" { depth += 1 }
                else if chars[k] == "}" {
                    depth -= 1
                    if depth == 0 { return k }
                }
                k += 1
            }
        }
        return nil
    }

    /// 1-based 行号 → 字符偏移。
    static func offset(ofLine line: Int, in code: String) -> Int {
        var offset = 0, current = 1
        for ch in code {
            if current >= line { break }
            offset += 1
            if ch == "\n" { current += 1 }
        }
        return offset
    }

    /// 提取每个运动调用**自身的实参文本**（配对括号），连同起始行号。
    static func motionCallArguments(in code: String) -> [(call: String, args: String, line: Int)] {
        let chars = Array(code)
        var result: [(String, String, Int)] = []
        for call in Self.motionCalls {
            var searchStart = code.startIndex
            while let r = code.range(of: call, range: searchStart..<code.endIndex) {
                let openIndex = code.index(before: r.upperBound)   // 指向 "("
                let openOffset = code.distance(from: code.startIndex, to: openIndex)
                var depth = 0
                var k = openOffset
                while k < chars.count {
                    if chars[k] == "(" { depth += 1 }
                    else if chars[k] == ")" {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    k += 1
                }
                let args = String(chars[openOffset...min(k, chars.count - 1)])
                let line = code[code.startIndex..<r.lowerBound].filter { $0 == "\n" }.count + 1
                result.append((call, args, line))
                searchStart = r.upperBound
            }
        }
        return result
    }

    /// 早退名单同样做**双向差集**——新领一张豁免必须改本文件 ⇒ 在 diff 里必然可见。
    @Test("早退名单与实际一致（双向差集）")
    func earlyExitListMatchesReality() throws {
        let actual = Set(try Self.motionFiles()
            .filter { $0.1.contains("guard !isReduced") || $0.1.contains("guard !self.reduceMotion") }
            .map(\.0.lastPathComponent))
        #expect(actual == Self.approvedEarlyExit,
                "早退名单 \(Self.approvedEarlyExit.sorted()) 与实际 \(actual.sorted()) 不一致")
    }

    /// 形态 2 名单与实际使用**双向差集**——名单里有、文件却没走形态 2（或反之）都判红。
    @Test("形态 2 名单与实际一致（双向差集）")
    func formTwoListMatchesReality() throws {
        let files = try Self.motionFiles()
        let actual = Set(files
            .filter { !$0.1.contains("reduceMotionFallback(") }
            .map(\.0.lastPathComponent))
        #expect(actual == Self.approvedFormTwo,
                "形态 2 名单 \(Self.approvedFormTwo.sorted()) 与实际 \(actual.sorted()) 不一致")
    }

    /// ⚠️⚠️ **替代那句被证伪的「回退即编译失败」**（第 3 轮终审 C-2）。
    ///
    /// 我在测试注释与 commit 里写过：把 `TriggerRelay` 删掉、泛型直接进动画 modifier，
    /// **回退即编译失败**。评审把那枚变异真建出来跑了——`-swift-version 6`
    /// `-default-isolation MainActor` 下只得到一条
    /// `warning: capture of non-Sendable type 'T.Type' in an isolated closure`，
    /// **Build complete、测试全绿**。而 CI 没开 `-warnings-as-errors`
    /// ⇒ 那条 warning 不构成机器判据，只构成「希望下一个人注意到」。
    ///
    /// `IsolatedTrigger` 真正钉住的是**另一枚**变异（给 `T` 加 `Sendable` 约束 ⇒ 编译红）。
    /// 「泛型直接进动画 modifier」这枚由本判据接管：**效果的 `*Core` ViewModifier 不得泛型**。
    @Test("效果的 Core ViewModifier 不得是泛型（泛型必须停在 TriggerRelay）")
    func coreModifiersAreNotGeneric() throws {
        var offenders: [String] = []
        for (url, code) in try Self.swiftFiles().map({ ($0, Self.stripComments(try String(contentsOf: $0, encoding: .utf8))) }) {
            for line in code.split(separator: "\n") where line.contains("Core<") && line.contains("struct ") {
                offenders.append("\(url.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        let detail = offenders.joined(separator: "\n")
        #expect(offenders.isEmpty,
                "这些 Core modifier 是泛型 —— 泛型应停在 TriggerRelay：\n\(detail)")
    }

    /// ⚠️ **防假绿**：上面几条在"零文件"或"判据失配"时都会静默变绿。
    ///
    /// ⚠️ 阈值取**实际数**而非下界（第 3 轮终审 I-5）：`>= 9` 在文件从 10 个变成 9 个
    /// （被挪进子目录）时仍然通过，留了一格逃逸位。
    @Test("扫描确实覆盖到预期数量的文件（不是零命中的假绿）")
    func scanActuallyMatches() throws {
        let files = try Self.swiftFiles()
        #expect(files.count == 10, "扫到 \(files.count) 个文件（预期 10）—— 增删文件时请同步本断言")
        let motion = try Self.motionFiles()
        #expect(motion.count == 7,
                "判定为含运动的文件有 \(motion.count) 个（预期 7：Shake/Jump/Spin/Ping/Spray/Rise/Shine）")
    }
}
