import SwiftUI

/// Small-caps muted section label ("MAIN MENU" style) — 12pt semibold, tracked,
/// uppercased, tertiary ink. Used above grouped content.
public struct SectionLabel: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(DS.Typography.sectionLabel)
            .tracking(0.6)
            .foregroundStyle(DS.Colors.inkTertiary)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    GradientCanvas {
        SectionLabel("Main menu")
    }
}
