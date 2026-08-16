import Testing
import Foundation
@testable import Sediment

/// Stage 4 autosave tests. The composer model must persist edits (both Markdown
/// projection and lossless archive) without the caller having to manage saves.
@MainActor
@Suite struct EntryComposerModelTests {

    @Test func saveNowPersistsMarkdownAndArchive() async throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry())
        let model = EntryComposerModel(repository: repo, entry: entry)

        var text = AttributedString("Felt the ")
        var bold = AttributedString("fear")
        bold.inlinePresentationIntent = .stronglyEmphasized
        text.append(bold)
        model.text = text
        await model.saveNow()

        let saved = try #require(try repo.entry(id: entry.id))
        #expect(saved.body == "Felt the **fear**")
        #expect(saved.bodyArchive != nil)
        // The archive restores the exact styled text the editor held.
        #expect(RichTextCodec.load(archive: saved.bodyArchive, markdown: saved.body) == text)
        #expect(model.lastSavedAt != nil)
    }

    @Test func editingExistingEntryUpdatesBodyAndTimestamp() async throws {
        let repo = try Repository.inMemory()
        let created = try repo.create(
            JournalEntry(updatedAt: Date(timeIntervalSince1970: 0), body: "old thoughts")
        )
        let loaded = try #require(try repo.entry(id: created.id))
        // Restores from the existing row.
        let model = EntryComposerModel(repository: repo, entry: loaded)
        #expect(String(model.text.characters) == "old thoughts")

        model.text = AttributedString("new thoughts")
        await model.saveNow()

        let saved = try #require(try repo.entry(id: created.id))
        #expect(saved.body == "new thoughts")
        #expect(saved.updatedAt > loaded.updatedAt)
    }

    @Test func debouncedEditsCoalesceAndFlush() async throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry())
        let model = EntryComposerModel(repository: repo, entry: entry, debounce: .milliseconds(10))

        // Two rapid edits; only the latest should survive after a flush.
        model.text = AttributedString("draft one")
        model.text = AttributedString("draft two")
        await model.flush()

        #expect(try repo.entry(id: entry.id)?.body == "draft two")
    }

    @Test func emptyEntrySavesEmptyBody() async throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "seed"))
        let model = EntryComposerModel(repository: repo, entryID: entry.id, initialText: AttributedString(""))

        await model.saveNow()

        #expect(try repo.entry(id: entry.id)?.body == "")
    }
}
