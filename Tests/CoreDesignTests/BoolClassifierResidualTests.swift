import Testing

// 5 类「已撞见并修复」的分类器残余形态（Task 2 前置修复，见 `BoolParameterScanner.swift`
// 里 `classifyBoolParameterType` 的 5 处改动与 `stripComments` 上方文档「4 组已知残余」）
// 的**永久**回归见证。
//
// ⚠️ **为什么单独开一个文件，而不是并进 `BoolParameterScannerTests.swift`**：
// `BoolParameterScannerTests.swift` 的 18 条 `@Test` 是 Task 1 评审冻结的硬计数，
// 不得增减（`git diff --quiet f7800fb..HEAD -- Tests/CoreDesignTests/BoolParameterScannerTests.swift`
// 必须通过）——这条约束的范围是**那一个文件**，不是全仓测试总数，新开文件不违反它。
//
// ⚠️ **为什么这组测试是必要的，不是锦上添花**：这 5 类形态在本仓真源码里全部零命中
// （`swiftc -typecheck` 合法、调用点与 `f(flag: true)` 逐字相同，但曾经落
// `.boolCarrying`）——真源码扫描不见证它们，Task 1 的 18 条合成单测也不覆盖它们。
// 在这份文件落地之前，红→绿的证据只存在于 `.superpowers/sdd/task-2-report.md` §1.1
// 的转录里（用的是一个已删除、未提交的 scratch 文件），评审侧无法重放——谁把
// `normalizeWhitespace` 的标点收紧、autoclosure 返回位递归、或 CBool 分支改坏，
// 全量测试依然会全绿。下面前 11 条断言把那份转录原样落成可重放的回归测试，
// 分组、命名、**断言表达式**顺序与 report §1.1 逐字一致（`@Test` 显示名做了扩写，
// 不在「逐字一致」范围内）。第 12 条断言是 Task 2 评审第 2 轮 Important-1 新增
// ——`@autoclosure()->Bool`（残余组 3 的粘连兄弟形态，箭头也无空格）比组 3 已修的
// 那类更黑，见残余组 3 测试函数与 `BoolParameterScanner.swift` 里的裁决注释。
// 第 13 条断言是 Task 8 终审 Important-2 新增——`@autoclosure( ) -> Bool`（括号内
// 有空格）此前被误判为「不同类，正确落 `.boolCarrying`」，实为裁决层面的漏判，
// 见残余组 3 测试函数与 `BoolParameterScanner.swift` 里同一裁决的注释。
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
        // ⚠️ **本轮新增（Task 2 评审第 2 轮 Important-1）**：组 3 的粘连兄弟形态
        // ——箭头也无空格。全串无空白 ⇒ `prefix(while:)` 把整串当 attribute 吞掉
        // ⇒ `t = ""` ⇒ `sawAutoclosure` 未置位 ⇒ 落 `.notBool`（比组 3 已修的
        // `.boolCarrying` 更黑：命中/清点/留痕三层同时看不见）。变异自证：把
        // `BoolParameterScanner.swift` 里的 `else if attribute.hasPrefix("@autoclosure()")`
        // 分支去掉、只留原 `attribute.hasSuffix("()") ? … : attribute` 三元表达式
        // （即撤回本轮修复）后本条应变红。⚠️ 修法**不能**只写
        // `hasPrefix("@autoclosure(")`（少一个闭合括号）——那会把「(」到「)」之间
        // **除空白外还有其它内容**的假想输入一起误判，见 `BoolParameterScanner.swift`
        // 里该分支的注释。
        #expect(classifyBoolParameterType("@autoclosure()->Bool") == .plainBool)
        // ⚠️ **Task 8 终审 Important-2 新增**：`@autoclosure( ) -> Bool`（括号内有一个
        // 空格）此前被误判为「与上面两条不同类，正确落 `.boolCarrying`」——按裁决 (b″)
        // 判命中的两条理由（零成本改写 + 调用点仍是一个 Bool 参数）对它逐字成立，与
        // `@autoclosure() -> Bool` 只差括号里一个空格，旧的区分理由是纯词法的
        // （`prefix(while:)` 在哪截停），不是裁决层面的。变异自证：把
        // `BoolParameterScanner.swift` 里 `attribute == "@autoclosure("` 那条分支删掉
        // （即撤回本轮修复）后本条应变红（落回 `.boolCarrying`）。
        #expect(classifyBoolParameterType("@autoclosure( ) -> Bool") == .plainBool)
    }

    @Test("残余组 4：标点周围空白——Swift . Bool / Optional <Bool> / 泛型实参位复现")
    func residualGroup4WhitespaceAroundPunctuation() {
        #expect(classifyBoolParameterType("Swift . Bool") == .plainBool)
        #expect(classifyBoolParameterType("Optional <Bool>") == .plainBool)
        // 泛型实参位的复现形态：`normalizeWhitespace` 在每次递归调用时重新执行，
        // 不需要对「Optional × 空白」单独处理。
        #expect(classifyBoolParameterType("Optional<Swift . Bool>") == .plainBool)
    }

    @Test("CBool 折入 plainBool——stdlib typealias CBool = Bool 是同一类型的另一拼法")
    func cboolFoldedIntoPlainBool() {
        #expect(classifyBoolParameterType("CBool") == .plainBool)
        #expect(classifyBoolParameterType("Swift.CBool") == .plainBool)
    }
}
