@testable import CoreDesign

enum SurfaceKindAPIGuard {
    private static let apiGuard: [SurfaceKind] = [
        .canvas, .content, .control, .floating, .overlay,
        .canvasSubtle, .panel, .sidebar, .card, .grouped,
    ]
}
