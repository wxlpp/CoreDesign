import Testing

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
        #expect(classifyBoolParameterType("MyBool") == .notBool)
        #expect(classifyBoolParameterType("Boolish") == .notBool)

        #expect(classifyBoolParameterType("consuming Bool") == .plainBool)
        #expect(classifyBoolParameterType("borrowing Bool") == .plainBool)
        #expect(classifyBoolParameterType("sending Bool") == .plainBool)
        #expect(classifyBoolParameterType("inout Bool") == .boolCarrying)
        #expect(classifyBoolParameterType("inout Cache") == .notBool)

        #expect(classifyBoolParameterType("@autoclosure () -> Bool") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure () -> Swift.Bool") == .plainBool)
        #expect(classifyBoolParameterType("() -> Bool") == .boolCarrying)
        #expect(classifyBoolParameterType("@escaping (Bool) -> Void") == .boolCarrying)

        #expect(classifyBoolParameterType("(Bool)") == .plainBool)
        #expect(classifyBoolParameterType("((Bool))") == .plainBool)
        #expect(classifyBoolParameterType("Swift.Optional<Swift.Bool>") == .plainBool)
        #expect(classifyBoolParameterType("(Bool, Int)") == .boolCarrying)

        #expect(classifyBoolParameterType("Optional<(Bool)>") == .plainBool)
        #expect(classifyBoolParameterType("@autoclosure () -> (Bool)") == .plainBool)
        #expect(classifyBoolParameterType("Optional< Bool >") == .plainBool)
        #expect(classifyBoolParameterType("Optional<Int>") == .notBool)
        #expect(classifyBoolParameterType("Optional<(Bool, Int)>") == .boolCarrying)

        #expect(classifyBoolParameterType("(Bool/*x*/)") == .plainBool)
        #expect(classifyBoolParameterType("Optional<Bool/*x*/>") == .plainBool)
        #expect(classifyBoolParameterType("(Bool // trailing note\n)") == .plainBool)
        #expect(classifyBoolParameterType("Bool/* a /* b */ c */") == .plainBool)

        #expect(classifyBoolParameterType("(Bool // c\r)") == .plainBool)

        #expect(classifyBoolParameterType("`Bool`") == .plainBool)
        #expect(classifyBoolParameterType("Optional<`Bool`>") == .plainBool)
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
        #expect(result.hits.isEmpty, "alias 竟然被代入了？实际命中：\(result.keys.sorted())")
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
