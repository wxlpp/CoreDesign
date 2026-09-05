import Foundation
import Testing

@Suite("组件判据扫描层")
struct ComponentJudgeScannerTests {

    // MARK: - 文本型参数分类器 / Text parameter classification

    @Test("裸文本：String 的各种等价拼法都判 .bareText")
    func bareTextSpellings() {
        for spelling in [
            "String", "Swift.String", "String?", "String!", "(String)", "((String))",
            "Optional<String>", "Swift.Optional<Swift.String>", "Optional<(String)>",
            "`String`", "String /* 说明 */", "(String/*x*/)", "Swift . String",
            "consuming String", "sending String", "_const String", "borrowing(String)",
            "@autoclosure () -> String", "@autoclosure() -> String", "@autoclosure () throws -> String",
        ] {
            #expect(
                classifyTextParameterType(spelling, stringProtocolGenerics: []) == .bareText,
                "「\(spelling)」应判 .bareText —— 调用点与 `f(title: \"x\")` 逐字相同，漏判即免登记逃逸"
            )
        }
    }

    @Test("可本地化文本：LSK / LSR 及其可选形态判 .localizedText")
    func localizedSpellings() {
        for spelling in [
            "LocalizedStringKey", "LocalizedStringKey?", "SwiftUI.LocalizedStringKey",
            "LocalizedStringResource", "Optional<LocalizedStringResource>",
            "Foundation.LocalizedStringResource?",
        ] {
            #expect(
                classifyTextParameterType(spelling, stringProtocolGenerics: []) == .localizedText,
                "「\(spelling)」应判 .localizedText —— AC 明令 LSK/LSR 不能被当成「未知类型」漏判"
            )
        }
    }

    @Test("StringProtocol 泛型形参名判 .bareText（`init<S: StringProtocol>(title: S)`）")
    func stringProtocolGenericIsBare() {
        #expect(classifyTextParameterType("S", stringProtocolGenerics: ["S"]) == .bareText)
        #expect(classifyTextParameterType("S?", stringProtocolGenerics: ["S"]) == .bareText)
        // 不在集合里的泛型名不能误判 —— 否则任何 `T` 都成了文本参数。
        #expect(classifyTextParameterType("T", stringProtocolGenerics: ["S"]) == .notText)
    }

    @Test("some/any StringProtocol 判 .bareText —— 与 `<S: StringProtocol>(title: S)` 是同一声明的语法糖、调用点逐字相同（#40 Task 2 评审 Important-1）")
    func stringProtocolOpaqueOrExistentialIsBare() {
        for spelling in ["some StringProtocol", "any StringProtocol", "some StringProtocol?", "any StringProtocol?"] {
            #expect(
                classifyTextParameterType(spelling, stringProtocolGenerics: []) == .bareText,
                "「\(spelling)」应判 .bareText —— 类型文本逐字含 StringProtocol，与泛型形态结论必须一致"
            )
        }
        // 负例：词边界——`some`/`any` 后面紧跟标识符字符（不是空格）不得被误剥前缀。
        // 若误用 `hasPrefix("some")`（不带空格），`someCustomType` 会被剥成
        // `CustomType`，与本例无关地判 .notText 只是巧合；换一个「剥了之后恰好撞进
        // StringProtocol 判据」的输入就会被误判 .bareText，所以这里同时钉住剥离结果
        // 与最终分类两层。
        #expect(
            classifyTextParameterType("someCustomType", stringProtocolGenerics: []) == .notText,
            "「someCustomType」不含空格分隔的 some 前缀，不应被剥掉后误判"
        )
        #expect(
            classifyTextParameterType("anyCustomType", stringProtocolGenerics: []) == .notText,
            "「anyCustomType」不含空格分隔的 any 前缀，不应被剥掉后误判"
        )
        #expect(
            stripSomeOrAnyPrefix("someCustomType") == nil,
            "剥离函数本身也必须对无空格的 some 前缀返回 nil，不能只靠下游巧合兜底"
        )
        // ⚠️ 上面两个负例即使实现写成 `hasPrefix("some")` 也照样绿（剥出的
        // `CustomType` / `AnyCustomType` 本来就不在 StringProtocol 集合里）——它们钉的是
        // 剥离函数那一层。下面这两条才是**唯一会在错误实现下变成假阳性**的输入：
        // `hasPrefix("some")` 会把 `someStringProtocol` 剥成 `StringProtocol`、恰好撞进
        // 集合而误判 .bareText。缺了它们，「词边界安全」这个宣称就没有承重的反例。
        for spelling in ["someStringProtocol", "anyStringProtocol"] {
            #expect(
                classifyTextParameterType(spelling, stringProtocolGenerics: []) == .notText,
                "「\(spelling)」没有空格分隔，不是 opaque/existential 写法，剥前缀就会撞进 StringProtocol 集合误判"
            )
        }
    }

    @Test("返回位是文本的函数类型判为文本（登记表把 `(Item) -> String` 记成 textParams）")
    func textProducingClosureIsText() {
        #expect(classifyTextParameterType("@escaping (Item) -> String", stringProtocolGenerics: []) == .bareText)
        #expect(classifyTextParameterType("(Item) -> LocalizedStringKey", stringProtocolGenerics: []) == .localizedText)
        // ⚠️ 反向：把文本**传出去**的回调不是文本参数入口，判 .textCarrying。
        #expect(classifyTextParameterType("((String) -> Void)?", stringProtocolGenerics: []) == .textCarrying)
        #expect(classifyTextParameterType("@escaping (String) -> Void", stringProtocolGenerics: []) == .textCarrying)
    }

    @Test("双向 / 容器形态判 .textCarrying（清点、不进判据）")
    func carryingSpellings() {
        for spelling in ["Binding<String>", "Binding<[String]>", "[String]", "inout String", "[String: String]"] {
            #expect(
                classifyTextParameterType(spelling, stringProtocolGenerics: []) == .textCarrying,
                "「\(spelling)」应判 .textCarrying"
            )
        }
    }

    @Test("非文本判 .notText")
    func notTextSpellings() {
        for spelling in ["Int", "Color", "Double?", "() -> Void", "MyStringish", "StringLike"] {
            #expect(
                classifyTextParameterType(spelling, stringProtocolGenerics: []) == .notText,
                "「\(spelling)」应判 .notText"
            )
        }
    }

    // MARK: - 文本参数采集器 / Text parameter collector

    @Test("采集器：public init 的裸文本参数进 bareTextKeys")
    func collectorPicksUpPublicInitBareText() {
        let scan = scanComponentJudgeInputs(source: """
        public struct Widget {
            public init(title: String, count: Int) {}
        }
        """, fileName: "Widget.swift")
        #expect(scan.bareTextKeys == ["Widget.init#title"])
        #expect(scan.localizedTextKeys.isEmpty)
    }

    @Test("采集器：非 public 与 private 容器整体不可见")
    func collectorSkipsNonPublic() {
        let scan = scanComponentJudgeInputs(source: """
        public struct A { init(title: String) {} }
        struct B { public init(title: String) {} }
        private struct C { public init(title: String) {} }
        """, fileName: "X.swift")
        #expect(scan.bareTextKeys.isEmpty, "三种都不是有效 public，扫到任何一条都是多报")
    }

    @Test("采集器：public extension 给成员与嵌套具名类型发默认 public（裁决 g）")
    func collectorHandlesPublicExtension() {
        let scan = scanComponentJudgeInputs(source: """
        public extension Widget {
            init(subtitle: String) {}
            struct Options { public init(hint: String) {} }
        }
        """, fileName: "X.swift")
        #expect(scan.bareTextKeys == ["Widget.init#subtitle", "Widget.Options.init#hint"])
    }

    @Test("采集器：`init<S: StringProtocol>` 的泛型形参判裸文本（含 where 子句写法）")
    func collectorResolvesStringProtocolGenerics() {
        let scan = scanComponentJudgeInputs(source: """
        public struct A {
            public init<S: StringProtocol>(title: S, subtitle: S?) {}
            public init<T>(name: T) where T: StringProtocol {}
            public init<U>(other: U) {}
        }
        """, fileName: "X.swift")
        #expect(scan.bareTextKeys == ["A.init#title", "A.init#subtitle", "A.init#name"])
    }

    @Test("采集器：init 与 func 分桶（FR-4 主判据只吃 init）")
    func collectorTagsInitializers() {
        let scan = scanComponentJudgeInputs(source: """
        public struct A {
            public init(title: String) {}
            public func show(_ message: String) {}
        }
        """, fileName: "X.swift")
        #expect(Set(scan.textParams.filter(\.isInitializer).map(\.key)) == ["A.init#title"])
        #expect(Set(scan.textParams.filter { !$0.isInitializer }.map(\.key)) == ["A.show#message"])
    }

    @Test("采集器：`#if` 两支都走、`#Preview` 整块跳过")
    func collectorWalksBothIfConfigBranchesAndSkipsPreview() {
        let scan = scanComponentJudgeInputs(source: """
        #if os(iOS)
        public struct A { public init(title: String) {} }
        #else
        public struct A { public init(caption: String) {} }
        #endif
        #Preview("x") { PreviewOnly(text: "y") }
        public struct PreviewOnly { public init(text: String) {} }
        """, fileName: "X.swift")
        #expect(scan.bareTextKeys == ["A.init#title", "A.init#caption", "PreviewOnly.init#text"],
                "`#if` 只走一支会漏采；`#Preview` 块内不得采集，块外的同名类型声明照采")
    }

    @Test("采集器：Binding / 回调进 carrying，不进 bareText")
    func collectorSeparatesCarrying() {
        let scan = scanComponentJudgeInputs(source: """
        public struct A {
            public init(text: Binding<String>, onSubmit: ((String) -> Void)?) {}
        }
        """, fileName: "X.swift")
        #expect(scan.bareTextKeys.isEmpty)
        #expect(scan.carryingKeys == ["A.init#text", "A.init#onSubmit"])
    }

    // MARK: - 自有样式协议 / Custom style protocols

    @Test("样式协议识别：信号是 makeBody(configuration:) requirement，不是名字里有 Style")
    func styleProtocolSignalIsStructural() {
        let scan = scanComponentJudgeInputs(source: """
        public protocol BannerStyle {
            associatedtype Body: View
            func makeBody(configuration: Self.Configuration) -> Body
            typealias Configuration = BannerStyleConfiguration
        }
        /// 名字里有 Style，但没有 makeBody requirement ⇒ 不是样式协议。
        public protocol StyleToken { var name: String { get } }
        /// 名字里没有 Style，但有 makeBody requirement ⇒ 是样式协议。
        public protocol Appearance {
            associatedtype Body: View
            func makeBody(configuration: Self.Configuration) -> Body
            typealias Configuration = Int
        }
        """, fileName: "X.swift")
        #expect(scan.styleProtocolNames == ["BannerStyle", "Appearance"],
                "识别信号必须是 makeBody(configuration:) 的结构，裸 Style 子串匹配既漏又误伤")
    }

    @Test("样式协议识别：makeBody 的参数标签必须是 configuration")
    func styleProtocolRequiresConfigurationLabel() {
        let scan = scanComponentJudgeInputs(source: """
        public protocol NotAStyle {
            func makeBody(from input: Int) -> Int
        }
        public protocol AlsoNot { func makeBody() -> Int }
        """, fileName: "X.swift")
        #expect(scan.styleProtocolNames.isEmpty)
    }

    @Test("conformance 采集：类型声明与 extension 两条路径都要认")
    func conformanceCollection() {
        let scan = scanComponentJudgeInputs(source: """
        public struct PlainBannerStyle: BannerStyle {}
        public struct Later {}
        extension Later: BannerStyle {}
        public struct Widget: View {}
        """, fileName: "X.swift")
        #expect(scan.conformers(of: "BannerStyle") == ["PlainBannerStyle", "Later"])
        #expect(scan.conformers(of: "View") == ["Widget"])
        #expect(scan.conformers(of: "ProgressViewStyle").isEmpty)
    }

    @Test("conformance 采集：容忍限定名与泛型形参（SwiftUI.View / Foo<T>）")
    func conformanceToleratesQualifiedAndGeneric() {
        let scan = scanComponentJudgeInputs(source: """
        public struct A: SwiftUI.View {}
        public struct B<Item: Hashable>: View {}
        extension C<Int>: BannerStyle {}
        """, fileName: "X.swift")
        #expect(scan.conformers(of: "View") == ["A", "B"])
        #expect(scan.conformers(of: "BannerStyle") == ["C"])
    }

    @Test("类型→文件索引：类型声明与 extension 都记进宿主文件")
    func typeDeclFilesIndex() {
        var scan = scanComponentJudgeInputs(source: """
        public struct Widget: View {}
        """, fileName: "Widget.swift")
        scan.merge(scanComponentJudgeInputs(source: """
        public extension Widget { init(title: String) {} }
        """, fileName: "WidgetExtras.swift"))
        #expect(scan.typeDeclFiles["Widget"] == ["Widget.swift", "WidgetExtras.swift"])
        #expect(scan.typeDeclFiles["Nope"] == nil)
    }

    @Test("真实源码扫描：文本参数三个桶的实测规模")
    func realScanMagnitudes() throws {
        let scan = try scanComponentJudgeInputs(roots: ComponentRegistryGuard.componentScanRoots)
        // ⚠️ 非空断言先行：扫描器失效时「零命中 ⇒ 零违规 ⇒ 绿」会静默通过。
        #expect(scan.bareTextKeys.count > 20, "只扫到 \(scan.bareTextKeys.count) 个裸文本参数 —— 扫描器失效")
        #expect(scan.localizedTextKeys.count > 5, "只扫到 \(scan.localizedTextKeys.count) 个 LSK/LSR 参数 —— 扫描器失效")
        print("裸文本 \(scan.bareTextKeys.count) 个：\(scan.bareTextKeys.sorted())")
        print("LSK/LSR \(scan.localizedTextKeys.count) 个：\(scan.localizedTextKeys.sorted())")
        print("carrying \(scan.carryingKeys.count) 个：\(scan.carryingKeys.sorted())")
        // ⚠️ 非空断言：自有样式协议识别器一旦失效，J-3 的「作用域内没有自有协议 ⇒ 绿」
        // 就变成假绿（零命中 ⇒ 零违规）。这里先钉住它真的认得出东西。
        #expect(scan.styleProtocolNames == ["BannerStyle", "RatingStyle", "SegmentedControlStyle"],
                "本仓自有样式协议实测恰为这三个（#41 裁决 4c 新增 RatingStyle）；集合变了要么是新增了扩展点（预期变化，同步改这里），要么是识别器失效")
        #expect(scan.conformers(of: "ProgressViewStyle").contains("CoreProgressViewStyle"),
                "原生协议 conformance 采集失效 —— J-2 对 nativeProtocol 的核对会因此假绿")
        print("自有样式协议：\(scan.styleProtocols.map { "\($0.name)@\($0.file):\($0.line) styleSuffix=\($0.nameHasStyleSuffix)" }.sorted())")
        print("conformance 记录 \(scan.conformances.count) 条；ProgressViewStyle 实现：\(scan.conformers(of: "ProgressViewStyle").sorted())")
        print("BannerStyle 实现：\(scan.conformers(of: "BannerStyle").sorted())；SegmentedControlStyle 实现：\(scan.conformers(of: "SegmentedControlStyle").sorted())")
    }

    @Test("baseTypeName：已知限度 —— 泛型包装会在 `<` 处截断，接线记录随之丢失")
    func baseTypeNameKnownLimits() {
        // ⚠️ **钉住已知限度，不是期望行为**（与 `j2StyleEnumWiringCannotJudgeSemantics` 同款）。
        // 今天无条目命中，将来真有人把形态枚举做成 `Binding<Layout>` 而被判「没接线」时，
        // 第一时间能查到这是已知形状、不是判据坏了。
        #expect(componentJudgeBaseTypeName("Binding<StepsPresentation>") == "Binding",
                "泛型实参被丢弃 ⇒ 包在 Binding 里的形态枚举登记不到接线")

        // 正常形态：剥可选、剥点分前缀。
        #expect(componentJudgeBaseTypeName("StepsPresentation") == "StepsPresentation")
        #expect(componentJudgeBaseTypeName("StepsPresentation?") == "StepsPresentation")
        #expect(componentJudgeBaseTypeName("SwiftUI.HorizontalEdge") == "HorizontalEdge")

        // 容器 / 闭包 / 带空格的类型一律不参与 D2 接线（返回空串）。
        #expect(componentJudgeBaseTypeName("[StepItem]").isEmpty)
        #expect(componentJudgeBaseTypeName("@escaping () -> Avatars").isEmpty)
        #expect(componentJudgeBaseTypeName("some View").isEmpty)
    }
}

