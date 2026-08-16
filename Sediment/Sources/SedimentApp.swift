import SwiftUI
import SQLiteData

/// App entry point for Sediment — a calm, local-first iOS journal.
///
/// Keep this file thin — it should stay a pure composition root. The default
/// database (SQLiteData) is prepared once at launch here; CloudKit sync is wired
/// but dormant until the sync/E2EE stage (see ``SedimentDatabase``).
@main
struct SedimentApp: App {
    /// True when launched by the UI test suite (`-uiTesting`) — swaps in an
    /// in-memory store and never touches disk or iCloud, for deterministic runs.
    static let isUITesting = SedimentRuntime.isUITesting

    init() {
        do {
            try prepareDependencies { deps in
                if SedimentApp.isUITesting {
                    deps.defaultDatabase = try SedimentDatabase.inMemory()
                } else {
                    try deps.bootstrapSediment(enableCloudKit: false)
                }
            }
        } catch {
            // A database that can't open is unrecoverable; surface it loudly in
            // debug rather than limping along with a broken store.
            assertionFailure("Failed to prepare database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
