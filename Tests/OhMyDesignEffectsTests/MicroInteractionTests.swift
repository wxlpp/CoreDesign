import OhMyDesign
import SwiftUI
import Testing

private enum IsolatedTrigger: Equatable { case idle, done }

@testable import OhMyDesignEffects

@Suite("MicroInteractionStrength 语义档位")
struct MicroInteractionStrengthTests {
    @Test("三条轴都随档位单调递增")
    func monotonic() {
        let all = MicroInteractionStrength.allCases
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.displacement < $1.displacement })
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.scaleDelta < $1.scaleDelta })
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.particleCount < $1.particleCount })
    }

    @Test("粒子数至少 1 —— 0 会让 spray 静默什么都不画")
    func particleCountIsPositive() {
        #expect(MicroInteractionStrength.allCases.allSatisfy { $0.particleCount >= 1 })
    }

    @Test("SpinDirection 的 sign 互为相反数")
    func spinDirection() {
        #expect(SpinDirection.clockwise.sign == -SpinDirection.counterClockwise.sign)
        #expect(SpinDirection.clockwise.sign > 0)
    }
}

@Suite("微交互的 API 契约")
@MainActor
struct MicroInteractionAPITests {
    static func pixels(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        #else
        var rect = CGRect(origin: .zero, size: renderer.nsImage?.size ?? .zero)
        guard let cg = renderer.nsImage?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        else { return nil }
        #endif
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress, let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        return Data(buffer)
    }

    private static let processWarmUp: Bool = {
        let probe = Text("Unlock").frame(width: 320, height: 44).background(Color.accent)
        for _ in 0..<8 { _ = Self.pixels(probe) }
        return true
    }()

    static func stablePixels(_ view: some View) -> Data? {
        _ = Self.processWarmUp
        _ = Self.pixels(view)
        _ = Self.pixels(view)
        return Self.pixels(view)
    }

    @Test("九个入口全部存在且可链式组合")
    func allEntryPointsCompose() {
        let composed = Text("x")
            .shake(trigger: 1)
            .jump(trigger: 1)
            .spin(trigger: 1)
            .ping(trigger: 1)
            .spray(trigger: 1, symbol: "heart.fill")
            .rise(trigger: 1, text: "+1")
            .haptic(.success, trigger: 1)
            .shine(trigger: 1)
            .confetti(trigger: 1)
        #expect(Self.stablePixels(composed) != nil, "叠加 9 个后渲染失败")
    }
    @Test("静息态：九个叠加后位图与裸视图逐字节相同")
    func restingPixelsUnchanged() {
        let bare = Self.stablePixels(Text("x"))
        let stacked = Self.stablePixels(
            Text("x")
                .shake(trigger: 1)
                .jump(trigger: 1)
                .spin(trigger: 1)
                .ping(trigger: 1)
                .spray(trigger: 1, symbol: "heart.fill")
                .rise(trigger: 1, text: "+1")
                .haptic(.success, trigger: 1)
                .shine(trigger: 1)
                .confetti(trigger: 1)
        )
        #expect(bare != nil && stacked != nil, "渲染失败，下面的相等断言会静默变绿")
        expectBitmapsEqual(bare, stacked, "叠加 9 个微交互后静息位图变了 —— 有效果在静息态就在画东西")
    }

    @Test("静息态：九个各自单独用、三种内容都不改变位图")
    func eachEffectRestsClean() {
        func check(_ contentName: String, _ content: some View) {
            let bare = Self.stablePixels(content.modifier(EmptyModifier()))
            #expect(bare != nil, "\(contentName) 渲染失败")
            let cases: [(String, Data?)] = [
                ("shake", Self.stablePixels(content.shake(trigger: 1))),
                ("jump", Self.stablePixels(content.jump(trigger: 1))),
                ("spin", Self.stablePixels(content.spin(trigger: 1))),
                ("ping", Self.stablePixels(content.ping(trigger: 1))),
                ("spray", Self.stablePixels(content.spray(trigger: 1, symbol: "heart.fill"))),
                ("rise", Self.stablePixels(content.rise(trigger: 1, text: "+1"))),
                ("haptic", Self.stablePixels(content.haptic(.success, trigger: 1))),
                ("shine", Self.stablePixels(content.shine(trigger: 1))),
                ("confetti", Self.stablePixels(content.confetti(trigger: 1))),
            ]
            for (name, pixels) in cases {
                expectBitmapsEqual(pixels, bare, "\(name) 在 \(contentName) 上静息就改变了位图")
            }
        }
        check("Text", Text("x"))
        check("SFSymbol", Image(systemName: "star.fill").font(.system(size: 40)))
        check("WideBackground", Text("Unlock").frame(width: 320, height: 44).background(Color.accent))
    }

