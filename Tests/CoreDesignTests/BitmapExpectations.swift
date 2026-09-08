import Foundation
import Testing

// MARK: - 位图断言的归约入口 / Reduced bitmap expectations（Issue #293）

nonisolated func bitmapFingerprint<Bytes: Collection>(_ bytes: Bytes) -> UInt64
where Bytes.Element == UInt8 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in bytes {
        hash ^= UInt64(byte)
        hash = hash &* 0x1000_0000_01b3
    }
    return hash
}

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

nonisolated func bitmapDifferenceSummary<Bytes: Collection>(_ a: Bytes?, _ b: Bytes?) -> String
where Bytes.Element == UInt8 {
    func describe(_ bytes: Bytes?) -> String {
        guard let bytes else { return "nil" }
        return "\(bytes.count) B / fp=0x\(String(bitmapFingerprint(bytes), radix: 16))"
    }
    let head = "a=[\(describe(a))] b=[\(describe(b))]"
    if let failure = bitmapRenderFailure(a, b) { return "\(head)\n\(failure)" }
    guard let a, let b else { return head }
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
    let matches = a == b
    #expect(
        matches,
        Comment(rawValue: bitmapExpectationMessage(comment(), a, b)),
        sourceLocation: sourceLocation
    )
}

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

// MARK: - 容差相等（Issue #358）

/// 逐通道最大偏差 —— `a` 与 `b` 长度须相同，返回 `nil` 表示任一侧未渲染。
nonisolated func bitmapMaxChannelDelta<Bytes: Collection>(_ a: Bytes?, _ b: Bytes?) -> Int?
where Bytes.Element == UInt8 {
    guard let a, let b, a.count == b.count else { return nil }
    var maxDelta = 0
    for (lhs, rhs) in zip(a, b) {
        let delta = Int(lhs) > Int(rhs) ? Int(lhs) - Int(rhs) : Int(rhs) - Int(lhs)
        if delta > maxDelta { maxDelta = delta }
    }
    return maxDelta
}

/// 断言两张位图**在光栅化噪声以内**相同：逐通道偏差不超过 `maxChannelDelta`。
///
/// ⚠️ **不要拿它替换 `expectBitmapsEqual`**。只用在「两张图按构造应当逐像素同值、
/// 但画面里含抗锯齿的字形 / 曲线边缘」的地方——那种边缘的量化舍入在**同一份输入**上
/// 都不稳定（`#358` 实测：同参数连渲两次，3/20000 像素差 ±1）。
///
/// 判据强度未被削弱：本函数钉的是**逐通道最大偏差**，不是「差异像素数」。
/// 真正的图层渗透会以饱和色按 α 合成上来，偏差是几十到上百，`maxChannelDelta: 1` 照样判红。
nonisolated func expectBitmapsEquivalent<Bytes: Collection & Equatable>(
    _ a: Bytes?,
    _ b: Bytes?,
    maxChannelDelta: Int,
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
    guard let delta = bitmapMaxChannelDelta(a, b) else {
        #expect(
            Bool(false),
            Comment(rawValue: bitmapExpectationMessage("两张位图长度不同，无法逐通道比较。" + comment(), a, b)),
            sourceLocation: sourceLocation
        )
        return
    }
    #expect(
        delta <= maxChannelDelta,
        Comment(rawValue: bitmapExpectationMessage(
            "逐通道最大偏差 \(delta) > 容差 \(maxChannelDelta)。" + comment(), a, b
        )),
        sourceLocation: sourceLocation
    )
}
