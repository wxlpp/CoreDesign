import Foundation
import Testing

// MARK: - 位图断言的归约入口 / Reduced bitmap expectations（Issue #293）
//
// ## 它治什么
//
// `#expect(a == b)` 在两幅**大位图**上判红时**不判红，而是挂住**：swift-testing 为了
// 渲染失败信息去求 `CollectionDifference`（Myers 差分），两个 160 000 字节、处处不同的
// `Data` ⇒ 98% CPU、1.6 GB 常驻、**90 秒不收敛**。
//
// ⚠️ **失效的恰好是最该判红的那一类变异**：整层被绕过 = 整幅图都变 = 差分规模爆炸。
// 而失效形态是「进程卡住、读不出是哪条判据在咬」——比静默绿更难诊断，因为它看起来
// 像机器慢或死锁。既有断言至今没被咬到，只是因为迄今判红的场景里两幅图差异都很小。
//
// ## 实测（本文件的存在理由，`swift test` 原始输出，160 000 字节 × 两幅无关随机位图）
//
// | 形态 | 结果 |
// |---|---|
// | `#expect(a == b, …)`，两侧是 **`Data`（非可选）** | **SIGALRM at 90 s，一行汇总都没打印**（exit 142） |
// | `let matches = a == b; #expect(matches, …)` | **0.038 s 判红** |
// | `#expect(bitmapsEqual(a, b), …)`（比较归约进函数） | **0.038 s 判红** |
// | `#expect(a.elementsEqual(b), …)` | **0.038 s 判红** |
// | `#expect(a == b, …)`，两侧是 **`Data?`（可选）** | **0.039 s 判红** |
//
// ⇒ 关键不在"用哪个函数"，而在**进 `#expect` 的那个表达式的顶层不是 `==` / `!=`**：
// 只要宏看到的是一个 `Bool`（或一个返回 `Bool` 的调用），它就不会去求差分。
// 上表第 4 行说明 `elementsEqual` **不是**逃逸口子，它和归约一样快——这一点写在这里，
// 免得后人以为守卫漏掉了它。
//
// ## ⚠️⚠️ 最后一行是本轮实测出来的**修正**，issue 原文里没有：`Data?` 不挂
//
// `Optional<Data>` **本身不是 `Collection`** ⇒ swift-testing 不会为它求
// `CollectionDifference`。同一对 160 000 字节位图：
// 声明成 `let a: Data` ⇒ 60 秒 SIGALRM；声明成 `let a: Data?` ⇒ **0.039 s**。
//
// ⚠️ **这不是"大多数点位其实没事所以不用改"的理由**，有三条：
// 1. 会挂的那一类在本仓真实存在，且**恰好是最承重的那些**——凡是走
//    `try #require(...)` 拿到位图的断言，操作数都是非可选 `Data`。#293 的
//    端到端复现就落在 `MaskRevealRenderTests` 的这类断言上（200 秒不收敛）。
// 2. 「可选 ⇒ 非可选」是**一次重构的距离**：谁把 `let a = pixels(v)` 改成
//    `let a = try #require(pixels(v))`（本仓一直在鼓励的写法，它能挡住"渲染失败
//    ⇒ 断言恒真"），那条断言当天就从 0.04 秒变成挂死，而**没有任何提示**。
// 3. 判据若按可选性区分，就变成了一张"哪种拼法安全"的表——本仓已有四次
//    「判据钉写法、等价改写即逃逸」的教训。纪律对两者一视同仁，反而最简单。
//
// ## 为什么是函数而不是逐处 `let matches = …`
//
// `let matches = a == b; #expect(matches, …)`（#291 `MaskRevealTransitionBodyTests`、
// #294 基准腿）是本仓已有的成法，**它仍然是被认可的写法**，守卫放行它。
// 本文件把同一形态收进一个函数，是因为要改的点位有 **122 处**：
//
// 1. 逐处插一行 `let` 要在 `for` / 闭包 / `throws` 各种上下文里重排代码，
//    而换成一次调用是**单表达式**替换，逐行可读、可审；
// 2. 验收还要求「失败信息携带**指纹或首个相异下标**，不要携带整个差分」——
//    那段诊断文本逐处手写 122 遍必然漂移，收进函数才有一份。
//
// ⚠️ **函数体里就是那条成法本身**（`let matches = a == b`），不是另造一种形态。
//
// ## 已知边界（不要读成比实际更强）
//
// ⚠️ 本文件**不**保证"所有位图断言都走这里"——那是 `BitmapExpectationGuard` 的职责，
// 且那条守卫自己也有堵不住的等价改写，逐条列在它的文件头里。
//
// ⚠️ **本文件在 `CoreDesignTests` 与 `CoreDesignEffectsTests` 两份完全相同的拷贝**。
// 两个 test target 按 `Package.swift` 的 AD-D 刻意互不依赖（并进去会让
// `CoreDesignTests` 的依赖图包含 `CoreDesignEffects`，判红既有的隔离判据），
// SwiftPM 也没有"test-only 共享 target"这种东西而不破坏那条隔离。
// ⇒ 改动其中一份时**必须同步另一份**；`BitmapExpectationGuard.copiesAreInSync`
// 会逐字节比对两份拷贝并在漂移时判红。

