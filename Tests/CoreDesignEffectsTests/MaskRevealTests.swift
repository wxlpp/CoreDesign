import CoreDesign
import Foundation
import SwiftUI
import Testing

@testable import CoreDesignEffects

// MARK: - #268：mask reveal 转场簇（iris / wipe / blinds / clock / glare / dissolve）

// MARK: - 纯几何

@Suite("MaskReveal 几何契约")
struct MaskRevealGeometryTests {
    static let rect = CGRect(x: 0, y: 0, width: 160, height: 120)

    static let samples = 20

    static func samplePoint(_ index: Int, in rect: CGRect = MaskRevealGeometryTests.rect) -> CGPoint {
        let column = index % Self.samples
        let row = index / Self.samples
        return CGPoint(
            x: rect.minX + rect.width * (Double(column) + 0.5) / Double(Self.samples),
            y: rect.minY + rect.height * (Double(row) + 0.5) / Double(Self.samples)
        )
    }

    static func revealed(_ kind: MaskRevealKind, progress: Double) -> Set<Int> {
        let plan = MaskReveal.plan(kind: kind, progress: progress, isReduced: false)
        let path = MaskReveal.path(for: plan, in: Self.rect)
        return Set((0..<(Self.samples * Self.samples)).filter { path.contains(Self.samplePoint($0)) })
    }

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
        #expect(!path(.center).contains(nearTopLeading))
        #expect(path(.center).contains(CGPoint(x: 80, y: 60)))
    }

    @Test("clock 的方向选的是扫针转向")
    func clockDirectionSelectsTheSweep() {
        let center = CGPoint(x: Self.rect.midX, y: Self.rect.midY)
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
        #expect(Self.revealed(.dissolve(cellSize: 16), progress: 0.4)
                == Self.revealed(.dissolve(cellSize: 16), progress: 0.4))

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

        let atFull = Self.subpathCount(
            MaskReveal.dissolvePath(cellSize: 0.5, progress: 1, in: huge)
        )
        #expect(atFull > 0, "cellSize 0.5 在 1200×900 上一个格子都没画 —— 死转场")
        #expect(atFull <= MaskReveal.dissolveMaximumCells * 2, """
        `.dissolve(cellSize: 0.5)` 在 1200×900 上实际生成了 \(atFull) 条子路径
        （上限 \(MaskReveal.dissolveMaximumCells * 2)）—— 逐帧重建这么多子路径会卡死。
        请检查 `MaskReveal.dissolvePath` 是否真的走了 `effectiveCellSize(_:in:)` 这道闸。
        """)

        let side = MaskReveal.effectiveCellSize(0.5, in: huge)
        #expect(atFull == Self.subpathCount(
            MaskReveal.dissolvePath(cellSize: side, progress: 1, in: huge)
        ), """
        `dissolvePath(cellSize: 0.5)` 与 `dissolvePath(cellSize: effectiveCellSize(0.5))`
        画出的格数不同 —— `dissolvePath` 没有走 `effectiveCellSize(_:in:)` 这道闸。
        """)

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

    @Test("恒等相位与 Reduce Motion 下的裁剪对任何尺寸的溢出内容都不起作用")
    func identityClipsNothingRegardlessOfContentSize() {
        let boxes: [(name: String, rect: CGRect)] = [
            ("160×120", Self.rect),
            ("60×24 badge", CGRect(x: 0, y: 0, width: 60, height: 24)),
            ("4×4 icon", CGRect(x: 0, y: 0, width: 4, height: 4)),
        ]
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

    static func overflowing() -> some View {
        Color.surfaceRaised
            .frame(width: 60, height: 60)
            .overlay { Rectangle().fill(Color.contentPrimary).frame(width: 150, height: 150) }
    }

    static func empty() -> some View {
        Color.clear.frame(width: 60, height: 60)
    }

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

    @Test("恒等相位与裸视图逐字节相同（被测内容故意溢出 bounds）")
    func identityIsBytewiseIdentityEvenWithOverflow() throws {
        let bare = try #require(Self.pixels(Self.framed(Self.overflowing())), "基线渲染失败")
        #expect(bare.contains(where: { $0 != 0 }), "基线位图全 0 —— 下面的相等断言恒真")
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

    @Test("极小内容的恒等相位也与裸视图逐字节相同（溢出远超自身对角线）")
    func identityIsBytewiseIdentityForTinyContentWithHugeOverflow() throws {
        let bare = try #require(Self.pixels(Self.framed(Self.tinyOverflowing())), "基线渲染失败")
        #expect(bare.contains(where: { $0 != 0 }), "基线位图全 0 —— 下面的相等断言恒真")
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

@Suite("MaskRevealTransition.body 本身")
@MainActor
struct MaskRevealTransitionBodyTests {
    static func placeholder() throws -> MaskRevealTransition.Content {
        try #require(MemoryLayout<MaskRevealTransition.Content>.size == 0, """
        `PlaceholderContentView` 不再是零尺寸类型 —— 本 suite 的 `body` 直呼手法失效，
        请改用别的方式对 `MaskRevealTransition.body(content:phase:)` 求值。
        """)
        return unsafeBitCast((), to: MaskRevealTransition.Content.self)
    }

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

    @Test("body 把 (相位 → 进度, 自己的 kind) 原样交给 MaskRevealChrome")
    func bodyHandsChromeThePhaseAndTheKind() throws {
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
                let matches = applied == expected
                #expect(matches, """
                `.transition(.\(entry.name))` 在相位 \(step.name) 上渲染出的画面
                与「\(expectedName)」不同 —— `MaskRevealTransition.body` 没有把这个相位
                交给 `MaskRevealChrome`（丢掉相位 ⇒ 转场根本不发生／内容凭空出现）。
                """)
            }
        }
    }

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

    static func testSource() throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
    }

    @Test("本文件的位图断言只许走 MaskRevealRenderTests.pixels（暖机门）")
    func bitmapAssertionsGoThroughTheWarmUpGate() throws {
        let code = MicroInteractionReduceMotionGuard.stripComments(try Self.testSource())
        let plain = "Tests." + "pixels("
        let stable = "Tests." + "stablePixels("
        let gateCall = "MaskRevealRenderTests." + "pixels("

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
        let viaGate = ConfettiTests.occurrences(of: gateCall, in: code)
        let inRegions = hits(warmUp) + hits(gate)
        let allowed = inRegions + viaGate

        #expect(inRegions > 0, "暖机块与闸函数里一次底层 harness 调用都没有 —— 本条已经与实现脱节")
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
        for file in Self.files {
            #expect(MicroInteractionReduceMotionGuard.approvedNoMotion.contains(file),
                    "\(file) 不在 approvedNoMotion 名单上 —— 本条与那份名单已经脱节")
        }
    }

    @Test("reduceMotion 只许喂给 MaskReveal.plan(...) 这一个裁决点")
    func reduceMotionIsOnlyConsumedByThePlan() throws {
        var reads = 0
        var fed = 0
        for file in Self.files {
            let code = try Self.code(file)
            reads += code.components(separatedBy: "self.reduceMotion").count - 1
            fed += code.components(separatedBy: "isReduced: self.reduceMotion").count - 1
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
