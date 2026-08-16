import Testing
import ViewInspector
import SnapshotTesting
@testable import Journal

/// Stage 0 view-tree tests — prove the snapshot target links both
/// `SnapshotTesting` and `ViewInspector` and can inspect app views.
///
/// We deliberately do NOT call `assertSnapshot` yet: there is no design system
/// to pin (that is Stage 1), and recording reference PNGs here would fail the
/// first CI run. Stage 1 adds real image-diff snapshots per component. For now
/// we assert the render tree with ViewInspector, which is deterministic and
/// needs no reference image.
struct RootViewInspectionTests {
    @Test @MainActor func rootViewShowsTitle() throws {
        let sut = RootView()
        let title = try sut.inspect().implicitAnyView().find(text: "Journal").string()
        #expect(title == "Journal")
    }

    @Test @MainActor func rootViewShowsScaffoldStatus() throws {
        let sut = RootView()
        #expect(throws: Never.self) {
            try sut.inspect().implicitAnyView().find(text: "Scaffold ready")
        }
    }
}
