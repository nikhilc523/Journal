import SwiftUI

/// A timeline entry card. Tinted with the entry's mood `wash` (or plain
/// `surface` if no mood), showing a 2-line preview, media/todo indicators, and a
/// trailing timestamp. The whole card is one tap target that opens the entry.
public struct EntryCard: View {
    private let preview: String
    private let mood: DS.Mood?
    private let timestamp: String
    private let mediaCount: Int
    private let todoCount: Int
    private let action: () -> Void

    public init(
        preview: String,
        mood: DS.Mood? = nil,
        timestamp: String,
        mediaCount: Int = 0,
        todoCount: Int = 0,
        action: @escaping () -> Void = {}
    ) {
        self.preview = preview
        self.mood = mood
        self.timestamp = timestamp
        self.mediaCount = mediaCount
        self.todoCount = todoCount
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Card(fill: mood?.wash ?? DS.Colors.surface) {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    if let mood {
                        MoodFace(mood, size: 36)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(preview)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if mediaCount > 0 || todoCount > 0 {
                            HStack(spacing: DS.Spacing.sm) {
                                if mediaCount > 0 {
                                    AttachmentChip(.photo, title: "\(mediaCount)")
                                }
                                if todoCount > 0 {
                                    Label("\(todoCount)", systemImage: "checklist")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.inkSecondary)
                                        .labelStyle(.titleAndIcon)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(timestamp)
                        .font(DS.Typography.meta)
                        .foregroundStyle(DS.Colors.inkSecondary)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("entryCard")
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let mood { parts.append("\(mood.label) mood") }
        parts.append(preview)
        if mediaCount > 0 { parts.append("\(mediaCount) attachments") }
        if todoCount > 0 { parts.append("\(todoCount) todos") }
        parts.append(timestamp)
        return parts.joined(separator: ", ")
    }
}

#Preview {
    GradientCanvas {
        VStack(spacing: DS.Spacing.cardGap) {
            EntryCard(preview: "Launched the side hustle today. Felt the fear and did it anyway.",
                      mood: .amber, timestamp: "Today", mediaCount: 2, todoCount: 3)
            EntryCard(preview: "A quiet morning. Coffee, rain on the window, no agenda.",
                      mood: .sky, timestamp: "Tue")
            EntryCard(preview: "Plain note without a mood.", timestamp: "Mon")
        }
        .padding(DS.Spacing.screenInset)
    }
}
