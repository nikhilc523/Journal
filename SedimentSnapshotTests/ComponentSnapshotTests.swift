import SwiftUI
import SnapshotTesting
import Testing
@testable import Sediment

/// Image-diff snapshots for the deterministic (non-glass) design-system
/// components, in light + dark. Gated to the canonical runtime by `Snapshot`.
/// Glass components (icon button, FAB, tab bar) are covered structurally in
/// `ComponentInspectionTests` because Liquid Glass is not pixel-deterministic.
@MainActor
struct ComponentSnapshotTests {
    private func padded(_ view: some View) -> some View {
        view.padding(DS.Spacing.screenInset)
    }

    @Test func card() {
        Snapshot.assertLightDark(
            padded(VStack(spacing: DS.Spacing.cardGap) {
                Card { Text("A frosted card").font(DS.Typography.headline).foregroundStyle(DS.Colors.ink) }
                Card(fill: DS.Mood.sage.wash) {
                    Text("Mood-washed card").font(DS.Typography.headline).foregroundStyle(DS.Colors.ink)
                }
            }),
            named: "Card"
        )
    }

    @Test func checkbox() {
        Snapshot.assertLightDark(
            padded(HStack(spacing: DS.Spacing.xl) {
                Checkbox(isOn: .constant(false))
                Checkbox(isOn: .constant(true))
            }),
            named: "Checkbox"
        )
    }

    @Test func moodFaces() {
        Snapshot.assertLightDark(
            padded(HStack(spacing: DS.Spacing.sm) {
                ForEach(DS.Mood.allCases) { MoodFace($0, size: 44) }
            }),
            named: "MoodFace"
        )
    }

    @Test func sectionLabel() {
        Snapshot.assertLightDark(
            padded(SectionLabel("Main menu")),
            named: "SectionLabel"
        )
    }

    @Test func attachmentChips() {
        Snapshot.assertLightDark(
            padded(HStack(spacing: DS.Spacing.sm) {
                AttachmentChip(.photo, title: "3")
                AttachmentChip(.audio, title: "0:42")
                AttachmentChip(.file, title: "report.pdf")
            }),
            named: "AttachmentChip"
        )
    }

    @Test func pill() {
        Snapshot.assertLightDark(
            padded(HStack(spacing: DS.Spacing.sm) {
                Pill("Today", isActive: true) {}
                Pill("Tue", isActive: false) {}
            }),
            named: "Pill"
        )
    }

    @Test func todoRow() {
        Snapshot.assertLightDark(
            padded(VStack(spacing: DS.Spacing.cardGap) {
                TodoRow(title: "Identify 3 core strengths and write them down.", isDone: .constant(false), meta: "Today")
                TodoRow(title: "Draft a \"Value Proposition\".", isDone: .constant(true), meta: "Today")
                TodoRow(title: "Overdue task example", isDone: .constant(false), meta: "Mon", isOverdue: true)
            }),
            named: "TodoRow"
        )
    }

    @Test func entryCard() {
        Snapshot.assertLightDark(
            padded(VStack(spacing: DS.Spacing.cardGap) {
                EntryCard(preview: "Launched the side hustle today. Felt the fear and did it anyway.",
                          mood: .amber, timestamp: "Today", mediaCount: 2, todoCount: 3)
                EntryCard(preview: "A quiet morning. Coffee, rain on the window, no agenda.",
                          mood: .sky, timestamp: "Tue")
                EntryCard(preview: "Plain note without a mood.", timestamp: "Mon")
            }),
            named: "EntryCard"
        )
    }

    // Dynamic Type stress — the layout must survive the largest accessibility size.
    @Test func todoRowExtraLarge() {
        Snapshot.assertLightDark(
            padded(TodoRow(title: "Identify 3 core strengths and write them down.",
                           isDone: .constant(false), meta: "Today")),
            named: "TodoRow-AX5",
            dynamicType: .accessibility5
        )
    }

    @Test func entryCardExtraLarge() {
        Snapshot.assertLightDark(
            padded(EntryCard(preview: "A quiet morning. Coffee, rain on the window, no agenda.",
                             mood: .sky, timestamp: "Tue", mediaCount: 1, todoCount: 2)),
            named: "EntryCard-AX5",
            dynamicType: .accessibility5
        )
    }
}
