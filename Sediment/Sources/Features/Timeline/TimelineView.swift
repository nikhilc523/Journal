import SwiftUI
import SQLiteData

/// The live Timeline screen: binds the presentational ``TimelineContent`` to the
/// database via `@FetchAll` (auto-updating reads) and handles entry creation.
public struct TimelineView: View {
    @Binding private var tab: AppTab
    @State private var scope: TimelineScope = .all

    @FetchAll(JournalEntry.all.order { $0.createdAt.desc() })
    private var entries: [JournalEntry]
    @FetchAll(Todo.all) private var todos: [Todo]
    @FetchAll(MediaAttachment.all) private var media: [MediaAttachment]

    @Dependency(\.defaultDatabase) private var database

    public init(tab: Binding<AppTab>) {
        self._tab = tab
    }

    public var body: some View {
        TimelineContent(
            entries: rows,
            scope: $scope,
            tab: $tab,
            onOpen: { _ in /* entry detail arrives in Stage 4 */ },
            onCreate: createEntry,
            onMenu: { /* calendar browse arrives in Stage 10 */ }
        )
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

    private func createEntry() {
        // Stage 4 opens the composer; for now, seed a fresh page so the create
        // affordance is real and the new entry appears at the top of the timeline.
        // The write runs off the main thread (GRDB's async writer); `@FetchAll`
        // delivers the update back on the main actor.
        let database = database
        Task {
            try? await database.write { db in
                try JournalEntry.insert { JournalEntry() }.execute(db)
            }
        }
    }
}
