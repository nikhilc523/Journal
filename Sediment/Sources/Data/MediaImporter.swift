import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Copies imported originals (PhotosPicker data / document-picker files) into the
/// `MediaStore` filesystem home and produces the `MediaAttachment` row that
/// references them — `relativePath` + `utType` + SHA-256 `checksum`, never blobs.
///
/// All work here is pure filesystem + hashing (no UI, no database), so it runs
/// safely off the main thread and is unit-testable against a temp `MediaStore`
/// root. Every destination path is generated from UUIDs and re-validated through
/// `MediaStore.resolve`, so it can never escape the media root (invariant #4).
public struct MediaImporter: Sendable {
    public let store: MediaStore

    public init(store: MediaStore) {
        self.store = store
    }

    public enum ImportError: Error, Equatable {
        case unreadableSource
    }

    // MARK: Import

    /// Copy a security-scoped source file (from the document picker) into storage.
    /// The original bytes are preserved verbatim; the checksum is computed over the
    /// stored copy.
    public func importFile(at source: URL, entryID: UUID, id: UUID = UUID()) throws -> MediaAttachment {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let utType = resolvedType(for: source)
        let ext = source.pathExtension.isEmpty
            ? (utType.preferredFilenameExtension ?? "dat")
            : source.pathExtension
        let relativePath = Self.relativePath(entryID: entryID, id: id, ext: ext)
        let destination = try store.resolve(relativePath)

        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            throw ImportError.unreadableSource
        }

        let checksum = try Self.checksum(ofFileAt: destination)
        return MediaAttachment(
            id: id,
            entryID: entryID,
            type: Self.kind(for: utType),
            relativePath: relativePath,
            utType: utType.identifier,
            checksum: checksum
        )
    }

    /// Store raw data (from a `PhotosPickerItem`) into storage under the given type.
    public func importData(_ data: Data, utType: UTType, entryID: UUID, id: UUID = UUID()) throws -> MediaAttachment {
        let ext = utType.preferredFilenameExtension ?? "dat"
        let relativePath = Self.relativePath(entryID: entryID, id: id, ext: ext)
        let destination = try store.resolve(relativePath)

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)

        return MediaAttachment(
            id: id,
            entryID: entryID,
            type: Self.kind(for: utType),
            relativePath: relativePath,
            utType: utType.identifier,
            checksum: Self.checksum(of: data)
        )
    }

    // MARK: Path + type

    /// A per-entry, UUID-named relative path. UUIDs make collisions impossible and
    /// guarantee the path stays inside the media root (no user-controlled segments).
    static func relativePath(entryID: UUID, id: UUID, ext: String) -> String {
        "\(entryID.uuidString)/\(id.uuidString).\(ext.lowercased())"
    }

    private func resolvedType(for url: URL) -> UTType {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }
        return UTType(filenameExtension: url.pathExtension) ?? .data
    }

    /// Map a `UTType` onto our coarse `MediaKind` for row storage and UI routing.
    static func kind(for utType: UTType) -> MediaKind {
        if utType.conforms(to: .movie) || utType.conforms(to: .video) { return .video }
        if utType.conforms(to: .image) { return .photo }
        if utType.conforms(to: .audio) { return .audio }
        return .file
    }

    // MARK: Checksum (SHA-256, lowercase hex)

    public static func checksum(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Streaming checksum for files — hashes in 1 MiB chunks so large videos never
    /// load fully into memory.
    public static func checksum(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
