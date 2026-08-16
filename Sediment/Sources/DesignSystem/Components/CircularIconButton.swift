import SwiftUI

/// A circular, glass icon button for top-corner chrome (back, ⋯, etc.).
/// Liquid Glass over the sand canvas, warm ink glyph.
public struct CircularIconButton: View {
    private let systemImage: String
    private let label: String
    private let action: () -> Void

    /// - Parameters:
    ///   - systemImage: SF Symbol name.
    ///   - label: VoiceOver label (required — the glyph alone isn't descriptive).
    public init(systemImage: String, label: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .dsGlass(in: Circle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityIdentifier("iconButton.\(systemImage)")
    }
}

#Preview {
    GradientCanvas {
        HStack(spacing: 16) {
            CircularIconButton(systemImage: "chevron.left", label: "Back") {}
            CircularIconButton(systemImage: "ellipsis", label: "More") {}
        }
    }
}
