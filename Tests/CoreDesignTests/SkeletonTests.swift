import Foundation
import SwiftUI
import Testing
@testable import CoreDesign

@Suite("Skeleton")
@MainActor
struct SkeletonTests {
    @Test("isLoading true stores the loading flag")
    func isLoadingTrueStoresFlag() {
        let skeleton = Skeleton(isLoading: true) {
            SkeletonLine()
        } content: {
            Text("Real content")
        }
        #expect(skeleton.isLoading == true)
    }

    @Test("isLoading false stores the loading flag")
    func isLoadingFalseStoresFlag() {
        let skeleton = Skeleton(isLoading: false) {
            SkeletonLine()
        } content: {
            Text("Real content")
        }
        #expect(skeleton.isLoading == false)
    }

    @Test("placeholder and content builders are preserved without erasure")
    func buildersPreserveConcreteTypes() {
        let skeleton = Skeleton(isLoading: true) {
            SkeletonCircle(diameter: 32)
        } content: {
            Text("Avatar")
        }
        #expect(type(of: skeleton) == Skeleton<SkeletonCircle, Text>.self)
    }

    @Test("composed placeholder tree (circle + line) type-checks without erasure")
    func composedPlaceholderTreeTypeChecks() {
        let skeleton = Skeleton(isLoading: true) {
            HStack {
                SkeletonCircle(diameter: 40)
                SkeletonLine(lineCount: 2)
            }
        } content: {
            Text("Real")
        }
        #expect(skeleton.isLoading == true)
    }
}

@Suite("SkeletonLine")
@MainActor
struct SkeletonLineTests {
    @Test("default init uses a single line")
    func defaultLineCount() {
        let line = SkeletonLine()
        #expect(line.lineCount == 1)
    }

    @Test("lineCount below 1 clamps to 1")
    func lineCountClampsToOne() {
        let line = SkeletonLine(lineCount: 0)
        #expect(line.lineCount == 1)

        let negative = SkeletonLine(lineCount: -3)
        #expect(negative.lineCount == 1)
    }

    @Test("explicit lineCount is preserved")
    func explicitLineCountPreserved() {
        let line = SkeletonLine(lineCount: 4)
        #expect(line.lineCount == 4)
    }

    @Test("custom metrics are stored")
    func customMetricsStored() {
        let line = SkeletonLine(lineCount: 2, lineHeight: 16, spacing: CoreSpacing.sm, lastLineWidthFraction: 0.5)
        #expect(line.lineHeight == 16)
        #expect(line.spacing == CoreSpacing.sm)
        #expect(line.lastLineWidthFraction == 0.5)
    }
}

@Suite("SkeletonRect")
@MainActor
struct SkeletonRectTests {
    @Test("default init has nil width and CoreRadius.medium corner radius")
    func defaultInit() {
        let rect = SkeletonRect()
        #expect(rect.width == nil)
        #expect(rect.height == 120)
        #expect(rect.cornerRadius == CoreRadius.medium)
    }

    @Test("explicit width is preserved")
    func explicitWidthPreserved() {
        let rect = SkeletonRect(width: 200, height: 80, cornerRadius: CoreRadius.small)
        #expect(rect.width == 200)
        #expect(rect.height == 80)
        #expect(rect.cornerRadius == CoreRadius.small)
    }
}

@Suite("SkeletonCircle")
@MainActor
struct SkeletonCircleTests {
    @Test("default diameter is 40")
    func defaultDiameter() {
        let circle = SkeletonCircle()
        #expect(circle.diameter == 40)
    }

    @Test("explicit diameter is preserved")
    func explicitDiameterPreserved() {
        let circle = SkeletonCircle(diameter: 64)
        #expect(circle.diameter == 64)
    }
}

@Suite("SkeletonShimmerMath")
struct SkeletonShimmerMathTests {
    @Test("offset with zero or negative width returns zero")
    func zeroWidthReturnsZero() {
        #expect(SkeletonShimmerMath.offset(at: Date(), width: 0) == 0)
        #expect(SkeletonShimmerMath.offset(at: Date(), width: -10) == 0)
    }

    @Test("offset stays within [-width, width] across the full period")
    func offsetStaysWithinBounds() {
        let width: CGFloat = 200
        var t = 0.0
        while t < SkeletonShimmerMath.duration * 3 {
            let date = Date(timeIntervalSinceReferenceDate: t)
            let offset = SkeletonShimmerMath.offset(at: date, width: width)
            #expect(offset >= -width)
            #expect(offset <= width)
            t += 0.13
        }
    }

    @Test("offset is periodic with the configured duration")
    func offsetIsPeriodic() {
        let width: CGFloat = 150
        let baseTime = 12.34
        let date0 = Date(timeIntervalSinceReferenceDate: baseTime)
        let date1 = Date(timeIntervalSinceReferenceDate: baseTime + SkeletonShimmerMath.duration)
        let offset0 = SkeletonShimmerMath.offset(at: date0, width: width)
        let offset1 = SkeletonShimmerMath.offset(at: date1, width: width)
        #expect(abs(offset0 - offset1) < 0.0001)
    }

    @Test("offset starts at -width when progress is 0")
    func offsetStartsAtNegativeWidth() {
        let width: CGFloat = 100
        // timeIntervalSinceReferenceDate == 0 → progress == 0 → offset == -width.
        let offset = SkeletonShimmerMath.offset(at: Date(timeIntervalSinceReferenceDate: 0), width: width)
        #expect(abs(offset - (-width)) < 0.0001)
    }
}
