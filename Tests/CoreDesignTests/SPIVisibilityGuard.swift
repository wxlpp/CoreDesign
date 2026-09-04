import Foundation
import Testing

// MARK: - `@_spi` 的单向棘轮 / SPI one-way ratchet（PR #294 第 2 轮 S-2）
//
// ## 它守什么
//
// 本仓有且仅有 **2 个** `@_spi(CoreDesignBenchmark)` 的 `public` 声明 ——
// `ConfettiRenderProbe` 与 `NetworkGraphRenderProbe`。它们是 NFR-1 基准的观测点
// （**仪器**），不是设计系统的 API 面：只有
// `@_spi(CoreDesignBenchmark) import CoreDesignEffects` 的调用方看得见，
// 普通下游的补全列表里不出现。
//
// ## 为什么要一条判据
//
// ⚠️⚠️ **`@_spi` 是一行注解，删掉它没有任何东西会红。**
// 把 `@_spi(CoreDesignBenchmark)` 那一行删掉，两个 Probe 就**静默变成正式 public API**，
// 而已有的四条可见性验证命令**全绿**：
//
//   · `swift build` / `swift test` —— 少一个注解只是让符号更可见，编译只会更宽松；
//   · `scripts/downstream-probe` —— 它本来就不引用这两个类型，多出两个 public 符号
//     对它是不可观测的；
//   · `xcodebuild` 的 iOS 腿 —— 同上。
//
// 而 `PublicVisibility.swift` / `reachable-type-registry.json` / `docs/README.md`
// 这三张登记表都**不含**这两个名字（它们今天没有外溢，评审已逐张核过）——
// 于是「变成正式 API」这件事在机器上是**零信号**的。
// 本仓对付这一族问题的既有形态是「登记表 + 双向差集」（见
// `ReachableTypeRegistryGuard` / `ComponentRegistryGuard`），这里照搬同一形态：
// **登记表钉死 2 条，扫描结果与它做双向差集。**
//
// ## 射程与已知边界（不要读成比实际更强）
//
// ⚠️ 本判据是**纯文本**的：它认的是「`public` 声明的上一/上二行有没有 `@_spi(...)`」，
// 不是编译器的可见性模型。因此：
// · 它**不**保证这两个类型没被别的方式外溢（那由 `PublicVisibility` /
//   `reachable-type-registry.json` 各自的判据管）；
// · 它**只**认单行 `@_spi(组名)` 这一种写法 —— 与 `public` 写在同一行的形态
//   （`@_spi(X) public enum …`）也认，见 `scan(text:file:)`；
// · 反方向（**新增**一个 `@_spi` 声明）同样判红，那是有意的：SPI 面扩张必须是
//   一次显式的、有人签字的登记表变更，不能顺手带进来。
@Suite("#294 @_spi 单向棘轮：SPI 面不得静默外溢或扩张")
struct SPIVisibilityGuard {

    /// 唯一允许的 SPI 组名。
    nonisolated static let expectedGroup = "CoreDesignBenchmark"