    @Test("rise 的跨 bundle 绕行：预解析字符串包成 LocalizedStringKey 后原样渲染")
    func riseAcceptsPreResolvedLocalizedString() {
        let resolved = "已加一分"
        let verbatim = Self.stablePixels(Text(verbatim: resolved))
        let viaKey = Self.stablePixels(Text(LocalizedStringKey(resolved)))
        #expect(verbatim != nil && viaKey != nil, "渲染失败，下面的相等断言会静默变绿")
        expectBitmapsEqual(verbatim, viaKey, "Bundle.main 查不到该键时未原样回落 —— rise 文档写的绕行方式失效")
        let applied = Self.stablePixels(
            Text("x").rise(trigger: 1, text: LocalizedStringKey(resolved))
        )
        #expect(applied != nil, "预解析字符串包成的 key 无法传给 .rise")
    }

    @Test("public 入口数 == 叠加/逐件清单的长度")
    func entryCountMatchesLists() throws {
        var entries = 0
        for url in try MicroInteractionReduceMotionGuard.swiftFiles() {
            let code = try String(contentsOf: url, encoding: .utf8)
            guard let r = code.range(of: "public extension View") else { continue }
            entries += code[r.upperBound...].components(separatedBy: "\n")
                .filter { $0.hasPrefix("    func ") }.count
        }
        let detail = "`public extension View` 里有 \(entries) 个 trigger 入口，"
            + "而本文件两处清单是 9 个 —— 新增效果后请同步，否则它在静息像素这一层零覆盖"
        #expect(entries == 9, "\(detail)")
    }

    static func shinePinned(_ content: some View, progress: CGFloat) -> some View {
        content.overlay {
            GeometryReader { proxy in
                let travel = proxy.size.width + proxy.size.height
                ShineBand.gradient(travel: travel, highlight: .specularHighlight)
                    .offset(x: ShineBand.offset(progress: progress, travel: travel))
            }
            .mask(content)
        }
    }

    @Test("动画终帧态：Spin / Shine 的终点变换是恒等（真轨道求值 + 位图）")
    func terminalFrameIsIdentity() {
        let bare = Self.stablePixels(Text("x"))
        #expect(bare != nil, "渲染失败，下面的相等断言会静默变绿")

        // MARK: Spin —— 终帧转角取模后必须是 0，且施加它与裸视图逐字节相同

        for direction in SpinDirection.allCases {
            let timeline = KeyframeTimeline(initialValue: SpinTurn.initialTurns) {
                SpinTurn.track(direction: direction)
            }
            let turns = timeline.value(time: timeline.duration)
            let angle = SpinTurn.angle(turns: turns, isReduced: false)
            let detail = "Spin(\(direction)) 终帧转到 \(turns)°，取角后是 \(angle)° —— "
                + "不是恒等，动画结束后会永久残留一个变换"
            #expect(angle == 0, "\(detail)")
            expectBitmapsEqual(Self.stablePixels(Text("x").rotationEffect(.degrees(angle))), bare,
                    "Spin(\(direction)) 终帧角 \(angle)° 施加后位图与裸视图不同")
        }
        expectBitmapsDiffer(Self.stablePixels(Text("x").rotationEffect(.degrees(37))), bare,
                "harness 分辨不出 37° 旋转 —— Spin 那条相等断言是恒真的")

        // MARK: Shine —— 终帧光带必须完全扫出遮罩之外

        let timeline = KeyframeTimeline(initialValue: ShineBand.initialProgress) {
            ShineBand.track()
        }
        let terminal = timeline.value(time: timeline.duration)
        expectBitmapsEqual(Self.stablePixels(Self.shinePinned(Text("x"), progress: terminal)), bare,
                "Shine 终帧 progress = \(terminal) —— 光带没有完全扫出界，会永久留在内容上")
        expectBitmapsDiffer(Self.stablePixels(Self.shinePinned(Text("x"), progress: 0)), bare,
                "钉帧路径在 progress = 0 都量不出光带 —— 上一条相等断言是恒真的")
    }

    @Test("用动画器的文件清单固定 —— 新增一个就必须回头补它的终帧判据")
    func animatorFilesAreEnumerated() throws {
        var animatorFiles: Set<String> = []
        for url in try MicroInteractionReduceMotionGuard.swiftFiles() {
            let code = MicroInteractionReduceMotionGuard.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            guard code.contains("keyframeAnimator(") || code.contains("phaseAnimator(")
            else { continue }
            animatorFiles.insert(url.lastPathComponent)
        }
        let known: Set<String> = [
            "Spin.swift", "Shine.swift",
            "Shake.swift", "Jump.swift", "Ping.swift", "Spray.swift", "Rise.swift",
            "MicroInteractionSupport.swift",
        ]
        let detail = "用动画器的文件从 \(known.sorted()) 变成了 \(animatorFiles.sorted()) —— "
            + "请同步本清单，并到 terminalFrameIsIdentity 补上新文件的终帧判据"
        #expect(animatorFiles == known, "\(detail)")
    }

