import SwiftUI

// MARK: - MoodPickerView
//
// Freddy is the mood picker. Selecting a mood tints him with that mood's pastel
// and plays its animation; he's the single expressive surface, with a row of
// pastel chips beneath to choose. Tapping the active mood again clears it.
//
// Motion is gated by Reduce Motion; selection fires `.sensoryFeedback(.selection)`.
public struct MoodPickerView: View {
    @Binding private var mood: DS.Mood?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let heroSize: CGFloat

    public init(mood: Binding<DS.Mood?>, heroSize: CGFloat = 150) {
        self._mood = mood
        self.heroSize = heroSize
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            hero
            chips
        }
        .sensoryFeedback(.selection, trigger: mood)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("moodPicker.root")
    }

    // Freddy on a soft mood-washed disc.
    private var hero: some View {
        ZStack {
            Circle()
                .fill(mood?.wash ?? DS.Colors.surface)
                .overlay(Circle().strokeBorder(DS.Colors.hairline, lineWidth: 1))
                .dsShadow(.card)
            FreddyView(look: mood.map(FreddyLook.mood) ?? .resting)
                .padding(heroSize * 0.06)
        }
        .frame(width: heroSize, height: heroSize)
        .animation(reduceMotion ? nil : DS.Motion.transition, value: mood?.wash)
        .accessibilityElement()
        .accessibilityLabel(mood.map { "Freddy, \($0.label) mood" } ?? "Freddy")
        .accessibilityIdentifier("moodPicker.freddy")
    }

    private var chips: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(DS.Mood.allCases) { candidate in
                MoodChip(mood: candidate, isActive: mood == candidate) {
                    select(candidate)
                }
            }
        }
    }

    private func select(_ candidate: DS.Mood) {
        let next: DS.Mood? = (mood == candidate) ? nil : candidate
        if reduceMotion {
            mood = next
        } else {
            withAnimation(DS.Motion.moodPop) { mood = next }
        }
    }
}

// MARK: - MoodChip

/// A single mood swatch: a pastel dot over its label. The active chip pops
/// slightly and gains a clay ring so the selection reads at a glance.
private struct MoodChip: View {
    let mood: DS.Mood
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(mood.fill)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().strokeBorder(DS.Colors.clay, lineWidth: isActive ? 2.5 : 0)
                    )
                    .scaleEffect(isActive ? 1.12 : 1)
                Text(mood.label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isActive ? DS.Colors.ink : DS.Colors.inkSecondary)
            }
            .padding(.vertical, DS.Spacing.xs)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(mood.label) mood")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("mood.chip.\(mood.rawValue)")
    }
}

#Preview {
    struct Demo: View {
        @State private var mood: DS.Mood? = .amber
        var body: some View {
            GradientCanvas { MoodPickerView(mood: $mood).padding(DS.Spacing.screenInset) }
        }
    }
    return Demo()
}