    /// 一条 `@_spi` 的 `public` 声明。
    nonisolated struct SPIDeclaration: Hashable, Comparable, CustomStringConvertible {
        let group: String
        let name: String

        var description: String { "@_spi(\(self.group)) \(self.name)" }

        static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.name, lhs.group) < (rhs.name, rhs.group)
        }
    }

    // MARK: - 登记表

    /// ⚠️⚠️ **改这张表 = 改公开 API 面的形状。**
    /// 往里加一条，等于声明「本仓又多了一件只给基准看的仪器」；
    /// 从里删一条，等于声明「那件仪器已经彻底移除」（**不是**「它变成正式 API 了」——
    /// 后者要走 `PublicVisibility` / `reachable-type-registry.json` 的登记流程）。
    nonisolated static let registry: Set<SPIDeclaration> = [
        .init(group: "CoreDesignBenchmark", name: "ConfettiRenderProbe"),
        .init(group: "CoreDesignBenchmark", name: "NetworkGraphRenderProbe"),
    ]

    // MARK: - 纯扫描器（供合成输入的变红自证使用）

    /// 从一份源码文本里取出「带 `@_spi(...)` 的 `public` 声明」。
    ///
    /// 认两种形态：
    /// ```swift
    /// @_spi(Group)
    /// public enum Foo { }          // 注解在上一行（可再隔一行 attribute）
    ///
    /// @_spi(Group) public enum Foo { }   // 同一行
    /// ```
    /// ⚠️ **注释行不算「上一行」**：doc comment 里出现 `@_spi` 不得被认成注解
    /// （本仓这两处的文档注释里恰好都写着 `` `@_spi` ``）。
    nonisolated static func scan(text: String) -> [SPIDeclaration] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var out: [SPIDeclaration] = []
        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            // ⚠️ 注释行整行跳过 —— 否则 doc comment 里的 `` `@_spi` `` 会被当成注解。
            guard !line.hasPrefix("//") else { continue }
            guard line.contains("public ") || line.hasPrefix("public") else { continue }
            // 同一行的 `@_spi(...) public …`，或往上最多两行找注解。
            var group: String?
            if let found = Self.spiGroup(inLine: line) {
                group = found
            } else {
                for back in 1...2 where index - back >= 0 {
                    let previous = lines[index - back].trimmingCharacters(in: .whitespaces)
                    if previous.hasPrefix("//") { break }
                    if let found = Self.spiGroup(inLine: previous) { group = found; break }
                    // 只允许中间夹别的 attribute（`@available` 之类）；夹别的代码就断链。
                    if !previous.hasPrefix("@") { break }
                }
            }
            guard let group else { continue }
            guard let name = Self.declaredName(inLine: line) else { continue }
            out.append(.init(group: group, name: name))
        }
        return out
    }

    /// 取一行里 `@_spi(X)` 的 `X`。不是注解写法就返回 `nil`。
    nonisolated static func spiGroup(inLine line: String) -> String? {
        guard let start = line.range(of: "@_spi(") else { return nil }
        // ⚠️ 反引号包起来的 `` `@_spi` `` 是散文，不是注解 —— 上面已整行跳过注释，
        // 这里再防一层：`@_spi(` 之前若紧邻反引号，不算。
        if start.lowerBound > line.startIndex {
            let before = line[line.index(before: start.lowerBound)]
            if before == "`" { return nil }
        }
        let rest = line[start.upperBound...]
        guard let close = rest.firstIndex(of: ")") else { return nil }
        let group = String(rest[..<close]).trimmingCharacters(in: .whitespaces)
        return group.isEmpty ? nil : group
    }

    /// 取一行声明里被声明的名字（`public nonisolated enum Foo {` → `Foo`）。
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

    /// 扫全部 `Sources/` 根，返回「声明 → 出现在哪些文件」。
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

        // ⚠️ 方向一：登记表里有、扫不到 —— **这就是「`@_spi(` 那一行被删掉」的形态**。
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

        // ⚠️ 方向二：扫到了、登记表里没有 —— SPI 面扩张必须显式签字。
        let extra = actual.subtracting(Self.registry).sorted()
        #expect(extra.isEmpty, """
        Sources/ 里有这些 `@_spi` 声明，而登记表没有：\(extra)
        —— SPI 面扩张不能顺手带进来；确认它确实是「只给基准看的仪器」后再登记。
        位置：\(extra.compactMap { found[$0] })
        """)

        // ⚠️ 大小钉死：双向差集已经蕴含它，但把数字写出来能让「表和扫描一起被改小」
        //    这种同向漂移在 diff 上刺眼。
        #expect(actual.count == 2, "扫到 \(actual.count) 条 `@_spi` public 声明，登记的是 2 条")
        #expect(Self.registry.count == 2, "登记表被改成了 \(Self.registry.count) 条 —— 见上一条")

        // ⚠️ 组名必须仍是那一个：换成别的组名同样是「换了一套可见性契约」。
        let groups = Set(actual.map(\.group))
        #expect(groups == [Self.expectedGroup], "SPI 组名不再是唯一的 \(Self.expectedGroup)：\(groups.sorted())")
    }

    @Test("R2：判据自证会开火 —— 合成源码逐个打红")
    func judgeActuallyFires() {
        // ① 删掉 `@_spi(` 那一行 ⇒ 一条都扫不到（⇒ R1 的 `missing` 判红）。
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

        // ② 正常形态必须被扫到（否则上面那条「为空」不构成证据）。
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

        // ③ 同一行的写法也要认。
        #expect(
            Self.scan(text: "@_spi(CoreDesignBenchmark) public enum Probe {}")
                == [.init(group: "CoreDesignBenchmark", name: "Probe")]
        )

        // ④ 换组名必须被看见（⇒ R1 的组名断言判红）。
        #expect(
            Self.scan(text: "@_spi(SomethingElse)\npublic enum Probe {}")
                == [.init(group: "SomethingElse", name: "Probe")]
        )

        // ⑤ doc comment 里的 `` `@_spi` `` 不得被认成注解 —— 本仓这两处的文档注释里
        //    恰好都写着这个词，误认会让「注解已删」仍然扫得到 ⇒ ① 那条通路重新打开。
        #expect(
            Self.scan(text: "/// ⚠️ **`@_spi` 而不是普通 `public`**\npublic enum Probe {}").isEmpty,
            "文档注释里的 `@_spi` 被当成了注解"
        )

        // ⑥ 中间夹一个 attribute 仍算同一条声明；夹了别的代码就断链。
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
