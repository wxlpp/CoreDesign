import SwiftUI

// MARK: - 转场裁决 / Transition decision

enum FullScreenTransitionPlan: Sendable, Equatable, CaseIterable {
    case zoom

    case plain

    static var platformSupportsZoom: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    static func resolve(reduceMotion: Bool, platformSupportsZoom: Bool) -> FullScreenTransitionPlan {
        guard platformSupportsZoom else { return .plain }
        return reduceMotion ? .plain : .zoom
    }
}
