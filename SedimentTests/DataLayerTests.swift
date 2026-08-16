import Testing
import Foundation
import GRDB
@testable import Sediment

/// Stage 2 persistence tests. Each test runs against a fresh in-memory database
/// (deterministic, no disk/iCloud) built from the same migrator the app uses, so
/// prod and test schemas can never drift.
@Suite struct DataLayerTests {

    // MARK: Migration integrity

    @Test func migrationCreatesAllFiveEntities() throws {
        let repo = try Repository.inMemory()
        let present = try repo.database.read { db -> [String: Bool] in
            var result: [String: Bool] = [:]
            for table in ["journalEntries", "mediaAttachments", "todos", "tags", "entryTags", "embeddings"] {
                result[table] = try db.tableExists(table)
            }
            return result
        }
        for (table, exists) in present {
            #expect(exists, "missing table \(table)")
        }
    }

    @Test func migratorIsIdempotent() throws {
        // Re-applying the migrator to an already-migrated store must be a no-op,
        // not an error (guards against non-idempotent migrations).
        let db = try SedimentDatabase.inMemory()
        #expect(throws: Never.self) {
            try SedimentDatabase.migrator().migrate(db)
        }
    }

    @Test func v1MigrationIsRegistered() throws {
        let repo = try Repository.inMemory()
        let applied = try repo.database.read { db in
            try SedimentDatabase.migrator().appliedIdentifiers(db)
        }
        #expect(applied.contains("v1_create_entities"))
    }

    /// Stage 4 added `bodyArchive` via `v2_entry_body_archive`. Seed a store at the
    /// *old* (v1-only) schema, then migrate forward and prove: (a) the column is
    /// added, and (b) the pre-existing row survives with a NULL archive — no data
    /// loss (repo rule: every schema change ships a seeded-old-store test).
    @Test func v2AddsBodyArchiveAndPreservesV1Rows() throws {
        let db = try DatabaseQueue()
        let migrator = SedimentDatabase.migrator()

        // Old store: only v1 applied — no `bodyArchive` column yet.
        try migrator.migrate(db, upTo: "v1_create_entities")
        let hasColumnBefore = try db.read { d in
            try d.columns(in: "journalEntries").contains { $0.name == "bodyArchive" }
        }
        #expect(hasColumnBefore == false)

        // Seed a v1-era row directly (the typed model has the newer column).
        let id = UUID().uuidString.lowercased()
        try db.write { d in
            try d.execute(
                sql: """
                    INSERT INTO "journalEntries" ("id","createdAt","updatedAt","body","isPrivate")
                    VALUES (?, '2024-01-01 00:00:00.000', '2024-01-01 00:00:00.000', ?, 1)
                    """,
                arguments: [id, "**old** entry"]
            )
        }

        // Migrate to the latest schema.
        try migrator.migrate(db)

        let (hasColumnAfter, body, archive) = try db.read { d -> (Bool, String?, Data?) in
            let hasColumn = try d.columns(in: "journalEntries").contains { $0.name == "bodyArchive" }
            let row = try Row.fetchOne(
                d, sql: #"SELECT "body", "bodyArchive" FROM "journalEntries" WHERE "id" = ?"#,
                arguments: [id]
            )
            return (hasColumn, row?["body"], row?["bodyArchive"])
        }
        #expect(hasColumnAfter)
        #expect(body == "**old** entry")  // old data intact
        #expect(archive == nil)           // new column defaults to NULL

        // And the typed model can now write/read the new column.
        let repo = Repository(database: db)
        let fresh = try repo.create(JournalEntry(body: "new", bodyArchive: Data([0x01, 0x02])))
        #expect(try repo.entry(id: fresh.id)?.bodyArchive == Data([0x01, 0x02]))
    }

    // MARK: Entry CRUD round-trip

    @Test func insertFetchUpdateDeleteEntry() throws {
        let repo = try Repository.inMemory()
        let entry = JournalEntry(body: "First light.", mood: DS.Mood.sky.rawValue)

        try repo.create(entry)
        #expect(try repo.entryCount() == 1)

        let fetched = try #require(try repo.entry(id: entry.id))
        #expect(fetched.body == "First light.")
        #expect(fetched.mood == DS.Mood.sky.rawValue)
        #expect(fetched.isPrivate == true) // private by default

        let updated = try repo.update({ var e = fetched; e.body = "Second light."; return e }())
        #expect(updated.updatedAt >= fetched.updatedAt)
        #expect(try repo.entry(id: entry.id)?.body == "Second light.")

        try repo.deleteEntry(id: entry.id)
        #expect(try repo.entry(id: entry.id) == nil)
        #expect(try repo.entryCount() == 0)
    }

    @Test func allEntriesAreNewestFirst() throws {
        let repo = try Repository.inMemory()
        let older = JournalEntry(createdAt: Date(timeIntervalSince1970: 1_000), body: "older")
        let newer = JournalEntry(createdAt: Date(timeIntervalSince1970: 2_000), body: "newer")
        try repo.create(older)
        try repo.create(newer)

        let all = try repo.allEntries()
        #expect(all.map(\.body) == ["newer", "older"])
    }

    // MARK: Media (filesystem references, cascade delete)

    @Test func mediaAttachesAndCascadeDeletesWithEntry() throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "trip"))
        let media = MediaAttachment(
            entryID: entry.id, type: .photo,
            relativePath: "photos/\(entry.id).jpg", utType: "public.jpeg", checksum: "abc123"
        )
        try repo.attach(media)
        #expect(try repo.media(forEntry: entry.id).count == 1)
        #expect(try repo.media(forEntry: entry.id).first?.kind == .photo)

        // Deleting the entry cascades to its media rows.
        try repo.deleteEntry(id: entry.id)
        #expect(try repo.media(forEntry: entry.id).isEmpty)
    }

    // MARK: Todos (standalone + SET NULL on entry delete)

    @Test func todoCrudAndCompletion() throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "plan"))
        let todo = try repo.create(Todo(entryID: entry.id, title: "Ship stage 2", dueDate: Date()))

        #expect(try repo.todos(forEntry: entry.id).count == 1)
        try repo.setTodoDone(id: todo.id, true)
        #expect(try repo.todos(forEntry: entry.id).first?.isDone == true)

        try repo.deleteTodo(id: todo.id)
        #expect(try repo.todos(forEntry: entry.id).isEmpty)
    }

    @Test func deletingEntryOrphansItsTodosViaSetNull() throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "plan"))
        let todo = try repo.create(Todo(entryID: entry.id, title: "standalone survivor"))

        try repo.deleteEntry(id: entry.id)
        // Todo survives (standalone todos are allowed); its entryID is nulled.
        let survived = try repo.database.read { db in try Todo.find(todo.id).fetchOne(db) }
        #expect(survived != nil)
        #expect(survived?.entryID == nil)
    }

    // MARK: Many-to-many tags

    @Test func tagsAreUniqueByNameAndLinkManyToMany() throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "tagged"))

        let work1 = try repo.findOrCreateTag(name: "work")
        let work2 = try repo.findOrCreateTag(name: "work") // dedupes by unique name
        #expect(work1.id == work2.id)
        let calm = try repo.findOrCreateTag(name: "calm")

        try repo.addTag(work1.id, toEntry: entry.id)
        try repo.addTag(work1.id, toEntry: entry.id) // idempotent, no duplicate link
        try repo.addTag(calm.id, toEntry: entry.id)

        let tags = try repo.tags(forEntry: entry.id)
        #expect(tags.map(\.name) == ["calm", "work"]) // ordered by name

        try repo.removeTag(calm.id, fromEntry: entry.id)
        #expect(try repo.tags(forEntry: entry.id).map(\.name) == ["work"])
    }

    @Test func deletingEntryRemovesTagLinksButKeepsTags() throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "x"))
        let tag = try repo.findOrCreateTag(name: "keep-me")
        try repo.addTag(tag.id, toEntry: entry.id)

        try repo.deleteEntry(id: entry.id)
        // The link is cascade-deleted; the tag itself persists for reuse.
        #expect(try repo.tags(forEntry: entry.id).isEmpty)
        let tagStillThere = try repo.database.read { db in try Tag.find(tag.id).fetchOne(db) }
        #expect(tagStillThere?.name == "keep-me")
    }

    // MARK: Embeddings (1:1 with entry)

    @Test func embeddingUpsertAndFetch() throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "vectorize me"))
        let vector = Data([0x00, 0x01, 0x02, 0x03])
        try repo.upsertEmbedding(Embedding(entryID: entry.id, vector: vector))

        let fetched = try #require(try repo.embedding(forEntry: entry.id))
        #expect(fetched.vector == vector)

        // Re-upsert replaces (ON CONFLICT REPLACE on the primary key).
        let vector2 = Data([0xFF])
        try repo.upsertEmbedding(Embedding(entryID: entry.id, vector: vector2))
        #expect(try repo.embedding(forEntry: entry.id)?.vector == vector2)
    }
}
