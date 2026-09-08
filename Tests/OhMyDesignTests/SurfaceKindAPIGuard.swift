@testable import OhMyDesign

enum SurfaceKindAPIGuard {
    private static let apiGuard: [SurfaceKind] = [
        .canvas, .content, .control, .floating,
        .canvasSubtle, .panel, .sidebar, .card, .grouped,
    ]
}
