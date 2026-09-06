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
