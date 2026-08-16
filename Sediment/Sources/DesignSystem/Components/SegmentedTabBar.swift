import SwiftUI

/// The four app destinations, mapped from `primary.jpg`'s frosted tab bar.
public enum AppTab: Int, CaseIterable, Identifiable, Sendable {
    case timeline = 0, search, insights, settings

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .search: return "Search"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .timeline: return "book.pages"
        case .search: return "magnifyingglass"
        case .insights: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

/// A floating, glass segmented tab bar. Active segment = raised surface pill with
/// clay tint; inactive = muted ink. Selection-haptic on change.
public struct SegmentedTabBar: View {
    @Binding private var selection: AppTab

    public init(selection: Binding<AppTab>) {
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(AppTab.allCases) { tab in
                segment(tab)
            }
        }
        .padding(DS.Spacing.xs)
        .dsGlass(in: Capsule())
        .dsShadow(.raised)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityIdentifier("tabBar")
    }

    private func segment(_ tab: AppTab) -> some View {
        let isActive = tab == selection
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(DS.Typography.caption.weight(.medium))
            }
            .foregroundStyle(isActive ? DS.Colors.clay : DS.Colors.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background {
                Capsule()
                    .fill(isActive ? DS.Colors.surfaceRaised : Color.clear)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tab.\(tab.title)")
    }
}

#Preview {
    struct Demo: View {
        @State var tab: AppTab = .timeline
        var body: some View {
            GradientCanvas {
                VStack {
                    Spacer()
                    SegmentedTabBar(selection: $tab)
                        .padding(.horizontal, DS.Spacing.screenInset)
                }
            }
        }
    }
    return Demo()
}
