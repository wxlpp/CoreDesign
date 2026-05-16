import Testing
@testable import CoreDesign

@Suite("SurfaceKind")
struct SurfaceKindTests {
    @Test("native primer surface roles construct")
    func nativePrimerSurfaceRolesConstruct() {
        let roles: [SurfaceKind] = [
            .canvas,
            .content,
            .control,
            .floating,
            .overlay,
        ]

        #expect(roles.count == 5)
    }

    @Test("legacy surface roles remain available")
    func legacySurfaceRolesRemainAvailable() {
        let roles: [SurfaceKind] = [
            .canvasSubtle,
            .panel,
            .sidebar,
            .card,
        ]

        #expect(roles.count == 4)
    }

    @Test("all surface roles construct after Craft token tuning")
    func allSurfaceRolesConstructAfterCraftTokenTuning() {
        let roles: [SurfaceKind] = [
            .canvas,
            .content,
            .control,
            .floating,
            .overlay,
            .canvasSubtle,
            .panel,
            .sidebar,
            .card,
        ]

        #expect(roles.count == 9)
    }
}
