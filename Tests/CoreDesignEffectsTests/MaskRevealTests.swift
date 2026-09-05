import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #268：mask reveal 转场簇（iris / wipe / blinds / clock / glare / dissolve）
//
// ## 本文件三条「承重」断言，其余是它们的非退化前置（互锁）
//
// 1. `MaskRevealRenderTests.chromeRevealsMidFlight`
//    —— **揭示真的是连续的**。`TransitionPhase` 是 3 case frozen enum ⇒
//    `MaskReveal.progress(phase:)` 的可达取值只有 `{0, 1}`；若 `MaskRevealChrome`
//    不是 `Animatable`，用户看到的就是"整块内容凭空出现"，而三个真实相位上的
//    位图断言**照样全绿**。这枚缺陷在 `ParticleTransition`（#253 终审 C-A）
//    上真实发生过一次，本簇是同一族机制。
// 2. `MaskRevealRenderTests.identityIsBytewiseIdentityEvenWithOverflow`
//    —— **恒等相位是真的恒等**。自定义 `Transition` 的修饰器在被修饰视图的整个
//    生命周期里都生效，一个裁到 bounds 的 `clipShape` 会**永久**吃掉阴影 /
//    溢出子视图，且是在转场结束之后才吃掉。
// 3. `MaskRevealGeometryTests.sixEntryPointsAreSixDifferentGeometries`
//    —— **六个名字确实是六种东西**。本仓最常见的缺陷形态是「判定通过而东西
//    不工作」（粒子从没出现过、滑块左右画反而标签把两半都标错），六条静态成员
//    全部悄悄指向同一族几何是这一簇最可能的落点。
// 4. `MaskRevealTransitionBodyTests.bodyHandsChromeThePhaseAndTheKind`
//    —— **`MaskRevealTransition.body` 真的把调用方的相位与几何族交给了 chrome**。
//    ⚠️⚠️ **这一条是终审 C-1 补的，补的是上面三条全都看不见的洞**：`body` 是六个
//    公开静态成员通向 `MaskRevealChrome` 的**唯一**路径，而把它整段改成
//    `content.modifier(MaskRevealChrome(progress: 1, kind: .iris(anchor: .center)))`
//    （六种转场全部退化成「内容凭空出现」）时，本簇 31 条与全量 761 条**零红**
//    ——1 取的是静态成员的存储属性、2/3 直接构造 chrome、逐字钉不含 `body`。
// 5. `MaskRevealGeometryTests.identityClipsNothingRegardlessOfContentSize`
//    —— **恒等相位的"不裁"与内容尺寸无关**（终审 I-2）。上一版的余量按内容对角线
//    派生 ⇒ 一个 20×20 的图标配 `.shadow(radius: 30)`，阴影在转场结束**之后**
//    仍被永久裁掉，而 2 的被测内容（60×60、溢出 45pt）对这枚缺陷结构上不可见。
//
// ⚠️ 每一条断言在写下时都做过**变红自证**（故意注入对应缺陷 → 跑 → 看红 → 改回），
// 结果贴在 PR 正文里。没有做过这一步的断言不写结论性注释。
//
// ⚠️⚠️ **PR 正文上一版写过「31 条里 30 条被变异打红过、唯一没有的
// `allSixEntryPointsCompose` 是编译期契约、没有『绿着但不工作』的状态」——
// 那句话是假的，已按实测更正**：M-A 就是一个「编译通过、31 条全绿、六种转场全部
// 不工作」的状态。真实的覆盖缺口不是那一条，而是**整个 `MaskRevealTransitions.swift`
// 的 `body` 没有任何变异落在上面**。

// MARK: - 纯几何

@Suite("MaskReveal 几何契约")
struct MaskRevealGeometryTests {

    /// 判据统一用的内容 bounds。**非正方形**——正方形会把"横竖搞反"这一类缺陷藏起来。
    static let rect = CGRect(x: 0, y: 0, width: 160, height: 120)

    /// 采样网格边长。`20 × 20 = 400` 个内点，取格心。
    ///
    /// ⚠️⚠️ **必须是偶数**，这是实测换来的：`21` 时第 10 行的格心恰好落在
    /// `rect.midY` 上，而 `clock` 的扇形**顶点就在中心** ⇒ 水平射线正穿过那个顶点，
    /// `Path.contains(_:)` 在这种退化输入上给出的答案不稳定
    /// （实测 `p = 0.70` 判"在内"、`p = 0.75` 判"在外"，`revealGrowsMonotonically`
    /// 因此对一条**几何上完全单调**的扇形判红 10 个点）。偶数格心永远不落在中线上。
    /// ⚠️ 这是采样判据的限度、不是 `clock` 的缺陷：渲染出来的像素没有这个问题。
    static let samples = 20

    static func samplePoint(_ index: Int, in rect: CGRect = MaskRevealGeometryTests.rect) -> CGPoint {
        let column = index % Self.samples
        let row = index / Self.samples
        return CGPoint(
            x: rect.minX + rect.width * (Double(column) + 0.5) / Double(Self.samples),
            y: rect.minY + rect.height * (Double(row) + 0.5) / Double(Self.samples)
        )
    }

    /// 某个进度下**被揭示的采样点下标集合**。
    ///
    /// ⚠️ 走 `MaskReveal.path(for:in:)`（生产代码的总入口），不是某个分支函数
    /// ——判据要对**这条真路径**求值，包含恒等余量那一段变换。
    static func revealed(_ kind: MaskRevealKind, progress: Double) -> Set<Int> {
        let plan = MaskReveal.plan(kind: kind, progress: progress, isReduced: false)
        let path = MaskReveal.path(for: plan, in: Self.rect)
        return Set((0..<(Self.samples * Self.samples)).filter { path.contains(Self.samplePoint($0)) })
    }

    /// 六个**公开入口点**默认参数下的几何族。
    ///
    /// ⚠️ 刻意从 `MaskRevealTransition.<成员>` 取而不是就地写 `MaskRevealKind`：
    /// 判据要覆盖的正是"名字 → 几何"这段接线，就地写等于把接线抄一遍再验自己。
    static let entryPoints: [(name: String, kind: MaskRevealKind)] = [
        ("iris", MaskRevealTransition.iris.kind),
        ("wipe", MaskRevealTransition.wipe.kind),
        ("blinds", MaskRevealTransition.blinds.kind),
        ("clock", MaskRevealTransition.clock.kind),
        ("glare", MaskRevealTransition.glare.kind),
        ("dissolve", MaskRevealTransition.dissolve.kind),
    ]

    // MARK: 相位

    /// ⚠️ **本条曾在验一个没有已验证消费者的纯函数**（终审 C-1）：
    /// `MaskReveal.progress(phase:)` 的唯一消费者是 `MaskRevealTransition.body`，
    /// 而那段 `body` 此前没有任何判据 ⇒ 把它整段改成丢弃相位，本条照绿。
    /// 现由 `MaskRevealTransitionBodyTests.bodyHandsChromeThePhaseAndTheKind` 接上
    /// （它断言 chrome 拿到的进度**等于本函数的返回值**，而不是写死 0 / 1）。
    @Test("相位映射：identity ⇒ 完全揭示，两端 ⇒ 完全隐藏")
    func phaseMapping() {
        #expect(MaskReveal.progress(phase: .identity) == 1)
        #expect(MaskReveal.progress(phase: .willAppear) == 0)
        #expect(MaskReveal.progress(phase: .didDisappear) == 0)
    }

    @Test("进度被钳到 0…1，非有限值回落到 0")
    func progressIsClamped() {
        let kind = MaskRevealKind.iris(anchor: .center)
        #expect(MaskReveal.plan(kind: kind, progress: -3, isReduced: false).progress == 0)
        #expect(MaskReveal.plan(kind: kind, progress: 2.5, isReduced: false).progress == 1)
        #expect(MaskReveal.plan(kind: kind, progress: .nan, isReduced: false).progress == 0)
        // 弹性曲线会让 SwiftUI 插出 0…1 之外的值；不钳的话 `blinds` 的百叶会翻到自己背面。
        #expect(MaskReveal.plan(kind: kind, progress: 1.4, isReduced: false).progress == 1)
    }

    // MARK: 三条共同契约

