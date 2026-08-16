import SwiftUI

/// The `primary.jpg` checkbox card row, reused verbatim for in-entry todos:
/// leading circular `Checkbox`, up-to-2-line title, trailing meta ("Today").
/// Completed todos strike through and fade. Overdue meta turns `warning`.
public struct TodoRow: View {
    private let title: String
    @Binding private var isDone: Bool
    private let meta: String?
    private let isOverdue: Bool

    public init(
        title: String,
        isDone: Binding<Bool>,
        meta: String? = nil,
        isOverdue: Bool = false
    ) {
        self.title = title
        self._isDone = isDone
        self.meta = meta
        self.isOverdue = isOverdue
    }

    public var body: some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Checkbox(isOn: $isDone, label: title)

                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(isDone ? DS.Colors.inkTertiary : DS.Colors.ink)
                    .strikethrough(isDone, color: DS.Colors.inkTertiary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10) // optical centering against the 44pt checkbox

                if let meta {
                    Text(meta)
                        .font(DS.Typography.meta)
                        .foregroundStyle(isOverdue ? DS.Colors.warning : DS.Colors.inkSecondary)
                        .padding(.top, 12)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("todoRow")
    }
}

#Preview {
    struct Demo: View {
        @State var a = false
        @State var b = true
        var body: some View {
            GradientCanvas {
                VStack(spacing: DS.Spacing.cardGap) {
                    TodoRow(title: "Identify 3 core strengths and write them down.", isDone: $a, meta: "Today")
                    TodoRow(title: "Draft a \"Value Proposition\" (How you help people).", isDone: $b, meta: "Today")
                    TodoRow(title: "Overdue task example", isDone: .constant(false), meta: "Mon", isOverdue: true)
                }
                .padding(DS.Spacing.screenInset)
            }
        }
    }
    return Demo()
}
