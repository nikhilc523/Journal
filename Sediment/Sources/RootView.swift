import SwiftUI

/// The app shell. Owns the selected tab and swaps in the screen for it. The
/// Timeline is the real, data-bound home (`UI_Interface/primary.jpg` re-skinned to
/// oatmeal); the other tabs are calm placeholders until their stages land.
struct RootView: View {
    @State private var tab: AppTab = .timeline

    var body: some View {
        Group {
            switch tab {
            case .timeline:
                TimelineView(tab: $tab)
            case .search:
                PlaceholderScreen(.search, tab: $tab)
            case .insights:
                PlaceholderScreen(.insights, tab: $tab)
            case .settings:
                PlaceholderScreen(.settings, tab: $tab)
            }
        }
        .animation(DS.Motion.transition, value: tab)
    }
}
