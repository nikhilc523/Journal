import SwiftUI

/// Placeholder mood face — a circular pastel-tinted disc with a simple drawn
/// expression. Stage 5 swaps this for curated avatar art (SVG or Fluent 3D);
/// the API (a `DS.Mood` + size) stays stable so call sites don't change.
public struct MoodFace: View {
    private let mood: DS.Mood
    private let size: CGFloat

    public init(_ mood: DS.Mood, size: CGFloat = 40) {
        self.mood = mood
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle().fill(mood.fill)
            face
                .stroke(DS.Colors.ink.opacity(0.65), style: StrokeStyle(lineWidth: max(1.5, size * 0.05), lineCap: .round))
                .frame(width: size * 0.5, height: size * 0.32)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(mood.label) mood")
        .accessibilityIdentifier("moodFace.\(mood.rawValue)")
    }

    /// A gentle smile arc + two eyes, drawn in the lower/upper thirds.
    private var face: some Shape {
        MoodExpression()
    }
}

private struct MoodExpression: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let eyeY = rect.minY
        let eyeR = rect.width * 0.06
        // Eyes
        p.addEllipse(in: CGRect(x: rect.minX, y: eyeY, width: eyeR * 2, height: eyeR * 2))
        p.addEllipse(in: CGRect(x: rect.maxX - eyeR * 2, y: eyeY, width: eyeR * 2, height: eyeR * 2))
        // Smile
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.6)
        )
        return p
    }
}

#Preview {
    GradientCanvas {
        HStack(spacing: 12) {
            ForEach(DS.Mood.allCases) { MoodFace($0, size: 44) }
        }
    }
}
