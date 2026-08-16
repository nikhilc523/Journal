import SwiftUI

/// App entry point for Journal — a calm, local-first iOS journal.
///
/// Stage 0 wires only the scaffold: a single window rendering ``RootView``.
/// Persistence (SQLiteData + CloudKit) lands in Stage 2; the design system in
/// Stage 1. Keep this file thin — it should stay a pure composition root.
@main
struct JournalApp: App {
    /// True when launched by the UI test suite (`-uiTesting`). Later stages use
    /// this to swap in an in-memory store and disable CloudKit sync for
    /// deterministic runs (see the `xcuitest-writer` skill).
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
