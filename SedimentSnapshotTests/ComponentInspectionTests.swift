import SwiftUI
import ViewInspector
import Testing
@testable import Sediment

/// Deterministic view-tree / interaction tests for the design system. These run
/// on every simulator and OS (no reference images), so they are the always-on
/// safety net — especially for the Liquid Glass components that image snapshots
/// intentionally skip.
@MainActor
struct ComponentInspectionTests {

    // MARK: Glass chrome (image snapshots skip these)

    @Test func circularIconButtonFiresAction() throws {
        var tapped = false
        let sut = CircularIconButton(systemImage: "chevron.left", label: "Back") { tapped = true }
        try sut.inspect().implicitAnyView().find(ViewType.Button.self).tap()
        #expect(tapped)
    }

    @Test func floatingActionButtonFiresAction() throws {
        var tapped = false
        let sut = FloatingActionButton { tapped = true }
        try sut.inspect().implicitAnyView().find(ViewType.Button.self).tap()
        #expect(tapped)
    }

    @Test func segmentedTabBarHasAllTabsAndSwitches() throws {
        var selection: AppTab = .timeline
        let binding = Binding(get: { selection }, set: { selection = $0 })
        let sut = SegmentedTabBar(selection: binding)

        // All four destinations are present.
        for tab in AppTab.allCases {
            #expect(throws: Never.self) {
                try sut.inspect().implicitAnyView().find(text: tab.title)
            }
        }

        // Tapping the Search tab updates the binding.
        let searchButton = try sut.inspect().implicitAnyView().find(ViewType.Button.self) { view in
            (try? view.accessibilityIdentifier()) == "tab.Search"
        }
        try searchButton.tap()
        #expect(selection == .search)
    }

    // MARK: Selection / toggle logic

    @Test func pillFiresAction() throws {
        var tapped = false
        let sut = Pill("Today", isActive: false) { tapped = true }
        try sut.inspect().implicitAnyView().find(ViewType.Button.self).tap()
        #expect(tapped)
    }

    @Test func checkboxTogglesBinding() throws {
        var value = false
        let binding = Binding(get: { value }, set: { value = $0 })
        let sut = Checkbox(isOn: binding)
        try sut.inspect().implicitAnyView().find(ViewType.Button.self).tap()
        #expect(value == true)
    }

    // MARK: Content rendering

    @Test func entryCardShowsPreview() throws {
        let sut = EntryCard(preview: "A quiet morning.", mood: .sky, timestamp: "Tue")
        let text = try sut.inspect().implicitAnyView().find(text: "A quiet morning.").string()
        #expect(text == "A quiet morning.")
    }

    @Test func todoRowShowsTitle() throws {
        let sut = TodoRow(title: "Call mom", isDone: .constant(false), meta: "Today")
        #expect(throws: Never.self) {
            try sut.inspect().implicitAnyView().find(text: "Call mom")
        }
    }

    @Test func sectionLabelUppercases() throws {
        let sut = SectionLabel("Main menu")
        let text = try sut.inspect().implicitAnyView().find(ViewType.Text.self).string()
        #expect(text == "MAIN MENU")
    }
}
