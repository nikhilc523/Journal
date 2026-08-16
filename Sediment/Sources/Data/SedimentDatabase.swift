import Foundation
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "com.nikhilc.sediment", category: "Database")

/// Database provisioning for Sediment: one shared `DatabaseMigrator` used by both
/// the live on-disk store and the in-memory test store, so prod and test schemas
/// can never drift. CloudKit sync is wired but dormant (see `bootstrap`).
public enum SedimentDatabase {

    // MARK: Migrator (single source of truth)

    /// The ordered, explicit migrations. Every schema change adds a new
    /// `registerMigration` here **and** a seeded-old-store test — never edit an
    /// existing migration (they are frozen once shipped).
    public static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        // NOTE: intentionally NOT setting `eraseDatabaseOnSchemaChange` even in
        // DEBUG — we want migration bugs to surface loudly, not silently wipe data.

        migrator.registerMigration("v1_create_entities") { db in
            try db.execute(sql: """
                CREATE TABLE "journalEntries" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "createdAt" TEXT NOT NULL,
                    "updatedAt" TEXT NOT NULL,
                    "body" TEXT NOT NULL DEFAULT '',
                    "mood" INTEGER,
                    "weatherTempC" REAL,
                    "weatherCondition" TEXT,
                    "weatherSymbol" TEXT,
                    "latitude" REAL,
                    "longitude" REAL,
                    "placeName" TEXT,
                    "isPrivate" INTEGER NOT NULL DEFAULT 1
                ) STRICT;

                CREATE TABLE "mediaAttachments" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "entryID" TEXT NOT NULL REFERENCES "journalEntries"("id") ON DELETE CASCADE,
                    "type" TEXT NOT NULL,
                    "relativePath" TEXT NOT NULL,
                    "utType" TEXT NOT NULL,
                    "checksum" TEXT NOT NULL,
                    "createdAt" TEXT NOT NULL,
                    "transcript" TEXT,
                    "ocrText" TEXT,
                    "caption" TEXT
                ) STRICT;

                CREATE TABLE "todos" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "entryID" TEXT REFERENCES "journalEntries"("id") ON DELETE SET NULL,
                    "title" TEXT NOT NULL,
                    "dueDate" TEXT,
                    "isDone" INTEGER NOT NULL DEFAULT 0,
                    "recurrenceRule" TEXT,
                    "notificationID" TEXT,
                    "rollsForward" INTEGER NOT NULL DEFAULT 0
                ) STRICT;

                CREATE TABLE "tags" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "name" TEXT NOT NULL
                ) STRICT;

                CREATE UNIQUE INDEX "tags_name" ON "tags"("name");

                CREATE TABLE "entryTags" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                    "entryID" TEXT NOT NULL REFERENCES "journalEntries"("id") ON DELETE CASCADE,
                    "tagID" TEXT NOT NULL REFERENCES "tags"("id") ON DELETE CASCADE
                ) STRICT;

                CREATE UNIQUE INDEX "entryTags_pair" ON "entryTags"("entryID", "tagID");

                CREATE TABLE "embeddings" (
                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid())
                        REFERENCES "journalEntries"("id") ON DELETE CASCADE,
                    "vector" BLOB NOT NULL
                ) STRICT;
                """)
        }

        return migrator
    }

    // MARK: Live (on-disk) database

    /// Context-aware live database (on disk in the app; temporary in previews /
    /// tests), migrated with the shared migrator.
    public static func appDatabase() throws -> any DatabaseWriter {
        var configuration = Configuration()
        #if DEBUG
        configuration.prepareDatabase { db in
            db.trace(options: .profile) { logger.debug("\($0.expandedDescription)") }
        }
        #endif
        let database = try defaultDatabase(configuration: configuration)
        logger.info("open '\(database.path)'")
        try migrator().migrate(database)
        return database
    }

    /// A private in-memory database — deterministic, isolated, never touches disk
    /// or iCloud. Used by unit tests and the `-uiTesting` launch path.
    public static func inMemory() throws -> any DatabaseWriter {
        let queue = try DatabaseQueue()
        try migrator().migrate(queue)
        return queue
    }
}

// MARK: - Dependency bootstrap (database + optional CloudKit sync)

public extension DependencyValues {
    /// Wire the app's default database and — when explicitly enabled — the
    /// CloudKit `SyncEngine` over all syncable tables.
    ///
    /// **CloudKit is dormant by default (`enableCloudKit: false`).** The engine
    /// is fully wired here, but activating it requires the iCloud container +
    /// entitlements, which are intentionally deferred to the sync/E2EE stage (see
    /// the `persistence-setup` skill: "don't add the entitlement before the sync
    /// stage"). Flip the flag to `true` once those land — no other code changes.
    mutating func bootstrapSediment(enableCloudKit: Bool = false) throws {
        let database = try SedimentDatabase.appDatabase()
        defaultDatabase = database

        guard enableCloudKit, !SedimentRuntime.isUITesting else { return }
        defaultSyncEngine = try SyncEngine(
            for: database,
            tables: JournalEntry.self,
                    MediaAttachment.self,
                    Todo.self,
                    Tag.self,
                    EntryTag.self,
                    Embedding.self
        )
    }
}

/// Small runtime probe shared by the app and the persistence layer.
public enum SedimentRuntime {
    public static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
}
