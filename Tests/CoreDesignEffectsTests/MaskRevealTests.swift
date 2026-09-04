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
//
// ⚠️ 每一条断言在写下时都做过**变红自证**（故意注入对应缺陷 → 跑 → 看红 → 改回），
// 结果贴在 PR 正文里。没有做过这一步的断言不写结论性注释。

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

    @Test("dissolve 的退化 cellSize：不崩、不爆量、仍然是一条活转场")
    func dissolveClampsDegenerateCellSize() {
        let huge = CGRect(x: 0, y: 0, width: 1200, height: 900)
        // ① 过小的值被抬到让格数落在上限内。
        let side = MaskReveal.effectiveCellSize(0.5, in: huge)
        let cells = Int((huge.width / side).rounded(.up)) * Int((huge.height / side).rounded(.up))
        #expect(cells <= MaskReveal.dissolveMaximumCells + 2 * Int((huge.width / side).rounded(.up)),
                "cellSize 0.5 在 1200×900 上要画 \(cells) 格 —— 逐帧重建这么多子路径会卡死")
        #expect(cells > 0)
        // ② 非法值回落到默认值。
        for bad: CGFloat in [0, -5, .nan, .infinity] {
            let resolved = MaskReveal.effectiveCellSize(bad, in: Self.rect)
            #expect(resolved.isFinite && resolved > 0, "cellSize \(bad) 解析成了 \(resolved)")
        }
        // ③ 退化输入下转场仍然发生。
        #expect(!Self.revealed(.dissolve(cellSize: 0), progress: 0.5).isEmpty)
        #expect(!Self.revealed(.dissolve(cellSize: -5), progress: 0.5).isEmpty)
    }

    // MARK: 恒等余量

    @Test("恒等余量只在最后一段张开，且完全张开时把 bounds 外一整条对角线包住")
    func haloOpensOnlyAtTheEnd() {
        #expect(MaskReveal.halo(progress: 0) == 0)
        #expect(MaskReveal.halo(progress: MaskReveal.haloOnset) == 0)
        #expect(MaskReveal.halo(progress: 1) == 1)
        #expect(MaskReveal.halo(progress: (MaskReveal.haloOnset + 1) / 2) > 0)

        // 进度 1 时，bounds 外一整条对角线处的点必须仍在裁剪路径内
        // —— 否则阴影 / 溢出子视图会被**永久**裁掉（转场结束之后才发生，最难归因）。
        let diagonal = hypot(Self.rect.width, Self.rect.height)
        for entry in Self.entryPoints {
            let path = MaskReveal.path(
                for: MaskReveal.plan(kind: entry.kind, progress: 1, isReduced: false),
                in: Self.rect
            )
            // ⚠️ 取 0.9 倍而不是整条对角线：整条恰好落在外框的**外边界**上，
            // 边界点的 `contains` 取决于浮点比较方向，判据会变得看运气。
            let far = Self.rect.insetBy(dx: -diagonal * 0.9, dy: -diagonal * 0.9)
            for corner in MaskReveal.corners(of: far) {
                #expect(path.contains(corner), """
                \(entry.name) 在恒等相位裁掉了 bounds 外 \(Int(diagonal))pt 处的内容
                —— `.transition(.\(entry.name))` 会永久吃掉被修饰视图的阴影 / 溢出子视图。
                """)
            }
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

    /// ⚠️ 与 `ConfettiTests.canvasWarmUp` / `ParticleTransitionTests.chromeWarmUp` 同一条
    /// 首帧伪影：`ImageRenderer` 在进程内最早的若干次渲染上给出的光栅化与之后不同。
    ///
    /// ⚠️⚠️ **必须把「带 chrome 的形态」也跑热，这是变异实证换来的**：上一版只暖机了
    /// 裸内容与空白两种，`chromeRevealsMidFlight` 于是**间歇性判红**——它比较
    /// 「插值出的中间帧」与「直接用 0.5 构造的中间帧」，两者结构相同、数值相同，
    /// 但**进程内第一次带 chrome 的渲染**是异类，谁先跑到谁就是那个异类，
    /// 而 Swift Testing 不保证测试顺序。实证：一个**语义上完全等价**的变异
    /// （去掉一对不影响求值的括号，见 `dissolveOrderIsDeterministicAndWellSpread`）
    /// 让这条判据判红 ⇒ 它当时测的是渲染栈的冷热，不是被测行为。
    private static let warmUp: Bool = {
        for _ in 0..<8 {
            _ = MicroInteractionAPITests.stablePixels(Self.framed(Self.overflowing()))
            _ = MicroInteractionAPITests.stablePixels(Self.framed(Self.empty()))
            for entry in Self.kinds {
                _ = MicroInteractionAPITests.stablePixels(Self.chrome(progress: 0.5, kind: entry.kind))
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
        #expect(bare != notOverflowing, "被测内容其实没有溢出 bounds —— 本判据观测不到裁剪")

        for entry in Self.kinds {
            let identity = try #require(
                Self.pixels(Self.chrome(progress: 1, kind: entry.kind)), "渲染失败：\(entry.name)"
            )
            #expect(identity == bare, """
            `.\(entry.name)` 在恒等相位改变了画面 —— 转场停住之后被修饰视图的溢出内容
            （阴影 / 超出 bounds 的子视图）被裁剪永久吃掉了。
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
            #expect(hidden == blank, "`.\(entry.name)` 在进度 0 上还画着东西")
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
            #expect(midFlight != bare, "`.\(entry.name)` 的中间帧与完全揭示相同 —— 它中途就已经全开")
            #expect(midFlight != blank, "`.\(entry.name)` 的中间帧什么都不画 —— 揭示从未发生")

            // `animatableData` 必须**真的绑在 `progress` 上**，而不是某个不参与绘制的字段：
            // 插出来的那一帧必须与"直接用中间进度构造"的 chrome 逐字节相同。
            let direct = try #require(
                Self.pixels(Self.chrome(progress: 0.5, kind: entry.kind)), "渲染失败：\(entry.name)"
            )
            #expect(midFlight == direct, """
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
                #expect(frame != other, "`.\(entry.name)` 与 `.\(name)` 的中间帧逐字节相同")
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
            #expect(masked == bare, "`.\(entry.name)` 在 Reduce Motion 下仍然裁掉了东西")

            // 互锁：不降级时同一进度**必须**裁掉东西，否则上一条恒真。
            let motion = MaskReveal.plan(kind: entry.kind, progress: 0.5, isReduced: false)
            let clipped = try #require(
                Self.pixels(Self.framed(Self.overflowing().clipShape(MaskRevealShape(plan: motion)))),
                "渲染失败：\(entry.name)"
            )
            #expect(clipped != bare, "`.\(entry.name)` 在运动路径上也没裁掉任何东西")
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
        #expect(Self.pixels(band(0)) == blank, "travel 0 的柔光带还在画东西")
        #expect(Self.pixels(band(1)) == blank, "travel 1（恒等相位）的柔光带还在画东西 —— 永久残留")
        #expect(Self.pixels(band(0.5)) != blank, "travel 0.5 的柔光带什么都不画 —— 上两条是恒真的")
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

// MARK: - 源码契约

@Suite("MaskReveal 源码契约")
struct MaskRevealSourceGuard {

    static let files = ["MaskReveal.swift", "MaskRevealTransitions.swift"]

    static func code(_ fileName: String) throws -> String {
        MicroInteractionReduceMotionGuard.stripComments(try TypewriterTextTests.source(fileName))
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
    /// 这类等价形态原样绕过 ⇒ 断言面必须是整个类型。
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
