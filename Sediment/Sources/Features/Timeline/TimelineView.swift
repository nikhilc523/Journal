import SwiftUI
import SQLiteData

/// The live Timeline screen: binds the presentational ``TimelineContent`` to the
/// database via `@FetchAll` (auto-updating reads), handles entry creation, and
/// hosts the entry composer as a hero-transitioned overlay.
public struct TimelineView: View {
    @Binding private var tab: AppTab
    @State private var scope: TimelineScope = .all

    /// The active composer session, or `nil` when the timeline is at rest.
    /// Presence drives both the overlay and which card hands off its geometry.
    @State private var composer: EntryComposerModel?
    @Namespace private var hero

    @FetchAll(JournalEntry.all.order { $0.createdAt.desc() })
    private var entries: [JournalEntry]
    @FetchAll(Todo.all) private var todos: [Todo]
    @FetchAll(MediaAttachment.all) private var media: [MediaAttachment]

    @Dependency(\.defaultDatabase) private var database

    public init(tab: Binding<AppTab>) {
        self._tab = tab
    }

    public var body: some View {
        ZStack {
            TimelineContent(
                entries: rows,
                scope: $scope,
                tab: $tab,
                onOpen: openEntry,
                onCreate: createEntry,
                onMenu: { /* calendar browse arrives in Stage 10 */ },
                heroNamespace: hero,
                activeHeroID: composer?.entryID
            )

            if let composer {
                EntryComposerView(
                    model: composer,
                    title: composerTitle(for: composer.entryID),
                    onClose: closeComposer
                )
                .heroMatched(id: composer.entryID, in: hero)
                .zIndex(1)
            }
        }
        .animation(DS.Motion.transition, value: composer?.entryID)
    }

    private var rows: [EntryRowModel] {
        entries
            .filter { scope.contains($0.createdAt) }
            .map { entry in
                EntryRowModel(
                    id: entry.id,
                    preview: entryPreview(entry.body),
                    mood: entry.mood.flatMap(DS.Mood.init(rawValue:)),
                    timestamp: timelineTimestamp(entry.createdAt),
                    mediaCount: media.filter { $0.entryID == entry.id }.count,
                    todoCount: todos.filter { $0.entryID == entry.id }.count
                )
            }
    }

    // MARK: Composer lifecycle

    /// Open the composer for an existing entry, restoring its rich text.
    private func openEntry(_ id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        composer = EntryComposerModel(repository: Repository(database: database), entry: entry)
    }

    /// Seed a fresh entry row, then open the composer on it. The write runs on
    /// GRDB's async writer (off main); `@FetchAll` delivers the update, and the
    /// composer autosaves subsequent edits into the same row.
    private func createEntry() {
        let repository = Repository(database: database)
        let entry = JournalEntry()
        Task {
            try? await repository.database.write { db in
                try JournalEntry.insert { entry }.execute(db)
            }
            composer = EntryComposerModel(repository: repository, entry: entry)
        }
    }

    /// Flush the last keystrokes, then dismiss the composer (hero shrinks back).
    private func closeComposer() {
        guard let model = composer else { return }
        Task {
            await model.flush()
            composer = nil
        }
    }

    private func composerTitle(for id: UUID) -> String {
        guard let entry = entries.first(where: { $0.id == id }) else { return "Today" }
        return timelineTimestamp(entry.createdAt)
    }
}

// MARK: - Hero geometry helper

public extension View {
    /// Apply a `matchedGeometryEffect` for the card↔composer hero, but only when a
    /// namespace is supplied. Presentational previews/snapshots pass `nil` and are
    /// unaffected.
    @ViewBuilder
    func heroMatched(id: UUID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}
