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
