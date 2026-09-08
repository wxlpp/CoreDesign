import Testing

@Suite("Bool 分类器残余形态回归")
struct BoolClassifierResidualTests {
    @Test("残余组 1：autoclosure 组合糖——返回位递归覆盖 Bool? / Optional<Bool> / (Bool)?")
    func residualGroup1AutoclosureCombinatorSugar() {
        #expect(classifyBoolParameterType("@autoclosure () -> Bool?") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure () -> Optional<Bool>") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure () -> (Bool)?") == .plainBool)
    }

    @Test("残余组 2：specifier 后无空格——consuming(Bool) / borrowing(Bool)")
    func residualGroup2SpecifierWithoutSpace() {
        #expect(classifyBoolParameterType("consuming(Bool)") == .plainBool)
        #expect(classifyBoolParameterType("borrowing(Bool)") == .plainBool)
    }

    @Test("残余组 3：attribute 后无空格——@autoclosure() -> Bool")
    func residualGroup3AttributeWithoutSpace() {
        #expect(classifyBoolParameterType("@autoclosure() -> Bool") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure()->Bool") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure( ) -> Bool") == .plainBool)
    }

    @Test("残余组 4：标点周围空白——Swift . Bool / Optional <Bool> / 泛型实参位复现")
    func residualGroup4WhitespaceAroundPunctuation() {
        #expect(classifyBoolParameterType("Swift . Bool") == .plainBool)
        #expect(classifyBoolParameterType("Optional <Bool>") == .plainBool)
        #expect(classifyBoolParameterType("Optional<Swift . Bool>") == .plainBool)
    }

    @Test("CBool 折入 plainBool——stdlib typealias CBool = Bool 是同一类型的另一拼法")
    func cboolFoldedIntoPlainBool() {
        #expect(classifyBoolParameterType("CBool") == .plainBool)
        #expect(classifyBoolParameterType("Swift.CBool") == .plainBool)
    }
}
