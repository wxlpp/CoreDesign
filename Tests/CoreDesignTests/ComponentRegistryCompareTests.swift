import Testing

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