// MARK: - D2 第二条接线通路：`extension View` 上的 modifier 方法（`#65`）

/// 采集口径扩到 `extension View` 的 modifier 方法后，**三条收窄条件**各自的负测试。
///
/// ⚠️ 这些**不是**一次性变异，是**常驻守卫**（`65-plan` 评审 S-4 的建议）：一次性变异
/// 只在跑的那一刻有效，而收窄条件一旦被后人放宽，D2 的第二道门槛会被稀释到没有意义
/// —— 那时**任意公开方法的任意参数**都算「扩展点接线」。
@Suite("D2 接线通路二：extension View modifier 的三条收窄条件")
struct ViewModifierStyleEnumWiringTests {
    private func hosts(_ source: String, of enumName: String) -> Set<String> {
        scanComponentJudgeInputs(source: source).styleEnumHosts[enumName] ?? []
    }

    @Test("正例：public extension View 上返回 some View 的方法，参数被采进接线")
    func positiveCase() {
        let hosts = self.hosts(
            """
            public enum Demo: Sendable {}
            public extension View {
                func demoHost(mode: Demo = .init()) -> some View { self }
            }
            """,
            of: "Demo"
        )
        // ⚠️ hostType 记的是**方法名**，不是 `View` —— 对 modifier 型 API，调用方写的就是方法名。
        #expect(hosts.contains("demoHost"), "公开 extension View modifier 的参数没被采到：\(hosts)")
    }

