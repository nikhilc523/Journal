import SwiftUI

/// The scrollable body of the timeline — either the entry stack or a calm empty
/// state. Extracted as its own view so it can be snapshot-tested deterministically
/// (no Liquid Glass, no live database).
public struct TimelineList: View {
    private let entries: [EntryRowModel]
    private let onOpen: (UUID) -> Void

    public init(entries: [EntryRowModel], onOpen: @escaping (UUID) -> Void = { _ in }) {
        self.entries = entries
        self.onOpen = onOpen
    }

    public var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.cardGap) {
                    ForEach(entries) { entry in
                        EntryCard(
                            preview: entry.preview,
                            mood: entry.mood,
                            timestamp: entry.timestamp,
                            mediaCount: entry.mediaCount,
                            todoCount: entry.todoCount,
                            action: { onOpen(entry.id) }
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.screenInset)
                .padding(.top, DS.Spacing.sm)
                // Leave room for the floating tab bar + FAB.
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("timeline.list")
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DS.Colors.inkTertiary)
                .accessibilityHidden(true)
            Text("Nothing here yet")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.ink)
            Text("Tap + to begin today's page.")
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Colors.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(DS.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timeline.empty")
    }
}

/// The full Timeline home screen — the oatmeal re-skin of `UI_Interface/primary.jpg`.
/// Purely presentational: state and callbacks are injected so it snapshots and
/// unit-tests without a database.
public struct TimelineContent: View {
    private let entries: [EntryRowModel]
    @Binding private var scope: TimelineScope
    @Binding private var tab: AppTab
    private let onOpen: (UUID) -> Void
    private let onCreate: () -> Void
    private let onMenu: () -> Void

    public init(
        entries: [EntryRowModel],
        scope: Binding<TimelineScope>,
        tab: Binding<AppTab>,
        onOpen: @escaping (UUID) -> Void = { _ in },
        onCreate: @escaping () -> Void = {},
        onMenu: @escaping () -> Void = {}
    ) {
        self.entries = entries
        self._scope = scope
        self._tab = tab
        self.onOpen = onOpen
        self.onCreate = onCreate
        self.onMenu = onMenu
    }

    public var body: some View {
        ZStack {
            GradientCanvas()

            VStack(spacing: DS.Spacing.lg) {
                header
                PillSelector(
                    items: TimelineScope.allCases,
                    selection: $scope,
                    title: \.title
                )
                TimelineList(entries: entries, onOpen: onOpen)
            }
            .padding(.top, DS.Spacing.sm)

            // Floating chrome over the sand canvas.
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: DS.Spacing.md) {
                    SegmentedTabBar(selection: $tab)
                    FloatingActionButton(action: onCreate)
                }
                .padding(.horizontal, DS.Spacing.screenInset)
                .padding(.bottom, DS.Spacing.sm)
            }
        }
        .accessibilityIdentifier("timeline.root")
    }

    private var header: some View {
        HStack {
            Text("Today")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.ink)
            Spacer()
            CircularIconButton(systemImage: "calendar", label: "Calendar", action: onMenu)
        }
        .padding(.horizontal, DS.Spacing.screenInset)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Populated") {
    struct Demo: View {
        @State var scope: TimelineScope = .all
        @State var tab: AppTab = .timeline
        var body: some View {
            TimelineContent(entries: EntryRowModel.samples, scope: $scope, tab: $tab)
        }
    }
    return Demo()
}

#Preview("Empty") {
    struct Demo: View {
        @State var scope: TimelineScope = .all
        @State var tab: AppTab = .timeline
        var body: some View {
            TimelineContent(entries: [], scope: $scope, tab: $tab)
        }
    }
    return Demo()
}

// MARK: - Sample data (previews + snapshots)

public extension EntryRowModel {
    static let samples: [EntryRowModel] = [
        EntryRowModel(id: UUID(0), preview: "Launched the side hustle today. Felt the fear and did it anyway.",
                      mood: .amber, timestamp: "Today", mediaCount: 2, todoCount: 3),
        EntryRowModel(id: UUID(1), preview: "A quiet morning. Coffee, rain on the window, no agenda.",
                      mood: .sky, timestamp: "Today", mediaCount: 1, todoCount: 0),
        EntryRowModel(id: UUID(2), preview: "Long walk to clear my head. The park was gold.",
                      mood: .sage, timestamp: "Yesterday", mediaCount: 0, todoCount: 1),
        EntryRowModel(id: UUID(3), preview: "Reflecting on the week — slower, kinder to myself.",
                      mood: .lavender, timestamp: "Mon", mediaCount: 0, todoCount: 0),
        EntryRowModel(id: UUID(4), preview: "Plain note without a mood.",
                      mood: nil, timestamp: "Sun", mediaCount: 0, todoCount: 0),
        EntryRowModel(id: UUID(5), preview: "Dreamed up a new project. Sketches everywhere.",
                      mood: .lilac, timestamp: "Sat", mediaCount: 4, todoCount: 2),
    ]
}

private extension UUID {
    /// Deterministic UUID for stable snapshots/previews (falls back safely).
    init(_ n: Int) {
        let hex = String(format: "%032X", n)
        let string = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.suffix(12))"
        self = UUID(uuidString: string) ?? UUID()
    }
}
