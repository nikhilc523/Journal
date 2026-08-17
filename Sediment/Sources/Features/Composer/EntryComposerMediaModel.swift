import Foundation
import Observation
import UniformTypeIdentifiers

// MARK: - EntryComposerMediaModel
//
// Owns one entry's media attachments while the composer is open: the live list of
// `MediaAttachment` rows plus the import/remove operations that keep the database
// and the filesystem in step.
//
// The composer entry row already exists (the timeline seeds it), so this model
// only attaches/detaches media — never creates or deletes the entry. All copying,
// hashing, and database writes run **off the main thread** on a detached task; the
// `@Observable` list is mutated back on the main actor once the work lands, so the
// UI stays responsive during large video imports.
@MainActor
@Observable
public final class EntryComposerMediaModel {

    /// The entry's attachments, oldest first — bound to the composer's media strip.
    public private(set) var attachments: [MediaAttachment] = []

    /// True while an import is in flight (drives a progress affordance).
    public private(set) var isImporting = false

    public let entryID: UUID
    /// Media root, exposed so the viewer can resolve originals for playback.
    public let store: MediaStore

    private let repository: Repository
    private let importer: MediaImporter

    public init(repository: Repository, entryID: UUID, store: MediaStore? = nil) {
        self.repository = repository
        self.entryID = entryID
        let resolvedStore = store ?? Self.defaultStore()
        self.store = resolvedStore
        self.importer = MediaImporter(store: resolvedStore)
        reload()
    }

    /// The default on-disk media root, degrading to a temp directory only if
    /// Application Support is somehow unavailable (never force-unwrap file URLs).
    private static func defaultStore() -> MediaStore {
        if let store = try? MediaStore() { return store }
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent("SedimentMedia", isDirectory: true)
        return MediaStore(root: fallback)
    }

    /// Re-read the attachment rows for this entry from the database.
    public func reload() {
        attachments = (try? repository.media(forEntry: entryID)) ?? []
    }

    /// Resolve an attachment's on-disk original, or `nil` if the path is invalid or
    /// the file is missing (privacy invariant #4 is enforced by `store.resolve`).
    public func resolvedURL(for attachment: MediaAttachment) -> URL? {
        guard let url = try? store.resolve(attachment.relativePath),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    // MARK: Import

    /// Import already-loaded data (from a `PhotosPickerItem`) under a known type.
    public func addData(_ data: Data, utType: UTType) async {
        await runImport { importer, entryID, repository in
            guard let media = try? importer.importData(data, utType: utType, entryID: entryID) else { return [] }
            try? repository.attach(media)
            return [media]
        }
    }

    /// Import one or more files from the document picker.
    public func addFiles(_ urls: [URL]) async {
        await runImport { importer, entryID, repository in
            var imported: [MediaAttachment] = []
            for url in urls {
                guard let media = try? importer.importFile(at: url, entryID: entryID) else { continue }
                try? repository.attach(media)
                imported.append(media)
            }
            return imported
        }
    }

    /// Shared import scaffold: flips `isImporting`, runs the copy/hash/insert work
    /// off-main on a detached task, then appends the new rows on the main actor.
    private func runImport(
        _ work: @escaping @Sendable (MediaImporter, UUID, Repository) -> [MediaAttachment]
    ) async {
        isImporting = true
        defer { isImporting = false }
        let importer = self.importer
        let entryID = self.entryID
        let repository = self.repository
        let imported = await Task.detached(priority: .userInitiated) {
            work(importer, entryID, repository)
        }.value
        attachments.append(contentsOf: imported)
    }

    // MARK: Remove

    /// Detach a single attachment: delete the row and its filesystem original. Both
    /// run off-main; the in-memory list updates once removal completes.
    public func remove(_ attachment: MediaAttachment) async {
        let repository = self.repository
        let store = self.store
        await Task.detached(priority: .utility) {
            try? repository.deleteMedia(id: attachment.id)
            if let url = try? store.resolve(attachment.relativePath) {
                try? FileManager.default.removeItem(at: url)
            }
            await ThumbnailCache.shared.invalidate(attachment.id)
        }.value
        attachments.removeAll { $0.id == attachment.id }
    }
}
