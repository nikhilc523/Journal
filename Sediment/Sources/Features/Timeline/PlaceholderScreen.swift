import SwiftUI

/// Calm placeholder for tabs that arrive in later stages (Search → 10,
/// Insights → 11, Settings → 13). Keeps the tab bar reachable so navigation works
/// end-to-end today.
public struct PlaceholderScreen: View {
    private let tabInfo: AppTab
    @Binding private var tab: AppTab

    public init(_ tabInfo: AppTab, tab: Binding<AppTab>) {
        self.tabInfo = tabInfo
        self._tab = tab
    }

    public var body: some View {
        ZStack {
            GradientCanvas()

            VStack(spacing: DS.Spacing.md) {
                Image(systemName: tabInfo.systemImage)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(DS.Colors.inkTertiary)
                    .accessibilityHidden(true)
                Text(tabInfo.title)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.ink)
                Text("Coming soon.")
                    .font(DS.Typography.subhead)
                    .foregroundStyle(DS.Colors.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                SegmentedTabBar(selection: $tab)
                    .padding(.horizontal, DS.Spacing.screenInset)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
        .accessibilityIdentifier("placeholder.\(tabInfo.title)")
    }
}
