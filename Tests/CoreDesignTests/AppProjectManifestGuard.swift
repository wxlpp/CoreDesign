import Foundation
import Testing

// MARK: - 预览宿主的 manifest 一致性判据 / App manifest consistency guard（PR #294 终审 S-2）

@Suite("#256 预览宿主 manifest 与 pbxproj 的一致性")
struct AppProjectManifestGuard {
    nonisolated static let localPackageName = "CoreDesign"

    static var projectYAMLURL: URL {
        GuardScanRoots.repoRoot.appendingPathComponent("App/project.yml")
    }

    static var pbxprojURL: URL {
        GuardScanRoots.repoRoot
            .appendingPathComponent("App/CoreDesignPreview.xcodeproj/project.pbxproj")
    }

    // MARK: - 纯解析器（供合成输入的变红自证使用）

    nonisolated static let previewTargetName = "CoreDesignPreview"

    nonisolated private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

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

    nonisolated static func localPackageProducts(
        inYAMLBlock yaml: String
    ) -> (products: [String], bareReferences: Int) {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var products: [String] = []
        var bare = 0
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed == "- package: \(Self.localPackageName)" else { continue }
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

    nonisolated private static func section(_ name: String, inPBXProj text: String) -> String? {
        let begin = "/* Begin \(name) section */"
        let end = "/* End \(name) section */"
        guard let lower = text.range(of: begin), let upper = text.range(of: end),
              lower.upperBound <= upper.lowerBound
        else { return nil }
        return String(text[lower.upperBound..<upper.lowerBound])
    }

    nonisolated private static func productName(inChunk chunk: String) -> String? {
        for rawLine in chunk.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("productName = ") else { continue }
            return line.dropFirst("productName = ".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: " ;\""))
        }
        return nil
    }

    nonisolated static func packageProductDependencyIDs(
        inPBXProj text: String, target: String
    ) -> [String]? {
        guard let section = Self.section("PBXNativeTarget", inPBXProj: text) else { return nil }
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
        let block = try #require(
            Self.targetBlock(inProjectYAML: yaml, target: Self.previewTargetName),
            """
            App/project.yml 里找不到 `targets:` → `\(Self.previewTargetName):` 这一块 ——
            判据无法工作，这不是「没有漂移」。
            """
        )
        let parsed = Self.localPackageProducts(inYAMLBlock: block)
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
        let bareYAML = """
            dependencies:
              - package: CoreDesign
              - package: CoreDesign
                product: CoreDesignEffects
        """
        let bare = Self.localPackageProducts(inYAMLBlock: bareYAML)
        #expect(bare.products == ["CoreDesignEffects"], "解析到的 product 不对：\(bare.products)")
        #expect(bare.bareReferences == 1, "裸 `- package:` 没被数到 —— K1 的那条断言形同虚设")

        let commentedYAML = """
            dependencies:
              - package: CoreDesign
                # 多 product 下必须逐条写 product:
                product: CoreDesignCharts
        """
        #expect(Self.localPackageProducts(inYAMLBlock: commentedYAML).products
            == ["CoreDesignCharts"])

        #expect(
            Self.localProductDependencies(inPBXProj: Self.driftedPBX, target: "CoreDesignPreview")
                == ["CoreDesign"],
            """
            合成 pbxproj 解析结果不对 —— 要么远程条目被误算成本地，要么本地条目没被认出来
            """
        )
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
        #expect(
            Self.localPackageProducts(
                inYAMLBlock: Self.targetBlock(inProjectYAML: escapedYAML, target: "SnapshotTests") ?? ""
            ).products == ["CoreDesign", "CoreDesignEffects", "CoreDesignCharts"],
            "SnapshotTests 块里那三条没被解析到 —— 那上面那条「为空」就不构成证据"
        )
        #expect(previewBlock?.contains("SnapshotTests") == false, "target 块吃进了下一个 target")

        #expect(
            Self.localProductDependencies(inPBXProj: Self.orphanPBX, target: "CoreDesignPreview")
                == ["CoreDesign"],
            """
            孤儿 `XCSwiftPackageProductDependency`（没被任何 target 的
            `packageProductDependencies` 引用）被算成了依赖 —— 它不参与链接。
            """
        )
        #expect(
            Self.localProductDependencies(inPBXProj: Self.orphanPBX, target: "SnapshotTests") == [],
            "SnapshotTests 只引用了远程 package，本地依赖该是空的"
        )
    }

    // MARK: - 合成输入

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
