import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Sediment

/// Stage 6 media-storage tests: copying originals into `MediaStore`, computing
/// SHA-256 checksums, mapping `UTType` → `MediaKind`, and keeping every generated
/// path inside the media root (privacy invariant #4).
@Suite struct MediaImporterTests {

    /// A fresh, isolated media root per call (created on disk, torn down by the OS
    /// temp reaper). Deterministic and never touches the real Application Support.
    private func makeImporter() throws -> MediaImporter {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sediment-media-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return MediaImporter(store: MediaStore(root: root))
    }

    // MARK: Checksum

    @Test func checksumMatchesKnownSHA256Vectors() {
        // RFC-style known-answer vectors for SHA-256.
        #expect(MediaImporter.checksum(of: Data()) ==
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(MediaImporter.checksum(of: Data("abc".utf8)) ==
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func fileChecksumEqualsDataChecksum() throws {
        let bytes = Data("streamed content across chunks".utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).bin")
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try MediaImporter.checksum(ofFileAt: url) == MediaImporter.checksum(of: bytes))
    }

    // MARK: Kind inference

    @Test func kindInferenceMapsUTTypes() {
        #expect(MediaImporter.kind(for: .jpeg) == .photo)
        #expect(MediaImporter.kind(for: .png) == .photo)
        #expect(MediaImporter.kind(for: .mpeg4Movie) == .video)
        #expect(MediaImporter.kind(for: .quickTimeMovie) == .video)
        #expect(MediaImporter.kind(for: .mp3) == .audio)
        #expect(MediaImporter.kind(for: .pdf) == .file)
        #expect(MediaImporter.kind(for: .plainText) == .file)
    }

    // MARK: Import data (PhotosPicker path)

    @Test func importDataStoresBytesInsideRootWithCorrectRow() throws {
        let importer = try makeImporter()
        let entryID = UUID()
        let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05])

        let media = try importer.importData(bytes, utType: .jpeg, entryID: entryID)

        #expect(media.entryID == entryID)
        #expect(media.kind == .photo)
        #expect(media.utType == UTType.jpeg.identifier)
        #expect(media.checksum == MediaImporter.checksum(of: bytes))

        // Path is safe (resolves without throwing) and the bytes round-trip.
        #expect(importer.store.isValid(media.relativePath))
        let resolved = try importer.store.resolve(media.relativePath)
        #expect(resolved.path.hasPrefix(importer.store.root.path + "/"))
        #expect(try Data(contentsOf: resolved) == bytes)
    }

    // MARK: Import file (document-picker path)

    @Test func importFileCopiesOriginalAndPreservesBytes() throws {
        let importer = try makeImporter()
        let entryID = UUID()
        let contents = Data("a small text document".utf8)
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("note-\(UUID().uuidString).txt")
        try contents.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let media = try importer.importFile(at: source, entryID: entryID)

        #expect(media.kind == .file)
        #expect(media.relativePath.hasSuffix(".txt"))
        #expect(media.checksum == MediaImporter.checksum(of: contents))

        let resolved = try importer.store.resolve(media.relativePath)
        #expect(try Data(contentsOf: resolved) == contents)
        // The original is copied, not moved — the source still exists.
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func importedPathIsScopedToEntry() throws {
        let importer = try makeImporter()
        let entryID = UUID()
        let media = try importer.importData(Data([0xFF]), utType: .png, entryID: entryID)
        // Rows are foldered per entry so an entry's media is easy to locate/purge.
        #expect(media.relativePath.hasPrefix("\(entryID.uuidString)/"))
    }
}
