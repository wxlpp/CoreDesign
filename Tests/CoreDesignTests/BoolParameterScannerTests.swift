import Testing

// Bool 参数扫描层的**合成输入**单测。
//
// ⚠️ **为什么必须用合成输入，不能只跑真源码**：本仓那**七**处 `-> Bool`
// （`PinCode.swift:237/251`、`Rating.swift:185`、`Radio.swift:133`、`Skeleton.swift:155`、
// `Toast.swift:471`、`Timeline.swift:185`）**没有一处是 public**，真源码扫描无论裁决 (a)
// 写没写对都不会变色——「零命中」在这里只说明**看不见**，不说明**规则对**。
// 同理：public 的 `Binding<Bool>` 参数当前 0 条；`inout/consuming Bool` 0 条；
// public protocol requirement 里的 Bool 0 条；带 Bool 关联值的 enum case 0 条；
// `@autoclosure` 0 条；含 Bool 的 public typealias 0 条；
// `public extension` 里的嵌套具名类型 0 处（`#Preview` 里那几个不算，宏块整块跳过）。
// ⇒ 全部边界（裁决 a/b/b′/b″/c/e/f/g）的裁决**只能**在合成源码上证伪。
// 这与 #38 抽 `compareRegistryToScan` 出来写常驻单测是同一个理由。
//
// ⚠️ **「本仓当前恰好没有」正是 #38 `Toast`/`BottomInputBar` 翻车的形态**：差集恒空、
// 变异照红、评审看不出。本文件里那几条「零命中形态」的测试就是为此存在的——
// 它们证的不是「今天有违规」，而是「明天出现时看得见」。
@Suite("Bool 参数扫描层")
struct BoolParameterScannerTests {

    // MARK: - 裁决 (a)：返回类型 `-> Bool` 不是命中

    @Test("`-> Bool` 但无 Bool 参数 ⇒ 零命中")
    func returnTypeBoolIsNotAHit() {
        let result = scanBoolParams(source: """
        public struct Probe {
            public static func isComplete(value: String, length: Int) -> Bool { true }
            public var anchor: Bool { true }
        }
        """)
        #expect(result.hits.isEmpty, "返回类型被误算成参数：\(result.hits.map(\.key))")
        // ⚠️ Task 1 评审 Important-3：`scanBoolParams(source:)` 有意不查 `tree.hasError`
        // （`#Preview` 可能触发），所以 `hits.isEmpty` 本身是空断言——若这段 here-doc
        // 被改坏成语法错误，整棵树变 error node，采集为空，上面那条断言照样绿。
        // `anchor` 是必然入账的锚点：解析真的成功时它必须出现在 publicBoolProperties 里，
        // 给「解析成功」这件事本身钉一个非空断言。
        #expect(result.publicBoolProperties == ["Probe.anchor"], "实际：\(result.publicBoolProperties)")
    }

    @Test("同时有 Bool 参数与 Bool 返回值 ⇒ 只命中参数，且命中数等于参数数")
    func boolParamsAndBoolReturnHitOnlyTheParams() {
        let result = scanBoolParams(source: """
        public struct Probe {
            public static func isInteractive(isReadOnly: Bool, isEnabled: Bool) -> Bool { true }
        }
        """)
        #expect(result.keys == ["Probe.isInteractive#isReadOnly", "Probe.isInteractive#isEnabled"])
        #expect(result.hits.count == 2, "命中数 \(result.hits.count) ≠ 2 —— 返回值可能被多算了一次")
    }

    // MARK: - 裁决 (b)：Binding / FocusState 不是命中，但要归类

