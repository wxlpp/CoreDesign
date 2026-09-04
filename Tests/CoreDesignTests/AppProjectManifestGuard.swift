import Foundation
import Testing

// MARK: - 预览宿主的 manifest 一致性判据 / App manifest consistency guard（PR #294 终审 S-2）
//
// ## 它守什么
//
// `App/project.yml`（xcodegen 的输入）与 `App/CoreDesignPreview.xcodeproj/project.pbxproj`
// （实际被 `xcodebuild` 消费的那份）里，**本地 package `CoreDesign` 的 product 依赖必须一致**，
// 且必须覆盖 `Package.swift` 声明的全部 library product。
//
// ## 为什么要一条判据
//
// ⚠️ **这是一次真实的、活了整整一个 epic 的漂移**：`#245` 把包拆成三个 product 之后，
// `App/project.yml` 逐条写了 `product: CoreDesign` / `CoreDesignEffects` / `CoreDesignCharts`，
// 而 `.xcodeproj` 里**只有 `CoreDesign` 一条** —— 因为**没有人在 worktree 里跑
// `xcodegen generate`**（那么做会把 local package 的 `name` 按目录名写死，见
// `App/project.yml` 顶部警告）⇒ 两份文件从此各说各话。
// `#256` 手工补齐了缺的两条 `XCSwiftPackageProductDependency`，但**没有任何东西
// 防止下一次分叉**。
//
// ⚠️⚠️ 它之所以能活这么久，是因为 **`App/` 不在任何一条 CI 腿里**：
// `.github/workflows/ci.yml` 跑 `swift build` / `swift test` /
// `xcodebuild test -scheme CoreDesign-Package` / `downstream-probe`，
// **没有任何一条构建 `App/CoreDesignPreview.xcodeproj`**。
// ⇒ 唯一能在 CI 里看见这件事的位置就是 `swift test`。本判据只解析文本、不构建 App，
// 因此**与 App 本身不同，它会在 CI 里跑**。
//
// ## 射程与已知边界（不要读成比实际更强）
//
// ⚠️ 本判据**不构建 App**，也**不**保证 `.xcodeproj` 的其余部分（sources / settings /
// scheme）与 `project.yml` 同步 —— 它只钉住 product 依赖这一条，因为那正是出过事的那条，
// 且它的失效形态是静默的（「预览宿主编译得过、但画廊里的新组件 import 不到」，`#245`）。
// 其余漂移仍然只能靠手跑 `scripts/run-preview.sh` 或 `xcodebuild -project ...` 发现。
//
// ⚠️⚠️ **两侧都必须认 target 归属**（PR #294 第 2 轮 S-1）。初版**不看条目挂在哪个
// target 下**：`localPackageProducts` 全文扫 `- package: CoreDesign`，
// `localProductDependencies` 只枚举 `XCSwiftPackageProductDependency` **对象**、
// 不解析 `PBXNativeTarget.packageProductDependencies`。评审实测的逃逸形态是
// ——把 `App/project.yml` 里那三条 `- package: / product:` **原封不动挪到
// `SnapshotTests` 的 `dependencies:` 下**（预览宿主从此对本地 package 零依赖），
// pbxproj 一个字不动 ⇒ 三条判据**全绿**。两侧同时 target-blind，于是一致地绿。
// ⇒ 现在 yml 侧按缩进把扫描**收进 `CoreDesignPreview:` 那个 target 块**，
// pbxproj 侧先取 `PBXNativeTarget` 里 `productName = CoreDesignPreview` 那块的
// `packageProductDependencies` UUID 列表，再拿它去交叉
// `XCSwiftPackageProductDependency` 对象。
// ⇒ 顺带堵住**孤儿形态**（对象在 section 里存在、却没有任何 target 引用它）——
// 那正是 K2 失败信息推荐的「照着既有条目手工补齐」最容易产出的东西。
@Suite("#256 预览宿主 manifest 与 pbxproj 的一致性")
struct AppProjectManifestGuard {

    /// `App/project.yml` 里本地 package 的名字（`packages:` 下那一条）。
    nonisolated static let localPackageName = "CoreDesign"

