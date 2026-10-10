import Testing
@testable import AlttabCore

@Suite struct TapHealthTests {
    @Test func healthyTapStays() {
        let fresh = TapHealth.needsRestart(found: true, enabled: true, avgLatencyMicros: 0)
        let normal = TapHealth.needsRestart(found: true, enabled: true, avgLatencyMicros: 108_000)
        #expect(!fresh)
        #expect(!normal)
    }

    @Test func zombieTapReportedEnabledButSlowRestarts() {
        // 10/out: o sistema dizia "enabled" e cada tecla levava 1–3 s; o callback nunca rodava.
        let zombie = TapHealth.needsRestart(found: true, enabled: true, avgLatencyMicros: 3_242_816)
        let borderline = TapHealth.needsRestart(found: true, enabled: true, avgLatencyMicros: 1_000_000)
        #expect(zombie)
        #expect(borderline)
    }

    @Test func disabledOrMissingTapRestarts() {
        let disabled = TapHealth.needsRestart(found: true, enabled: false, avgLatencyMicros: 0)
        let missing = TapHealth.needsRestart(found: false, enabled: false, avgLatencyMicros: 0)
        #expect(disabled)
        #expect(missing)
    }
}
