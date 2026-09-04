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

    /// 从 `project.yml` 文本里取「本地 package 的 product 依赖」。
    ///
    /// 返回值的第二项是**不带 `product:` 的裸 `- package: CoreDesign`** 的条数 ——
    /// 那正是 `#245` 记下的失效形态（只会链同名产品），必须被单独看见而不是静默丢弃。
    nonisolated static func localPackageProducts(
        inProjectYAML yaml: String
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

    /// 从 `project.pbxproj` 文本里取「**本地** package 的 product 依赖」。
    ///
    /// ⚠️ 判定「本地」的依据是块里**没有** `package = ...` 行：远程 package
    /// （本仓的 `SnapshotPreviews`）的条目会带一条指向 `XCRemoteSwiftPackageReference`
    /// 的 `package =`。本地 package 在 xcodegen 生成的 pbxproj 里不带这一行。
    ///
    /// 返回 `nil` 表示**根本没找到那个 section** —— 调用方必须把它当解析失效处理，
    /// 而不是「零依赖 ⇒ 零违规 ⇒ 绿」。
    nonisolated static func localProductDependencies(inPBXProj text: String) -> [String]? {
        let begin = "/* Begin XCSwiftPackageProductDependency section */"
        let end = "/* End XCSwiftPackageProductDependency section */"
        guard let lower = text.range(of: begin), let upper = text.range(of: end),
              lower.upperBound <= upper.lowerBound
        else { return nil }
        let section = String(text[lower.upperBound..<upper.lowerBound])
        var names: [String] = []
        for chunk in section.components(separatedBy: "};") {
            guard chunk.contains("isa = XCSwiftPackageProductDependency;") else { continue }
            guard !chunk.contains("package = ") else { continue }
            for rawLine in chunk.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("productName = ") else { continue }
                names.append(
                    line.dropFirst("productName = ".count)
                        .trimmingCharacters(in: CharacterSet(charactersIn: " ;\""))
                )
            }
        }
        return names
    }

    // MARK: - 判据

    @Test("K1：project.yml 逐条写的 product 必须覆盖 Package.swift 的全部 library product")
    func projectYAMLCoversEveryLibraryProduct() throws {
        let yaml = try String(contentsOf: Self.projectYAMLURL, encoding: .utf8)
        let parsed = Self.localPackageProducts(inProjectYAML: yaml)
        // ⚠️ 非空前置：解析器失效 ⇒ 空集 ⇒ 下面的差集全空 ⇒ 静默变绿。
        try #require(!parsed.products.isEmpty, """
        从 App/project.yml 一条 `- package: \(Self.localPackageName)` + `product:` 都没解析到 ——
        解析器可能失效（缩进/写法变了），这不是「没有依赖」。
        """)
        #expect(parsed.bareReferences == 0, """
        App/project.yml 里有 \(parsed.bareReferences) 条不带 `product:` 的
        `- package: \(Self.localPackageName)` —— 多 product 下它**只会链同名的 `CoreDesign` 产品**，
        失效形态是「预览宿主编译得过、但画廊里的新组件 import 不到」（`#245`）。
        """)

        let declared = try GuardScanRoots.declaredLibraryTargets()
        try #require(declared.count >= 3, """
        从 Package.swift 只解析到 \(declared.count) 个 library product —— 解析器可能失效。
        """)
        let missing = Set(declared).subtracting(parsed.products).sorted()
        #expect(missing.isEmpty, """
        这些 library product 在 Package.swift 里声明了，却没进 App/project.yml 的依赖：\(missing)
        —— 预览宿主里 `import` 不到它们，而画廊正是这些单位唯一的评审面。
        """)
    }

    @Test("K2：pbxproj 的本地 product 依赖必须与 project.yml 逐条吻合")
    func pbxprojMatchesProjectYAML() throws {
        let yaml = try String(contentsOf: Self.projectYAMLURL, encoding: .utf8)
        let expected = Set(Self.localPackageProducts(inProjectYAML: yaml).products)
        try #require(!expected.isEmpty, "project.yml 侧解析为空 —— 见 K1 的说明")

        let text = try String(contentsOf: Self.pbxprojURL, encoding: .utf8)
        let actualList = try #require(
            Self.localProductDependencies(inPBXProj: text),
            """
            project.pbxproj 里找不到 `XCSwiftPackageProductDependency` section ——
            判据无法工作，这不是「没有漂移」。
            """
        )
        let actual = Set(actualList)

        let missing = expected.subtracting(actual).sorted()
        #expect(missing.isEmpty, """
        App/project.yml 声明了这些 product，而 .xcodeproj 里没有对应的
        `XCSwiftPackageProductDependency`：\(missing)

        ⚠️ 这**正是** `#245`→`#256` 之间真实发生过的那次漂移（yml 三条、pbxproj 一条）。
        成因通常是：改了 `project.yml` 却没重新生成 `.xcodeproj`。
        ⚠️ **不要在 git worktree 里跑 `xcodegen generate`**（会把 local package 的 `name`
        按目录名写死并清空 scheme，见 `App/project.yml` 顶部注释）——
        在主仓生成，或照着既有条目的形态手工补齐。
        """)
        let extra = actual.subtracting(expected).sorted()
        #expect(extra.isEmpty, """
        .xcodeproj 里有这些本地 product 依赖，而 App/project.yml 没有声明：\(extra)
        —— 下次谁真的跑了 `xcodegen generate`，它们会被静默删掉。
        """)
    }

    @Test("K3：判据自证会开火 —— 合成 manifest 逐个打红")
    func judgeActuallyFires() {
        // ① 裸 `- package:`（`#245` 的失效形态）必须被数出来，而不是静默丢弃。
        let bareYAML = """
        targets:
          CoreDesignPreview:
            dependencies:
              - package: CoreDesign
              - package: CoreDesign
                product: CoreDesignEffects
        """
        let bare = Self.localPackageProducts(inProjectYAML: bareYAML)
        #expect(bare.products == ["CoreDesignEffects"], "解析到的 product 不对：\(bare.products)")
        #expect(bare.bareReferences == 1, "裸 `- package:` 没被数到 —— K1 的那条断言形同虚设")

        // ② 注释行不得打断「package 的下一行是 product」的配对。
        let commentedYAML = """
            dependencies:
              - package: CoreDesign
                # 多 product 下必须逐条写 product:
                product: CoreDesignCharts
        """
        #expect(Self.localPackageProducts(inProjectYAML: commentedYAML).products
            == ["CoreDesignCharts"])

        // ③ pbxproj 侧：远程 package 的条目（带 `package = `）**不得**被算成本地依赖，
        //    而缺条目必须真的少一项 —— 这就是 `#245`→`#256` 那次漂移的合成复现。
        let driftedPBX = """
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
        #expect(Self.localProductDependencies(inPBXProj: driftedPBX) == ["CoreDesign"], """
        合成 pbxproj 解析结果不对 —— 要么远程条目被误算成本地，要么本地条目没被认出来
        """)
        // ④ section 缺失必须返回 `nil`（⇒ K2 判红），而不是空数组（⇒ 差集恒空 ⇒ 绿）。
        #expect(Self.localProductDependencies(inPBXProj: "// 没有那个 section") == nil, """
        section 缺失时返回了空数组而不是 nil —— K2 会在「解析失效」上判绿，
        这正是本仓反复记在案的「零输入 ⇒ 零违规 ⇒ 绿」。
        """)
    }
}
