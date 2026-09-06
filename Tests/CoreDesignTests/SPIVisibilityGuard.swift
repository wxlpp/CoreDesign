import Foundation
import Testing

// MARK: - `@_spi` 的单向棘轮 / SPI one-way ratchet（PR #294 第 2 轮 S-2）

@Suite("#294 @_spi 单向棘轮：SPI 面不得静默外溢或扩张")
struct SPIVisibilityGuard {
    nonisolated static let expectedGroup = "CoreDesignBenchmark"

    nonisolated struct SPIDeclaration: Hashable, Comparable, CustomStringConvertible {
        let group: String
        let name: String

        var description: String { "@_spi(\(self.group)) \(self.name)" }

        static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.name, lhs.group) < (rhs.name, rhs.group)
        }
    }

    // MARK: - 登记表

    nonisolated static let registry: Set<SPIDeclaration> = [
        .init(group: "CoreDesignBenchmark", name: "ConfettiRenderProbe"),
        .init(group: "CoreDesignBenchmark", name: "NetworkGraphRenderProbe"),
    ]

    // MARK: - 纯扫描器（供合成输入的变红自证使用）

    nonisolated static func scan(text: String) -> [SPIDeclaration] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var out: [SPIDeclaration] = []
        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("//") else { continue }
            guard line.contains("public ") || line.hasPrefix("public") else { continue }
            var group: String?
            if let found = Self.spiGroup(inLine: line) {
                group = found
            } else {
                for back in 1...2 where index - back >= 0 {
                    let previous = lines[index - back].trimmingCharacters(in: .whitespaces)
                    if previous.hasPrefix("//") { break }
                    if let found = Self.spiGroup(inLine: previous) { group = found; break }
                    if !previous.hasPrefix("@") { break }
                }
            }
            guard let group else { continue }
            guard let name = Self.declaredName(inLine: line) else { continue }
            out.append(.init(group: group, name: name))
        }
        return out
    }

    nonisolated static func spiGroup(inLine line: String) -> String? {
        guard let start = line.range(of: "@_spi(") else { return nil }
        if start.lowerBound > line.startIndex {
            let before = line[line.index(before: start.lowerBound)]
            if before == "`" { return nil }
        }
        let rest = line[start.upperBound...]
        guard let close = rest.firstIndex(of: ")") else { return nil }
        let group = String(rest[..<close]).trimmingCharacters(in: .whitespaces)
        return group.isEmpty ? nil : group
    }

    nonisolated static func declaredName(inLine line: String) -> String? {
        let keywords = ["enum", "struct", "class", "actor", "protocol", "extension",
                        "func", "var", "let", "typealias"]
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard let keywordIndex = tokens.firstIndex(where: { keywords.contains($0) }),
              keywordIndex + 1 < tokens.count
        else { return nil }
        let raw = tokens[keywordIndex + 1]
        let name = raw.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        return name.isEmpty ? nil : String(name)
    }

    // MARK: - 判据

    nonisolated static func scanAllSources() -> [SPIDeclaration: [String]] {
        var found: [SPIDeclaration: [String]] = [:]
        for root in GuardScanRoots.allRoots {
            for file in GuardScanRoots.swiftFiles(in: root.url) {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else {
                    Issue.record("读不出源码文件：\(GuardScanRoots.relativePath(file)) —— 判据无法工作，这不是「零违规」")
                    continue
                }
                for declaration in Self.scan(text: text) {
                    found[declaration, default: []].append(GuardScanRoots.relativePath(file))
                }
            }
        }
        return found
    }

    @Test("R1：SPI 面与登记表逐条吻合（双向差集），且集合大小钉死为 2")
    func spiSurfaceMatchesRegistry() {
        GuardScanRoots.assertRootsExist(GuardScanRoots.allRoots)
        let found = Self.scanAllSources()
        let actual = Set(found.keys)

        let missing = Self.registry.subtracting(actual).sorted()
        #expect(missing.isEmpty, """
        这些声明登记为 `@_spi`，却在 Sources/ 里扫不到对应的注解：\(missing)

        ⚠️ 最常见的成因是**有人删掉了 `@_spi(\(Self.expectedGroup))` 那一行** ——
        那样它们会**静默变成正式 public API**，而 swift build / swift test /
        downstream-probe / iOS 腿**全绿**（少一个注解只让符号更可见）。
        若确实要把它升成正式 API，请走 `PublicVisibility` /
        `reachable-type-registry.json` / `docs/README.md` 的登记流程，
        而不是只把这张表改小。
        """)

        let extra = actual.subtracting(Self.registry).sorted()
        #expect(extra.isEmpty, """
        Sources/ 里有这些 `@_spi` 声明，而登记表没有：\(extra)
        —— SPI 面扩张不能顺手带进来；确认它确实是「只给基准看的仪器」后再登记。
        位置：\(extra.compactMap { found[$0] })
        """)

        #expect(actual.count == 2, "扫到 \(actual.count) 条 `@_spi` public 声明，登记的是 2 条")
        #expect(Self.registry.count == 2, "登记表被改成了 \(Self.registry.count) 条 —— 见上一条")

        let groups = Set(actual.map(\.group))
        #expect(groups == [Self.expectedGroup], "SPI 组名不再是唯一的 \(Self.expectedGroup)：\(groups.sorted())")
    }

    @Test("R2：判据自证会开火 —— 合成源码逐个打红")
    func judgeActuallyFires() {
        let stripped = """
        /// ⚠️ **`@_spi` 而不是普通 `public`**：这是仪器，不是图表的 API 面。
        public nonisolated enum NetworkGraphRenderProbe {
            public static var drawnFrames: Int { 0 }
        }
        """
        #expect(Self.scan(text: stripped).isEmpty, """
        删掉 `@_spi(...)` 那一行之后仍被扫成 SPI 声明 —— R1 的 `missing` 方向形同虚设，
        「静默升成正式 public API」这条通路没被堵住。
        """)

        let annotated = """
        /// ⚠️ **`@_spi` 而不是普通 `public`**：这是仪器，不是图表的 API 面。
        @_spi(CoreDesignBenchmark)
        public nonisolated enum NetworkGraphRenderProbe {
            public static var drawnFrames: Int { 0 }
        }
        """
        #expect(
            Self.scan(text: annotated) == [
                .init(group: "CoreDesignBenchmark", name: "NetworkGraphRenderProbe"),
            ],
            "正常形态没被扫到 —— 那么 ① 的「为空」什么都证明不了"
        )

        #expect(
            Self.scan(text: "@_spi(CoreDesignBenchmark) public enum Probe {}")
                == [.init(group: "CoreDesignBenchmark", name: "Probe")]
        )

        #expect(
            Self.scan(text: "@_spi(SomethingElse)\npublic enum Probe {}")
                == [.init(group: "SomethingElse", name: "Probe")]
        )

        #expect(
            Self.scan(text: "/// ⚠️ **`@_spi` 而不是普通 `public`**\npublic enum Probe {}").isEmpty,
            "文档注释里的 `@_spi` 被当成了注解"
        )

        #expect(
            Self.scan(text: "@_spi(G)\n@available(iOS 26, *)\npublic enum Probe {}")
                == [.init(group: "G", name: "Probe")]
        )
        #expect(
            Self.scan(text: "@_spi(G)\nlet unrelated = 0\npublic enum Probe {}").isEmpty,
            "`@_spi` 与 public 声明之间夹了别的代码，却仍被配成一对"
        )
    }
}