/// 位图的 64 位指纹（FNV-1a）。**O(n)、无分配**——与 `CollectionDifference` 的
/// O(n·d) 时空爆炸是两回事。
nonisolated func bitmapFingerprint<Bytes: Collection>(_ bytes: Bytes) -> UInt64
where Bytes.Element == UInt8 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in bytes {
        hash ^= UInt64(byte)
        hash = hash &* 0x1000_0000_01b3
    }
    return hash
}

/// 两侧位图的**渲染失败诊断**：任一侧为 `nil` ⇒ 返回一句点名是哪一侧没渲染出来的话；
/// 两侧都拿到了位图 ⇒ 返回 `nil`。
///
/// ## ⚠️⚠️ 为什么这一步必须独立存在（#298 评审 S-7 / Copilot）
///
/// `Optional` 的 `==` / `!=` 让 `nil` 有了**关于位图内容的语义**，于是「渲染失败」会被
/// 读成一个结论：
///
/// | 写法 | 一侧 `nil` | 两侧 `nil` |
/// |---|---|---|
/// | `expectBitmapsDiffer(a, b)`（改前） | `nil != 非 nil` ⇒ **静默通过** | `nil != nil` ⇒ 判红 |
/// | `expectBitmapsEqual(a, b)`（改前） | 判红，但信息读起来像「两幅图不同」 | `nil == nil` ⇒ **静默通过** |
///
/// 两格「静默通过」是同一个病：**渲染失败 ⇒ 断言恒真**。而 `differ` 那一格尤其毒——
/// `expectBitmapsDiffer(fullOrbit, lowOrbit, "低电量下环上点数没变")` 想证明的正是
/// 「这两幅图确实不同」，一侧渲染失败却让它**恰好以那句话的名义**变绿。
/// `equal` 那一格不是静默通过而是**信息质量**问题：它会判红，但失败信息把
/// 「有一侧根本没画出来」说成「edge 影响了渲染」。
///
/// ⇒ 两个入口都先问「两侧都渲染出来了吗」，没有就判红，**并且明说是渲染失败**。
/// 收进这里而不是逐处加前置，是因为 122 处点位已经收敛到了这两个函数
/// ——这是把这条恒真一次性钉死最省事的位置。
///
/// ⚠️ 这**不解除**调用点写显式非空前置的义务：`#expect(top != nil, "渲染失败 —— 不得
/// 当作通过")` 这类前置说的是「本平台量不了这件事」，与本函数说的「这条断言的结论无效」
/// 是两件事，且前者能在更靠前的位置停住。
nonisolated func bitmapRenderFailure<Bytes: Collection>(_ a: Bytes?, _ b: Bytes?) -> String?
where Bytes.Element == UInt8 {
    switch (a == nil, b == nil) {
    case (true, true):
        return "⚠️ 渲染失败：**两侧都是 nil** —— 这不是「位图相同」，是两侧都没画出来"
    case (true, false):
        return "⚠️ 渲染失败：**第一侧（a）是 nil** —— 这不是「位图不同」，是 a 没画出来"
    case (false, true):
        return "⚠️ 渲染失败：**第二侧（b）是 nil** —— 这不是「位图不同」，是 b 没画出来"
    case (false, false):
        return nil
    }
}

