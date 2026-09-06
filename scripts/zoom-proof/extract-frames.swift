import AVFoundation
import CoreImage
import Foundation

// 逐样本解码，不抽样、不去重。
// ⚠️ 有意不用 `AVAssetImageGenerator` 按时刻取帧：网格比帧间隔粗时，某些帧在任何网格点上
// 都不是「当前帧」，于是整帧不出现——而零容差请求落在两帧之间**不会报错**，返回前一帧，
// 所以这种丢帧是静默的。模拟器录屏是变帧率的（时基 600 Hz；实测同一批文件里中位
// 15.0 ms = 9/600 与 16.67 ms = 10/600 都有，最短样本 1.667 ms = 1/600），
// 减小步长只能降概率、不能消除。
// ⚠️ 本机 I/O 失败（建目录 / 写文件）走顶层 trap，退出码 133，不在下面 1 / 2 那套约定里。
// ⚠️ 非零退出时 outDir 里可能已留下部分 PNG —— 调用方别忽略退出码直接 glob。
// ⚠️ 直通样本数会多于解码帧数：重复时间戳的样本解码后合并为一帧，末尾还有零时长收尾样本。
// 输出已按显示顺序单调递增（`measure.py` 按文件名排序因此安全）。
// ⚠️ `alwaysCopiesSampleData = false` 只在「同步写完再取下一帧」的循环里安全；
// 改成异步 / 并行编码 PNG 时必须去掉这一行。

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: extract-frames <movie> <outDir> [fromSeconds] [toSeconds]\n", stderr)
    exit(2)
}
func seconds(_ index: Int, default fallback: Double) -> Double {
    guard args.count > index else { return fallback }
    guard let value = Double(args[index]) else {
        fputs("bad time argument: \(args[index])\n", stderr)
        exit(2)
    }
    return value
}
let from = seconds(3, default: 0)
let to = seconds(4, default: .greatestFiniteMagnitude)
guard from <= to else { fputs("from > to\n", stderr); exit(2) }

let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let outDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let track: AVAssetTrack
do {
    guard let first = try await asset.loadTracks(withMediaType: .video).first else {
        fputs("no video track in \(args[1])\n", stderr)
        exit(1)
    }
    track = first
} catch {
    fputs("cannot read \(args[1]): \(error)\n", stderr)
    exit(1)
}

let reader: AVAssetReader
do {
    reader = try AVAssetReader(asset: asset)
} catch {
    fputs("cannot open reader for \(args[1]): \(error)\n", stderr)
    exit(1)
}
let output = AVAssetReaderTrackOutput(
    track: track,
    outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
)
output.alwaysCopiesSampleData = false
reader.add(output)
guard reader.startReading() else {
    fputs("startReading failed: \(reader.error.map(String.init(describing:)) ?? "unknown")\n", stderr)
    exit(1)
}

let ctx = CIContext()
var index = 0
var kept = 0
while let sample = output.copyNextSampleBuffer() {
    defer { index += 1 }
    let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
    guard pts >= from, pts <= to, let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    let ci = CIImage(cvPixelBuffer: buffer)
    guard let data = ctx.pngRepresentation(
        of: ci, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    ) else { continue }
    try data.write(to: outDir.appendingPathComponent(String(format: "s%03d_%.4fs.png", index, pts)))
    kept += 1
}
guard reader.status == .completed else {
    fputs("reader ended with status \(reader.status.rawValue): "
          + "\(reader.error.map(String.init(describing:)) ?? "unknown")\n", stderr)
    exit(1)
}
let window = to == .greatestFiniteMagnitude ? "[\(from), end]" : "[\(from), \(to)]"
print("decoded \(index) frames, wrote \(kept) in window \(window)")
