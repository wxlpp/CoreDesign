import Foundation
import Testing

@Suite("Reduce Motion 降级守卫")
struct MicroInteractionReduceMotionGuard {
    static let motionCalls = [
        "offset(", "rotationEffect(", "scaleEffect(", "rotation3DEffect(",
        "symbolEffect(", "position(", "transformEffect(", "matchedGeometryEffect(",
        "Canvas(", "TimelineView(", "visualEffect(", "projectionEffect(",
    ]

    static let approvedFormTwo: Set<String> = [
        "Rise.swift", "Confetti.swift", "ProcessingSweep.swift",
        "AnimatedMeshGradient.swift", "ParticleTransition.swift",
        "SphereSurface.swift", "OrbitingLogos.swift",
        "FlipTransition.swift", "Rotate3DTransition.swift", "SwooshTransition.swift",
        "BoingTransition.swift", "SkidTransition.swift", "PolarMoveTransition.swift",
    ]

    static let approvedEarlyExit: Set<String> = [
        "Ping.swift", "Spray.swift", "Shine.swift",
        "Confetti.swift", "ProcessingSweep.swift",
        "AnimatedMeshGradient.swift", "ParticleTransition.swift",
        "SphereSurface.swift", "OrbitingLogos.swift",
    ]

    static let earlyExitMarkers = [
        "guard !isReduced", "guard !self.reduceMotion", "switch presentation {",
    ]

    static let approvedNoMotion: Set<String> = [
        "OhMyDesignEffects.swift",
        "MicroInteractionSupport.swift",
        "Haptic.swift",
        "EffectsEnergy.swift",
        "ScanningOverlay.swift",
        "GlowSweep.swift",
        "PerimeterGlowTrail.swift", // 纯相位绘制；计时及减少动态效果由 ProcessingSweep 管理。
        "LightSweep.swift",
        "TypewriterText.swift",
        "BeforeAfterSlider.swift",
        "SphereField.swift",
        "OrbitRing.swift",
        "FullScreenTransitionPlan.swift",
        "DotSphere.swift",
        "CharSphere.swift",
        "FullScreenButton.swift",
        "TransitionSupport.swift",

        "FilterTransitionSupport.swift",
        "BlurTransition.swift",
        "FilmExposureTransition.swift",
        "SnapshotTransition.swift",
        "FlickerTransition.swift",

        "MaskReveal.swift",
        "MaskRevealTransitions.swift",
    ]

