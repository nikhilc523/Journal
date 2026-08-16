import SwiftUI
import SnapshotTesting
import ViewInspector
import Testing
@testable import Sediment

/// Stage 3 — the Timeline home screen. Image snapshots cover the deterministic
/// list region (empty / few / many, light+dark, XXL); ViewInspector covers the
/// full composition including the Liquid Glass chrome that image diffs skip.
@MainActor
struct TimelineSnapshotTests {

    private func list(_ entries: [EntryRowModel], height: CGFloat = 640) -> some View {
        TimelineList(entries: entries).frame(height: height)
    }

    // MARK: Image snapshots (list region)

    @Test func emptyState() {
        Snapshot.assertLightDark(list([]), named: "Timeline-empty")
    }

    @Test func fewEntries() {
        Snapshot.assertLightDark(list(Array(EntryRowModel.samples.prefix(2))), named: "Timeline-few")
    }

    @Test func manyEntries() {
        Snapshot.assertLightDark(list(EntryRowModel.samples), named: "Timeline-many")
    }

    @Test func manyEntriesExtraLarge() {
        Snapshot.assertLightDark(
            list(Array(EntryRowModel.samples.prefix(3)), height: 900),
            named: "Timeline-many-AX5",
            dynamicType: .accessibility5
        )
    }

    // MARK: Structure (ViewInspector, always-on)

    @Test func populatedTimelineShowsEntriesChromeAndFAB() throws {
        let sut = TimelineContent(
            entries: EntryRowModel.samples,
            scope: .constant(.all),
            tab: .constant(.timeline)
        )
        // First entry preview is rendered.
        #expect(throws: Never.self) {
            try sut.inspect().implicitAnyView()
                .find(text: "A quiet morning. Coffee, rain on the window, no agenda.")
        }
        // The create affordance (FAB) is present.
        #expect(throws: Never.self) {
            try sut.inspect().implicitAnyView().find(viewWithAccessibilityIdentifier: "fab.plus")
        }
        // The segmented tab bar's destinations are present.
        for title in ["Timeline", "Search", "Insights", "Settings"] {
            #expect(throws: Never.self) {
                try sut.inspect().implicitAnyView().find(text: title)
            }
        }
    }

    @Test func emptyTimelineShowsEmptyCopy() throws {
        let sut = TimelineContent(
            entries: [],
            scope: .constant(.all),
            tab: .constant(.timeline)
        )
        let text = try sut.inspect().implicitAnyView().find(text: "Nothing here yet").string()
        #expect(text == "Nothing here yet")
    }

    @Test func creatingAnEntryInvokesCallback() throws {
        var created = false
        let sut = TimelineContent(
            entries: [],
            scope: .constant(.all),
            tab: .constant(.timeline),
            onCreate: { created = true }
        )
        let fab = try sut.inspect().implicitAnyView()
            .find(viewWithAccessibilityIdentifier: "fab.plus")
        try fab.button().tap()
        #expect(created)
    }
}
