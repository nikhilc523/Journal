import Testing
@testable import Sediment

/// Stage 0 smoke tests — prove the unit-test target compiles, links against the
/// app module, and runs under Swift Testing.
struct ScaffoldSmokeTests {
    @Test func appModuleLinks() {
        // If this compiles and runs, `@testable import Sediment` and the Swift
        // Testing harness are wired correctly.
        #expect(Bool(true))
    }

    @Test func uiTestingFlagDefaultsOffInUnitTests() {
        // The unit-test runner does not pass `-uiTesting`, so the app defaults
        // to its real (persistent) configuration path.
        #expect(SedimentApp.isUITesting == false)
    }
}
