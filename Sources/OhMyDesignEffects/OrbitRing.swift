import OhMyDesign
import SwiftUI

// MARK: - 轨道环几何 / Orbit ring geometry

nonisolated enum OrbitRing {
    // MARK: 常量（取值沿用上游的观感）

    static let ringCount: Int = 4

    static let dotsPerRing: Int = 23

    static let rotationPeriod: Double = 10

    static let featureSeconds: Double = 2.4

    static let popPeak: Double = 1.85

    static let pushRadiusRatio: Double = 0.12

    static let pushStrengthRatio: Double = 0.035

    static let minimumAlpha: Double = 0.35
    static let maximumAlpha: Double = 1.0

    static let restingPhase: Double = 0.125

    // MARK: 环与点

    static func turns(at date: Date, period: Double = OrbitRing.rotationPeriod) -> Double {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return (t < 0 ? t + period : t) / period
    }

    static func ringRadius(ring: Int, size: Double) -> Double {
        let outer = size * 0.5 * 0.86
        let step = size * 0.5 * 0.075
        return max(0, outer - Double(ring) * step)
    }

    static func dotDiameter(ring: Int, size: Double) -> Double {
        let base = size * 0.021
        return max(size * 0.006, base - Double(ring) * size * 0.0025)
    }

    static func angle(index: Int, of count: Int, turns: Double, ring: Int) -> Double {
        guard count > 0 else { return 0 }
        let step = 2 * Double.pi / Double(count)
        return step * Double(index) + Double(ring) * 0.4 - turns * 2 * .pi
    }

    static func point(angle: Double, radius: Double, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    static func alpha(angle: Double) -> Double {
        let t = (cos(angle) + 1) / 2
        return Self.minimumAlpha + (Self.maximumAlpha - Self.minimumAlpha) * t
    }

    // MARK: logo 的 slot 与轮播

    static func seats(particleScale: Double) -> Int {
        guard particleScale.isFinite, particleScale > 0 else { return 1 }
        return max(1, Int((Double(Self.dotsPerRing) * particleScale).rounded()))
    }

    static func slot(of logoIndex: Int, logoCount: Int, dotsPerRing: Int = OrbitRing.dotsPerRing) -> Int {
        guard logoCount > 0, dotsPerRing > 0 else { return 0 }
        let stride = Double(dotsPerRing) / Double(logoCount)
        let raw = Int((Double(logoIndex) * stride).rounded(.down))
        return ((raw % dotsPerRing) + dotsPerRing) % dotsPerRing
    }

    static func logoAngle(logoIndex: Int, logoCount: Int, dotsPerRing: Int, turns: Double) -> Double {
        guard logoCount > 0 else { return 0 }
        let seats = max(1, dotsPerRing)
        guard logoCount <= seats else {
            return Self.angle(index: logoIndex, of: logoCount, turns: turns, ring: 0)
        }
        return Self.angle(
            index: Self.slot(of: logoIndex, logoCount: logoCount, dotsPerRing: seats),
            of: seats, turns: turns, ring: 0
        )
    }

    static func feature(at date: Date, logoCount: Int) -> (index: Int, progress: Double) {
        guard logoCount > 0, Self.featureSeconds > 0 else { return (0, 0) }
        let elapsed = date.timeIntervalSinceReferenceDate
        let window = Self.featureSeconds
        let slotIndex = Int((elapsed / window).rounded(.down))
        let index = ((slotIndex % logoCount) + logoCount) % logoCount
        let raw = elapsed.truncatingRemainder(dividingBy: window)
        let progress = (raw < 0 ? raw + window : raw) / window
        return (index, min(max(0, progress), 1))
    }

    static let restingFeature: (index: Int, progress: Double) = (0, 0)

    static func popScale(progress: Double) -> Double {
        let t = min(max(0, progress), 1)
        let bump = sin(t * .pi)
        return 1 + (Self.popPeak - 1) * bump * bump
    }

    // MARK: 挤压位移场（替代 SpriteKit 物理体）

    static func pushed(_ dot: CGPoint, awayFrom source: CGPoint, radius: Double, strength: Double) -> CGPoint {
        guard radius > 0, strength != 0 else { return dot }
        let dx = Double(dot.x - source.x)
        let dy = Double(dot.y - source.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0, distance < radius else { return dot }
        let falloff = 1 - distance / radius
        let amount = strength * falloff
        return CGPoint(x: dot.x + dx / distance * amount, y: dot.y + dy / distance * amount)
    }
}
