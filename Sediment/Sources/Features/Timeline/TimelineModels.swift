import Foundation

/// A presentation-ready row for the timeline — decoupled from the DB record so
/// the view layer is deterministic and snapshot-testable.
public struct EntryRowModel: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let preview: String
    public let mood: DS.Mood?
    public let timestamp: String
    public let mediaCount: Int
    public let todoCount: Int

    public init(id: UUID, preview: String, mood: DS.Mood?, timestamp: String, mediaCount: Int, todoCount: Int) {
        self.id = id
        self.preview = preview
        self.mood = mood
        self.timestamp = timestamp
        self.mediaCount = mediaCount
        self.todoCount = todoCount
    }
}

/// Date-scope filter shown as the pill selector.
public enum TimelineScope: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case today = "Today"
    case week = "Week"
    case month = "Month"

    public var id: String { rawValue }
    public var title: String { rawValue }

    /// Whether `date` falls within this scope relative to `now`.
    public func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        }
    }
}

/// Format an entry's `createdAt` for the trailing timeline label.
public func timelineTimestamp(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
    if calendar.isDate(date, inSameDayAs: now) { return "Today" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
       calendar.isDate(date, inSameDayAs: yesterday) {
        return "Yesterday"
    }
    if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7, days >= 0 {
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
    return date.formatted(.dateTime.month(.abbreviated).day())
}

/// Build a preview string from an entry body, collapsing whitespace and falling
/// back to a calm placeholder for empty entries.
public func entryPreview(_ body: String) -> String {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "New entry" : trimmed
}
