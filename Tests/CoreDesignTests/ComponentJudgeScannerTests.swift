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
        let scan = try scanComponentJudgeInputs(root: ComponentRegistryGuard.coreDesignSources)
        // ⚠️ 非空断言先行：扫描器失效时「零命中 ⇒ 零违规 ⇒ 绿」会静默通过。
        #expect(scan.bareTextKeys.count > 20, "只扫到 \(scan.bareTextKeys.count) 个裸文本参数 —— 扫描器失效")
        #expect(scan.localizedTextKeys.count > 5, "只扫到 \(scan.localizedTextKeys.count) 个 LSK/LSR 参数 —— 扫描器失效")
        print("裸文本 \(scan.bareTextKeys.count) 个：\(scan.bareTextKeys.sorted())")
        print("LSK/LSR \(scan.localizedTextKeys.count) 个：\(scan.localizedTextKeys.sorted())")
        print("carrying \(scan.carryingKeys.count) 个：\(scan.carryingKeys.sorted())")
        // ⚠️ 非空断言：自有样式协议识别器一旦失效，J-3 的「作用域内没有自有协议 ⇒ 绿」
        // 就变成假绿（零命中 ⇒ 零违规）。这里先钉住它真的认得出东西。
        #expect(scan.styleProtocolNames == ["BannerStyle", "SegmentedControlStyle"],
                "本仓自有样式协议实测恰为这两个；集合变了要么是新增了扩展点（预期变化，同步改这里），要么是识别器失效")
        #expect(scan.conformers(of: "ProgressViewStyle").contains("CoreProgressViewStyle"),
                "原生协议 conformance 采集失效 —— J-2 对 nativeProtocol 的核对会因此假绿")
        print("自有样式协议：\(scan.styleProtocols.map { "\($0.name)@\($0.file):\($0.line) styleSuffix=\($0.nameHasStyleSuffix)" }.sorted())")
        print("conformance 记录 \(scan.conformances.count) 条；ProgressViewStyle 实现：\(scan.conformers(of: "ProgressViewStyle").sorted())")
        print("BannerStyle 实现：\(scan.conformers(of: "BannerStyle").sorted())；SegmentedControlStyle 实现：\(scan.conformers(of: "SegmentedControlStyle").sorted())")
    }
}