    static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/OhMyDesignEffects")
    }

    static var energyGateScanRoots: [URL] {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return ["Sources/OhMyDesignEffects", "Sources/OhMyDesign"]
            .map { repoRoot.appendingPathComponent($0) }
    }

    static func swiftFiles() throws -> [URL] {
        try Self.swiftFiles(in: [Self.sourceRoot])
    }

    static func swiftFiles(in roots: [URL]) throws -> [URL] {
        var all: [URL] = []
        for root in roots {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory)
            #expect(exists && isDirectory.boolValue,
                    "扫描根不存在：\(root.path) —— 判据无法工作，这不是「零违规」")
            guard exists,
                  let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            else { continue }
            all += e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        }
        return all.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func assertNoBasenameCollision(_ files: [URL]) {
        let grouped = Dictionary(grouping: files, by: \.lastPathComponent)
        let collisions = grouped.filter { $0.value.count > 1 }
        #expect(collisions.isEmpty,
                "两个扫描根里有同名文件 \(collisions.keys.sorted()) —— 本守卫的名单按裸文件名建，会同时命中两份；要么改名，要么把名单改成带 target 前缀")
    }

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

    @Test("不走早退的文件，每一处运动变换都必须自带门控")
    func everyMotionCallIsGated() throws {
        var offenders: [String] = []
        for (url, code) in try Self.motionFiles() {
            let name = url.lastPathComponent
            let guardEnd: Int? = Self.approvedEarlyExit.contains(name)
                ? Self.earlyExitBodyStart(in: code)
                : nil
            for (call, args, line) in Self.motionCallArguments(in: code) {
                if let end = guardEnd, Self.offset(ofLine: line, in: code) > end { continue }
                guard args.contains("isReduced") || args.contains("reduceMotion") else {
                    offenders.append("\(url.lastPathComponent):\(line) \(call)… [无门控]")
                    continue
                }
                if let q = args.firstIndex(of: "?"), let c = args[q...].firstIndex(of: ":") {
                    let trueBranch = args[args.index(after: q)..<c]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let animationRefs = ["state.", "phase.", "progress", "turns"]
                    if let bad = animationRefs.first(where: { trueBranch.contains($0) }) {
                        offenders.append("\(url.lastPathComponent):\(line) \(call)… "
                                         + "[Reduce Motion 分支引用了动画状态 `\(bad)`："
                                         + "`\(trueBranch)` —— 极性反了或门控成了另一个动画值]")
                    }
                }
            }
        }
        #expect(offenders.isEmpty, "这些运动变换没有被 Reduce Motion 门控：\n\(offenders.joined(separator: "\n"))")
    }

    static func earlyExitBodyStart(in code: String) -> Int? {
        let chars = Array(code)
        for marker in Self.earlyExitMarkers {
            guard let r = code.range(of: marker) else { continue }
            var k = code.distance(from: code.startIndex, to: r.lowerBound)
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

    static func offset(ofLine line: Int, in code: String) -> Int {
        var offset = 0, current = 1
        for ch in code {
            if current >= line { break }
            offset += 1
            if ch == "\n" { current += 1 }
        }
        return offset
    }

    static func motionCallArguments(in code: String) -> [(call: String, args: String, line: Int)] {
        let chars = Array(code)
        var result: [(String, String, Int)] = []
        for call in Self.motionCalls {
            var searchStart = code.startIndex
            while let r = code.range(of: call, range: searchStart..<code.endIndex) {
                let openIndex = code.index(before: r.upperBound)
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

    static let energyGatedFiles: Set<String> = [
        "Confetti.swift", "ProcessingSweep.swift", "AnimatedMeshGradient.swift",
        "SphereSurface.swift", "OrbitingLogos.swift",
    ]

    @Test("走能耗闸的文件：reduceMotion 只许喂给 presentation(reduceMotion:) 这一个裁决点")
    func reduceMotionIsOnlyConsumedByTheSharedGate() throws {
        let files = try Self.swiftFiles(in: Self.energyGateScanRoots)
        Self.assertNoBasenameCollision(files)
        let scanned = try files.map { url -> (String, String) in
            (url.lastPathComponent, Self.stripComments(try String(contentsOf: url, encoding: .utf8)))
        }
        let actual = Set(scanned.filter { entry in
            entry.1.filter { !$0.isWhitespace }.contains("EnergyState.resolve(")
        }.map(\.0))
        #expect(actual == Self.energyGatedFiles,
                "走能耗闸的文件名单 \(Self.energyGatedFiles.sorted()) 与实际 \(actual.sorted()) 不一致")

        for (name, code) in scanned where Self.energyGatedFiles.contains(name) {
            let reads = code.components(separatedBy: "self.reduceMotion").count - 1
            let fed = code.components(separatedBy: "presentation(reduceMotion: self.reduceMotion)")
                .count - 1
            #expect(fed >= 1,
                    "\(name) 没有把 reduceMotion 喂给 EnergyState.presentation(reduceMotion:) —— 两道闸的顺序在这个调用点上又变成各写一遍了")
            #expect(reads == fed,
                    "\(name) 里 `self.reduceMotion` 出现 \(reads) 次，但只有 \(fed) 次是喂给 presentation(reduceMotion:) 的 —— 多出来的那些是调用点自己又判了一遍 Reduce Motion，能耗闸会被绕过（I-1 的原形态）")

            let strays = Self.bareReduceMotionOccurrences(in: code)
            #expect(strays.isEmpty,
                    "\(name) 里这些 `reduceMotion` 既不是声明、也不是实参标签、更不是 `self.reduceMotion`：\n\(strays.joined(separator: "\n"))\n—— 去掉 `self.` 就能绕过上面按字面子串的计数，把 I-1 原样放回来")
        }
    }

    static func bareReduceMotionOccurrences(in code: String) -> [String] {
        func isIdentifierChar(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        let needle = "reduceMotion"
        var out: [String] = []
        for (index, rawLine) in code.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(rawLine)
            var searchStart = line.startIndex
            while let r = line.range(of: needle, range: searchStart..<line.endIndex) {
                searchStart = r.upperBound
                if r.lowerBound > line.startIndex,
                   isIdentifierChar(line[line.index(before: r.lowerBound)]) { continue }
                if r.upperBound < line.endIndex, isIdentifierChar(line[r.upperBound]) { continue }
                let prefix = line[line.startIndex..<r.lowerBound]
                if prefix.hasSuffix("var ") { continue }
                if r.upperBound < line.endIndex, line[r.upperBound] == ":" { continue }
                if prefix.hasSuffix("self.") { continue }
                out.append("\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        return out
    }

    @Test("早退名单与实际一致（双向差集）")
    func earlyExitListMatchesReality() throws {
        let actual = Set(try Self.motionFiles()
            .filter { code in Self.earlyExitMarkers.contains(where: { code.1.contains($0) }) }
            .map(\.0.lastPathComponent))
        #expect(actual == Self.approvedEarlyExit,
                "早退名单 \(Self.approvedEarlyExit.sorted()) 与实际 \(actual.sorted()) 不一致")
    }

    @Test("形态 2 名单与实际一致（双向差集）")
    func formTwoListMatchesReality() throws {
        let files = try Self.motionFiles()
        let actual = Set(files
            .filter { !$0.1.contains("reduceMotionFallback(") }
            .map(\.0.lastPathComponent))
        #expect(actual == Self.approvedFormTwo,
                "形态 2 名单 \(Self.approvedFormTwo.sorted()) 与实际 \(actual.sorted()) 不一致")
    }

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

    @Test("每个源文件都必须被分类（含运动 / 确认无运动），不留第三种")
    func everyFileIsClassified() throws {
        let all = Set(try Self.swiftFiles().map(\.lastPathComponent))
        let motion = Set(try Self.motionFiles().map(\.0.lastPathComponent))
        let unclassified = all.subtracting(motion).subtracting(Self.approvedNoMotion)
        #expect(unclassified.isEmpty,
                "这些文件既没被判为含运动、也不在 approvedNoMotion 名单里：\(unclassified.sorted())")
        let stale = Self.approvedNoMotion.subtracting(all)
        #expect(stale.isEmpty, "approvedNoMotion 里有已不存在的文件：\(stale.sorted())")
        let contradiction = Self.approvedNoMotion.intersection(motion)
        #expect(contradiction.isEmpty, "这些文件在无运动名单里，却被判为含运动：\(contradiction.sorted())")
    }
}
