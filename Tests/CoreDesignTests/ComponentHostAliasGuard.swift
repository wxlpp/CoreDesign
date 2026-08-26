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
/// **四条断言，缺第 4 条就是把万能钥匙**：前三条只核「表里写的东西存在」，
/// 而「存在但无关」的名字能让它们全过 —— 第 4 条把「表里写了谁」与「那个谁真的接了
/// 这个枚举」绑死。
@Suite("别名表自洽：四条断言")
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
        for (key, values) in ComponentHostAliases.table {
            guard let entry = byName[key] else { continue }   // ① 已经守了存在性
            guard let styleEnum = entry.styleEnum else {
                // ⚠️ `styleEnum` 为 null ⇒ 本条**不适用**（不判红）。
                // 理由：条目在落地过程中会有一段「别名表已写、registry 字段未写」的中间态；
                // 若此时判红，实现根本无法分步推进。而这**不构成后门** —— 别名通路只活在
                // J-2 的 `else if let styleEnum = entry.styleEnum` 那条臂里，null 条目
                // 要么落「四字段皆空」的红、要么根本不进定义域 ⇒ 对判定零作用。
                // ⇒ 打一行诊断标记「死条目」，防止表里长期挂惰性键。
                print("⚠️ 别名表死条目：`\(key)` 的 styleEnum 为 null，第 ④ 条对它暂不适用")
                continue
            }
            let hosts = scan.styleEnumHosts[styleEnum] ?? []
            for value in values {
                #expect(hosts.contains(value),
                        "别名表 `\(key)` → `\(value)`：该入口并没有携带本条目登记的 `\(styleEnum)` 参数（该枚举实际接线于 \(hosts.sorted())）—— 前三条只核『名字存在』，存在但无关的名字能让它们全过，本条专堵这个")
            }
        }
    }
}