    @Test("进度 0：六种都一个点都不揭示")
    func nothingRevealedAtZero() {
        for entry in Self.entryPoints {
            #expect(Self.revealed(entry.kind, progress: 0).isEmpty,
                    "\(entry.name) 在进度 0 上已经揭示了东西 —— 内容会在转场开始前就闪一下")
        }
    }

    @Test("进度 1：六种都完全揭示")
    func everythingRevealedAtOne() {
        let all = Self.samples * Self.samples
        for entry in Self.entryPoints {
            let revealed = Self.revealed(entry.kind, progress: 1)
            #expect(revealed.count == all,
                    "\(entry.name) 在进度 1 上只揭示了 \(revealed.count)/\(all) 个采样点 —— 转场停住之后内容仍有一块被裁掉")
        }
    }

    @Test("揭示区域随进度单调不减（不许先露后藏）")
    func revealGrowsMonotonically() {
        for entry in Self.entryPoints {
            var previous: Set<Int> = []
            for step in 0...20 {
                let progress = Double(step) / 20
                let current = Self.revealed(entry.kind, progress: progress)
                #expect(previous.isSubset(of: current), """
                \(entry.name) 从进度 \(Double(step - 1) / 20) 到 \(progress) 之间
                有 \(previous.subtracting(current).count) 个采样点**又被藏回去了**
                —— 揭示型转场倒着走，用户看到的是闪烁。
                """)
                previous = current
            }
        }
    }

    @Test("中途是**部分**揭示（不是 0 也不是全部）")
    func midProgressIsPartial() {
        let all = Self.samples * Self.samples
        for entry in Self.entryPoints {
            let revealed = Self.revealed(entry.kind, progress: 0.5).count
            #expect(revealed > 0 && revealed < all, """
            \(entry.name) 在进度 0.5 上揭示了 \(revealed)/\(all) 个采样点
            —— 要么它在中途什么都不画（转场退化成端点跳变），要么它中途就已经全开
            （上面的单调 / 覆盖两条会因此变成恒真）。
            """)
        }
    }

    /// ⚠️⚠️ **承重判据：六个名字确实是六种东西。**
    ///
    /// 这一簇最可能的失效形态不是"某一种画错了"，而是**六条静态成员悄悄指向同一族
    /// 几何**——`.transition(.blinds)` 与 `.transition(.clock)` 看起来都"能用"、
    /// 都有转场发生，只是它们其实是同一个。上面所有共同契约在这种情况下**全绿**。
    @Test("六个公开入口点是六种互不相同的几何")
    func sixEntryPointsAreSixDifferentGeometries() {
        var seen: [String: Set<Int>] = [:]
        for entry in Self.entryPoints {
            let revealed = Self.revealed(entry.kind, progress: 0.5)
            for (name, other) in seen {
                #expect(revealed != other, """
                `.\(entry.name)` 与 `.\(name)` 在进度 0.5 上揭示的区域**逐点相同**
                —— 两个公开名字指向了同一族几何。
                """)
            }
            seen[entry.name] = revealed
        }
        #expect(seen.count == 6)
    }

    @Test("六个入口点接到的几何族与名字对得上")
    func entryPointsMapToTheirOwnKind() {
        #expect(MaskRevealTransition.iris.kind == .iris(anchor: .center))
        #expect(MaskRevealTransition.iris(anchor: .topLeading).kind == .iris(anchor: .topLeading))
        #expect(MaskRevealTransition.wipe.kind
                == .wipe(radians: MaskRevealTransition.defaultWipeAngle.radians))
        #expect(MaskRevealTransition.wipe(angle: .degrees(90)).kind == .wipe(radians: .pi / 2))
        #expect(MaskRevealTransition.blinds.kind
                == .blinds(count: MaskRevealTransition.defaultBlindCount))
        #expect(MaskRevealTransition.blinds(count: 3).kind == .blinds(count: 3))
        #expect(MaskRevealTransition.clock.kind == .clock(sign: 1))
        #expect(MaskRevealTransition.clock(direction: .counterClockwise).kind == .clock(sign: -1))
        #expect(MaskRevealTransition.glare.kind
                == .glare(radians: MaskRevealTransition.defaultGlareAngle.radians))
        #expect(MaskRevealTransition.glare(angle: .degrees(-20)).kind == .glare(radians: -.pi / 9))
        #expect(MaskRevealTransition.dissolve.kind
                == .dissolve(cellSize: MaskRevealTransition.defaultCellSize))
        #expect(MaskRevealTransition.dissolve(cellSize: 12).kind == .dissolve(cellSize: 12))
        // ⚠️ 互锁：`.glare` 与 `.wipe` 共用同一条半平面数学，默认角度必须不同，
        // 否则调用方在默认参数下分不出两者（差别只剩柔光带）。
        #expect(MaskRevealTransition.defaultGlareAngle != MaskRevealTransition.defaultWipeAngle)
    }

    // MARK: 各族的方向 / 参数真的被用上了

    @Test("wipe 的角度选的是方向（0° 左→右、180° 右→左、90° 上→下）")
    func wipeAngleSelectsTheDirection() {
        let left = CGPoint(x: 8, y: 60), right = CGPoint(x: 152, y: 60)
        let top = CGPoint(x: 80, y: 6), bottom = CGPoint(x: 80, y: 114)
        func path(_ degrees: Double) -> Path {
            MaskReveal.path(
                for: MaskReveal.plan(
                    kind: .wipe(radians: Angle.degrees(degrees).radians),
                    progress: 0.3, isReduced: false
                ),
                in: Self.rect
            )
        }
        #expect(path(0).contains(left) && !path(0).contains(right), "0° 应该从左边开始揭示")
        #expect(path(180).contains(right) && !path(180).contains(left), "180° 应该从右边开始揭示")
        #expect(path(90).contains(top) && !path(90).contains(bottom), "90° 应该从上边开始揭示")
        #expect(path(-90).contains(bottom) && !path(-90).contains(top), "−90° 应该从下边开始揭示")
    }

    @Test("iris 的 anchor 选的是光圈中心")
    func irisAnchorSelectsTheOrigin() {
        func path(_ anchor: UnitPoint) -> Path {
            MaskReveal.path(
                for: MaskReveal.plan(kind: .iris(anchor: anchor), progress: 0.25, isReduced: false),
                in: Self.rect
            )
        }
        let nearTopLeading = CGPoint(x: 14, y: 10)
        let nearBottomTrailing = CGPoint(x: 146, y: 110)
        #expect(path(.topLeading).contains(nearTopLeading))
        #expect(!path(.topLeading).contains(nearBottomTrailing))
        #expect(path(.bottomTrailing).contains(nearBottomTrailing))
        #expect(!path(.bottomTrailing).contains(nearTopLeading))
        // 中心起手时两个角都还没轮到。
        #expect(!path(.center).contains(nearTopLeading))
        #expect(path(.center).contains(CGPoint(x: 80, y: 60)))
    }

    @Test("clock 的方向选的是扫针转向")
    func clockDirectionSelectsTheSweep() {
        let center = CGPoint(x: Self.rect.midX, y: Self.rect.midY)
        // 屏幕坐标 y 轴向下：−45° 是右上方，−135° 是左上方。
        let upperTrailing = CGPoint(x: center.x + 30 * cos(-.pi / 4), y: center.y + 30 * sin(-.pi / 4))
        let upperLeading = CGPoint(x: center.x + 30 * cos(-3 * .pi / 4), y: center.y + 30 * sin(-3 * .pi / 4))
        func path(_ sign: Double) -> Path {
            MaskReveal.path(
                for: MaskReveal.plan(kind: .clock(sign: sign), progress: 0.2, isReduced: false),
                in: Self.rect
            )
        }
        #expect(path(1).contains(upperTrailing), "顺时针起手 20% 应该先扫到右上")
        #expect(!path(1).contains(upperLeading), "顺时针起手 20% 不该已经扫到左上")
        #expect(path(-1).contains(upperLeading), "逆时针起手 20% 应该先扫到左上")
        #expect(!path(-1).contains(upperTrailing), "逆时针起手 20% 不该已经扫到右上")
    }

    /// 沿内容纵向中线扫描，数出"揭示 → 未揭示"的连续段数。
    static func blindBandCount(count: Int, progress: Double) -> Int {
        let path = MaskReveal.path(
            for: MaskReveal.plan(kind: .blinds(count: count), progress: progress, isReduced: false),
            in: Self.rect
        )
        var bands = 0
        var inside = false
        let steps = 1200
        for step in 0..<steps {
            let y = Self.rect.minY + Self.rect.height * (Double(step) + 0.5) / Double(steps)
            let hit = path.contains(CGPoint(x: Self.rect.midX, y: y))
            if hit, !inside { bands += 1 }
            inside = hit
        }
        return bands
    }

    @Test("blinds 的 count 真的决定百叶条数")
    func blindsCountSelectsTheBandCount() {
        for count in [2, 3, 5, 8] {
            #expect(Self.blindBandCount(count: count, progress: 0.3) == count,
                    "blinds(count: \(count)) 在中线上数出 \(Self.blindBandCount(count: count, progress: 0.3)) 条")
        }
    }

    @Test("blinds 的退化条数被钳到 1（而不是变成死转场）")
    func blindsClampsDegenerateCount() {
        for count in [0, -3, Int.min] {
            let revealed = Self.revealed(.blinds(count: count), progress: 0.5)
            #expect(!revealed.isEmpty, "blinds(count: \(count)) 在中途什么都不揭示 —— 死转场")
            #expect(revealed == Self.revealed(.blinds(count: 1), progress: 0.5))
        }
    }

    @Test("dissolve：次序确定、分布非退化")
    func dissolveOrderIsDeterministicAndWellSpread() {
        // ① 确定性：同样的输入两次求值必须逐点相同。
        #expect(Self.revealed(.dissolve(cellSize: 16), progress: 0.4)
                == Self.revealed(.dissolve(cellSize: 16), progress: 0.4))

        // ② 分布非退化。挡的是「浮现次序塌成少数几个值」这一族——那会让 dissolve
        // 退化成"整块一起浮现"，而上面的单调 / 覆盖 / 部分揭示三条在那种情况下**全绿**。
        //
        // ⚠️⚠️ **本条的动机曾被写成一枚不存在的缺陷，实测证伪后照录在此**：
        // 初版注释写「`mixed & 0x7FFF_FFFF % 1000` 里 `%` 比 `&` 结合得紧 ⇒ 实际算的是
        // `mixed & 647`」——那是 **C 的**优先级。Swift 的 `&` 是 `MultiplicationPrecedence`，
        // 与 `%` 同级、左结合。变异实证：把生产代码里的那对括号去掉重跑整簇，
        // 本条与 dissolve 的另外两条**全部照绿**、位图无变化（`out-M5.log`）。
        // ⇒ 本条真正能判红的是**换掉散列函数本身**（例如让它返回常数），见变异 M5b。
        var thresholds: Set<Int> = []
        for row in 0..<40 {
            for column in 0..<40 {
                thresholds.insert(Int(MaskReveal.cellThreshold(column: column, row: row) * 1000))
            }
        }
        #expect(thresholds.count > 300,
                "1600 个格子只算出 \(thresholds.count) 个不同的浮现次序 —— 伪随机塌了")
        #expect((thresholds.max() ?? 0) > 900, "浮现次序的上界只到 \((thresholds.max() ?? 0)) / 1000")
    }

    @Test("dissolve 的 cellSize 真的决定格子大小")
    func dissolveCellSizeSelectsTheGrid() {
        let fine = Self.revealed(.dissolve(cellSize: 8), progress: 0.5)
        let coarse = Self.revealed(.dissolve(cellSize: 40), progress: 0.5)
        #expect(fine != coarse, "cellSize 8 与 40 揭示的区域逐点相同 —— 参数没被用上")
    }

    /// 一条 `Path` 里有多少条子路径 —— 数 `.move` 事件。
    ///
    /// ⚠️ 存在理由见 `dissolveClampsDegenerateCellSize` ①：要量的是 `dissolvePath`
    /// **实际画了多少格**，而不是在测试里把生产代码的格数公式抄一遍。
    static func subpathCount(_ path: Path) -> Int {
        var count = 0
        path.forEach { element in
            if case .move = element { count += 1 }
        }
        return count
    }

    @Test("dissolve 的退化 cellSize：不崩、不爆量、仍然是一条活转场")
    func dissolveClampsDegenerateCellSize() {
        let huge = CGRect(x: 0, y: 0, width: 1200, height: 900)

        // ① 过小的值被抬到让格数落在量级闸内。
        //
        // ⚠️⚠️ **本条上一版喂的是「字面量进闸」而不是「闸的输出」，实测可整个绕过**
        // （终审 I-1，变异 M-H）：上一版直接调 `effectiveCellSize(0.5, in: huge)`
        // 再**照抄一遍生产代码的格数公式**，从未观测 `dissolvePath` 到底生成了多少
        // 子路径 ⇒ 让 `dissolvePath` 跳过闸（`side = cellSize`），整簇 31 条**零红**，
        // 而那时 `.dissolve(cellSize: 0.5)` 在 1200×900 上是 2400×1800 ≈ **432 万个
        // 子路径逐帧重建**——正是 `MaskReveal.dissolveMaximumCells` 的注释里写着
        // 「那不是『慢』，是卡死」的那个场景。
        // ⇒ 现在量的是 `dissolvePath` 自己的输出。
        //
        // ⚠️ 上限取 `dissolveMaximumCells * 2` 而不是一个精确格数：`columns` / `rows`
        // 各要向上取整，`(c+1)(r+1)` 天然会略微越过上限（实测 52×39 = 2028），
        // 而把那条修正公式写进判据就又变成"抄一遍生产代码"。本条守的是**量级闸**
        // ——2028 与 432 万之间有三个数量级，任何"闸没接上"的形态都落在这条线之外。
        let atFull = Self.subpathCount(
            MaskReveal.dissolvePath(cellSize: 0.5, progress: 1, in: huge)
        )
        #expect(atFull > 0, "cellSize 0.5 在 1200×900 上一个格子都没画 —— 死转场")
        #expect(atFull <= MaskReveal.dissolveMaximumCells * 2, """
        `.dissolve(cellSize: 0.5)` 在 1200×900 上实际生成了 \(atFull) 条子路径
        （上限 \(MaskReveal.dissolveMaximumCells * 2)）—— 逐帧重建这么多子路径会卡死。
        请检查 `MaskReveal.dissolvePath` 是否真的走了 `effectiveCellSize(_:in:)` 这道闸。
        """)

        // ⚠️ 互锁：`dissolvePath` 的格子必须**就是**闸算出来的那个边长。
        // 少了它，上一条可以被"闸的输出恰好也落在量级内"这类巧合放过；
        // 有了它，跳过闸的形态（M-H）在这里逐格判红。
        let side = MaskReveal.effectiveCellSize(0.5, in: huge)
        #expect(atFull == Self.subpathCount(
            MaskReveal.dissolvePath(cellSize: side, progress: 1, in: huge)
        ), """
        `dissolvePath(cellSize: 0.5)` 与 `dissolvePath(cellSize: effectiveCellSize(0.5))`
        画出的格数不同 —— `dissolvePath` 没有走 `effectiveCellSize(_:in:)` 这道闸。
        """)

        // ② 非法值回落到默认值。
        //
        // ⚠️ 断言的是**回落值与 `.dissolve()` 的默认实参同源**，不只是"合法"
        // （#291 第 2 轮 Copilot id=3933604025）：上一版 `MaskReveal.dissolveDefaultCellSize`
        // 与 `MaskRevealTransition.defaultCellSize` 各自独立写了一个 `24`，
        // 只改一处两者就静默分叉，而"合法且为正"这条弱断言对那枚缺陷零可见性。
        for bad: CGFloat in [0, -5, .nan, .infinity] {
            let resolved = MaskReveal.effectiveCellSize(bad, in: Self.rect)
            #expect(resolved.isFinite && resolved > 0, "cellSize \(bad) 解析成了 \(resolved)")
            #expect(resolved == MaskRevealTransition.defaultCellSize, """
            `cellSize \(bad)` 回落到 \(resolved)，而 `.dissolve()` 的默认实参是
            `MaskRevealTransition.defaultCellSize` = \(MaskRevealTransition.defaultCellSize)
            —— 两个"默认值"已经分叉：同一个 `.dissolve()` 在「不传参」与「传非法值」
            两条入口上会画出两种格子，而且都不报错。
            请让 `MaskReveal.dissolveDefaultCellSize` 继续直接引用那个 `public` 常量。
            """)
        }
        // ③ 退化输入下转场仍然发生。
        #expect(!Self.revealed(.dissolve(cellSize: 0), progress: 0.5).isEmpty)
        #expect(!Self.revealed(.dissolve(cellSize: -5), progress: 0.5).isEmpty)
    }

    // MARK: 恒等余量

    @Test("恒等余量只在最后一段张开，且张开量随进度单增")
    func haloOpensOnlyAtTheEnd() {
        #expect(MaskReveal.halo(progress: 0) == 0)
        #expect(MaskReveal.halo(progress: MaskReveal.haloOnset) == 0)
        #expect(MaskReveal.halo(progress: 1) == 1)
        #expect(MaskReveal.halo(progress: (MaskReveal.haloOnset + 1) / 2) > 0)

        // 进度**还没到 1** 的那一段由 `haloPath` 承担（进度 1 已被 `path(for:in:)`
        // 短路到 `openPath`，见下一条判据）。这里钉的是"最后 15% 里外框确实在张开"：
        // 0.95 时 bounds 外半条对角线处的点已经被包住。
        let diagonal = hypot(Self.rect.width, Self.rect.height)
        for entry in Self.entryPoints {
            let path = MaskReveal.path(
                for: MaskReveal.plan(kind: entry.kind, progress: 0.95, isReduced: false),
                in: Self.rect
            )
            let far = Self.rect.insetBy(dx: -diagonal * 0.5, dy: -diagonal * 0.5)
            for corner in MaskReveal.corners(of: far) {
                #expect(path.contains(corner), """
                \(entry.name) 在进度 0.95 上仍然裁掉了 bounds 外 \(Int(diagonal * 0.5))pt 处的内容
                —— 恒等余量没有在最后一段张开，转场收尾会看到溢出内容一次闪跳。
                """)
            }
        }
    }

    /// ⚠️⚠️ **承重判据（终审 I-2 补）：恒等相位的"不裁"与内容尺寸无关。**
    ///
    /// 上一版的余量是 `hypot(rect.width, rect.height) * halo(...)` —— 按**内容对角线**
    /// 派生 ⇒ 「`progress == 1` 时裁剪对任何溢出内容都不再有任何作用」这句绝对表述
    /// **只在一条对角线以内成立**。实测（临时探针）：
    /// ```
    /// small 4x4 @identity contains(-30pt above) = false
    /// small 4x4 @identity contains(-4pt  above) = true
    /// badge 60x24 @identity contains(-80pt above) = false
    /// RM 4x4 contains(-30pt above) = false
    /// ```
    /// ⇒ 一个 20×20 的图标配 `.shadow(radius: 30)`，阴影在**转场结束之后**仍被永久吃掉
    /// ——正是这段设计要消灭的那类缺陷，只是把阈值从 0 抬到了一条对角线。
    /// 上一版的 `haloOpensOnlyAtTheEnd` 看不见它，因为它刻意只采到 **0.9 倍**对角线。
    ///
    /// ⚠️ 本条**逐个尺寸**采样，且采样距离与内容尺寸**无关**（取 `openReach` 的 0.9 倍）
    /// ——只要有人把余量改回"按内容派生"，小内容那一档当场判红。
    @Test("恒等相位与 Reduce Motion 下的裁剪对任何尺寸的溢出内容都不起作用")
    func identityClipsNothingRegardlessOfContentSize() {
        // ⚠️ 三种尺寸：一个正常内容、一个 badge 形状、一个**极小**内容
        // （对角线 5.66pt —— 上一版在它上面连 30pt 的阴影都吃掉）。
        let boxes: [(name: String, rect: CGRect)] = [
            ("160×120", Self.rect),
            ("60×24 badge", CGRect(x: 0, y: 0, width: 60, height: 24)),
            ("4×4 icon", CGRect(x: 0, y: 0, width: 4, height: 4)),
        ]
        // ⚠️ 取 0.9 倍而不是整条 `openReach`：整条恰好落在外框的**外边界**上，
        // 边界点的 `contains` 取决于浮点比较方向，判据会变得看运气。
        let far = MaskReveal.openReach * 0.9

        for box in boxes {
            for entry in Self.entryPoints {
                for (label, isReduced) in [("恒等相位", false), ("Reduce Motion", true)] {
                    let plan = MaskReveal.plan(
                        kind: entry.kind, progress: 1, isReduced: isReduced
                    )
                    let path = MaskReveal.path(for: plan, in: box.rect)
                    for corner in MaskReveal.corners(of: box.rect.insetBy(dx: -far, dy: -far)) {
                        #expect(path.contains(corner), """
                        \(entry.name) 在 \(label) 下裁掉了 \(box.name) 内容 bounds 外
                        \(Int(far))pt 处的东西 —— 余量又变回"按内容尺寸派生"了。
                        一个 20×20 的图标配 `.shadow(radius: 30)`，阴影会在**转场结束之后**
                        被永久吃掉，而这是本簇最难归因的那一类缺陷。
                        """)
                    }
                }
            }
        }
        // 互锁：`openReach` 与内容尺寸无关 ⇒ 三种尺寸拿到的余量必须一样大。
        // （若它又变回派生量，4×4 与 160×120 的外框宽度就会差 30 倍。）
        for box in boxes {
            let open = MaskReveal.openPath(in: box.rect).boundingRect
            #expect(open.width - box.rect.width == MaskReveal.openReach * 2,
                    "\(box.name) 的全开余量是 \((open.width - box.rect.width) / 2)pt，不是 openReach")
        }
    }

    @Test("零尺寸 bounds 不崩、不揭示")
    func zeroSizedBoundsIsEmpty() {
        for entry in Self.entryPoints {
            for progress in [0.0, 0.5, 1.0] {
                let plan = MaskReveal.plan(kind: entry.kind, progress: progress, isReduced: false)
                #expect(MaskReveal.path(for: plan, in: .zero).isEmpty, "\(entry.name) @ \(progress)")
            }
        }
    }

    // MARK: Reduce Motion

    @Test("Reduce Motion：遮罩全开、内容不透明度跟着进度走（不是 no-op）")
    func reduceMotionOpensTheMaskAndCrossFadesInstead() {
        let all = Self.samples * Self.samples
        for entry in Self.entryPoints {
            for progress in [0.0, 0.25, 0.5, 1.0] {
                let plan = MaskReveal.plan(kind: entry.kind, progress: progress, isReduced: true)
                #expect(plan.kind == nil, "\(entry.name) 在 Reduce Motion 下仍然带着几何族")
                #expect(plan.glare == nil, "\(entry.name) 在 Reduce Motion 下仍然画柔光带")
                #expect(plan.contentOpacity == progress, """
                \(entry.name) 在 Reduce Motion 下的内容不透明度是 \(plan.contentOpacity)
                而不是进度 \(progress) —— 降级要么变成 no-op（界面瞬间跳变），
                要么内容永远不出现。
                """)
                let path = MaskReveal.path(for: plan, in: Self.rect)
                let revealed = (0..<all).filter { path.contains(Self.samplePoint($0)) }.count
                #expect(revealed == all,
                        "\(entry.name) 在 Reduce Motion 下仍然裁掉了 \(all - revealed) 个采样点")
            }
        }
        // 互锁：运动路径上内容不透明度恒为 1，揭示完全由几何承担。
        for entry in Self.entryPoints {
            #expect(MaskReveal.plan(kind: entry.kind, progress: 0.5, isReduced: false)
                .contentOpacity == 1, "\(entry.name) 在运动路径上也叠了透明度 —— 两套揭示叠加")
        }
    }

    // MARK: 柔光带

    @Test("柔光带：只有 glare 有，且两端不透明度恒为 0")
    func glareBandBelongsToGlareAloneAndVanishesAtBothEnds() {
        for entry in Self.entryPoints {
            let plan = MaskReveal.plan(kind: entry.kind, progress: 0.5, isReduced: false)
            if entry.name == "glare" {
                #expect(plan.glare?.travel == 0.5, "glare 的柔光带没跟上揭示进度")
                #expect(plan.glare?.radians == MaskRevealTransition.defaultGlareAngle.radians)
            } else {
                #expect(plan.glare == nil, "\(entry.name) 不该带柔光带")
            }
        }
        #expect(MaskReveal.glareOpacity(travel: 0) == 0)
        #expect(MaskReveal.glareOpacity(travel: 1) == 0, "恒等相位还留着一条高光 —— 永久残留")
        #expect(MaskReveal.glareOpacity(travel: 0.5) > 0.99)
        #expect(MaskReveal.glareOpacity(travel: 0.1) > 0)
    }

    @Test("柔光带骑在揭示边上，而不是各算各的")
    func glareBandRidesTheRevealEdge() {
        let radians = MaskRevealTransition.defaultGlareAngle.radians
        for travel in [0.25, 0.5, 0.75] {
            let band = MaskReveal.glarePath(
                MaskRevealGlare(radians: radians, travel: travel), in: Self.rect
            )
            let revealed = MaskReveal.path(
                for: MaskReveal.plan(kind: .glare(radians: radians), progress: travel, isReduced: false),
                in: Self.rect
            )
            // 光带的后缘落在已揭示的一侧、前缘落在未揭示的一侧 ⇒ 它压在那条边上。
            let inside = (0..<(Self.samples * Self.samples))
                .map { Self.samplePoint($0) }
                .filter { band.contains($0) }
            #expect(!inside.isEmpty, "travel \(travel) 的柔光带在内容范围内一个点都不覆盖")
            #expect(inside.contains(where: { revealed.contains($0) }),
                    "travel \(travel) 的柔光带完全落在**未**揭示的一侧 —— 它没骑在边上")
            #expect(inside.contains(where: { !revealed.contains($0) }),
                    "travel \(travel) 的柔光带完全落在**已**揭示的一侧 —— 它跑到边后面去了")
        }
    }
}

// MARK: - 渲染与插值

@Suite("MaskReveal 的渲染与插值")
@MainActor
struct MaskRevealRenderTests {

    /// 形态同 `ConfettiTests.canvasWarmUp` / `ParticleTransitionTests.chromeWarmUp`：
    /// 在跑任何位图断言之前，把每一种**将被断言的视图形态**先渲若干遍。
    ///
    /// ## ⚠️⚠️ 病因照录，**上一版这段写错了因果**（终审 I-6，评审实测）
    ///
    /// 上一版写「`ImageRenderer` 在**进程内最早的若干次**渲染上给出的光栅化与之后不同」
    /// ——那个模型会让下一个人以为"多暖几次就行"。**实测更强也更难缠**：
    /// · 在进程级暖机**已经生效**的前提下，同一视图同一断言，**隔离**跑 5/5 正确；
    ///   把它放进 7 条测试的同一 suite 里跑 4 次，给出**三种不同答案**
    ///   （两次 `opacity(0)` 渲成完全不透明）；
    /// · 把 `.opacity` 挪到 5 个不同位置逐一**隔离**测，全部正常。
    /// ⇒ **位置无关，真正的变量是「跨测试交错」**，不是"进程内最早若干次"。
    ///
    /// ⚠️ 因此本暖机门是**承重**的，不是保险丝：实测绕过它（直接调
    /// `MicroInteractionAPITests.stablePixels`）时，`clock` / `glare` 在**同一条 `#Test`
    /// 内**三次调用都不收敛；走 `Self.pixels` 时 6/6 稳定、连跑 6 次全同，
    /// 真实 suite 隔离 8/8、全量 10/10。
    /// ⇒ **本文件的每一条位图断言都必须走 `Self.pixels`**。
    ///
    /// ⚠️⚠️ **这句话是要求，不是既成事实的完备保证——判据只是"大部分守住"**
    /// （#291 第 2 轮 Imp-2，上一版这里宣称由判据"钉住"，那是高估，照录更正）：
    /// `MaskRevealSourceGuard.bitmapAssertionsGoThroughTheWarmUpGate` 靠**源码后缀计数**
    /// 拦截，射程与已知缺口逐条写在那条判据的文档注释里。今天全簇确实都走 `Self.pixels`,
    /// 但别把那条判据读成"绕不过去"。
    ///
    /// ⚠️⚠️ **必须把「带 chrome 的形态」也跑热**：上一版只暖机了裸内容与空白两种，
    /// `chromeRevealsMidFlight` 于是**间歇性判红**——它比较「插值出的中间帧」与
    /// 「直接用 0.5 构造的中间帧」，两者结构相同、数值相同，而 Swift Testing
    /// 不保证测试顺序。实证：一个**语义上完全等价**的变异（去掉一对不影响求值的括号，
    /// 见 `dissolveOrderIsDeterministicAndWellSpread`）让这条判据判红
    /// ⇒ 它当时测的是渲染栈的状态，不是被测行为。
    private static let warmUp: Bool = {
        for _ in 0..<8 {
            _ = MicroInteractionAPITests.stablePixels(Self.framed(Self.overflowing()))
            _ = MicroInteractionAPITests.stablePixels(Self.framed(Self.tinyOverflowing()))
            _ = MicroInteractionAPITests.stablePixels(Self.framed(Self.empty()))
            for entry in Self.kinds {
                _ = MicroInteractionAPITests.stablePixels(Self.chrome(progress: 0.5, kind: entry.kind))
                _ = MicroInteractionAPITests.stablePixels(Self.framed(
                    Self.tinyOverflowing().modifier(MaskRevealChrome(progress: 1, kind: entry.kind))
                ))
            }
        }
        return true
    }()

    static func pixels(_ view: some View) -> Data? {
        _ = Self.warmUp
        return MicroInteractionAPITests.stablePixels(view)
    }

    /// 被测内容：一个 60×60 的视图，**故意**在自己的 bounds 之外还画着东西。
    ///
    /// ⚠️ 溢出这一半是承重的：裁剪型转场最隐蔽的缺陷是"恒等相位把溢出内容永久吃掉"，
    /// 而一个不溢出的被测内容对这枚缺陷**结构上零可见性**。
    static func overflowing() -> some View {
        Color.surfaceRaised
            .frame(width: 60, height: 60)
            .overlay { Rectangle().fill(Color.contentPrimary).frame(width: 150, height: 150) }
    }

    /// 同尺寸的空白对照（什么都不画）。
    static func empty() -> some View {
        Color.clear.frame(width: 60, height: 60)
    }

    /// ⚠️⚠️ **极小内容 + 大溢出**（终审 I-2 补）：4×4 的 bounds，对角线只有 5.66pt，
    /// 而画出来的东西溢出到 bounds 外 73pt。
    /// 上一版的恒等余量按**内容对角线**派生 ⇒ 这个形态在恒等相位仍被裁掉一大片，
    /// 而 `overflowing()`（60×60、溢出 45pt、对角线 84.85pt）对这枚缺陷
    /// **结构上零可见性**——溢出量恰好小于自己的对角线。
    static func tinyOverflowing() -> some View {
        Color.surfaceRaised
            .frame(width: 4, height: 4)
            .overlay { Rectangle().fill(Color.contentPrimary).frame(width: 150, height: 150) }
    }

    static func framed(_ view: some View) -> some View {
        view.frame(width: 200, height: 200).background(Color.accent)
    }

    static func chrome(progress: Double, kind: MaskRevealKind) -> some View {
        Self.framed(Self.overflowing().modifier(MaskRevealChrome(progress: progress, kind: kind)))
    }

    static let kinds: [(name: String, kind: MaskRevealKind)] = MaskRevealGeometryTests.entryPoints

    /// ⚠️⚠️ **承重判据：恒等相位是真的恒等。**
    ///
    /// 自定义 `Transition` 的修饰器在被修饰视图的**整个生命周期**里都生效
    /// ——转场停住之后相位是 `.identity`，修饰器并不会被摘掉。一个裁到 bounds 的
    /// `clipShape` 因此会**永久**吃掉阴影 / 溢出子视图，且是在转场结束之后才吃掉。
    @Test("恒等相位与裸视图逐字节相同（被测内容故意溢出 bounds）")
    func identityIsBytewiseIdentityEvenWithOverflow() throws {
        let bare = try #require(Self.pixels(Self.framed(Self.overflowing())), "基线渲染失败")
        #expect(bare.contains(where: { $0 != 0 }), "基线位图全 0 —— 下面的相等断言恒真")
        // 互锁：溢出的那部分确实画出来了，否则"没被裁掉"是恒真的。
        let notOverflowing = try #require(
            Self.pixels(Self.framed(
                Color.surfaceRaised.frame(width: 60, height: 60)
                    .overlay { Rectangle().fill(Color.contentPrimary).frame(width: 50, height: 50) }
            )),
            "对照渲染失败"
        )
        expectBitmapsDiffer(bare, notOverflowing, "被测内容其实没有溢出 bounds —— 本判据观测不到裁剪")

        for entry in Self.kinds {
            let identity = try #require(
                Self.pixels(Self.chrome(progress: 1, kind: entry.kind)), "渲染失败：\(entry.name)"
            )
            expectBitmapsEqual(identity, bare, """
            `.\(entry.name)` 在恒等相位改变了画面 —— 转场停住之后被修饰视图的溢出内容
            （阴影 / 超出 bounds 的子视图）被裁剪永久吃掉了。
            """)
        }
    }

    /// ⚠️⚠️ **承重判据（终审 I-2 补）：极小内容 + 大溢出的恒等相位。**
    ///
    /// 上一条用的 `overflowing()` 是 60×60、溢出 45pt，而它自己的对角线是 84.85pt
    /// ⇒ 上一版"按内容对角线派生"的余量恰好够用，那枚缺陷对它**结构上不可见**。
    /// 本条把内容缩到 4×4（对角线 5.66pt）而溢出仍是 73pt —— 上一版在这里判红。
    @Test("极小内容的恒等相位也与裸视图逐字节相同（溢出远超自身对角线）")
    func identityIsBytewiseIdentityForTinyContentWithHugeOverflow() throws {
        let bare = try #require(Self.pixels(Self.framed(Self.tinyOverflowing())), "基线渲染失败")
        #expect(bare.contains(where: { $0 != 0 }), "基线位图全 0 —— 下面的相等断言恒真")
        // 互锁：4×4 的 bounds 之外确实画着东西，否则"没被裁掉"是恒真的。
        let notOverflowing = try #require(
            Self.pixels(Self.framed(Color.surfaceRaised.frame(width: 4, height: 4))),
            "对照渲染失败"
        )
        expectBitmapsDiffer(bare, notOverflowing, "被测内容其实没有溢出 4×4 的 bounds —— 本判据观测不到裁剪")

        for entry in Self.kinds {
            let identity = try #require(
                Self.pixels(Self.framed(
                    Self.tinyOverflowing().modifier(MaskRevealChrome(progress: 1, kind: entry.kind))
                )),
                "渲染失败：\(entry.name)"
            )
            // ⚠️ 先归约成 `Bool`：两个 160 KB 的 `Data` 直接进判红的 `#expect` 会让
            // `swift-testing` 求 `CollectionDifference`（实测 98% CPU / 1.6 GB / 不收敛）,
            // 于是"判红"变成"卡死"。完整实测见
            // `MaskRevealTransitionBodyTests.appliedTransitionRendersThroughBody` 的文档。
            let matches = identity == bare
            #expect(matches, """
            `.\(entry.name)` 在恒等相位把 4×4 内容的溢出部分裁掉了
            —— 恒等余量又变回"按内容尺寸派生"了：一个 20×20 的图标配 `.shadow(radius: 30)`,
            阴影会在**转场结束之后**被永久吃掉。
            """)
        }
    }

    @Test("两个端点相位什么都不画")
    func endpointsDrawNothing() throws {
        let blank = try #require(Self.pixels(Self.framed(Self.empty())), "基线渲染失败")
        #expect(blank.contains(where: { $0 != 0 }), "基线位图全 0 —— 相等断言恒真")
        for entry in Self.kinds {
            let hidden = try #require(
                Self.pixels(Self.chrome(progress: 0, kind: entry.kind)), "渲染失败：\(entry.name)"
            )
            expectBitmapsEqual(hidden, blank, "`.\(entry.name)` 在进度 0 上还画着东西")
        }
    }

    /// SwiftUI 在一次动画事务里对 `Animatable` 做的**正是这三步**：
    /// 取两端的 `animatableData`、按 `amount` 插值、写回。本函数逐字复刻它。
    ///
    /// ⚠️ 走存在类型 `any Animatable` 而不是直接写具体类型：去掉 `MaskRevealChrome`
    /// 的 `Animatable` 一致性时，判据是**运行时判红**（`as?` 返回 nil ⇒ `#require` 抛出），
    /// 而不是"整个测试 target 编译不过"——后者在变异实证里读不出是哪一条判据在咬。
    static func interpolatedChrome(
        kind: MaskRevealKind, from: Double, to: Double, amount: Double
    ) -> MaskRevealChrome? {
        let lhs: Any = MaskRevealChrome(progress: from, kind: kind)
        let rhs: Any = MaskRevealChrome(progress: to, kind: kind)
        guard let start = lhs as? (any Animatable), let end = rhs as? (any Animatable)
        else { return nil }
        return Self.blend(start, towards: end, amount: amount) as? MaskRevealChrome
    }

    private static func blend<A: Animatable>(
        _ start: A, towards end: any Animatable, amount: Double
    ) -> A? {
        guard let target = end.animatableData as? A.AnimatableData else { return nil }
        var out = start
        var data = start.animatableData
        data.interpolate(towards: target, amount: amount)
        out.animatableData = data
        return out
    }

    /// ⚠️⚠️⚠️ **承重判据：揭示真的是连续的。**
    ///
    /// `TransitionPhase` 是 3 case frozen enum ⇒ `MaskReveal.progress(phase:)` 的
    /// **可达取值只有 `{0, 1}`**。若 `MaskRevealChrome` 不是 `Animatable`，SwiftUI 就只在
    /// 这两个端点上求值它——用户看到的是"整块内容凭空出现"，那条扫过去的边**从未发生**，
    /// 而三个真实相位上的位图断言（上面两条）**照样全绿**。
    /// 这枚缺陷在 `ParticleTransition`（#253 终审 C-A）上真实发生过一次。
    ///
    /// ⚠️ 判据不能写成「某个真实相位必须画出半张脸」——那对任何正确实现都判红
    /// （两个端点本来就一个全开一个全关）。承重的是**插值中间值**这条链。
    @Test("chrome 可被 SwiftUI 插值：动画中间值真的是部分揭示")
    func chromeRevealsMidFlight() throws {
        let bare = try #require(Self.pixels(Self.framed(Self.overflowing())), "基线渲染失败")
        let blank = try #require(Self.pixels(Self.framed(Self.empty())), "基线渲染失败")

        for entry in Self.kinds {
            let interpolated = try #require(
                Self.interpolatedChrome(kind: entry.kind, from: 0, to: 1, amount: 0.5),
                """
                `MaskRevealChrome` 不是 `Animatable`（或它的 `animatableData` 不是 `Double`）——
                SwiftUI 于是只在两个离散相位上求值它，`.\(entry.name)` 的揭示边根本不会出现，
                用户看到的是整块内容凭空跳出来。
                """
            )
            let midFlight = try #require(
                Self.pixels(Self.framed(Self.overflowing().modifier(interpolated))),
                "渲染失败：\(entry.name)"
            )
            expectBitmapsDiffer(midFlight, bare, "`.\(entry.name)` 的中间帧与完全揭示相同 —— 它中途就已经全开")
            expectBitmapsDiffer(midFlight, blank, "`.\(entry.name)` 的中间帧什么都不画 —— 揭示从未发生")

            // `animatableData` 必须**真的绑在 `progress` 上**，而不是某个不参与绘制的字段：
            // 插出来的那一帧必须与"直接用中间进度构造"的 chrome 逐字节相同。
            let direct = try #require(
                Self.pixels(Self.chrome(progress: 0.5, kind: entry.kind)), "渲染失败：\(entry.name)"
            )
            expectBitmapsEqual(midFlight, direct, """
            `.\(entry.name)` 插值出来的那一帧与 `MaskRevealChrome(progress: 0.5)` 不同
            —— `animatableData` 没有绑在 `progress` 上，插值改不动绘制。
            """)
        }
    }

    @Test("六种在同一进度上渲染出的画面互不相同")
    func sixKindsRenderDifferently() throws {
        var seen: [String: Data] = [:]
        for entry in Self.kinds {
            let frame = try #require(
                Self.pixels(Self.chrome(progress: 0.5, kind: entry.kind)), "渲染失败：\(entry.name)"
            )
            for (name, other) in seen {
                expectBitmapsDiffer(frame, other, "`.\(entry.name)` 与 `.\(name)` 的中间帧逐字节相同")
            }
            seen[entry.name] = frame
        }
        #expect(seen.count == 6)
    }

    @Test("Reduce Motion 的裁决结论渲染出来是遮罩全开 + 纯淡入淡出")
    func reducedPlanRendersAsPlainFade() throws {
        let bare = try #require(Self.pixels(Self.framed(Self.overflowing())), "基线渲染失败")
        for entry in Self.kinds {
            let reduced = MaskReveal.plan(kind: entry.kind, progress: 0.5, isReduced: true)
            let masked = try #require(
                Self.pixels(Self.framed(Self.overflowing().clipShape(MaskRevealShape(plan: reduced)))),
                "渲染失败：\(entry.name)"
            )
            expectBitmapsEqual(masked, bare, "`.\(entry.name)` 在 Reduce Motion 下仍然裁掉了东西")

            // 互锁：不降级时同一进度**必须**裁掉东西，否则上一条恒真。
            let motion = MaskReveal.plan(kind: entry.kind, progress: 0.5, isReduced: false)
            let clipped = try #require(
                Self.pixels(Self.framed(Self.overflowing().clipShape(MaskRevealShape(plan: motion)))),
                "渲染失败：\(entry.name)"
            )
            expectBitmapsDiffer(clipped, bare, "`.\(entry.name)` 在运动路径上也没裁掉任何东西")
        }
    }

    @Test("柔光带：中途画得出，两端一个像素都不留")
    func glareBandDrawsOnlyMidFlight() throws {
        let radians = MaskRevealTransition.defaultGlareAngle.radians
        func band(_ travel: Double) -> some View {
            MaskRevealGlareBand(glare: MaskRevealGlare(radians: radians, travel: travel))
                .frame(width: 160, height: 120)
                .background(Color.accent)
        }
        // ⚠️ 底色**不能**用 `Color.surfaceRaised`：macOS 浅色外观下它解析到
        // `controlBackgroundColor`（近纯白），而柔光带是 `Color.white.opacity(0.45)`
        // ——白盖白，三条断言会一起变成"逐字节相同"。首版正是这么写的，实测判红。
        let blank = try #require(
            Self.pixels(Color.clear.frame(width: 160, height: 120).background(Color.accent)),
            "基线渲染失败"
        )
        #expect(blank.contains(where: { $0 != 0 }), "基线位图全 0 —— 相等断言恒真")
        expectBitmapsEqual(Self.pixels(band(0)), blank, "travel 0 的柔光带还在画东西")
        expectBitmapsEqual(Self.pixels(band(1)), blank, "travel 1（恒等相位）的柔光带还在画东西 —— 永久残留")
        expectBitmapsDiffer(Self.pixels(band(0.5)), blank, "travel 0.5 的柔光带什么都不画 —— 上两条是恒真的")
    }

    @Test("六个入口点都能用点语法接上 `.transition(_:)` 并渲染")
    func allSixEntryPointsCompose() {
        let composed = VStack {
            Text("iris").transition(.iris)
            Text("wipe").transition(.wipe(angle: .degrees(45)))
            Text("blinds").transition(.blinds(count: 5))
            Text("clock").transition(.clock(direction: .counterClockwise))
            Text("glare").transition(.glare)
            Text("dissolve").transition(.dissolve(cellSize: 10))
        }
        #expect(Self.pixels(composed) != nil, "六个入口点叠在一起渲染失败")
    }
}

// MARK: - `MaskRevealTransition.body` 本身

/// ⚠️⚠️⚠️ **本 suite 整个是终审 C-1 补的，补的是一个 31 条判据全都看不见的洞。**
///
/// `MaskRevealTransition.body(content:phase:)` 是六个公开静态成员通向
/// `MaskRevealChrome` 的**唯一**路径，而它此前没有任何判据。评审把它整段改成
/// ```swift
/// content.modifier(MaskRevealChrome(progress: 1, kind: .iris(anchor: .center)))
/// ```
/// （变异 M-A：相位与 `self.kind` 双双丢弃 ⇒ 六种转场全部退化成「内容凭空出现」，
/// `.iris` 连相位都不看）—— 本簇 31 条与全量 761 条**零红**。
///
/// 为什么此前所有判据都看不见：
/// · `MaskRevealGeometryTests.entryPoints` 取的是静态成员的**存储属性** `kind`；
/// · `MaskRevealRenderTests.chrome(progress:kind:)` **直接构造** `MaskRevealChrome`；
/// · `MaskRevealSourceGuard.chromeIsPinnedVerbatim` 钉的是 `MaskRevealChrome` 的
///   类型体，`MaskRevealTransition.body` 不在断言面内；
/// · `allSixEntryPointsCompose` 只断言 `pixels(composed) != nil`
///   —— 静态渲染下 SwiftUI 根本不求值 transition 的 `body`。
///
/// **连带**：`MaskReveal.progress(phase:)` 的唯一消费者就是这段 `body`，
/// 所以 `phaseMapping` 此前在验一个没有已验证消费者的纯函数；本 suite 一并接上。
@Suite("MaskRevealTransition.body 本身")
@MainActor
struct MaskRevealTransitionBodyTests {

    /// `Transition.Content`（= `PlaceholderContentView<MaskRevealTransition>`）没有公开
    /// 构造器，但它是**零尺寸**类型 ⇒ 可以从 `()` 位转换出来。
    ///
    /// ⚠️ 先断言尺寸真的是 0 再转换：哪天 SDK 给它加了存储，这里会明确判红，
    /// 而不是变成一次静默的未定义行为。
    static func placeholder() throws -> MaskRevealTransition.Content {
        try #require(MemoryLayout<MaskRevealTransition.Content>.size == 0 ? true : nil, """
        `PlaceholderContentView` 不再是零尺寸类型 —— 本 suite 的 `body` 直呼手法失效，
        请改用别的方式对 `MaskRevealTransition.body(content:phase:)` 求值。
        """)
        return unsafeBitCast((), to: MaskRevealTransition.Content.self)
    }

    /// 从 `body` 的产物里取出它交给 `MaskRevealChrome` 的那份实参。
    ///
    /// `MaskRevealTransition.Body` 的具体类型是
    /// `ModifiedContent<PlaceholderContentView<MaskRevealTransition>, MaskRevealChrome>`,
    /// 但在本类型之外它是 opaque ⇒ 走 `Mirror` 的 `modifier` 子节点。
    static func chromeProduced(by transition: MaskRevealTransition, phase: TransitionPhase) throws
        -> MaskRevealChrome {
        let produced = transition.body(content: try Self.placeholder(), phase: phase)
        return try #require(
            Mirror(reflecting: produced).descendant("modifier") as? MaskRevealChrome, """
            `MaskRevealTransition.body` 的产物里没有 `MaskRevealChrome`
            —— 实测类型是 \(type(of: produced))。
            `body` 若不再是 `content.modifier(MaskRevealChrome(...))` 这一个形态，
            本 suite 的两条判据都无从谈起，请连同它们一起重写。
            """
        )
    }

    static let phases: [(name: String, phase: TransitionPhase)] = [
        ("willAppear", .willAppear), ("identity", .identity), ("didDisappear", .didDisappear),
    ]

    /// ⚠️⚠️⚠️ **承重判据：`body` 把调用方的相位与几何族原样交给 chrome。**
    ///
    /// 这是 M-A（`content.modifier(MaskRevealChrome(progress: 1, kind: .iris(anchor: .center)))`）
    /// 的**直接**判据：`kind` 被丢弃 ⇒ 除 `iris` 外五种当场判红；相位被丢弃 ⇒
    /// 两个端点相位当场判红。它同时是 `MaskReveal.progress(phase:)` 的**已验证消费者**。
    ///
    /// ⚠️ 断言的是「与 `MaskReveal.progress(phase:)` 相同」而不是写死 `0 / 1 / 0`：
    /// 后者会把相位映射的定义抄进判据，`phaseMapping` 那条就变成自证。
    @Test("body 把 (相位 → 进度, 自己的 kind) 原样交给 MaskRevealChrome")
    func bodyHandsChromeThePhaseAndTheKind() throws {
        // 六个公开入口点的**含参重载**也走一遍——两个成员按 `Host.member` 算同一条登记，
        // 但它们是两段独立的接线。
        let transitions: [(name: String, transition: MaskRevealTransition, kind: MaskRevealKind)] = [
            ("iris", .iris, .iris(anchor: .center)),
            ("iris(anchor:)", .iris(anchor: .topLeading), .iris(anchor: .topLeading)),
            ("wipe", .wipe, .wipe(radians: MaskRevealTransition.defaultWipeAngle.radians)),
            ("wipe(angle:)", .wipe(angle: .degrees(90)), .wipe(radians: .pi / 2)),
            ("blinds", .blinds, .blinds(count: MaskRevealTransition.defaultBlindCount)),
            ("blinds(count:)", .blinds(count: 3), .blinds(count: 3)),
            ("clock", .clock, .clock(sign: 1)),
            ("clock(direction:)", .clock(direction: .counterClockwise), .clock(sign: -1)),
            ("glare", .glare, .glare(radians: MaskRevealTransition.defaultGlareAngle.radians)),
            ("glare(angle:)", .glare(angle: .degrees(-20)), .glare(radians: -.pi / 9)),
            ("dissolve", .dissolve, .dissolve(cellSize: MaskRevealTransition.defaultCellSize)),
            ("dissolve(cellSize:)", .dissolve(cellSize: 12), .dissolve(cellSize: 12)),
        ]
        #expect(transitions.count == 12, "12 个公开入口点少了几个 —— 本条与登记表脱节了")

        for entry in transitions {
            for step in Self.phases {
                let chrome = try Self.chromeProduced(by: entry.transition, phase: step.phase)
                #expect(chrome.kind == entry.kind, """
                `.\(entry.name)` 的 `body` 交给 `MaskRevealChrome` 的几何族是 \(chrome.kind),
                而这个入口点选的是 \(entry.kind) —— `body` 丢掉了 `self.kind`,
                六种转场会全部退化成同一种（而 31 条判据对此**结构上零可见性**）。
                """)
                #expect(chrome.progress == MaskReveal.progress(phase: step.phase), """
                `.\(entry.name)` 在相位 \(step.name) 上交给 chrome 的进度是 \(chrome.progress),
                而 `MaskReveal.progress(phase:)` 给的是 \(MaskReveal.progress(phase: step.phase))
                —— `body` 丢掉了调用方的相位，转场退化成「内容凭空出现」。
                """)
            }
        }
    }

    /// ⚠️⚠️ **端到端那一半**：经**公开的** `Transition.apply(content:phase:)` 渲染。
    ///
    /// 上一条走的是 `body` 直呼 + 反射（精确但绕过了 SwiftUI 自己那段接线）；本条把
    /// `.transition(_:)` 真正会走的那条链跑一遍——实测 `apply` 的返回视图在渲染时
    /// **确实**求值 `body`（`ModifiedContent<V, ApplyTransitionModifier<MaskRevealTransition>>`）。
    /// ⇒ 两条合起来，M-A 在结构与像素两侧都判红。
    ///
    /// ⚠️ 判据刻意**不依赖 `.opacity` 的可见性**（姊妹 PR #289 实测本仓位图 harness 里
    /// `opacity(0)` 与 `opacity(1)` 有时渲出逐字节相同的位图）：这里比较的是
    /// **裁剪**造成的差别（全开 / 全关），与不透明度无关。
    ///
    /// ## ⚠️⚠️ 两个 `Data` **必须先归约成 `Bool` 再进 `#expect`**，这是实测换来的
    ///
    /// 写成 `#expect(applied == expected, …)` 时，一旦判红，`swift-testing` 会对两个
    /// **160 KB 的 `Data`** 求集合差异（`CollectionDifference`）——两幅位图逐字节都不同
    /// 时那是 O(N·D) 的 Myers 差分。实测（最小复现：两个 160 000 字节、处处不同的
    /// `Data` 直接进一条判红的 `#expect`）：**98% CPU、1.6 GB 常驻、90 秒后仍未结束**。
    /// ⇒ 本条在 M-A 下的表现会从"判红"变成"卡死"，而**卡死不是红**：跑变异的人
    /// 只会看到进程挂住，读不出是哪一条判据在咬。
    /// ⇒ 先 `let matches = applied == expected`、再 `#expect(matches, …)`：
    /// `#expect` 拿到的是一个 `Bool`，没有集合可差分。
    /// ⚠️ 这条限度对本仓**所有**位图断言都成立（本文件其余几条写的仍是
    /// `#expect(x == y)`，它们至今没被咬到只是因为判红时两幅图差异很小）；
    /// 本条只修自己新增的那两处，不在本 PR 里翻修既有断言。
    @Test("经 Transition.apply 渲染确实走 body（三个真实相位逐字节对齐）")
    func appliedTransitionRendersThroughBody() throws {
        let content = MaskRevealRenderTests.overflowing()
        let bare = try #require(
            MaskRevealRenderTests.pixels(MaskRevealRenderTests.framed(content)), "基线渲染失败"
        )
        let blank = try #require(
            MaskRevealRenderTests.pixels(MaskRevealRenderTests.framed(
                Color.clear.frame(width: 60, height: 60)
            )),
            "基线渲染失败"
        )
        expectBitmapsDiffer(bare, blank, "两条基线逐字节相同 —— 下面的断言全部恒真")

        let transitions: [(name: String, transition: MaskRevealTransition)] = [
            ("iris", .iris), ("wipe", .wipe), ("blinds", .blinds),
            ("clock", .clock), ("glare", .glare), ("dissolve", .dissolve),
        ]
        for entry in transitions {
            for step in Self.phases {
                let applied = try #require(
                    MaskRevealRenderTests.pixels(MaskRevealRenderTests.framed(
                        entry.transition.apply(content: content, phase: step.phase)
                    )),
                    "渲染失败：\(entry.name) @ \(step.name)"
                )
                let expected = MaskReveal.progress(phase: step.phase) == 1 ? bare : blank
                let expectedName = MaskReveal.progress(phase: step.phase) == 1 ? "裸视图" : "空白"
                // ⚠️ 先归约成 `Bool`，理由见本函数文档里的「两个 `Data` 必须先归约」。
                let matches = applied == expected
                #expect(matches, """
                `.transition(.\(entry.name))` 在相位 \(step.name) 上渲染出的画面
                与「\(expectedName)」不同 —— `MaskRevealTransition.body` 没有把这个相位
                交给 `MaskRevealChrome`（丢掉相位 ⇒ 转场根本不发生／内容凭空出现）。
                """)
            }
        }
    }

    /// ⚠️⚠️ **`properties` 必须是显式声明**（终审 S-2 / I-5，`#292` 统一跟踪）。
    ///
    /// Apple 文档逐字：`hasMotion == true` ⇒ **Reduce Motion 打开时 SwiftUI 直接把
    /// 本转场换成 `.opacity`**（默认值就是 `true`）。`#268` 落地时实测的继承值：
    /// ```
    /// MaskRevealTransition.properties.hasMotion == true
    /// ParticleTransition.properties.hasMotion   == true
    /// OpacityTransition.properties.hasMotion    == false
    /// IdentityTransition.properties.hasMotion   == false
    /// ```
    /// ⚠️ 上表前两行是**当时**的继承值，今天两者都已是**显式声明**
    /// （`ParticleTransition` 在 `#292` 补上，取值仍是 `true`）；
    /// 后两行是 SwiftUI 自家类型，仍为实测继承值。
    /// ⇒ **框架那道闸在前**，`MaskReveal.plan(…isReduced:)` 是它为假时的兜底。
    /// 取值理由、内层 RM 路径「保留」的裁定与代价，全部写在 `MaskRevealTransition`
    /// 与 `MaskRevealTransition.properties` 的文档注释里。
    ///
    /// ⚠️ 只断言取值是不够的——`true` 恰好也是 SDK 默认值，一条纯 `#expect` 在
    /// 「有人把整个 `properties` 删掉」这枚变异下**零红**。因此配一条源码断言：
    /// 这个声明必须真的写在本仓代码里（它换来的是"下一个人看得见框架闸"）。
    ///
    /// ⚠️⚠️ **下面那条源码断言逐字钉的是「本簇自己那一种写法」，射程要读清楚**
    /// （#291 第 2 轮 Sug-1）：三簇今天各写各的，语义完全相同——
    /// ```
    /// #268（本簇）  public static let properties: TransitionProperties = TransitionProperties(hasMotion: true)
    /// #267（簇 B）  public static var properties: TransitionProperties { .init(hasMotion: true) }
    /// #266（滤镜簇）public static let properties = TransitionProperties(hasMotion: false)
    /// ```
    /// ⇒ 上一版这里写「**`#292` 统一声明形态的那次改动会让本条判红**，届时请连同下面的
    /// 期望串一起改」。**`#292` 落地时定案：不统一**——收益在
    /// `TransitionPropertiesGuard`（`CoreDesignTests`，SwiftSyntax 按**结构**判「有没有
    /// 声明 `properties`」，三种写法一视同仁）落地之后是零，而统一的代价就是改本条。
    /// ⇒ **本条继续原样有效**，期望串不动。完整理由见那条守卫的文件头
    /// 《`#292` 有意**不统一**三种声明形态》一节。
    /// ⚠️ 本条的射程仍然只有本簇那一种写法：它今天由 `TransitionPropertiesGuard` 兜底
    /// （那条守卫对**全仓 12 条**做结构判定），本条守的是"本簇这一行别被悄悄删掉"。
    @Test("MaskRevealTransition 显式声明 properties，且 hasMotion 为 true")
    func transitionDeclaresItHasMotion() throws {
        #expect(MaskRevealTransition.properties.hasMotion, """
        `hasMotion` 变成了 `false` —— 那是在对系统说"本转场不含运动"，
        Reduce Motion 下 SwiftUI 将**不再**把它替换成 `.opacity`,
        整簇的无障碍降级就只剩 `MaskReveal.plan(…isReduced:)` 这一道手写闸。
        若这是有意的改动，请连同 `MaskRevealTransition` 的两段裁决记录一起改
        （「两道闸，框架那道在前」与「内层 RM 路径：显式裁定为保留」）。
        """)
        let code = try MaskRevealSourceGuard.code("MaskRevealTransitions.swift")
        #expect(code.contains("static let properties: TransitionProperties"), """
        `MaskRevealTransitions.swift` 里找不到 `properties` 的显式声明 —— 上一条于是退化成
        「SDK 默认值恰好也是 true」，删掉整个声明它照样全绿，而下一个人也就再次看不见
        框架那道闸的存在。
        """)
        #expect(code.contains("TransitionProperties(hasMotion: true)"), """
        `properties` 的实现体不再是 `TransitionProperties(hasMotion: true)`
        —— 上一条读到的可能已经不是这个声明给的值。
        """)
    }
}

// MARK: - 源码契约

@Suite("MaskReveal 源码契约")
struct MaskRevealSourceGuard {

    static let files = ["MaskReveal.swift", "MaskRevealTransitions.swift"]

    static func code(_ fileName: String) throws -> String {
        MicroInteractionReduceMotionGuard.stripComments(try TypewriterTextTests.source(fileName))
    }

    /// 本判据文件**自己**的源码（`TypewriterTextTests.source(_:)` 只认
    /// `Sources/CoreDesignEffects/`，读不到 `Tests/`）。
    static func testSource() throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
    }

    /// ⚠️⚠️ **暖机门不许被绕过**（终审 I-6；射程按 #291 第 2 轮 Imp-2 扩宽 + 限度照录）。
    ///
    /// `MaskRevealRenderTests.warmUp` 是本文件所有位图断言的承重前提——实测绕过它
    /// （直接调 `MicroInteractionAPITests.stablePixels`）时 `clock` / `glare`
    /// 在**同一条 `#Test` 内**三次调用都不收敛。今天全簇确实都走 `Self.pixels`，
    /// 但在本条之前**没有任何判据守着这件事**：将来新增一条位图断言，只要顺手直接调
    /// 底层 harness，这道闸就被静默丢掉，而那条断言会以"间歇性判红"的形态出现
    /// ——本仓最难归因的那一类。
    ///
    /// 形态照 `ProcessingSweepTests.containersDelegateToDriver`：底层调用只许出现在
    /// **暖机块**与**闸函数**这两个区间内，区间之外一次都不许有。
    ///
    /// ## ⚠️ 上一版只钉一个符号，射程远小于它自称的那样（照录，已修）
    ///
    /// 上一版的 needle 是 `MicroInteractionAPITests.stablePixels` 一串。评审实测两枚
    /// 等价改写**双双判绿**：
    /// ```
    /// MicroInteractionAPITests.pixels(composed)                    → 全绿
    /// typealias Harness = MicroInteractionAPITests
    ///   → Harness.stablePixels(composed)                           → 全绿
    /// ```
    /// 第一条尤其咬人：`MicroInteractionAPITests.pixels`（`MicroInteractionTests.swift`）
    /// **连进程级暖机都不跑**（`processWarmUp` 只挂在 `stablePixels` 上）
    /// ⇒ 旧判据**禁住了较好的那个调用、放过了严格更差的那个**，而 `pixels` 恰恰是
    /// 下一个人更可能顺手写下的名字。本 target 里另有 6 个同名 `static func pixels`
    /// 助手（`CelebrationAndProcessingTests` / `TextAndDisplayTests` / `CrossPlatformTests`），
    /// 同样在旧 needle 之外。
    ///
    /// ⇒ 现在按**两个后缀** `Tests.pixels(` 与 `Tests.stablePixels(` 计数，
    /// 把 `MaskRevealRenderTests.pixels(` 单列为第三条豁免（那正是这道闸本身，
    /// `MaskRevealTransitionBodyTests` 从别的 suite 调它是合法的）
    /// ⇒ 上表第一行与那 6 个同名助手一起被关掉。
    ///
    /// ## ⚠️⚠️ 已知缺口：`typealias` / 元类型绑定关不掉
    ///
    /// 上表第二行（`typealias Harness = MicroInteractionAPITests`，随后
    /// `Harness.stablePixels(...)`）**今天仍然判绿**，源码后缀计数结构上看不见它；
    /// 真要关掉得改成扫 `ImageRenderer` 或干脆禁 `typealias`，两者都会把射程扩到
    /// 本判据无意承担的范围。⇒ **有意留着，写在这里**——别把本条读成"绕不过去"。
    ///
    /// ⚠️ 另一条限度：豁免是**按后缀**给的，`MaskRevealRenderTests.pixels(` 若出现在
    /// 暖机块或闸函数**内部**会被计两次 `allowed` ⇒ `allowed > total`，本条判红。
    /// 那是安全方向的假红（这两处本来也不该递归调闸），照录以免下一个人误判。
    @Test("本文件的位图断言只许走 MaskRevealRenderTests.pixels（暖机门）")
    func bitmapAssertionsGoThroughTheWarmUpGate() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.testSource())
        // ⚠️ 三条 needle 一律**拼出来**，不写成整串字面量：本判据扫的是**它自己所在的
        // 文件**，而 `stripComments` 不动字符串字面量 ⇒ 写成整串的话这几行自己就会被
        // 计进 `total`，判据永远比 `allowed` 多（旧版实测：
        // `Expectation failed: (total → 7) == (allowed → 6)`）。
        // ⚠️ 同理，下面所有 `#expect` 的失败文案里**不许**出现这三串的字面形态
        // ——提到那道闸时写 `MaskRevealRenderTests.pixels`（不带左括号）。
        let plain = "Tests." + "pixels("
        let stable = "Tests." + "stablePixels("
        let gateCall = "MaskRevealRenderTests." + "pixels("

        // 两个后缀一起数：`MicroInteractionAPITests.pixels` / 本 target 里另外 6 个
        // 同名 `pixels` 助手 / 任何 `*Tests.stablePixels` 都会命中。
        func hits(_ text: String) -> Int {
            ConfettiTests.occurrences(of: plain, in: text)
                + ConfettiTests.occurrences(of: stable, in: text)
        }

        let total = hits(code)

        let warmUp = try #require(
            ConfettiTests.bracedRegion(after: "private static let warmUp", in: code),
            "找不到暖机块 —— 下面的差集无从谈起"
        )
        let gate = try #require(
            ConfettiTests.bracedRegion(after: "static func pixels(_ view: some View)", in: code),
            "找不到 `MaskRevealRenderTests.pixels` 这道闸 —— 下面的差集无从谈起"
        )
        // 第三条豁免：调这道闸**本身**永远合法（`MaskRevealTransitionBodyTests`
        // 在别的 suite 里就是这么调的），它天然带着暖机。
        let viaGate = ConfettiTests.occurrences(of: gateCall, in: code)
        let inRegions = hits(warmUp) + hits(gate)
        let allowed = inRegions + viaGate

        // 互锁一：两个区间里确实有调用，否则本条守的是空气。
        #expect(inRegions > 0, "暖机块与闸函数里一次底层 harness 调用都没有 —— 本条已经与实现脱节")
        // 互锁二：闸确实被人从外面调，否则第三条豁免守的是空气。
        #expect(viaGate > 0, "全文件一次 `MaskRevealRenderTests.pixels` 调用都没有 —— 第三条豁免已与实现脱节")
        #expect(total == allowed, """
        `\(plain)` + `\(stable)` 在本文件里共出现 \(total) 次，而
        暖机块 + 闸函数（\(inRegions) 次）+ 对闸本身的调用（\(viaGate) 次）只占 \(allowed) 次
        —— 多出来的 \(total - allowed) 次绕过了 `MaskRevealRenderTests.pixels` 的暖机门。
        位图断言必须走 `Self.pixels` / `MaskRevealRenderTests.pixels`：实测直接调底层
        harness 时 `clock` / `glare` 在同一条 `#Test` 内三次调用都不收敛，
        失效形态是**间歇性判红**，而不是稳定的红。
        ⚠️ `MicroInteractionAPITests.pixels` 也在禁列——它连进程级暖机都不跑
        （`processWarmUp` 只挂在 `stablePixels` 上），比直接调 `stablePixels` 更差。
        """)
    }

    /// ⚠️⚠️ **这是本簇两个文件进 `approvedNoMotion` 名单的前提，不是装饰。**
    ///
    /// `MicroInteractionReduceMotionGuard` 按**关键字**判一个文件含不含运动
    /// （`offset(` / `scaleEffect(` / `Canvas(` …）。mask reveal 的运动全部长在
    /// `Path` 几何里，一个关键字都不命中 ⇒ 它必须进 `approvedNoMotion`，
    /// 与 `BeforeAfterSlider.swift` / `FullScreenButton.swift` 同一形态的豁免
    /// （**「这一条不是『它不动』」**）。
    /// ⇒ 豁免的前提「本文件确实不含任何运动关键字」由本条钉住；哪天有人往里加一处
    /// `offset(`，`everyFileIsClassified` 的矛盾分支与本条会一起判红，逼人回来重新分类。
    @Test("两个文件确实不含任何运动关键字（approvedNoMotion 豁免的前提）")
    func maskRevealFilesCarryNoMotionKeywords() throws {
        for file in Self.files {
            let code = try Self.code(file)
            for call in MicroInteractionReduceMotionGuard.motionCalls {
                #expect(!code.contains(call), """
                \(file) 里出现了运动关键字 `\(call)` —— 它已不该待在 `approvedNoMotion` 名单上，
                请回 `Tests/CoreDesignEffectsTests/ReduceMotionGuard.swift` 重新分类。
                """)
            }
        }
        // 互锁：两个文件都在名单上，否则本条守的是空气。
        for file in Self.files {
            #expect(MicroInteractionReduceMotionGuard.approvedNoMotion.contains(file),
                    "\(file) 不在 approvedNoMotion 名单上 —— 本条与那份名单已经脱节")
        }
    }

    /// ⚠️ 与 `PlatformSupportGuard.reduceMotionIsOnlyConsumedByTheTransitionPlan` 同形态：
    /// 纯函数判据只管 `MaskReveal.plan(...)` **函数体内**，而"调用点是否真的用这个结论"
    /// 是另一条链。`reduceMotion` 一旦在别处被再判一次，降级就会被绕过。
    @Test("reduceMotion 只许喂给 MaskReveal.plan(...) 这一个裁决点")
    func reduceMotionIsOnlyConsumedByThePlan() throws {
        var reads = 0
        var fed = 0
        for file in Self.files {
            let code = try Self.code(file)
            reads += code.components(separatedBy: "self.reduceMotion").count - 1
            fed += code.components(separatedBy: "isReduced: self.reduceMotion").count - 1
            // 去掉 `self.` 就能绕过上面按字面子串的计数 —— 与能耗闸文件同一条纪律。
            let strays = MicroInteractionReduceMotionGuard.bareReduceMotionOccurrences(in: code)
            #expect(strays.isEmpty, """
            \(file) 里这些 `reduceMotion` 既不是声明、也不是实参标签、更不是 `self.reduceMotion`：
            \(strays.joined(separator: "\n"))
            """)
        }
        #expect(fed == 1, "`isReduced: self.reduceMotion` 出现了 \(fed) 次，应当恰好 1 次")
        #expect(reads == fed, """
        `self.reduceMotion` 出现 \(reads) 次，但只有 \(fed) 次是喂给 `MaskReveal.plan(...)` 的
        —— 多出来的那些是调用点自己又判了一遍 Reduce Motion。
        """)
    }

    /// ⚠️⚠️ **整个 `MaskRevealChrome` 逐字钉死**（形态照
    /// `ParticleTransitionTests.particleLayerSurvivesTheWholeTransition`）。
    ///
    /// 要防的是**同一族**缺陷：往裁剪 / 叠加的门控里掺进相位，让恒等那一端把某一层
    /// 摘掉。`ParticleTransition` 上那次实证过，只钉某一行的字面形状会被
    /// `&& phase != .identity`、`let count = phase == .identity ? 0 : self.count`
    /// 这类等价形态原样绕过 ⇒ 断言面必须是整个**类型体**。
    ///
    /// ⚠️⚠️ **射程边界照录（终审 S-3，评审实测）**：本条的断言面是
    /// `struct MaskRevealChrome` 后面那一对 `{` … `}`——**声明行本身不在射程内**。
    /// 实测：去掉 `MaskRevealChrome` 的 `Animatable` 一致性（改**声明行**而不是类型体）
    /// ⇒ **本条不判红**，判红的是 `MaskRevealRenderTests.chromeRevealsMidFlight`。
    /// 这是好事（承重设计②由**性质**判据接住，而不是靠一条形状判据），
    /// 但别把本条的文档读成"整个类型的任何改动都会判红"：
    /// **协议一致性列表、属性包装、`@available` 之类的声明行修饰在射程外**，
    /// 由 `chromeRevealsMidFlight` 接管。
    ///
    /// ⚠️ 代价照录：本条是**逐字**的 ⇒ 给这个类型换行、加一个绑定、调整缩进都会判红，
    /// 必须连同期望串一起改。这是有意的。
    @Test("MaskRevealChrome 整个类型逐字钉死（任何相位门控都判红）")
    func chromeIsPinnedVerbatim() throws {
        let code = try Self.code("MaskReveal.swift")
        #expect(code.components(separatedBy: "struct MaskRevealChrome").count - 1 == 1,
                "`MaskRevealChrome` 不是恰好声明一次 —— 下面取到的可能不是被测的那个")
        guard let chrome = ConfettiTests.bracedRegion(after: "struct MaskRevealChrome", in: code) else {
            Issue.record("找不到 `MaskRevealChrome` 的类型体 —— 下面的断言无从谈起")
            return
        }

        let expected = #"""
        {
            var progress: Double
            let kind: MaskRevealKind

            @Environment(\.accessibilityReduceMotion) private var reduceMotion

            var animatableData: Double {
                get { self.progress }
                set { self.progress = newValue }
            }

            func body(content: Content) -> some View {
                let plan = MaskReveal.plan(
                    kind: self.kind, progress: self.progress, isReduced: self.reduceMotion
                )
                return content
                    .clipShape(MaskRevealShape(plan: plan))
                    .opacity(plan.contentOpacity)
                    .overlay {
                        if let glare = plan.glare {
                            MaskRevealGlareBand(glare: glare)
                        }
                    }
            }
        }
        """#

        #expect(ParticleTransitionTests.squeezed(chrome) == ParticleTransitionTests.squeezed(expected), """
        `MaskRevealChrome` 与期望形态逐字不符。

        实测：\(ParticleTransitionTests.squeezed(chrome))

        期望：\(ParticleTransitionTests.squeezed(expected))

        ⚠️ 先看**有没有把相位掺进任何一个门控**（`if let glare` 旁边加 `progress <` 之类、
        把 `clipShape` 或 `overlay` 整层按进度摘掉）——那会在恒等那一端截断动画：
        插值的前提是这一层整段动画都在树上。
        若这次是**有意**改这个类型，连同上面的期望串一起改，并在评审里说明为什么它仍然
        满足「裁剪层与柔光层整段动画都在树上、且拿到的是本次进度算出的 plan」。
        """)
    }
}
