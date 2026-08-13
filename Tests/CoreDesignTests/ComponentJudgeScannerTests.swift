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
}
