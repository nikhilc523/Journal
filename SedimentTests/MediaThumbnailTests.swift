import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Sediment

/// Stage 6 thumbnail-generation + media-model tests. Thumbnailing runs off the
/// main thread; here we prove the photo path decodes to a bounded bitmap and the
/// composer media model attaches/removes rows and their filesystem originals.
@Suite struct MediaThumbnailTests {

    /// Render a solid-color PNG to a temp file for deterministic decoding.
    private func writePNG(side: CGFloat) throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        let data = try #require(image.pngData())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    @Test func downsampledImageIsBoundedBySize() throws {
        let url = try writePNG(side: 400)
        defer { try? FileManager.default.removeItem(at: url) }

        let thumb = try #require(Thumbnailer.downsampledImage(at: url, maxPixel: 64))
        // The longest pixel edge must not exceed the requested cap.
        let longestPixelEdge = max(thumb.size.width, thumb.size.height) * thumb.scale
        #expect(longestPixelEdge <= 64)
    }

    @Test func downsamplingMissingFileReturnsNil() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).png")
        #expect(Thumbnailer.downsampledImage(at: missing, maxPixel: 64) == nil)
    }

    // MARK: Composer media model round-trip

    private func makeStore() throws -> MediaStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sediment-media-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return MediaStore(root: root)
    }

    @MainActor
    @Test func addingDataAttachesRowAndFileThenRemoveCleansUp() async throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "trip"))
        let store = try makeStore()
        let model = EntryComposerMediaModel(repository: repo, entryID: entry.id, store: store)

        #expect(model.attachments.isEmpty)

        await model.addData(Data([0xDE, 0xAD, 0xBE, 0xEF]), utType: .png)

        #expect(model.attachments.count == 1)
        #expect(try repo.media(forEntry: entry.id).count == 1)
        let attachment = try #require(model.attachments.first)
        let url = try #require(model.resolvedURL(for: attachment))
        #expect(FileManager.default.fileExists(atPath: url.path))

        await model.remove(attachment)

        #expect(model.attachments.isEmpty)
        #expect(try repo.media(forEntry: entry.id).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    @Test func reloadReflectsExistingRows() async throws {
        let repo = try Repository.inMemory()
        let entry = try repo.create(JournalEntry(body: "seeded"))
        try repo.attach(MediaAttachment(
            entryID: entry.id, type: .file,
            relativePath: "\(entry.id.uuidString)/x.dat", utType: "public.data", checksum: "abc"
        ))

        let model = EntryComposerMediaModel(repository: repo, entryID: entry.id, store: try makeStore())
        // Eager load in init already picked up the seeded row.
        #expect(model.attachments.count == 1)
    }
}
