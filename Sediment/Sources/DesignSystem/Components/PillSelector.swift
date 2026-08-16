import SwiftUI

/// A single capsule pill. Active = solid clay fill with light text; inactive =
/// frosted sunken surface with ink text (per `primary.jpg`).
public struct Pill: View {
    private let title: String
    private let isActive: Bool
    private let action: () -> Void

    public init(_ title: String, isActive: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.subhead.weight(.semibold))
                .foregroundStyle(isActive ? DS.Colors.inkOnAccent : DS.Colors.inkSecondary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background {
                    Capsule()
                        .fill(isActive ? DS.Colors.clay : DS.Colors.surfaceSunken)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("pill.\(title)")
    }
}

/// A horizontal, scrollable row of pills with a single selection. `selection`
/// binds to the active item.
public struct PillSelector<Item: Hashable>: View {
    private let items: [Item]
    private let title: (Item) -> String
    @Binding private var selection: Item

    public init(items: [Item], selection: Binding<Item>, title: @escaping (Item) -> String) {
        self.items = items
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    Pill(title(item), isActive: item == selection) {
                        selection = item
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screenInset)
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityIdentifier("pillSelector")
    }
}

/// Convenience for a `[String]` selector.
public extension PillSelector where Item == String {
    init(items: [String], selection: Binding<String>) {
        self.init(items: items, selection: selection, title: { $0 })
    }
}

#Preview {
    struct Demo: View {
        @State var day = "Today"
        var body: some View {
            GradientCanvas {
                PillSelector(items: ["Today", "Tue", "Wed", "Thu", "Fri", "Sat"], selection: $day)
            }
        }
    }
    return Demo()
}