    @Test("互锁：同一 harness 能分辨出真实差异")
    func harnessDetectsDifference() {
        let bare = Self.stablePixels(Text("x"))
        let probe = Self.stablePixels(Text("x").opacity(0.4))
        #expect(bare != nil && probe != nil)
        #expect(bare?.contains(where: { $0 != 0 }) == true,
                "位图全 0 —— CGContext 没有写进我们比较的这块缓冲，所有相等断言都是恒真的")
        expectBitmapsDiffer(bare, probe, "harness 分辨不出 opacity 差异 —— 上一条相等断言是恒真的")
    }

    @Test("trigger 接受任意 Equatable —— 含 MainActor 隔离 conformance 的类型")
    func triggerIsGeneric() {
        let v = Text("x")
            .shake(trigger: IsolatedTrigger.done)
            .spin(trigger: "string")
            .ping(trigger: 3.14)
        let stacked = Self.stablePixels(v)
        #expect(stacked != nil)
        expectBitmapsEqual(stacked, Self.stablePixels(Text("x")))
    }
}

// MARK: - #262 第 1 轮 review：AC 逐字对齐

@Suite("AC 逐字契约")
@MainActor
struct MicroInteractionACContractTests {
    static func source(_ fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/OhMyDesignEffects/\(fileName)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: spray 的色板契约

    @Test("spray 空色板 ⇒ 无显式色（交给 .tint），非空 ⇒ 按下标轮转")
    func sprayPaletteContract() {
        #expect([Color]().particleColor(at: 0) == nil, "空色板必须回落到 .tint，而不是取某个具体色")
        #expect([Color]().particleColor(at: 7) == nil)

        let two: [Color] = [.red, .blue]
        #expect(two.particleColor(at: 0) == .red)
        #expect(two.particleColor(at: 1) == .blue)
        #expect(two.particleColor(at: 2) == .red, "非空色板必须按下标轮转")
        #expect(two.particleColor(at: 3) == .blue)
    }

    @Test("spray 的公开入口用 colors: 标签、默认空数组，且实现里没有 Color.accent 回退")
    func sprayEntrySignatureMatchesAC() throws {
        let code = try Self.source("Spray.swift")
        #expect(code.contains("colors: [Color] = []"),
                "AC 逐字写的是 `.spray(trigger:symbol:colors:)`，且默认应为空 ⇒ 回落 .tint")
        #expect(!code.contains("[Color.accent]"),
                "空色板不得回退到 Color.accent —— 它不跟随 .tint(_:)")
    }

    @Test("spray 可用 colors: 标签调用，也可省略")
    func sprayCallableWithColorsLabel() {
        let explicit = Text("x").spray(trigger: 1, symbol: "heart.fill", colors: [.red, .blue])
        let defaulted = Text("x").spray(trigger: 1, symbol: "heart.fill")
        #expect(MicroInteractionAPITests.stablePixels(explicit) != nil)
        #expect(MicroInteractionAPITests.stablePixels(defaulted) != nil)
    }

    // MARK: Shine 的容器形态

    @Test("Shine { } 容器形态存在，且静息位图与裸视图逐字节相同")
    func shineContainerExists() {
        let bare = MicroInteractionAPITests.stablePixels(Text("x"))
        let wrapped = MicroInteractionAPITests.stablePixels(Shine { Text("x") })
        #expect(bare != nil && wrapped != nil, "渲染失败，下面的相等断言会静默变绿")
        expectBitmapsEqual(bare, wrapped, "Shine 容器在静息态就改变了位图")
    }

    @Test("Shine 容器必须委托给 .shine(trigger:)，不得绕过它自建一套（RM 降级由 modifier 承载）")
    func shineContainerDelegatesToModifier() throws {
        let code = try Self.source("Shine.swift")
        guard let start = code.range(of: "public struct Shine<Content: View>: View {") else {
            Issue.record("找不到 Shine 容器声明")
            return
        }
        let tail = code[start.upperBound...]
        let end = tail.range(of: "\npublic extension View")?.lowerBound ?? tail.endIndex
        let body = String(tail[tail.startIndex..<end])

        #expect(body.contains(".shine(trigger:"),
                "Shine 容器必须复用 `.shine(trigger:)`，RM 降级与 .mask 限度都继承自它")
        let forbidden = ["keyframeAnimator(", "phaseAnimator(", "LinearGradient(", ".mask("]
        let offenders = forbidden.filter { body.contains($0) }
        #expect(offenders.isEmpty,
                "Shine 容器里出现了自建的动画/绘制实现 \(offenders) —— 那会绕过 modifier 的 Reduce Motion 降级")
    }
}
