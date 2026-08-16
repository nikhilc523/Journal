import SwiftUI

/// A frosted rounded card — the base surface for entries, todos, and grouped
/// content. Cards use frosted `surface` + soft card shadow (not full glass) so
/// text stays legible over the sand canvas.
public struct Card<Content: View>: View {
    private let fill: Color
    private let padding: CGFloat
    private let content: Content

    /// - Parameters:
    ///   - fill: Background fill. Defaults to `surface`; pass a mood `wash` to
    ///     tint the card by mood.
    ///   - padding: Inner padding. Defaults to the card padding token.
    public init(
        fill: Color = DS.Colors.surface,
        padding: CGFloat = DS.Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Colors.hairline, lineWidth: 0.5)
            }
            .dsShadow(.card)
    }
}

#Preview {
    GradientCanvas {
        VStack(spacing: DS.Spacing.cardGap) {
            Card { Text("A frosted card").font(DS.Typography.headline).foregroundStyle(DS.Colors.ink) }
            Card(fill: DS.Mood.sage.wash) { Text("Mood-washed card").font(DS.Typography.headline).foregroundStyle(DS.Colors.ink) }
        }
        .padding(DS.Spacing.screenInset)
    }
}