    @Test("负例（收窄 3）：返回类型不是 some View ⇒ 不采")
    func rejectsNonViewReturn() {
        let hosts = self.hosts(
            """
            public enum Demo: Sendable {}
            public extension View {
                func demoCount(mode: Demo) -> Int { 0 }
            }
            """,
            of: "Demo"
        )
        #expect(hosts.isEmpty, "返回 Int 的方法被当成了扩展点接线：\(hosts)")
    }

    @Test("负例（收窄 1）：不在 extension View 上 ⇒ 不采")
    func rejectsNonViewExtension() {
        let hosts = self.hosts(
            """
            public enum Demo: Sendable {}
            public protocol Other {}
            public extension Other {
                func demoHost(mode: Demo) -> some View { EmptyView() }
            }
            """,
            of: "Demo"
        )
        #expect(hosts.isEmpty, "非 View 扩展上的方法被采了：\(hosts)")
    }

    @Test("负例（收窄 2）：非公开方法 ⇒ 不采")
    func rejectsNonPublicMethod() {
        let hosts = self.hosts(
            """
            public enum Demo: Sendable {}
            extension View {
                func demoHost(mode: Demo) -> some View { self }
            }
            """,
            of: "Demo"
        )
        #expect(hosts.isEmpty, "internal 方法被当成了扩展点接线（调用方够不着它）：\(hosts)")
    }

