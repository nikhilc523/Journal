import Foundation
import SQLiteData

// MARK: - Data model (Sediment)
//
// The five v1 entities from `docs/product/01-data-model.md`, defined as
// SQLiteData `@Table` records. Primary keys are globally-unique `UUID`s (stored
// as TEXT) so CloudKit sync never produces irreconcilable id collisions. Media
// binaries live on the filesystem — rows hold only `relativePath` + `utType` +
// `checksum` references, never blobs.
//
// PRIVACY NOTE (Stage 2): entry `body` is stored as plaintext Markdown for now.
// E2EE at rest (AES-GCM, Secure-Enclave key) is a dedicated later stage (see
// master-plan Stage 12); it will wrap `body` at the persistence boundary. No
// entry text leaves the device yet — there is no network path in this stage.

// MARK: JournalEntry

@Table("journalEntries")
public struct JournalEntry: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    /// Rich-text body projected to Markdown — the human-readable source used for
    /// timeline previews, search, and export. (Stage 12 encrypts this column.)
    public var body: String
    /// Lossless archive of the entry's `AttributedString` (JSON, SwiftUI attribute
    /// scope) — the fidelity source the composer reopens, preserving styling that
    /// Markdown can't carry (e.g. text color). `nil` for entries authored before
    /// Stage 4 or imported as plain Markdown; the composer falls back to parsing
    /// `body` in that case. (Stage 12 encrypts this column alongside `body`.)
    public var bodyArchive: Data?
    /// Raw value of `DS.Mood`; nil when the user hasn't set a mood.
    public var mood: Int?
    // Weather snapshot (Stage 8) — captured once at creation, never re-fetched.
    public var weatherTempC: Double?
    public var weatherCondition: String?
    public var weatherSymbol: String?
    // Location snapshot (Stage 8).
    public var latitude: Double?
    public var longitude: Double?
    public var placeName: String?
    /// Excluded from any future sharing / cloud-AI eligibility by default.
    public var isPrivate: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        body: String = "",
        bodyArchive: Data? = nil,
        mood: Int? = nil,
        weatherTempC: Double? = nil,
        weatherCondition: String? = nil,
        weatherSymbol: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        isPrivate: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.body = body
        self.bodyArchive = bodyArchive
        self.mood = mood
        self.weatherTempC = weatherTempC
        self.weatherCondition = weatherCondition
        self.weatherSymbol = weatherSymbol
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.isPrivate = isPrivate
    }
}

// MARK: MediaAttachment

public enum MediaKind: String, Codable, Sendable, CaseIterable {
    case photo, video, audio, file
}

@Table("mediaAttachments")
public struct MediaAttachment: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var entryID: UUID
    /// `MediaKind` raw value — stored as TEXT for stable, human-readable rows.
    public var type: String
    /// Path relative to the media root. Validated before use (no traversal).
    public var relativePath: String
    /// `UTType` identifier, e.g. "public.jpeg".
    public var utType: String
    /// Content hash for dedupe / integrity.
    public var checksum: String
    public var createdAt: Date
    public var transcript: String?  // on-device Speech (audio); encrypted in Stage 12
    public var ocrText: String?     // Vision OCR (photo/file); encrypted in Stage 12
    public var caption: String?     // optional on-device auto-caption

    public var kind: MediaKind? { MediaKind(rawValue: type) }

    public init(
        id: UUID = UUID(),
        entryID: UUID,
        type: MediaKind,
        relativePath: String,
        utType: String,
        checksum: String,
        createdAt: Date = Date(),
        transcript: String? = nil,
        ocrText: String? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.entryID = entryID
        self.type = type.rawValue
        self.relativePath = relativePath
        self.utType = utType
        self.checksum = checksum
        self.createdAt = createdAt
        self.transcript = transcript
        self.ocrText = ocrText
        self.caption = caption
    }
}

// MARK: Todo

@Table("todos")
public struct Todo: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    /// Nullable — todos may live inside an entry or stand alone.
    public var entryID: UUID?
    public var title: String
    public var dueDate: Date?
    public var isDone: Bool
    public var recurrenceRule: String?
    /// `UNNotificationRequest` identifier, to cancel on delete/complete.
    public var notificationID: String?
    /// Incomplete todos roll to the next day (no-penalty).
    public var rollsForward: Bool

    public init(
        id: UUID = UUID(),
        entryID: UUID? = nil,
        title: String,
        dueDate: Date? = nil,
        isDone: Bool = false,
        recurrenceRule: String? = nil,
        notificationID: String? = nil,
        rollsForward: Bool = false
    ) {
        self.id = id
        self.entryID = entryID
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.recurrenceRule = recurrenceRule
        self.notificationID = notificationID
        self.rollsForward = rollsForward
    }
}

// MARK: Tag + EntryTag (many-to-many)

@Table("tags")
public struct Tag: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// Join row linking an entry to a tag. Carries its own UUID primary key (so the
/// table is CloudKit-syncable) with a `UNIQUE(entryID, tagID)` constraint to
/// prevent duplicate links.
@Table("entryTags")
public struct EntryTag: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var entryID: UUID
    public var tagID: UUID

    public init(id: UUID = UUID(), entryID: UUID, tagID: UUID) {
        self.id = id
        self.entryID = entryID
        self.tagID = tagID
    }
}

// MARK: Embedding

/// On-device semantic-search vector for an entry (Stage 10). One per entry, so
/// `entryID` is the primary key. `vector` is a packed little-endian `[Float]`.
@Table("embeddings")
public struct Embedding: Codable, Identifiable, Sendable, Equatable {
    /// Primary key = the entry this embeds. Named `id` so the table is
    /// PrimaryKeyed (find/update/delete by key) and CloudKit-syncable.
    public var id: UUID
    public var vector: Data

    public var entryID: UUID { id }

    public init(entryID: UUID, vector: Data) {
        self.id = entryID
        self.vector = vector
    }
}
