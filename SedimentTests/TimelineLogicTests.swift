import Testing
import Foundation
@testable import Sediment

/// Pure logic behind the Timeline: scope filtering, timestamp formatting, and
/// preview fallback. Deterministic — fixed `now`/calendar, no rendering.
@Suite struct TimelineLogicTests {
    private let cal = Calendar(identifier: .gregorian)
    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) } // fixed reference

    @Test func scopeAllAlwaysMatches() {
        let ancient = Date(timeIntervalSince1970: 0)
        #expect(TimelineScope.all.contains(ancient, now: now, calendar: cal))
    }

    @Test func scopeTodayMatchesSameDayOnly() {
        let sameDay = now.addingTimeInterval(3_600)
        let yesterday = now.addingTimeInterval(-24 * 3_600)
        #expect(TimelineScope.today.contains(sameDay, now: now, calendar: cal))
        #expect(!TimelineScope.today.contains(yesterday, now: now, calendar: cal))
    }

    @Test func scopeMonthMatchesWithinMonth() {
        let sameMonth = now.addingTimeInterval(5 * 24 * 3_600)
        let lastYear = now.addingTimeInterval(-400 * 24 * 3_600)
        #expect(TimelineScope.month.contains(sameMonth, now: now, calendar: cal))
        #expect(!TimelineScope.month.contains(lastYear, now: now, calendar: cal))
    }

    @Test func timestampLabelsTodayAndYesterday() {
        #expect(timelineTimestamp(now, now: now, calendar: cal) == "Today")
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        #expect(timelineTimestamp(yesterday, now: now, calendar: cal) == "Yesterday")
    }

    @Test func previewFallsBackForEmptyBody() {
        #expect(entryPreview("   \n  ") == "New entry")
        #expect(entryPreview("Real content") == "Real content")
    }

    @Test func allFourScopesArePresented() {
        #expect(TimelineScope.allCases.map(\.title) == ["All", "Today", "Week", "Month"])
    }
}