    @Test("既有 init 通路不受影响：宿主仍记类型名")
    func initPathUnchanged() {
        let hosts = self.hosts(
            """
            public enum Demo: Sendable {}
            public struct Widget {
                public init(mode: Demo) {}
            }
            """,
            of: "Demo"
        )
        #expect(hosts == ["Widget"], "init 通路的宿主不该变（应为类型名）：\(hosts)")
    }
}

// MARK: - 扫描器台账键对符号链接分叉的免疫（`#311` / `#313` 终审 C-1）

/// ⚠️ `scanComponentJudgeInputs(root:)` 里那一处
/// `GuardScanRoots.relativePath(_:from:)` 在 `#313` 终审前**零判据覆盖**：
/// 只把它单独回退成 `url.path.replacingOccurrences(of: root.path + "/", with: "")`，
/// `/Users` checkout 下 `swift test` **全绿**（实测）。唯一沾边的间接守卫
/// `NativeProtocolPurityGuard.nativeProtocolComponentsAreFreeOfCustomStyleProtocols`
/// 走的是**真实扫描根** ⇒ 正常 checkout 下它恒绿，指望不上。
///
/// ⇒ 本 suite 以 `SymlinkedScanRootFixture` 造的**真实**源码树为输入：根的祖先分量是
/// 符号链接，而 `FileManager.enumerator(at:)` 会解析它 ⇒ **在任何机器、任何 checkout
/// 位置、macOS 与 iOS 两条腿上都能复现分叉**，与仓库放哪儿无关。
/// ⚠️ 早一版这里靠 `NSTemporaryDirectory()` 自带的 `/var` → `/private/var` 符号链接，
/// 那在 iOS Simulator 上不成立（实测），是一条会静默恒绿的写法——理由见该 fixture 的文档。
@Suite("扫描器台账键对符号链接分叉的免疫")
struct ComponentJudgeScannerPathKeyTests {

