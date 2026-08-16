import Testing
import Foundation
@testable import Sediment

/// Privacy invariant #4: a stored `relativePath` must never resolve outside the
/// media root (no traversal, no absolute paths, no sandbox escape).
@Suite struct MediaStoreTests {
    private let store = MediaStore(root: URL(fileURLWithPath: "/tmp/sediment-media-root", isDirectory: true))

    @Test func resolvesSafeRelativePaths() throws {
        let url = try store.resolve("photos/2026/pic.jpg")
        #expect(url.path.hasPrefix("/tmp/sediment-media-root/"))
        #expect(store.isValid("audio/note.m4a"))
    }

    @Test func rejectsTraversal() {
        #expect(!store.isValid("../secrets.txt"))
        #expect(!store.isValid("photos/../../etc/passwd"))
        #expect(throws: MediaStore.PathError.traversalOutsideRoot) {
            try store.resolve("../../../../etc/passwd")
        }
    }

    @Test func rejectsAbsolutePaths() {
        #expect(!store.isValid("/etc/passwd"))
        #expect(throws: MediaStore.PathError.absolutePath) {
            try store.resolve("/var/mobile/Containers/other.app/data")
        }
    }

    @Test func rejectsEmptyPath() {
        #expect(throws: MediaStore.PathError.empty) {
            try store.resolve("")
        }
    }

    @Test func nestedTraversalThatStaysInsideIsAllowed() throws {
        // `a/b/../c` normalizes to `a/c`, still inside the root — allowed.
        let url = try store.resolve("a/b/../c/file.png")
        #expect(url.path.hasPrefix("/tmp/sediment-media-root/"))
        #expect(url.lastPathComponent == "file.png")
    }
}
