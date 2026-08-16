import SwiftUI

/// The floating circular `+` action button (create an entry). Liquid Glass
/// circle with a clay glyph, soft FAB shadow.
public struct FloatingActionButton: View {
    private let systemImage: String
    private let label: String
    private let action: () -> Void
    @State private var tapCount = 0

    public init(systemImage: String = "plus", label: String = "New entry", action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DS.Colors.clay)
                .frame(width: 60, height: 60)
                .contentShape(Circle())
                .dsGlass(in: Circle())
                .dsShadow(.fab)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .accessibilityLabel(label)
        .accessibilityIdentifier("fab.\(systemImage)")
    }
}

#Preview {
    GradientCanvas {
        FloatingActionButton {}
    }
}
