import Foundation
import SQLiteData

/// A thin repository over the SQLiteData tables. Views can use `@FetchAll` for
/// live-updating reads (Stage 3); this type provides the imperative CRUD and the
/// join queries used for writes and tests. All work runs on GRDB's own queue via
/// `read`/`write` — never the main thread.
public struct Repository: Sendable {
    public let database: any DatabaseWriter

    public init(database: any DatabaseWriter) {
        self.database = database
    }

    /// Build a repository over a fresh in-memory database (tests / previews).
    public static func inMemory() throws -> Repository {
        Repository(database: try SedimentDatabase.inMemory())
    }

    // MARK: Entries

    @discardableResult
    public func create(_ entry: JournalEntry) throws -> JournalEntry {
        try database.write { db in
            try JournalEntry.insert { entry }.execute(db)
        }
        return entry
    }

    public func entry(id: UUID) throws -> JournalEntry? {
        try database.read { db in
            try JournalEntry.find(id).fetchOne(db)
        }
    }

    /// All entries, newest first.
    public func allEntries() throws -> [JournalEntry] {
        try database.read { db in
            try JournalEntry.all.order { $0.createdAt.desc() }.fetchAll(db)
        }
    }

    public func entryCount() throws -> Int {
        try database.read { db in try JournalEntry.fetchCount(db) }
    }

    /// Update an entry, stamping `updatedAt`.
    @discardableResult
    public func update(_ entry: JournalEntry, now: Date = Date()) throws -> JournalEntry {
        var updated = entry
        updated.updatedAt = now
        try database.write { db in
            try JournalEntry.update(updated).execute(db)
        }
        return updated
    }

    /// Persist the composer's rich text: the Markdown projection (`body`) plus the
    /// lossless `bodyArchive`, stamping `updatedAt`. Runs on GRDB's async writer so
    /// autosave never blocks the main thread.
    public func updateBody(entryID: UUID, markdown: String, archive: Data?, now: Date = Date()) async throws {
        try await database.write { db in
            try JournalEntry
                .update {
                    $0.body = markdown
                    $0.bodyArchive = archive
                    $0.updatedAt = now
                }
                .where { $0.id.eq(entryID) }
                .execute(db)
        }
    }

    /// Persist the entry's mood (raw `DS.Mood` value, or `nil` to clear it),
    /// stamping `updatedAt`. Runs on GRDB's async writer (off the main thread).
    public func updateMood(entryID: UUID, mood: Int?, now: Date = Date()) async throws {
        try await database.write { db in
            try JournalEntry
                .update {
                    $0.mood = mood
                    $0.updatedAt = now
                }
                .where { $0.id.eq(entryID) }
                .execute(db)
        }
    }

    /// Delete an entry. `ON DELETE CASCADE` removes its media, embedding, and tag
    /// links; todos have their `entryID` set NULL (they may be standalone).
    public func deleteEntry(id: UUID) throws {
        try database.write { db in
            try JournalEntry.delete().where { $0.id.eq(id) }.execute(db)
        }
    }

    // MARK: Media

    @discardableResult
    public func attach(_ media: MediaAttachment) throws -> MediaAttachment {
        try database.write { db in
            try MediaAttachment.insert { media }.execute(db)
        }
        return media
    }

    public func media(forEntry entryID: UUID) throws -> [MediaAttachment] {
        try database.read { db in
            try MediaAttachment.all
                .where { $0.entryID.eq(entryID) }
                .order { $0.createdAt.asc() }
                .fetchAll(db)
        }
    }

    // MARK: Todos

    @discardableResult
    public func create(_ todo: Todo) throws -> Todo {
        try database.write { db in
            try Todo.insert { todo }.execute(db)
        }
        return todo
    }

    public func todos(forEntry entryID: UUID) throws -> [Todo] {
        try database.read { db in
            try Todo.all.where { $0.entryID.eq(entryID) }.fetchAll(db)
        }
    }

    public func setTodoDone(id: UUID, _ isDone: Bool) throws {
        try database.write { db in
            try Todo.update { $0.isDone = isDone }.where { $0.id.eq(id) }.execute(db)
        }
    }

    public func deleteTodo(id: UUID) throws {
        try database.write { db in
            try Todo.delete().where { $0.id.eq(id) }.execute(db)
        }
    }

    // MARK: Tags (many-to-many)

    /// Fetch a tag by name, creating it if absent (names are unique).
    @discardableResult
    public func findOrCreateTag(name: String) throws -> Tag {
        try database.write { db in
            if let existing = try Tag.all.where({ $0.name.eq(name) }).fetchOne(db) {
                return existing
            }
            let tag = Tag(name: name)
            try Tag.insert { tag }.execute(db)
            return tag
        }
    }

    /// Link a tag to an entry. Idempotent: skips the insert if the pair already
    /// exists (the `UNIQUE(entryID, tagID)` index would otherwise reject it).
    public func addTag(_ tagID: UUID, toEntry entryID: UUID) throws {
        try database.write { db in
            let existing = try EntryTag.all
                .where { $0.entryID.eq(entryID) && $0.tagID.eq(tagID) }
                .fetchOne(db)
            guard existing == nil else { return }
            try EntryTag.insert { EntryTag(entryID: entryID, tagID: tagID) }.execute(db)
        }
    }

    public func removeTag(_ tagID: UUID, fromEntry entryID: UUID) throws {
        try database.write { db in
            try EntryTag.delete()
                .where { $0.entryID.eq(entryID) && $0.tagID.eq(tagID) }
                .execute(db)
        }
    }

    /// All tags linked to an entry.
    public func tags(forEntry entryID: UUID) throws -> [Tag] {
        try database.read { db in
            let links = try EntryTag.all.where { $0.entryID.eq(entryID) }.fetchAll(db)
            let ids = links.map(\.tagID)
            guard !ids.isEmpty else { return [] }
            return try Tag.all.where { $0.id.in(ids) }.order { $0.name.asc() }.fetchAll(db)
        }
    }

    // MARK: Embeddings

    /// Insert or replace the entry's embedding (one per entry). Atomic: the
    /// `write` block is a transaction, so the delete + insert can't interleave.
    public func upsertEmbedding(_ embedding: Embedding) throws {
        try database.write { db in
            try Embedding.delete().where { $0.id.eq(embedding.id) }.execute(db)
            try Embedding.insert { embedding }.execute(db)
        }
    }

    public func embedding(forEntry entryID: UUID) throws -> Embedding? {
        try database.read { db in
            try Embedding.find(entryID).fetchOne(db)
        }
    }
}