    @Test("台账键的根内相对路径段不被符号链接分叉污染（#311）")
    func componentJudgeKeysAreImmuneToSymlinkDivergence() throws {
        let fixture = try SymlinkedScanRootFixture.make(
            rootName: GuardScanRoots.primaryTargetName,
            files: ["Shape/Cd311KeyProbe.swift": "public struct Cd311KeyProbe {}\n"]
        )
        defer { fixture.destroy() }

        // ① **前提自证**：枚举结果确实与传进去的根**分叉了**（`#313` 第 2 轮终审 I-2）。
        //    没有这一条，本条的有效性就悄悄挂在「`FileManager.enumerator` 会解析祖先符号
        //    链接」这条 Foundation 行为上：哪天它不再解析 ⇒ 两端一致 ⇒ 串替换版**也能**
        //    替换成功 ⇒ 本条在串替换版下**也绿**，退化成本仓反复登记的
        //    「零命中 ⇒ 零违规 ⇒ 绿」。今天这条前提由
        //    `GuardScanRootsGuard.enumeratorResolvesSymlinksInScanRootAncestor` 单独钉着，
        //    但本条不该把它当**事实**默认下来，自己也证一次。
        //    ⚠️ **但它在 macOS 腿上不是干净的判别器，与那条同款 ① 同一条登记**
        //    （`#313` 第 3 轮终审 C-3；那条的登记见
        //    `GuardScanRootsGuard.enumeratorResolvesSymlinksInScanRootAncestor` 的 ①）：
        //    macOS 的 `NSTemporaryDirectory()` 自带 `/var` → `/private/var` 一味，单它就
        //    足以让前缀对不上 ⇒ **fixture 的符号链接那一半只有 iOS 腿钉得住**。
        //    实测（`#313` 第 4 轮 M-I2：把 `SymlinkedScanRootFixture.make` 返回的 `root`
        //    从 `linkDirectoryName` 改成 `realDirectoryName`，符号链接彻底不参与；各跑两遍）
        //    ⇒ macOS `swift test` 两条 ① 双绿（`Test run with 2 tests in 2 suites passed`）、
        //    iOS Simulator 腿两条 ① 双红。
        //    ⇒ 上面那句「哪天 `FileManager.enumerator` 不再解析祖先符号链接」只覆盖
        //    **Foundation 行为变更**这一种攻击面；「**有人把 fixture 改简单了**」这一种更现实，
        //    而它在 macOS 腿上本条**照样绿**。
        let walker = try #require(
            FileManager.default.enumerator(at: fixture.root, includingPropertiesForKeys: nil),
            "无法枚举 fixture 根 —— 判据无法工作，这不是「零违规」"
        )
        var enumerated: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" { enumerated.append(url) }
        let probe = try #require(enumerated.first, "fixture 里的 .swift 没被枚举出来")
        #expect(
            !probe.path.hasPrefix(fixture.root.path),
            """
            枚举得到的 \(probe.path) 仍落在传进去的根 \(fixture.root.path) 之下
            —— 分叉没有构造出来，本条会在串替换版下也绿（两端一致 ⇒ 替换成功），失去全部判别力。
            """
        )

        // ② 分叉确实存在的前提下，台账键的根内相对路径段仍必须干净。
        let scan = try scanComponentJudgeInputs(root: fixture.root)
        let expected = GuardScanRoots.primaryTargetName + "/Shape/Cd311KeyProbe.swift"
        #expect(
            scan.typeDeclFiles["Cd311KeyProbe"] == [expected],
            """
            台账键被污染：\(scan.typeDeclFiles["Cd311KeyProbe"] ?? [])，期望 [\(expected)]。
            串替换版在这里给的是一整条绝对路径（前缀对不上就不替换），
            `/private` 那一味分叉下则给 `<根目录名>//privateShape/…`
            —— J-3 的组件作用域靠这串做集合相交，污染后作用域整片对不上。
            """
        )
    }
}
