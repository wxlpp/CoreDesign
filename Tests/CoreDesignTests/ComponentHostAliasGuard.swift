import Foundation
import Testing

/// `ComponentHostAliases.table` 的**自洽守卫**（`#65`）。
///
/// ⚠️ **为什么必须有这个守卫**：别名表放宽的是 J-2 第三道门槛（「宿主必须是本条目自己」）
/// —— 那道门槛是 PR #206 第 3 轮 review 专门加的，用来堵「借别的组件的形态枚举也判绿」。
/// 一张没人守的别名表就是把那道门槛的钥匙交出去。
///
/// ⚠️ 本仓有前车之鉴：`ComponentRegistryGuard.knownOffScannerComponents` 白名单当初
/// **没有自洽断言**，是终审第 2 轮 M2 抓出来的。同一个坑不该踩第二次。
///
/// **五条断言**（⚠️ 上一版写「四条」，加 ⑤ 后已失真 —— PR #210 复审 Suggestion）：
/// - **缺第 ④ 条就是把万能钥匙**：前三条只核「表里写的东西存在」，而「存在但无关」的
///   名字能让它们全过 —— 第 ④ 条把「表里写了谁」与「那个谁真的接了这个枚举」绑死。
/// - **第 ⑤ 条补的是别名表打破的一条隐式约束**：原第三道门槛（宿主名 == 条目名）
///   **结构上**排除了「两个条目共享一个枚举」，别名表把这个约束打破了。
@Suite("别名表自洽：五条断言")
struct ComponentHostAliasGuard {
    private func loadInputs() throws -> (entries: [ComponentRegistryGuard.Entry], scan: ComponentJudgeScanResult) {
        (try ComponentRegistryGuard.loadRegistry(), try ComponentJudgeSources.scan())
    }

    @Test("① 表里每个 key 都在登记表里存在")
    func keysExistInRegistry() throws {
        let (entries, _) = try self.loadInputs()
        let known = Set(entries.map(\.component))
        for key in ComponentHostAliases.table.keys {
            #expect(known.contains(key),
                    "别名表 key `\(key)` 在 component-registry.json 里不存在 —— 悬空条目")
        }
    }

    @Test("② 表里每个 value 都是源码里存在的公开 modifier 方法名")
    func valuesExistAsPublicViewModifiers() throws {
        let (_, scan) = try self.loadInputs()
        // 数据源：T3 之后 `styleEnumUses` 的 hostType 集合。
        // ⚠️ 它**混装类型名与方法名**（init 通路记类型名、modifier 通路记方法名），
        // 因此本条对「类型名」偏宽。但那不构成逃逸：对**活条目**由第 4 条兜底，
        // 对 `styleEnum` 为 null 的**死条目**由第 4 条的「不适用」惰性兜底。
        let knownHosts = Set(scan.styleEnumUses.map(\.hostType))
        for (key, values) in ComponentHostAliases.table {
            for value in values {
                #expect(knownHosts.contains(value),
                        "别名表 `\(key)` → `\(value)`：源码里没有任何公开入口以该名字承载形态枚举参数")
            }
        }
    }

    @Test("③ 表里每个 key 都确实不等于任何单个公开类型名")
    func keysAreNotTypeNames() throws {
        let (_, scan) = try self.loadInputs()
        // 数据源：`typeDeclFiles.keys`（全部被声明/扩展过的类型名）。
        // ⚠️ 偏宽 = 偏严 = fail-safe：多认几个类型名只会让本条更容易红，不会漏放。
        for key in ComponentHostAliases.table.keys {
            #expect(scan.typeDeclFiles[key] == nil,
                    "别名表 key `\(key)` 本身就是一个真实类型名 —— 它不该进表，直接走「宿主 == 条目名」的原路径即可；进表只会平白放宽第三道门槛")
        }
    }

    @Test("④ 每个 value 必须真的携带该条目登记的 styleEnum 作为参数")
    func valuesActuallyCarryTheRegisteredEnum() throws {
        let (entries, scan) = try self.loadInputs()
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.component, $0) })
        var deadEntries: Set<String> = []
        for (key, values) in ComponentHostAliases.table {
            guard let entry = byName[key] else { continue }   // ① 已经守了存在性
            guard let styleEnum = entry.styleEnum else {
                // ⚠️ `styleEnum` 为 null ⇒ 本条**不适用**（不判红）。
                // 理由：条目在落地过程中会有一段「别名表已写、registry 字段未写」的中间态；
                // 若此时判红，实现根本无法分步推进。而这**不构成后门** —— 别名通路只活在
                // J-2 的 `else if let styleEnum = entry.styleEnum` 那条臂里，null 条目
                // 要么落「四字段皆空」的红、要么根本不进定义域 ⇒ 对判定零作用。
                // ⇒ 记入**棘轮**（当前应为空集），防止表里长期挂惰性键。
                // ⚠️ 上一版只 `print`（PR #210 终审 S-2）—— stdout 在 CI 里无人看。
                deadEntries.insert(key)
                continue
            }
            let hosts = scan.styleEnumHosts[styleEnum] ?? []
            for value in values {
                #expect(hosts.contains(value),
                        "别名表 `\(key)` → `\(value)`：该入口并没有携带本条目登记的 `\(styleEnum)` 参数（该枚举实际接线于 \(hosts.sorted())）—— 前三条只核『名字存在』，存在但无关的名字能让它们全过，本条专堵这个")
            }
        }
        #expect(deadEntries.isEmpty,
                "别名表出现死条目 \(deadEntries.sorted())（registry 里 styleEnum 为 null）—— 第 ④ 条对它们不适用、它们对判定也零作用。要么补上 registry 字段，要么从表里删掉，别让惰性键长期挂着")
    }

    @Test("⑤ 每个 styleEnum 只能被一个条目认领（别名表打破了原来的隐式约束）")
    func styleEnumsAreClaimedByExactlyOneEntry() throws {
        // ⚠️ **本条是 PR #210 终审 S-1 补的**：原第三道门槛（宿主名 == 条目名）**结构上**
        // 排除了「两个条目共享一个枚举」—— 一个枚举的 hosts 不可能同时等于两个条目名。
        // 别名表把这个隐式约束打破了：未来某条**非类型名**的登记条目（过守卫 ③）把
        // `styleEnum` 填成一个别人的枚举、别名映射到那个别人的入口，
        // ①②④ 会**全部通过**，J-2 判绿，而它一行组件代码都没写。
        let entries = try ComponentRegistryGuard.loadRegistry()
        var claimedBy: [String: [String]] = [:]
        for entry in entries {
            guard let styleEnum = entry.styleEnum else { continue }
            claimedBy[styleEnum, default: []].append(entry.component)
        }
        // ⚠️ **本条作用域是全 registry，比动机更宽**（复审 Suggestion）：将来若出现**合法**的
        // 「多组件共享一个配置枚举」形态（本仓已有先例：多个按钮样式共享
        // `ButtonRoleStyleRole`），本条会误红。届时**按共享形态另开通路**（例如给 registry
        // 加一个显式的 `sharedStyleEnum` 标记），**别直接放宽本条** —— 放宽等于把别名表
        // 打破的那条隐式约束彻底交出去。
        for (styleEnum, owners) in claimedBy.sorted(by: { $0.key < $1.key }) where owners.count > 1 {
            Issue.record("配置枚举 `\(styleEnum)` 被 \(owners.sorted()) 多个条目同时登记 —— 一个形态枚举只能属于一个组件；共享认领会让后来者靠别名表白蹭前者的接线")
        }
    }
}
