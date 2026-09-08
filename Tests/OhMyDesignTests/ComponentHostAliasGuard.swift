import Foundation
import Testing

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
            guard let entry = byName[key] else { continue }
            guard let styleEnum = entry.styleEnum else {
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
        let entries = try ComponentRegistryGuard.loadRegistry()
        var claimedBy: [String: [String]] = [:]
        for entry in entries {
            guard let styleEnum = entry.styleEnum else { continue }
            claimedBy[styleEnum, default: []].append(entry.component)
        }
        for (styleEnum, owners) in claimedBy.sorted(by: { $0.key < $1.key }) where owners.count > 1 {
            Issue.record("配置枚举 `\(styleEnum)` 被 \(owners.sorted()) 多个条目同时登记 —— 一个形态枚举只能属于一个组件；共享认领会让后来者靠别名表白蹭前者的接线")
        }
    }
}
