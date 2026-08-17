import Foundation
import Observation

// MARK: - EntryComposerModel
//
// Drives one entry-composer session: holds the live `AttributedString` and
// autosaves it. The entry row already exists in the database (the timeline seeds
// it before opening the composer), so this model only *updates* — it never
// creates or deletes. Serialization goes through ``RichTextCodec`` and the write
// runs on GRDB's async writer, off the main thread.
//
// Autosave is debounced: rapid keystrokes coalesce into a single write after a
// quiet interval. `flush()` forces an immediate save (used on close/scene-away)
// and `saveNow()` is the underlying one-shot save that tests drive directly.
@MainActor
@Observable
public final class EntryComposerModel {

    /// The entry's rich text, bound to the editor. Mutating it schedules a save.
    public var text: AttributedString {
        didSet { scheduleSave() }
    }

    /// The entry's mood, bound to the mood picker. Persisted immediately on change
    /// (moods are discrete choices, not a stream of keystrokes, so they don't go
    /// through the text debounce).
    public var mood: DS.Mood? {
        didSet {
            guard mood != oldValue else { return }
            Task { await persistMood() }
        }
    }

    /// True while a write is in flight (drives a subtle "Saving…" affordance).
    public private(set) var isSaving = false
    /// Timestamp of the last successful save, or `nil` if nothing saved yet.
    public private(set) var lastSavedAt: Date?

    public let entryID: UUID

    /// The entry's media attachments (photos / video / files), loaded eagerly so
    /// the composer's attachment strip reflects the current row on open.
    public let media: EntryComposerMediaModel

    private let repository: Repository
    private let debounce: Duration
    private var pendingSave: Task<Void, Never>?

    public init(
        repository: Repository,
        entryID: UUID,
        initialText: AttributedString,
        initialMood: DS.Mood? = nil,
        mediaStore: MediaStore? = nil,
        debounce: Duration = .milliseconds(700)
    ) {
        self.repository = repository
        self.entryID = entryID
        self.text = initialText
        self.mood = initialMood
        self.media = EntryComposerMediaModel(repository: repository, entryID: entryID, store: mediaStore)
        self.debounce = debounce
    }

    /// Build a model for an existing entry, restoring its text from the lossless
    /// archive (falling back to the Markdown `body`).
    public convenience init(repository: Repository, entry: JournalEntry, debounce: Duration = .milliseconds(700)) {
        self.init(
            repository: repository,
            entryID: entry.id,
            initialText: RichTextCodec.load(archive: entry.bodyArchive, markdown: entry.body),
            initialMood: entry.mood.flatMap(DS.Mood.init(rawValue:)),
            debounce: debounce
        )
    }

    /// Persist the current mood immediately. Best-effort like autosave: a failure
    /// leaves the in-memory value and the next change retries.
    private func persistMood() async {
        do {
            try await repository.updateMood(entryID: entryID, mood: mood?.rawValue)
        } catch {
            // Swallowed on purpose — mood is re-persisted on the next change.
        }
    }

    // MARK: Saving

    /// (Re)start the debounce timer. Each edit cancels the previous pending save,
    /// so only a single write lands once typing pauses for `debounce`.
    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await saveNow()
        }
    }

    /// Cancel any pending debounce and write immediately, awaiting completion.
    /// Call before dismissing the composer so the last keystrokes are durable.
    public func flush() async {
        pendingSave?.cancel()
        pendingSave = nil
        await saveNow()
    }

    /// One-shot save: serialize the current text and persist both projections.
    public func saveNow() async {
        let snapshot = text
        let (markdown, archive) = RichTextCodec.serialize(snapshot)
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.updateBody(entryID: entryID, markdown: markdown, archive: archive)
            lastSavedAt = Date()
        } catch {
            // Autosave is best-effort; the in-memory text remains and the next
            // edit reschedules a save. Surfacing a blocking error here would break
            // the calm writing flow, so we intentionally swallow and retry-on-edit.
        }
    }
}