/// 两幅位图的**可读差异摘要**：长度 + 指纹 + 首个相异下标 + 相异字节计数。
///
/// ⚠️ 刻意**不**输出任何逐元素差分——那正是 #293 的病根。整段是一次线性扫描。
nonisolated func bitmapDifferenceSummary<Bytes: Collection>(_ a: Bytes?, _ b: Bytes?) -> String
where Bytes.Element == UInt8 {
    func describe(_ bytes: Bytes?) -> String {
        guard let bytes else { return "nil" }
        return "\(bytes.count) B / fp=0x\(String(bitmapFingerprint(bytes), radix: 16))"
    }
    let head = "a=[\(describe(a))] b=[\(describe(b))]"
    // ⚠️ 渲染失败先说渲染失败：下面那些「首个相异下标」在这里一句也不成立。
    if let failure = bitmapRenderFailure(a, b) { return "\(head)\n\(failure)" }
    guard let a, let b else { return head }   // `bitmapRenderFailure` 已经排除，仅为解包
    if a.count != b.count { return "\(head)：长度不同，无逐字节下标可报" }

    var firstDifference: (index: Int, lhs: UInt8, rhs: UInt8)?
    var differingCount = 0
    for (index, pair) in zip(a, b).enumerated() where pair.0 != pair.1 {
        if firstDifference == nil { firstDifference = (index, pair.0, pair.1) }
        differingCount += 1
    }
    guard let first = firstDifference else { return "\(head)：逐字节相同" }
    let lhsHex = String(first.lhs, radix: 16)
    let rhsHex = String(first.rhs, radix: 16)
    return """
    \(head)：首个相异下标 \(first.index)（a=0x\(lhsHex) b=0x\(rhsHex)），\
    共 \(differingCount)/\(a.count) 字节不同
    """
}

/// `#expect(a == b)` 的归约替代。**位图相等一律走这里。**
///
/// - Parameters:
///   - comment: 失败时的人话说明；函数会在其后追加 `bitmapDifferenceSummary` 的摘要。
///     `@autoclosure` ⇒ **只有判红时才求值**，绿路径零开销。
///
/// ⚠️ **两侧都 `nil` 也判红**（渲染失败，不是「位图相同」）——见 `bitmapRenderFailure`。
nonisolated func expectBitmapsEqual<Bytes: Collection & Equatable>(
    _ a: Bytes?,
    _ b: Bytes?,
    _ comment: @autoclosure () -> String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) where Bytes.Element == UInt8 {
    let bothRendered = bitmapRenderFailure(a, b) == nil
    guard bothRendered else {
        #expect(
            bothRendered,
            Comment(rawValue: bitmapExpectationMessage(comment(), a, b)),
            sourceLocation: sourceLocation
        )
        return
    }
    // ⚠️ **这一行就是 #291 的成法**：比较在宏之外完成，宏只看到一个 `Bool`。
    let matches = a == b
    #expect(
        matches,
        Comment(rawValue: bitmapExpectationMessage(comment(), a, b)),
        sourceLocation: sourceLocation
    )
}

/// `#expect(a != b)` 的归约替代。
///
/// ⚠️ `!=` 判红时两幅图**相等**，Myers 在相同输入上很快 ⇒ 它不是 #293 的挂死形态。
/// 仍然一并归约，是为了让守卫只有**一条**规则（`#expect` 里不出现位图 `==` / `!=`）：
/// 留一个"`!=` 可以直接写"的例外，等于要求下一个人先判断自己那条会往哪边红。
///
/// ⚠️⚠️ **任一侧 `nil` 判红**：`nil != 非 nil` 恒真，会把「有一侧根本没渲染出来」
/// 当成「两幅图确实不同」——而那正是本函数每一处调用想证明的那件事。见 `bitmapRenderFailure`。
nonisolated func expectBitmapsDiffer<Bytes: Collection & Equatable>(
    _ a: Bytes?,
    _ b: Bytes?,
    _ comment: @autoclosure () -> String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) where Bytes.Element == UInt8 {
    let bothRendered = bitmapRenderFailure(a, b) == nil
    guard bothRendered else {
        #expect(
            bothRendered,
            Comment(rawValue: bitmapExpectationMessage(comment(), a, b)),
            sourceLocation: sourceLocation
        )
        return
    }
    let differs = a != b
    #expect(
        differs,
        Comment(rawValue: bitmapExpectationMessage(comment(), a, b)),
        sourceLocation: sourceLocation
    )
}

nonisolated func bitmapExpectationMessage<Bytes: Collection>(
    _ comment: String, _ a: Bytes?, _ b: Bytes?
) -> String where Bytes.Element == UInt8 {
    let summary = bitmapDifferenceSummary(a, b)
    return comment.isEmpty ? summary : "\(comment)\n\(summary)"
}
