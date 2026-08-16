---
name: persistence-setup
description: Set up Journal's persistence with SQLiteData (Point-Free, on GRDB) + CloudKit SyncEngine — table schema, explicit DatabaseMigrator migrations, media-on-filesystem with DB references, and private sync + optional iCloud sharing. Use when adding or changing persisted models, migrations, the database, or CloudKit sync.
---

# Persistence setup (Journal — SQLiteData + GRDB + CloudKit)

How Journal stores entries and their satellites (`JournalEntry`, `MediaAttachment`, `Todo`, `Tag`, `Embedding`) using **SQLiteData** (Point-Free's library on top of **GRDB**), with **CloudKit sync via `SyncEngine`** for the user's own devices plus optional iCloud sharing. Grounded in `docs/product/01-data-model.md` and the tech-stack decision in `docs/product/03-tech-stack.md`.

**Why SQLiteData over SwiftData:** GRDB performance, **explicit/testable `DatabaseMigrator` migrations** (no silent data loss), per-field last-write-wins conflict resolution, background handling of large binary assets, and CloudKit **sharing** — all things SwiftData still lacks for a media journal. Target `pointfreeco/sqlite-data` (this absorbed the old "SharingGRDB").

**Golden rules for this app:**
- **Media never goes in the DB.** Store originals on the filesystem (a dedicated media dir under Application Support); persist only `relativePath + UTType + checksum + createdAt` rows. Large binaries that must sync go through CloudKit **assets**, handled in the background by `SyncEngine` — never inline blobs.
- **Entries are E2EE at rest.** Encryption happens at the persistence boundary; keys live in Secure Enclave / iCloud Keychain, never in a column or a log. No server ever holds readable entries — CloudKit here is the *user's own* private database.
- **Every schema change is an explicit migration.** No implicit/auto-recreate. A schema change without a migration is a P0 (data loss on update).

## Schema (GRDB records)
Define tables as `Codable` GRDB records with SQLiteData's `@Table`. Keep entry *content* encrypted; keep only the columns you must filter/sort on in the clear (ids, timestamps, flags, foreign keys).

```swift
@Table struct JournalEntry: Codable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var cipherBody: Data        // E2EE-encrypted rich text / markdown payload
    var mood: Int?
    // weather + location snapshot: store as encrypted payload or discrete columns per privacy call
}

@Table struct MediaAttachment: Codable, Identifiable, Sendable {
    var id: UUID
    var entryID: UUID           // FK → JournalEntry.id
    var kind: String            // photo | video | audio | file
    var relativePath: String    // under the media root — validate on read (no traversal)
    var uti: String
    var checksum: String
    var createdAt: Date
    var transcript: Data?       // encrypted, optional (voice)
    var ocrText: Data?          // encrypted, optional (vision)
}

@Table struct Todo: Codable, Identifiable, Sendable {
    var id: UUID
    var entryID: UUID?          // may live inside an entry
    var title: String
    var dueDate: Date?
    var isDone: Bool
    var recurrenceRule: String?
    var notificationID: String? // UNNotificationRequest identifier to cancel on delete/complete
}

@Table struct Tag: Codable, Identifiable, Sendable { var id: UUID; var name: String }
@Table struct Embedding: Codable, Sendable { var entryID: UUID; var vector: Data }  // on-device semantic search
```

## The database factory
One factory used by app and tests so prod/test schemas can never drift.

```swift
enum JournalDB {
    /// On-disk database with the migrator applied. CloudKit SyncEngine attached separately.
    static func live() throws -> DatabaseQueue { /* open, then migrator.migrate(db) */ }

    /// In-memory for tests and `-uiTesting`. Never touches disk or iCloud.
    static func inMemory() throws -> DatabaseQueue { /* DatabaseQueue() + migrator.migrate */ }
}
```
Tests and `-uiTesting` must use `inMemory()` — deterministic, isolated, no disk residue.

## Migrations (explicit, ordered, tested)
```swift
var migrator = DatabaseMigrator()
migrator.registerMigration("v1_create_entries") { db in /* create tables */ }
migrator.registerMigration("v2_add_todo_recurrence") { db in /* ALTER ADD COLUMN … */ }
```
- Adding a column/table is additive and safe. Renames/type changes need a **data-preserving** migration + a test that seeds a store at the *old* version and asserts nothing is lost.
- Never delete/recreate the store to "fix" a migration.
- In DEBUG you may set `migrator.eraseDatabaseOnSchemaChange = true` for speed, but **never** in release.

## CloudKit sync (SyncEngine)
- Attach SQLiteData's `SyncEngine` to the live database for the user's **private** database; enable iCloud **sharing** only where a feature needs it.
- Conflict policy: per-field last-write-wins (SQLiteData default) — understand it for each table before relying on it.
- Large media sync as CloudKit **assets** in the background; the DB row keeps the reference only.
- The CloudKit container entitlement is required only when sync is actually enabled — don't add it before the sync stage (it pulls in review requirements early).

## Concurrency (Swift 6 strict)
- Do database work through GRDB's `read`/`write` on its own dispatch queue; hop to `@MainActor` for UI state. Don't block the main thread on DB or media I/O.
- Media/thumbnail generation runs off-main (`AVAssetImageGenerator` is slow), results cached to disk.

## Checklist before you commit a model change
- [ ] New/changed columns covered by an explicit `DatabaseMigrator` migration (additive, or data-preserving with a seeded-old-store test).
- [ ] Media stored on filesystem with a validated `relativePath`; nothing large inlined into the DB.
- [ ] Entry content encrypted at the persistence boundary; no key or plaintext in a column/log.
- [ ] Same schema/migrator used by `live()` and `inMemory()`.
- [ ] Round-trip test on the in-memory DB; relaunch-survival test on a temp on-disk DB.
- [ ] If sync-relevant: conflict behavior considered; binaries go through assets, not inline.
