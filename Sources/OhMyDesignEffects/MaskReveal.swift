import OhMyDesign
import SwiftUI

// MARK: - 几何族 / Geometry family

nonisolated enum MaskRevealKind: Equatable, Sendable {
    case iris(anchor: UnitPoint)

    case wipe(radians: Double)

    case blinds(count: Int)

    case clock(sign: Double)

    case glare(radians: Double)

    case dissolve(cellSize: CGFloat)
}

nonisolated struct MaskRevealPlan: Equatable, Sendable {
    let progress: Double

    let kind: MaskRevealKind?

    let contentOpacity: Double

    let glare: MaskRevealGlare?
}

nonisolated struct MaskRevealGlare: Equatable, Sendable {
    let radians: Double
    let travel: Double
}

// MARK: - 纯几何 / Pure geometry

nonisolated enum MaskReveal {
    // MARK: 相位

    static func progress(phase: TransitionPhase) -> Double {
        1 - abs(phase.value)
    }

    static func plan(kind: MaskRevealKind, progress: Double, isReduced: Bool) -> MaskRevealPlan {
        let clamped = progress.isFinite ? min(max(progress, 0), 1) : 0
        guard !isReduced else {
            return MaskRevealPlan(progress: clamped, kind: nil, contentOpacity: clamped, glare: nil)
        }
        var glare: MaskRevealGlare?
        if case .glare(let radians) = kind {
            glare = MaskRevealGlare(radians: radians, travel: clamped)
        }
        return MaskRevealPlan(progress: clamped, kind: kind, contentOpacity: 1, glare: glare)
    }

    // MARK: 恒等余量

    static let haloOnset: Double = 0.85

    static func halo(progress: Double) -> Double {
        guard progress > Self.haloOnset else { return 0 }
        return min(1, (progress - Self.haloOnset) / (1 - Self.haloOnset))
    }

    static let seamBite: CGFloat = 1

    static func haloPath(progress: Double, in rect: CGRect) -> Path {
        let reach = hypot(rect.width, rect.height) * CGFloat(Self.halo(progress: progress))
        var path = Path()
        guard reach > 0 else { return path }
        let bite = min(Self.seamBite, reach)
        let outer = rect.insetBy(dx: -reach, dy: -reach)
        path.addRect(CGRect(
            x: outer.minX, y: outer.minY, width: outer.width, height: reach + bite
        ))
        path.addRect(CGRect(
            x: outer.minX, y: rect.maxY - bite, width: outer.width, height: reach + bite
        ))
        path.addRect(CGRect(
            x: outer.minX, y: rect.minY, width: reach + bite, height: rect.height
        ))
        path.addRect(CGRect(
            x: rect.maxX - bite, y: rect.minY, width: reach + bite, height: rect.height
        ))
        return path
    }

    // MARK: 路径总入口

    static func path(for plan: MaskRevealPlan, in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        guard plan.progress < 1, let kind = plan.kind else { return Self.openPath(in: rect) }
        var path = Self.kindPath(kind, progress: plan.progress, in: rect)
        path.addPath(Self.haloPath(progress: plan.progress, in: rect))
        return path
    }

    static let openReach: CGFloat = 1_000_000

    static func openPath(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: -Self.openReach, dy: -Self.openReach))
    }

    static func kindPath(_ kind: MaskRevealKind, progress: Double, in rect: CGRect) -> Path {
        switch kind {
        case .iris(let anchor):
            Self.irisPath(anchor: anchor, progress: progress, in: rect)
        case .wipe(let radians), .glare(let radians):
            Self.wipePath(radians: radians, progress: progress, in: rect)
        case .blinds(let count):
            Self.blindsPath(count: count, progress: progress, in: rect)
        case .clock(let sign):
            Self.clockPath(sign: sign, progress: progress, in: rect)
        case .dissolve(let cellSize):
            Self.dissolvePath(cellSize: cellSize, progress: progress, in: rect)
        }
    }

    // MARK: 各族几何

    static let seamOverlap: CGFloat = 0.02

    static func irisPath(anchor: UnitPoint, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let center = CGPoint(
            x: rect.minX + rect.width * anchor.x,
            y: rect.minY + rect.height * anchor.y
        )
        let radius = Self.reach(from: center, in: rect) * CGFloat(progress)
        guard radius > 0 else { return Path() }
        return Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
        ))
    }

    static func reach(from center: CGPoint, in rect: CGRect) -> CGFloat {
        let dx = max(abs(center.x - rect.minX), abs(rect.maxX - center.x))
        let dy = max(abs(center.y - rect.minY), abs(rect.maxY - center.y))
        return hypot(dx, dy)
    }

    static func wipePath(radians: Double, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let direction = CGPoint(x: cos(radians), y: sin(radians))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let projections = Self.corners(of: rect).map {
            ($0.x - center.x) * direction.x + ($0.y - center.y) * direction.y
        }
        let slack = hypot(rect.width, rect.height) * 0.005
        let start = (projections.min() ?? 0) - slack
        let end = (projections.max() ?? 0) + slack
        let cut = start + (end - start) * CGFloat(progress)
        let half = hypot(rect.width, rect.height)

        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + direction.x * along + normal.x * across,
                y: center.y + direction.y * along + normal.y * across
            )
        }
        var path = Path()
        path.move(to: point(start, -half))
        path.addLine(to: point(cut, -half))
        path.addLine(to: point(cut, half))
        path.addLine(to: point(start, half))
        path.closeSubpath()
        return path
    }

    static func corners(of rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
        ]
    }

    static let minimumBlindCount: Int = 1

    static func blindsPath(count: Int, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let bands = max(Self.minimumBlindCount, count)
        let bandHeight = rect.height / CGFloat(bands)
        let grow = CGFloat(progress) * (1 + Self.seamOverlap)
        var path = Path()
        for index in 0..<bands {
            let midY = rect.minY + bandHeight * (CGFloat(index) + 0.5)
            let half = bandHeight * 0.5 * grow
            path.addRect(CGRect(
                x: rect.minX, y: midY - half, width: rect.width, height: half * 2
            ))
        }
        return path
    }

    static func clockPath(sign: Double, progress: Double, in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = Self.reach(from: center, in: rect) * (1 + Self.seamOverlap)
        let sweep = sign * progress * 360
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + sweep),
            clockwise: sign < 0
        )
        path.closeSubpath()
        return path
    }

    static let dissolveDefaultCellSize: CGFloat = MaskRevealTransition.defaultCellSize

    static let dissolveMaximumCells: Int = 2000

    static let dissolveCellSpan: Double = 0.35

    static func effectiveCellSize(_ requested: CGFloat, in rect: CGRect) -> CGFloat {
        let base = requested.isFinite && requested > 0 ? requested : Self.dissolveDefaultCellSize
        let area = rect.width * rect.height
        guard area > 0 else { return base }
        return max(base, sqrt(area / CGFloat(Self.dissolveMaximumCells)))
    }

    static func cellThreshold(column: Int, row: Int) -> Double {
        let mixed = (column &* 73_856_093) ^ (row &* 19_349_663)
        return Double((mixed & 0x7FFF_FFFF) % 1000) / 1000
    }

    static func cellProgress(threshold: Double, progress: Double) -> Double {
        let start = threshold * (1 - Self.dissolveCellSpan)
        guard progress > start else { return 0 }
        return min(1, (progress - start) / Self.dissolveCellSpan)
    }

    static func dissolvePath(cellSize: CGFloat, progress: Double, in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0 else { return path }
        let side = Self.effectiveCellSize(cellSize, in: rect)
        let columns = max(1, Int((rect.width / side).rounded(.up)))
        let rows = max(1, Int((rect.height / side).rounded(.up)))
        let cellWidth = rect.width / CGFloat(columns)
        let cellHeight = rect.height / CGFloat(rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let filled = Self.cellProgress(
                    threshold: Self.cellThreshold(column: column, row: row), progress: progress
                )
                guard filled > 0 else { continue }
                let grow = CGFloat(filled) * (1 + Self.seamOverlap)
                let midX = rect.minX + cellWidth * (CGFloat(column) + 0.5)
                let midY = rect.minY + cellHeight * (CGFloat(row) + 0.5)
                path.addRect(CGRect(
                    x: midX - cellWidth * 0.5 * grow,
                    y: midY - cellHeight * 0.5 * grow,
                    width: cellWidth * grow,
                    height: cellHeight * grow
                ))
            }
        }
        return path
    }

    // MARK: 柔光带（只有 `glare` 用）

    static let glareBandRatio: CGFloat = 0.22

    static func glareOpacity(travel: Double) -> Double {
        guard travel > 0, travel < 1 else { return 0 }
        return sin(travel * .pi)
    }

    static func glarePath(_ glare: MaskRevealGlare, in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let direction = CGPoint(x: cos(glare.radians), y: sin(glare.radians))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let diagonal = hypot(rect.width, rect.height)

        let projections = Self.corners(of: rect).map {
            ($0.x - center.x) * direction.x + ($0.y - center.y) * direction.y
        }
        let slack = diagonal * 0.005
        let start = (projections.min() ?? 0) - slack
        let end = (projections.max() ?? 0) + slack
        let cut = start + (end - start) * CGFloat(glare.travel)
        let band = diagonal * Self.glareBandRatio

        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + direction.x * along + normal.x * across,
                y: center.y + direction.y * along + normal.y * across
            )
        }
        var path = Path()
        path.move(to: point(cut - band / 2, -diagonal))
        path.addLine(to: point(cut + band / 2, -diagonal))
        path.addLine(to: point(cut + band / 2, diagonal))
        path.addLine(to: point(cut - band / 2, diagonal))
        path.closeSubpath()
        return path
    }
}

// MARK: - 绘制 / Drawing

struct MaskRevealShape: Shape {
    var plan: MaskRevealPlan

    var animatableData: Double {
        get { self.plan.progress }
        set {
            self.plan = MaskRevealPlan(progress: newValue, kind: self.plan.kind,
                                       contentOpacity: self.plan.contentOpacity, glare: self.plan.glare)
        }
    }

    func path(in rect: CGRect) -> Path {
        MaskReveal.path(for: self.plan, in: rect)
    }
}

struct MaskRevealGlareBand: View {
    let glare: MaskRevealGlare

    var body: some View {
        let glare = self.glare
        GeometryReader { proxy in
            MaskRevealGlareShape(glare: glare)
                .fill(Color.specularHighlight)
                .blur(radius: min(proxy.size.width, proxy.size.height) * 0.06)
                .opacity(MaskReveal.glareOpacity(travel: glare.travel))
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct MaskRevealGlareShape: Shape {
    let glare: MaskRevealGlare

    func path(in rect: CGRect) -> Path {
        MaskReveal.glarePath(self.glare, in: rect)
    }
}

struct MaskRevealChrome: ViewModifier, Animatable {
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
