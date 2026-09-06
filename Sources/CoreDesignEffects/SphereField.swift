import CoreDesign
import SwiftUI

// MARK: - 球面几何 / Sphere geometry

nonisolated enum SphereField {
    // MARK: 常量

    static let focalRatio: Double = 3

    static let radiusRatio: Double = 0.62

    static let rotationPeriod: Double = 24

    static let waveCycle: Double = 10.5

    static let waveFade: Double = 5.5

    static let restingPhase: Double = 0.125

    static let minimumAlpha: Double = 0.28
    static let maximumAlpha: Double = 1.0

    // MARK: 点集

    static func clamped(count: Int, limit: Int) -> Int {
        min(max(0, count), max(0, limit))
    }

    static func unitPoint(index: Int, count: Int) -> SIMD3<Double> {
        let y: Double = count > 1 ? 1 - (Double(index) / Double(count - 1)) * 2 : 0
        let clampedY = min(max(-1, y), 1)
        let radiusAtY = (max(0, 1 - clampedY * clampedY)).squareRoot()
        let goldenAngle = Double.pi * (3 - 5.0.squareRoot())
        let theta = goldenAngle * Double(index)
        return SIMD3(radiusAtY * cos(theta), clampedY, radiusAtY * sin(theta))
    }

    static func glyphSlot(index: Int, glyphCount: Int) -> Int {
        guard glyphCount > 0 else { return 0 }
        var x = UInt64(bitPattern: Int64(index)) &+ 0x9E37_79B9_7F4A_7C15
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Int(x % UInt64(glyphCount))
    }

    static func elevation(of point: SIMD3<Double>) -> Double {
        min(max(0, (point.y + 1) / 2), 1)
    }

    static func spun(_ point: SIMD3<Double>, byTurns turns: Double) -> SIMD3<Double> {
        let a = turns * 2 * .pi
        let c = cos(a)
        let s = sin(a)
        return SIMD3(point.x * c - point.z * s, point.y, point.x * s + point.z * c)
    }

    static func phase(at date: Date, period: Double = SphereField.rotationPeriod) -> Double {
        guard period > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return (t < 0 ? t + period : t) / period
    }

    // MARK: 投影

    struct Projected: Equatable {
        let x: Double
        let y: Double
        let depth: Double
    }

    static func project(_ point: SIMD3<Double>, worldRadius: Double, center: CGPoint) -> Projected {
        let focal = worldRadius * Self.focalRatio
        let z = point.z * worldRadius
        let denominator = focal + z
        let depth = (focal > 0 && denominator > 0) ? focal / denominator : 1
        return Projected(
            x: center.x + point.x * worldRadius * depth,
            y: center.y + point.y * worldRadius * depth,
            depth: depth
        )
    }

    static func isFarSide(_ point: SIMD3<Double>) -> Bool { point.z > 0 }

    static func alpha(depth: Double) -> Double {
        let lower = Self.focalRatio / (Self.focalRatio + 1)
        let upper = Self.focalRatio / (Self.focalRatio - 1)
        let t = min(max(0, (depth - lower) / (upper - lower)), 1)
        return Self.minimumAlpha + (Self.maximumAlpha - Self.minimumAlpha) * t
    }

    // MARK: 色波

    struct Wave: Equatable {
        let base: Int
        let next: Int
        let timeInCycle: Double
    }

    static func wave(at date: Date, paletteCount: Int) -> Wave {
        let slots = max(1, paletteCount)
        let elapsed = date.timeIntervalSinceReferenceDate
        let cycle = max(0.001, Self.waveCycle)
        let raw = elapsed.truncatingRemainder(dividingBy: cycle)
        let timeInCycle = raw < 0 ? raw + cycle : raw
        let index = Int((elapsed / cycle).rounded(.down))
        let base = ((index % slots) + slots) % slots
        return Wave(base: base, next: (base + 1) % slots, timeInCycle: timeInCycle)
    }

    static func restingWave(paletteCount: Int) -> Wave {
        let slots = max(1, paletteCount)
        return Wave(base: 0, next: slots > 1 ? 1 : 0, timeInCycle: 0)
    }

    static func waveProgress(elevation: Double, timeInCycle: Double) -> Double {
        let fade = max(0.001, Self.waveFade)
        let delay = min(max(0, elevation), 1) * fade
        return min(max(0, (timeInCycle - delay) / fade), 1)
    }

    static func tone(palette: [Color], wave: Wave, progress: Double) -> Color? {
        guard !palette.isEmpty else { return nil }
        let base = palette[wave.base % palette.count]
        let next = palette[wave.next % palette.count]
        guard base != next else { return base }
        return base.mix(with: next, by: min(max(0, progress), 1), in: .perceptual)
    }
}
