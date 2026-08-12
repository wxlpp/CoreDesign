import Testing

// `compareRegistryToScan` 的常驻单元测试（终审 M2）。
//
// ⚠️ **为什么需要这个文件**：`ComponentRegistryGuard` 的双向差集判据此前只在
// `swift test` 全绿/全红两种状态上验证过，证明「它真的会拦」靠的是两个 gitignored
// 一次性脚本临时改真实的 `component-registry.json` / 临时挪走真实源码文件，跑完
// 手动还原——这类证据不进 CI、不可复现，评审换个人来核对就得重新做一遍。
//
// 用**合成输入**测纯函数 `compareRegistryToScan`，两个方向（漏登记 / 幽灵条目）
// 都变成常驻 CI 测试，不再需要改动任何真实文件。
@Suite("登记表↔扫描器 差集纯函数")
struct ComponentRegistryCompareTests {

    @Test("双方完全一致 ⇒ 两个方向都空")
    func fullyMatched() {
        let names: Set<String> = ["Alpha", "Beta", "Gamma"]
        let diff = compareRegistryToScan(scanned: names, registered: names)
        #expect(diff.missing.isEmpty)
        #expect(diff.ghosts.isEmpty)
    }

    @Test("源码新增组件但登记表没有 ⇒ missing 非空、ghosts 仍为空")
    func detectsMissingEntry() {
        let scanned: Set<String> = ["Alpha", "Beta", "NewComponent"]
        let registered: Set<String> = ["Alpha", "Beta"]
        let diff = compareRegistryToScan(scanned: scanned, registered: registered)
        #expect(diff.missing == ["NewComponent"])
        #expect(diff.ghosts.isEmpty)
    }

    @Test("登记表有源码里找不到的条目 ⇒ ghosts 非空、missing 仍为空")
    func detectsGhostEntry() {
        let scanned: Set<String> = ["Alpha", "Beta"]
        let registered: Set<String> = ["Alpha", "Beta", "DeletedComponent"]
        let diff = compareRegistryToScan(scanned: scanned, registered: registered)
        #expect(diff.missing.isEmpty)
        #expect(diff.ghosts == ["DeletedComponent"])
    }

    @Test("两个方向可以同时非空——漏登记与幽灵条目互不掩盖")
    func detectsBothDirectionsSimultaneously() {
        let scanned: Set<String> = ["Alpha", "NewComponent"]
        let registered: Set<String> = ["Alpha", "DeletedComponent"]
        let diff = compareRegistryToScan(scanned: scanned, registered: registered)
        #expect(diff.missing == ["NewComponent"])
        #expect(diff.ghosts == ["DeletedComponent"])
    }
}