    static var projectYAMLURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent("App/project.yml")
    }

    static var pbxprojURL: URL {
        GuardScanRoots.repoRoot
            .appendingPathComponent("App/CoreDesignPreview.xcodeproj/project.pbxproj")
    }

    // MARK: - 纯解析器（供合成输入的变红自证使用）

    /// 预览宿主 target 在 `project.yml` / pbxproj 两侧的名字。
    nonisolated static let previewTargetName = "CoreDesignPreview"

    nonisolated private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    /// 从 `project.yml` 里切出 `targets:` → `<target>:` 那一块的文本（不含 target 行本身）。
    ///
    /// ⚠️ 返回 `nil` 表示**没找到那个 target 块** —— 调用方必须当解析失效处理，
    /// 而不是「零依赖 ⇒ 零违规 ⇒ 绿」。块的终点是「第一条缩进 ≤ target 行缩进的
    /// 非空非注释行」；空行与注释行一律并入块内（否则一个空行就能把块提前截断）。
    nonisolated static func targetBlock(inProjectYAML yaml: String, target: String) -> String? {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        func isSkippable(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix("#")
        }
        guard let targetsIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "targets:" && Self.indentation(of: $0) == 0
        }) else { return nil }

        var start: Int?
        var targetIndent = 0
        var cursor = targetsIndex + 1
        while cursor < lines.count {
            let line = lines[cursor]
            if isSkippable(line) { cursor += 1; continue }
            let indent = Self.indentation(of: line)
            // 缩进回到 0 ⇒ 已经离开 `targets:` 这一节。
            if indent == 0 { break }
            if line.trimmingCharacters(in: .whitespaces) == "\(target):" {
                start = cursor + 1
                targetIndent = indent
                break
            }
            cursor += 1
        }
        guard let first = start else { return nil }

        var block: [String] = []
        var index = first
        while index < lines.count {
            let line = lines[index]
            if !isSkippable(line), Self.indentation(of: line) <= targetIndent { break }
            block.append(line)
            index += 1
        }
        return block.joined(separator: "\n")
    }

    /// 从**某一个 target 块**的文本里取「本地 package 的 product 依赖」。
    ///
    /// 返回值的第二项是**不带 `product:` 的裸 `- package: CoreDesign`** 的条数 ——
    /// 那正是 `#245` 记下的失效形态（只会链同名产品），必须被单独看见而不是静默丢弃。
    ///
    /// ⚠️ **它只扫喂进来的那段文本**。target 归属由 `targetBlock(inProjectYAML:target:)`
    /// 负责 —— 直接把整份 yml 喂进来，就退回成 S-1 记的那个 target-blind 版本。
    nonisolated static func localPackageProducts(
        inYAMLBlock yaml: String
    ) -> (products: [String], bareReferences: Int) {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var products: [String] = []
        var bare = 0
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed == "- package: \(Self.localPackageName)" else { continue }
            // 往后找第一条非空、非注释行；它必须是 `product: X`。
            var next = index + 1
            var matched = false
            while next < lines.count {
                let candidate = lines[next].trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty || candidate.hasPrefix("#") { next += 1; continue }
                if candidate.hasPrefix("product:") {
                    products.append(
                        candidate.dropFirst("product:".count).trimmingCharacters(in: .whitespaces)
                    )
                    matched = true
                }
                break
            }
            if !matched { bare += 1 }
        }
        return (products, bare)
    }

    /// 切出 pbxproj 的某一个 section（不含首尾那两行注释）。返回 `nil` = 没有那个 section。
    nonisolated private static func section(_ name: String, inPBXProj text: String) -> String? {
        let begin = "/* Begin \(name) section */"
        let end = "/* End \(name) section */"
        guard let lower = text.range(of: begin), let upper = text.range(of: end),
              lower.upperBound <= upper.lowerBound
        else { return nil }
        return String(text[lower.upperBound..<upper.lowerBound])
    }

    /// 取块里的 `productName` 值（`productName = X;` / `productName = "X";` 两种形态）。
    nonisolated private static func productName(inChunk chunk: String) -> String? {
        for rawLine in chunk.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("productName = ") else { continue }
            return line.dropFirst("productName = ".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: " ;\""))
        }
        return nil
    }

    /// 取 `PBXNativeTarget` 里 `productName = <target>` 那一块引用的
    /// `packageProductDependencies` UUID 列表。
    ///
    /// ⚠️ 返回 `nil` 分三种失效：section 缺失 / 找不到那个 target / 那个 target 没有
    /// `packageProductDependencies = (` 这一段。**三种都必须判红**，不能塌成空集。
    nonisolated static func packageProductDependencyIDs(
        inPBXProj text: String, target: String
    ) -> [String]? {
        guard let section = Self.section("PBXNativeTarget", inPBXProj: text) else { return nil }
        // ⚠️ `PBXNativeTarget` 块里只有 `( … );` 这种括号、没有嵌套的 `};`
        // ⇒ 按 `};` 切块是安全的（与下面 SPD 侧同一套切法）。
        for chunk in section.components(separatedBy: "};") {
            guard chunk.contains("isa = PBXNativeTarget;") else { continue }
            guard Self.productName(inChunk: chunk) == target else { continue }
            guard let listStart = chunk.range(of: "packageProductDependencies = (")
            else { return nil }
            let rest = chunk[listStart.upperBound...]
            guard let listEnd = rest.range(of: ");") else { return nil }
            var ids: [String] = []
            for rawLine in rest[..<listEnd.lowerBound].split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard let id = line.split(whereSeparator: { $0 == " " || $0 == "," }).first
                else { continue }
                ids.append(String(id))
            }
            return ids
        }
        return nil
    }

    /// 从 `project.pbxproj` 文本里取「**某个 target 真的引用了的**、本地 package 的
    /// product 依赖」。
    ///
    /// ⚠️ 判定「本地」的依据是块里**没有** `package = ...` 行：远程 package
    /// （本仓的 `SnapshotPreviews`）的条目会带一条指向 `XCRemoteSwiftPackageReference`
    /// 的 `package =`。本地 package 在 xcodegen 生成的 pbxproj 里不带这一行。
    ///
    /// ⚠️⚠️ **必须先过 target 的引用列表**（PR #294 第 2 轮 S-1）：只枚举
    /// `XCSwiftPackageProductDependency` **对象**的旧版本既认不出「依赖挂错了 target」，
    /// 也认不出**孤儿对象**（section 里有、却没有任何 target 引用它）——
    /// 而后者正是 K2 的失败信息推荐的「照着既有条目手工补齐」最容易产出的东西。
    ///
    /// 返回 `nil` 表示**解析失效**（section 缺失 / target 缺失 / 引用列表缺失）——
    /// 调用方必须把它当判据失效处理，而不是「零依赖 ⇒ 零违规 ⇒ 绿」。
    nonisolated static func localProductDependencies(
        inPBXProj text: String, target: String
    ) -> [String]? {
        guard let referenced = Self.packageProductDependencyIDs(inPBXProj: text, target: target)
        else { return nil }
        guard let section = Self.section("XCSwiftPackageProductDependency", inPBXProj: text)
        else { return nil }
        let referencedSet = Set(referenced)
        var names: [String] = []
        for chunk in section.components(separatedBy: "};") {
            guard chunk.contains("isa = XCSwiftPackageProductDependency;") else { continue }
            guard !chunk.contains("package = ") else { continue }
            // 对象自己的 UUID：块里第一条形如 `<UUID> /* X */ = {` 的行的首个 token。
            guard let objectID = chunk.split(separator: "\n")
                .compactMap({ rawLine -> String? in
                    let line = rawLine.trimmingCharacters(in: .whitespaces)
                    guard line.hasSuffix("= {") else { return nil }
                    return line.split(separator: " ").first.map(String.init)
                })
                .first
            else { continue }
            guard referencedSet.contains(objectID) else { continue }
            if let name = Self.productName(inChunk: chunk) { names.append(name) }
        }
        return names
    }

    // MARK: - 判据

    @Test("K1：project.yml 逐条写的 product 必须覆盖 Package.swift 的全部 library product")
    func projectYAMLCoversEveryLibraryProduct() throws {
        let yaml = try String(contentsOf: Self.projectYAMLURL, encoding: .utf8)
        // ⚠️ **先按 target 收窄**（S-1）：全文扫描时，把三条依赖挪到 `SnapshotTests` 下
        // 照样全绿 —— 而那时预览宿主对本地 package 是零依赖。
        let block = try #require(
            Self.targetBlock(inProjectYAML: yaml, target: Self.previewTargetName),
            """
            App/project.yml 里找不到 `targets:` → `\(Self.previewTargetName):` 这一块 ——
            判据无法工作，这不是「没有漂移」。
            """
        )
        let parsed = Self.localPackageProducts(inYAMLBlock: block)
        // ⚠️ 非空前置：解析器失效 ⇒ 空集 ⇒ 下面的差集全空 ⇒ 静默变绿。
        try #require(!parsed.products.isEmpty, """
        从 App/project.yml 的 `\(Self.previewTargetName)` target 下一条
        `- package: \(Self.localPackageName)` + `product:` 都没解析到 ——
        要么解析器失效（缩进/写法变了），要么依赖被挪到了别的 target 下。
        两种都不是「没有依赖」。
        """)
        #expect(parsed.bareReferences == 0, """
        App/project.yml 的 \(Self.previewTargetName) target 下有 \(parsed.bareReferences) 条不带 `product:` 的
        `- package: \(Self.localPackageName)` —— 多 product 下它**只会链同名的 `CoreDesign` 产品**，
        失效形态是「预览宿主编译得过、但画廊里的新组件 import 不到」（`#245`）。
        """)

        let declared = try GuardScanRoots.declaredLibraryTargets()
        try #require(declared.count >= 3, """
        从 Package.swift 只解析到 \(declared.count) 个 library product —— 解析器可能失效。
        """)
        let missing = Set(declared).subtracting(parsed.products).sorted()
        #expect(missing.isEmpty, """
        这些 library product 在 Package.swift 里声明了，却没进 App/project.yml 的
        \(Self.previewTargetName) target 依赖：\(missing)
        —— 预览宿主里 `import` 不到它们，而画廊正是这些单位唯一的评审面。
        """)
    }

    @Test("K2：pbxproj 的本地 product 依赖必须与 project.yml 逐条吻合")
    func pbxprojMatchesProjectYAML() throws {
        let yaml = try String(contentsOf: Self.projectYAMLURL, encoding: .utf8)
        let block = try #require(
            Self.targetBlock(inProjectYAML: yaml, target: Self.previewTargetName),
            "App/project.yml 里找不到 `\(Self.previewTargetName):` 这一块 —— 见 K1 的说明"
        )
        let expected = Set(Self.localPackageProducts(inYAMLBlock: block).products)
        try #require(!expected.isEmpty, "project.yml 侧解析为空 —— 见 K1 的说明")

        let text = try String(contentsOf: Self.pbxprojURL, encoding: .utf8)
        let actualList = try #require(
            Self.localProductDependencies(inPBXProj: text, target: Self.previewTargetName),
            """
            project.pbxproj 里解析不出 \(Self.previewTargetName) 的本地 product 依赖 ——
            可能是 `PBXNativeTarget` / `XCSwiftPackageProductDependency` section 缺失、
            找不到 `productName = \(Self.previewTargetName)` 那个 target，
            或它没有 `packageProductDependencies = (` 那一段。
            判据无法工作，这不是「没有漂移」。
            """
        )
        let actual = Set(actualList)

        let missing = expected.subtracting(actual).sorted()
        #expect(missing.isEmpty, """
        App/project.yml 的 \(Self.previewTargetName) 声明了这些 product，而 .xcodeproj 里
        \(Self.previewTargetName) 这个 target **没有引用**对应的
        `XCSwiftPackageProductDependency`：\(missing)

        ⚠️ 「section 里有那个对象」不算数 —— 对象必须出现在该 target 的
        `packageProductDependencies = ( … )` 列表里，否则它是个孤儿、不参与链接。

        ⚠️ 这**正是** `#245`→`#256` 之间真实发生过的那次漂移（yml 三条、pbxproj 一条）。
        成因通常是：改了 `project.yml` 却没重新生成 `.xcodeproj`。
        ⚠️ **不要在 git worktree 里跑 `xcodegen generate`**（会把 local package 的 `name`
        按目录名写死并清空 scheme，见 `App/project.yml` 顶部注释）——
        在主仓生成，或照着既有条目的形态手工补齐。
        """)
        let extra = actual.subtracting(expected).sorted()
        #expect(extra.isEmpty, """
        .xcodeproj 的 \(Self.previewTargetName) 引用了这些本地 product 依赖，
        而 App/project.yml 的同名 target 没有声明：\(extra)
        —— 下次谁真的跑了 `xcodegen generate`，它们会被静默删掉。
        """)
    }

    @Test("K3：判据自证会开火 —— 合成 manifest 逐个打红")
    func judgeActuallyFires() {
        // ① 裸 `- package:`（`#245` 的失效形态）必须被数出来，而不是静默丢弃。
        let bareYAML = """
            dependencies:
              - package: CoreDesign
              - package: CoreDesign
                product: CoreDesignEffects
        """
        let bare = Self.localPackageProducts(inYAMLBlock: bareYAML)
        #expect(bare.products == ["CoreDesignEffects"], "解析到的 product 不对：\(bare.products)")
        #expect(bare.bareReferences == 1, "裸 `- package:` 没被数到 —— K1 的那条断言形同虚设")

        // ② 注释行不得打断「package 的下一行是 product」的配对。
        let commentedYAML = """
            dependencies:
              - package: CoreDesign
                # 多 product 下必须逐条写 product:
                product: CoreDesignCharts
        """
        #expect(Self.localPackageProducts(inYAMLBlock: commentedYAML).products
            == ["CoreDesignCharts"])

        // ③ pbxproj 侧：远程 package 的条目（带 `package = `）**不得**被算成本地依赖，
        //    而缺条目必须真的少一项 —— 这就是 `#245`→`#256` 那次漂移的合成复现。
        #expect(
            Self.localProductDependencies(inPBXProj: Self.driftedPBX, target: "CoreDesignPreview")
                == ["CoreDesign"],
            """
            合成 pbxproj 解析结果不对 —— 要么远程条目被误算成本地，要么本地条目没被认出来
            """
        )
        // ④ 解析失效必须返回 `nil`（⇒ K2 判红），而不是空数组（⇒ 差集恒空 ⇒ 绿）。
        #expect(
            Self.localProductDependencies(inPBXProj: "// 没有那些 section", target: "CoreDesignPreview")
                == nil,
            """
            section 缺失时返回了空数组而不是 nil —— K2 会在「解析失效」上判绿，
            这正是本仓反复记在案的「零输入 ⇒ 零违规 ⇒ 绿」。
            """
        )
        #expect(
            Self.localProductDependencies(inPBXProj: Self.driftedPBX, target: "NoSuchTarget") == nil,
            "找不到那个 target 时必须返回 nil —— 否则「target 改名了」会静默判绿"
        )
    }

    // MARK: - K4：**target 归属**必须被认出来（PR #294 第 2 轮 S-1 的那枚变异）

    @Test("K4：把依赖挪到别的 target 下，两侧都必须判红而不是全绿")
    func targetOwnershipIsNotBlind() {
        // ⓐ yml 侧：三条依赖原封不动挪到 `SnapshotTests` 下 —— 评审实测的逃逸形态。
        //    旧版全文扫描会照样解析出三条 product ⇒ K1/K2 全绿，而预览宿主已经
        //    对本地 package 零依赖。现在 `CoreDesignPreview` 块里必须一条都取不到。
        let escapedYAML = """
        targets:
          CoreDesignPreview:
            type: application
            sources:
              - path: Sources
            settings:
              base:
                SWIFT_VERSION: "6.0"

          SnapshotTests:
            type: bundle.unit-test
            dependencies:
              - target: CoreDesignPreview
              - package: CoreDesign
                product: CoreDesign
              - package: CoreDesign
                product: CoreDesignEffects
              - package: CoreDesign
                product: CoreDesignCharts
        """
        let previewBlock = Self.targetBlock(
            inProjectYAML: escapedYAML, target: "CoreDesignPreview"
        )
        #expect(previewBlock != nil, "切不出 CoreDesignPreview 块 —— K1 会在解析失效上判红，但这里该切得出来")
        #expect(
            Self.localPackageProducts(inYAMLBlock: previewBlock ?? "").products.isEmpty,
            """
            依赖挂在 SnapshotTests 下，却被算进了 CoreDesignPreview ——
            扫描仍是 target-blind 的，S-1 那枚变异会重新全绿。
            """
        )
        // 对照：同一份 yml 里，SnapshotTests 块**确实**能解析到那三条。
        #expect(
            Self.localPackageProducts(
                inYAMLBlock: Self.targetBlock(inProjectYAML: escapedYAML, target: "SnapshotTests") ?? ""
            ).products == ["CoreDesign", "CoreDesignEffects", "CoreDesignCharts"],
            "SnapshotTests 块里那三条没被解析到 —— 那上面那条「为空」就不构成证据"
        )
        // 块边界：`CoreDesignPreview` 的 `settings:` 之后必须停住，不得吃进下一个 target。
        #expect(previewBlock?.contains("SnapshotTests") == false, "target 块吃进了下一个 target")

        // ⓑ pbxproj 侧：对象在 section 里、但没有任何 target 引用它（孤儿形态）——
        //    那正是 K2 失败信息推荐的「手工补齐」最容易产出的东西。
        //    旧版只枚举对象 ⇒ 会把孤儿算成依赖 ⇒ 静默变绿。
        #expect(
            Self.localProductDependencies(inPBXProj: Self.orphanPBX, target: "CoreDesignPreview")
                == ["CoreDesign"],
            """
            孤儿 `XCSwiftPackageProductDependency`（没被任何 target 的
            `packageProductDependencies` 引用）被算成了依赖 —— 它不参与链接。
            """
        )
        // 对照：同一份 pbxproj 里，那个孤儿对象确实挂在 SnapshotTests 之外，
        // 而 SnapshotTests 自己只有远程条目 ⇒ 本地依赖为空。
        #expect(
            Self.localProductDependencies(inPBXProj: Self.orphanPBX, target: "SnapshotTests") == [],
            "SnapshotTests 只引用了远程 package，本地依赖该是空的"
        )
    }

    // MARK: - 合成输入

    /// `#245`→`#256` 那次漂移的合成复现：yml 三条、pbxproj 只有一条。
    nonisolated static let driftedPBX = """
    /* Begin PBXNativeTarget section */
    \t\t2E04 /* CoreDesignPreview */ = {
    \t\t\tisa = PBXNativeTarget;
    \t\t\tdependencies = (
    \t\t\t);
    \t\t\tname = CoreDesignPreview;
    \t\t\tpackageProductDependencies = (
    \t\t\t\tEBA0 /* CoreDesign */,
    \t\t\t);
    \t\t\tproductName = CoreDesignPreview;
    \t\t};
    /* End PBXNativeTarget section */

    /* Begin XCSwiftPackageProductDependency section */
    \t\tB3CA /* SnapshottingTests */ = {
    \t\t\tisa = XCSwiftPackageProductDependency;
    \t\t\tpackage = B734 /* XCRemoteSwiftPackageReference "SnapshotPreviews" */;
    \t\t\tproductName = SnapshottingTests;
    \t\t};
    \t\tEBA0 /* CoreDesign */ = {
    \t\t\tisa = XCSwiftPackageProductDependency;
    \t\t\tproductName = CoreDesign;
    \t\t};
    /* End XCSwiftPackageProductDependency section */
    """

    /// 孤儿形态：`CoreDesignEffects` 的对象在 section 里存在，
    /// 但**没有任何 target 的 `packageProductDependencies` 引用它**。
    nonisolated static let orphanPBX = """
    /* Begin PBXNativeTarget section */
    \t\t0887 /* SnapshotTests */ = {
    \t\t\tisa = PBXNativeTarget;
    \t\t\tname = SnapshotTests;
    \t\t\tpackageProductDependencies = (
    \t\t\t\tB3CA /* SnapshottingTests */,
    \t\t\t);
    \t\t\tproductName = SnapshotTests;
    \t\t};
    \t\t2E04 /* CoreDesignPreview */ = {
    \t\t\tisa = PBXNativeTarget;
    \t\t\tname = CoreDesignPreview;
    \t\t\tpackageProductDependencies = (
    \t\t\t\tEBA0 /* CoreDesign */,
    \t\t\t);
    \t\t\tproductName = CoreDesignPreview;
    \t\t};
    /* End PBXNativeTarget section */

    /* Begin XCSwiftPackageProductDependency section */
    \t\tB3CA /* SnapshottingTests */ = {
    \t\t\tisa = XCSwiftPackageProductDependency;
    \t\t\tpackage = B734 /* XCRemoteSwiftPackageReference "SnapshotPreviews" */;
    \t\t\tproductName = SnapshottingTests;
    \t\t};
    \t\tEBA0 /* CoreDesign */ = {
    \t\t\tisa = XCSwiftPackageProductDependency;
    \t\t\tproductName = CoreDesign;
    \t\t};
    \t\tEBA1 /* CoreDesignEffects */ = {
    \t\t\tisa = XCSwiftPackageProductDependency;
    \t\t\tproductName = CoreDesignEffects;
    \t\t};
    /* End XCSwiftPackageProductDependency section */
    """
}
