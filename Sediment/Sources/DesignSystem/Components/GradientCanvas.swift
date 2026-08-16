import SwiftUI

/// Full-bleed warm vertical gradient canvas — the app background (`canvasTop` →
/// `canvasBottom`). Everything else floats over this sand surface.
public struct GradientCanvas<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content = { Color.clear }) {
        self.content = content()
    }

    public var body: some View {
        LinearGradient(
            colors: [DS.Colors.canvasTop, DS.Colors.canvasBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .overlay(content)
    }
}

#Preview {
    GradientCanvas {
        Text("Sediment").font(DS.Typography.title).foregroundStyle(DS.Colors.ink)
    }
}
