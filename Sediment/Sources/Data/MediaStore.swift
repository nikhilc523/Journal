import Foundation

/// Filesystem home for media originals. The database stores only `relativePath`
/// references (never blobs); this type resolves those paths **safely**, enforcing
/// privacy invariant #4: a `relativePath` must never escape the media root via
/// traversal (`..`) or an absolute path.
public struct MediaStore: Sendable {
    public let root: URL

    public enum PathError: Error, Equatable {
        case absolutePath
        case traversalOutsideRoot
        case empty
    }

    /// The default media root under Application Support, created if needed.
    public init(fileManager: FileManager = .default) throws {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("Media", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        self.root = root.standardizedFileURL
    }

    /// Inject an explicit root (tests).
    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

    /// Resolve a stored `relativePath` to an absolute URL, rejecting anything that
    /// would leave the media root. Throws rather than returning an unsafe URL.
    public func resolve(_ relativePath: String) throws -> URL {
        guard !relativePath.isEmpty else { throw PathError.empty }
        guard !relativePath.hasPrefix("/") else { throw PathError.absolutePath }

        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL
        // `standardizedFileURL` resolves `..` segments; after that the path must
        // still be inside (or equal to) the root directory.
        let rootPath = root.path
        let candidatePath = candidate.path
        guard candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/") else {
            throw PathError.traversalOutsideRoot
        }
        return candidate
    }

    /// True if a `relativePath` is safe (no throw on `resolve`).
    public func isValid(_ relativePath: String) -> Bool {
        (try? resolve(relativePath)) != nil
    }
}
