import Testing
@testable import Journal

/// Stage 0 smoke tests — prove the unit-test target compiles, links against the
/// app module, and runs under Swift Testing. Real logic tests arrive with the
/// data layer in Stage 2 (see `swift-unit-tests`).
struct ScaffoldSmokeTests {
    @Test func appModuleLinks() {
        // If this compiles and runs, `@testable import Journal` and the Swift
        // Testing harness are wired correctly.
        #expect(Bool(true))
    }

    @Test func uiTestingFlagDefaultsOffInUnitTests() {
        // The unit-test runner does not pass `-uiTesting`, so the app defaults
        // to its real (persistent) configuration path.
        #expect(JournalApp.isUITesting == false)
    }
}