    @Test("Binding<Bool> / FocusState<Bool>.Binding 归 .boolCarrying，不进 hits")
    func bindingsAreCarryingNotHits() {
        let result = scanBoolParams(source: """
        public extension View {
            func probe(
                flag: Bool,
                shown: Binding<Bool>,
                focus: FocusState<Bool>.Binding?,
                flags: [Bool],
                onToggle: (Bool) -> Void
            ) {}
        }
        """)
        #expect(result.keys == ["View.probe#flag"], "实际命中：\(result.keys.sorted())")
        #expect(
            Set(result.carrying.map(\.key)) == [
                "View.probe#shown", "View.probe#focus", "View.probe#flags", "View.probe#onToggle",
            ],
            "实际归类：\(result.carrying.map(\.key).sorted())"
        )
    }

    @Test("分类器逐类型断言：显式处理，不靠「恰好没匹配上」")
    func classifierCoversEveryShape() {
        #expect(classifyBoolParameterType("Bool") == .plainBool)
        #expect(classifyBoolParameterType("Swift.Bool") == .plainBool)
        #expect(classifyBoolParameterType("Bool?") == .plainBool)
        #expect(classifyBoolParameterType("Optional<Bool>") == .plainBool)
        #expect(classifyBoolParameterType("Binding<Bool>") == .boolCarrying)
        #expect(classifyBoolParameterType("FocusState<Bool>.Binding?") == .boolCarrying)
        #expect(classifyBoolParameterType("[Bool]") == .boolCarrying)
        #expect(classifyBoolParameterType("(Bool) -> Void") == .boolCarrying)
        #expect(classifyBoolParameterType("String") == .notBool)
        // 词边界：不能被相似标识符骗过。
        #expect(classifyBoolParameterType("MyBool") == .notBool)
        #expect(classifyBoolParameterType("Boolish") == .notBool)

        // ⚠️ 裁决 (b′)：ownership / parameter specifier 必须先剥掉。
        // 不剥掉的话这三条会滑进 `\bBool\b` 兜底 ⇒ `.boolCarrying` ⇒ **免豁免逃逸**。
        #expect(classifyBoolParameterType("consuming Bool") == .plainBool)
        #expect(classifyBoolParameterType("borrowing Bool") == .plainBool)
        #expect(classifyBoolParameterType("sending Bool") == .plainBool)
        // `inout` 是**双向通道**，与 Binding<Bool> 同类——这是裁决，不是漏网。
        #expect(classifyBoolParameterType("inout Bool") == .boolCarrying)
        // 真源码里存在的形态（`Layout/FlowLayout.swift:37`）：剥完 specifier 仍不是 Bool。
        #expect(classifyBoolParameterType("inout Cache") == .notBool)

        // ⚠️ 裁决 (b″)：`@autoclosure () -> Bool` 的**调用点与 `flag: Bool` 逐字相同**
        // ⇒ 比 `consuming Bool` 更便宜的免豁免逃逸，必须判命中。
        #expect(classifyBoolParameterType("@autoclosure () -> Bool") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure () -> Swift.Bool") == .plainBool)
        // 反向：**没有** @autoclosure 的闭包调用点要写 `{ … }`，不是换皮 ⇒ 维持 .boolCarrying。
        #expect(classifyBoolParameterType("() -> Bool") == .boolCarrying)
        #expect(classifyBoolParameterType("@escaping (Bool) -> Void") == .boolCarrying)

        // ⚠️ 裁决 (b‴)（Task 1 评审 Important-2）：括号包裹比 @autoclosure 还便宜——
        // `func f(flag: (Bool))` 合法，调用点 `f(flag: true)` 逐字不变，必须剥到底再判。
        #expect(classifyBoolParameterType("(Bool)") == .plainBool)
        #expect(classifyBoolParameterType("((Bool))") == .plainBool)
        // 白名单补第四种拼法：之前只列了 Optional<Bool> / Optional<Swift.Bool> /
        // Swift.Optional<Bool> 三种，漏了 Swift.Optional<Swift.Bool>，同样滑进 carrying。
        #expect(classifyBoolParameterType("Swift.Optional<Swift.Bool>") == .plainBool)
        // 反向：`(Bool, Int)` 是元组，不是多余分组的括号——调用点要写元组字面量
        // `f(x: (true, 1))`，不是 `f(x: true)`，命中前提不成立；但含 Bool 标识符，
        // 与 [Bool] / (Bool) -> Void 同类落进兜底，归 .boolCarrying（清点不判违规）。
        #expect(classifyBoolParameterType("(Bool, Int)") == .boolCarrying)

        // ⚠️ 裁决 (b‴‴)（Task 1 评审第 2 轮 Important-B）：括号剥离只在最外层做，
        // `Optional<...>` 泛型实参位与 `@autoclosure` 返回位的 `(Bool)` 之前是免豁免
        // 逃逸——harness 探针 + `swiftc -typecheck` 双确认这些形态调用点逐字不变。
        // 改成对 Optional 泛型实参**递归**分类、对 autoclosure 返回位单独剥括号后堵上。
        #expect(classifyBoolParameterType("Optional<(Bool)>") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure () -> (Bool)") == .plainBool)
        // 内部空白同样要收：`Optional< Bool >` 与 `Optional<Bool>` 逐字等价。
        #expect(classifyBoolParameterType("Optional< Bool >") == .plainBool)
        // 反例：递归不能把非 Bool 的泛型实参误判成命中。
        #expect(classifyBoolParameterType("Optional<Int>") == .notBool)
        // 反例：元组实参递归后仍落 .boolCarrying（裁决 (b‴) 判元组不剥，不受递归影响）。
        #expect(classifyBoolParameterType("Optional<(Bool, Int)>") == .boolCarrying)
    }

    // MARK: - 访问级别

    @Test("非 public 宿主与非 public extension 的 Bool 参数一律不算")
    func nonPublicDeclarationsAreIgnored() {
        let result = scanBoolParams(source: """
        struct Internal {
            init(flag: Bool) {}
        }
        extension View {
            func internalModifier(flag: Bool) {}
        }
        private extension View {
            func focusedExternally(_ binding: FocusState<Bool>.Binding?) {}
        }
        public struct Host {
            static func helper(flag: Bool) -> Bool { flag }
            public var anchor: Bool { true }
        }
        """)
        #expect(result.hits.isEmpty, "非 public 声明被误采：\(result.hits.map(\.key))")
        #expect(result.carrying.isEmpty, "private extension 的参数被误采：\(result.carrying.map(\.key))")
        // ⚠️ Task 1 评审 Important-3：同上——两条空集断言都无法区分「解析成功、真的零命中」
        // 与「解析失败、树是空的」。`anchor` 是必然入账的锚点，钉住「解析确实成功」。
        #expect(result.publicBoolProperties == ["Host.anchor"], "实际：\(result.publicBoolProperties)")
    }

    @Test("public extension 的两种写法都算 public")
    func bothPublicExtensionSpellingsCount() {
        let result = scanBoolParams(source: """
        public extension View {
            func a(flag: Bool) {}
        }
        extension View {
            public func b(flag: Bool) {}
        }
        """)
        #expect(result.keys == ["View.a#flag", "View.b#flag"], "实际：\(result.keys.sorted())")
    }

    @Test("裁决 (g)：public extension 里的嵌套具名类型默认就是 public——不建模会整支漏采")
    func nestedTypesInsidePublicExtensionInheritPublic() {
        let result = scanBoolParams(source: """
        public extension Tag {
            enum Mode {
                case fancy(active: Bool)
            }
            struct Options {
                public init(flag: Bool) {}
            }
            protocol Styling {
                init(flag: Bool)
            }
            private enum Hidden {
                case secret(active: Bool)
            }
            enum Outer {
                enum Inner {
                    public func f(flag: Bool) {}
                }
            }
        }
        """)
        // ⚠️ Swift 语义：extension 上的显式访问修饰符是**其成员（含嵌套类型）的默认访问级**
        // ⇒ `Mode` / `Options` 都是 public。不在 `pushType` 建模的话它们以 isPublic: false
        // 压栈，被「任一具名类型层不是 public ⇒ 否」整支判掉 ⇒ **fail-open 漏采**。
        // 反向两条边界同样钉死：
        // · `private enum Hidden` —— 显式修饰符压过默认值；
        // · `Outer.Inner` —— 默认访问级只发给 extension 的**直接**成员，Inner 仍是 internal。
        //
        // ⚠️ **C-1（评审第 3/4 轮）**：`protocol Styling` 是同一条语义的第三个见证者，
        // 且它**不经过 `pushType`**——`ProtocolDeclSyntax` 有自己独立的压栈逻辑
        // （`visit(_:ProtocolDeclSyntax)`），裁决 (g) 只改了 `pushType` 时这里仍是
        // fail-open：`Styling` 以 `isPublic: a.pub == false` 压栈，`init(flag:)` 这条
        // requirement 走 `isEffectivelyPublic` 第 4 条 `return innermost.isPublic` 恒非
        // public ⇒ 结构性不可见，与裁决 (e)「protocol requirement 是命中」正面冲突。
        // `swiftc -typecheck` 实测确认 `Styling` 确实是 public（把 `public extension Host`
        // 改成裸 `extension Host` 后同一处报「generic parameter uses an internal type」）。
        #expect(
            result.keys == [
                "Tag.Mode.fancy#active", "Tag.Options.init#flag", "Tag.Styling.init#flag",
            ],
            "实际：\(result.keys.sorted())"
        )
    }

    @Test("嵌套类型的 owner 是点分全名；无标签参数取内部名")
    func nestedOwnerAndUnlabeledParameter() {
        let result = scanBoolParams(source: """
        public struct Config {
            public struct Segment {
                public init(index: Int, isSelected: Bool) {}
            }
        }
        public extension View {
            func sidebarSelectedBackground(_ isSelected: Bool) {}
        }
        """)
        #expect(
            result.keys == ["Config.Segment.init#isSelected", "View.sidebarSelectedBackground#isSelected"],
            "实际：\(result.keys.sorted())"
        )
    }

    @Test("subscript 上的 Bool 参数同样命中——不给它留逃逸口")
    func subscriptParametersCount() {
        let result = scanBoolParams(source: """
        public struct Host {
            public subscript(bordered: Bool) -> Int { 0 }
        }
        """)
        #expect(result.keys == ["Host.subscript#bordered"], "实际：\(result.keys.sorted())")
    }

    // MARK: - 裁决 (e)：protocol requirement 与 enum case 关联值

    @Test("public protocol 的 requirement 上的 Bool 参数是命中；非 public protocol 不是")
    func publicProtocolRequirementsAreHits() {
        let result = scanBoolParams(source: """
        public protocol Styling {
            init(flag: Bool)
            func apply(bordered: Bool) -> Int
            func bind(_ shown: Binding<Bool>)
        }
        protocol InternalStyling {
            init(flag: Bool)
        }
        """)
        // ⚠️ requirement **不允许**写访问修饰符 ⇒ 可见性必须由 protocol 自身决定。
        // 不压 ProtocolDecl 帧的实现会在这里得到空集（结构性不可见）。
        #expect(
            result.keys == ["Styling.init#flag", "Styling.apply#bordered"],
            "实际：\(result.keys.sorted())"
        )
        #expect(Set(result.carrying.map(\.key)) == ["Styling.bind#shown"],
                "实际归类：\(result.carrying.map(\.key).sorted())")
    }

    @Test("public enum case 的 Bool 关联值是命中（含无标签的位置兜底）")
    func enumCaseAssociatedValuesAreHits() {
        let result = scanBoolParams(source: """
        public enum Mode {
            case plain
            case decorated(active: Bool)
            case raw(Bool, String)
            case bound(Binding<Bool>)
        }
        enum InternalMode {
            case hidden(active: Bool)
        }
        """)
        // ⚠️ `E.decorated(active: true)` 在调用点就是一个 Bool 参数
        // ——把 init 参数改写成关联值是一条现成的换皮路线，不能看不见。
        #expect(
            result.keys == ["Mode.decorated#active", "Mode.raw#_0"],
            "实际：\(result.keys.sorted())"
        )
        #expect(Set(result.carrying.map(\.key)) == ["Mode.bound#_0"],
                "实际归类：\(result.carrying.map(\.key).sorted())")
    }

    @Test("`#if` 两个分支都扫；`#Preview` 里的声明不扫（顶层 expr 位 + 成员 decl 位）")
    func ifConfigBothBranchesAndPreviewSkipped() {
        let result = scanBoolParams(source: """
        #if os(iOS)
        public extension View { func onlyIOS(flag: Bool) {} }
        #else
        public extension View { func onlyMac(flag: Bool) {} }
        #endif
        #Preview("x") {
            public struct P { public init(flag: Bool) {} }
            AnyView(EmptyView())
        }
        public struct Container {
            #Preview("y") {
                public struct Q { public init(flag: Bool) {} }
            }
        }
        """)
        // ⚠️ Task 1 评审 Important-1：`#Preview` 闭包体里放了一个**若被走到就必然入账**的
        // 声明（`P.init(flag:)`）——`SwiftParser` 是纯语法解析，不知道 `P` 是局部类型，
        // 只要 visitor 真的走进宏体就会照采。这条断言因此同时证伪了两件事：
        // `#if` 两支都被扫到（`View.onlyIOS#flag` / `View.onlyMac#flag`），
        // **且** `#Preview` 体确实被跳过（`P.init#flag` 不在 keys 里）。
        // 之前的合成输入 `#Preview` 体内只有 `AnyView(EmptyView())`，没有任何可采集的声明
        // ——即使把 `visit(_:MacroExpansionDeclSyntax)` 的 `.skipChildren` 整行删掉，
        // `keys` 也不会变，「跳过 #Preview」这半个宣称从未被证伪。
        //
        // ⚠️ Task 1 评审第 2 轮 Important-A：上面那个顶层 `#Preview("x")` 在
        // `SwiftParser` 里落在 **expr** 语法节点（`MacroExpansionExprSyntax`），只见证了
        // `visit(_:MacroExpansionExprSyntax)` 那一处 `.skipChildren`；`Container` 里
        // **成员位**的 `#Preview("y")` 落在 **decl** 语法节点（`MacroExpansionDeclSyntax`
        // ——评审已实测该位置确实产出这个节点），见证的是另一处 `.skipChildren`
        // （`visit(_:MacroExpansionDeclSyntax)`）。两处跳过是各自独立的 override，
        // 只测顶层 expr 位对 decl 位那一处**零覆盖**——是 Important-1 同一形态的镜像复发：
        // 拿掉 decl 侧那道防线，这条测试原本不会红。`Container` 必须是 public、`Q` 必须
        // 是 public，否则就算 decl 位的跳过被拿掉，`Q.init#flag` 也会被访问级挡住，
        // 见证不到宏跳过本身。
        #expect(result.keys == ["View.onlyIOS#flag", "View.onlyMac#flag"], "实际：\(result.keys.sorted())")
    }

    @Test("public Bool 属性只进 publicBoolProperties，不进 hits")
    func publicBoolPropertiesAreCountedNotJudged() {
        let result = scanBoolParams(source: """
        public struct Host {
            public let glass: Bool
            public var isMonospaced: Bool { true }
            public init(glass: Bool) { self.glass = glass }
        }
        """)
        #expect(result.keys == ["Host.init#glass"], "实际命中：\(result.keys.sorted())")
        #expect(
            Set(result.publicBoolProperties) == ["Host.glass", "Host.isMonospaced"],
            "实际属性清单：\(result.publicBoolProperties.sorted())"
        )
    }

    // MARK: - 裁决 (f)：public typealias 洗 Bool

    @Test("public typealias 洗 Bool 会被清点——参数侧确实看不见，所以声明侧必须看得见")
    func boolWashingTypeAliasesAreCounted() {
        let result = scanBoolParams(source: """
        public typealias Flag = Bool
        public struct Host {
            public typealias MaybeFlag = Bool?
            public typealias Bound = Binding<Bool>
            public typealias Size = CGSize
            public init(flag: Flag) {}
        }
        struct Internal {
            public typealias Hidden = Bool
        }
        """)
        // ⚠️ **这条测试同时证明了盲区的存在**：`init(flag: Flag)` 的参数类型文本是 `"Flag"`
        // ⇒ `.notBool` ⇒ **不在 hits 里**。纯语法、逐文件的扫描器代不进 alias。
        #expect(result.hits.isEmpty, "alias 竟然被代入了？实际命中：\(result.keys.sorted())")
        // ⇒ 所以补的是**声明侧**清点：含 Bool 的 public typealias 一个都不许有。
        // `Size = CGSize` 不算；`Internal.Hidden` 的容器非 public，也不算。
        #expect(
            Set(result.publicBoolTypeAliases) == [
                "(top-level).Flag = Bool",
                "Host.MaybeFlag = Bool?",
                "Host.Bound = Binding<Bool>",
            ],
            "实际清点：\(result.publicBoolTypeAliases.sorted())"
        )
    }

    // MARK: - 双向差集纯函数

    @Test("清单与命中完全一致 ⇒ 两个方向都空")
    func diffFullyMatched() {
        let keys: Set<String> = ["A.init#x", "B.init#y"]
        let diff = compareBoolHitsToExemptions(hits: keys, exempted: keys)
        #expect(diff.violations.isEmpty)
        #expect(diff.stale.isEmpty)
    }

    @Test("源码新增未豁免 Bool ⇒ violations 非空、stale 仍空")
    func diffDetectsViolation() {
        let diff = compareBoolHitsToExemptions(
            hits: ["A.init#x", "View.probe#danger"], exempted: ["A.init#x"]
        )
        #expect(diff.violations == ["View.probe#danger"])
        #expect(diff.stale.isEmpty)
    }

    @Test("清单有源码里已不存在的条目 ⇒ stale 非空、violations 仍空")
    func diffDetectsStale() {
        let diff = compareBoolHitsToExemptions(
            hits: ["A.init#x"], exempted: ["A.init#x", "Gone.init#y"]
        )
        #expect(diff.violations.isEmpty)
        #expect(diff.stale == ["Gone.init#y"])
    }

    @Test("两个方向可以同时非空——违规与过期条目互不掩盖")
    func diffDetectsBothDirections() {
        let diff = compareBoolHitsToExemptions(
            hits: ["A.init#x", "New.init#z"], exempted: ["A.init#x", "Gone.init#y"]
        )
        #expect(diff.violations == ["New.init#z"])
        #expect(diff.stale == ["Gone.init#y"])
    }
}
