import SwiftUI

/// Placeholder root surface for Stage 0.
///
/// This is intentionally minimal — it exists to prove the app builds, launches,
/// and is reachable by the UI test suite. Stage 3 replaces it with the real
/// Timeline home screen (the oatmeal re-skin of `UI_Interface/primary.jpg`).
struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Journal")
                .font(.largeTitle.weight(.semibold))

            Text("Scaffold ready")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root.placeholder")
    }
}

#Preview {
    RootView()
}
