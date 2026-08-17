import SwiftUI

// MARK: - Freddy (the app's mascot) — native renderer
//
// Freddy is drawn entirely in SwiftUI: ``FreddyEngine`` turns the current
// expression into 2D outlines and a `Canvas` fills them. A lightweight timeline
// plays the avatar's animations (expression morphs + blinking); Reduce Motion
// pins him to a calm static pose. Body/eyes are tinted to our warm palette so he
// always lives in the oatmeal world.

/// The palette + animation Freddy adopts — bound to a mood, or a neutral rest.
public struct FreddyLook: Equatable, Sendable {
    public let animation: String
    public let body: Color
    public let eyes: Color

    public init(animation: String, body: Color, eyes: Color) {
        self.animation = animation
        self.body = body
        self.eyes = eyes
    }

    /// Neutral resting Freddy — clay body (our primary accent), ink eyes.
    public static let resting = FreddyLook(animation: "idle", body: DS.Colors.clay, eyes: DS.Colors.ink)

    /// The look for a given mood: its pastel tint + a fitting animation.
    public static func mood(_ mood: DS.Mood) -> FreddyLook {
        FreddyLook(animation: mood.freddyAnimation, body: mood.fill, eyes: DS.Colors.ink)
    }
}

public struct FreddyView: View {
    private let look: FreddyLook
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Stable animation anchor so the 30 fps schedule doesn't reset each redraw.
    @State private var start = Date()

    /// Decoded once and shared — the avatar document + its engine are immutable.
    private static let document = FreddyDocument.loadBundled()
    private static let engine: FreddyEngine? = document.map { FreddyEngine(avatar: $0.avatar) }

    public init(look: FreddyLook = .resting) {
        self.look = look
    }

    public var body: some View {
        content
            .accessibilityElement()
            .accessibilityLabel("Freddy")
            .accessibilityIdentifier("freddy.avatar")
    }

    @ViewBuilder
    private var content: some View {
        if let doc = Self.document, let engine = Self.engine,
           let timeline = FreddyTimeline(document: doc, engine: engine, animationName: look.animation) {
            // Reduce Motion pins Freddy to a calm pose. UI testing does too: a
            // perpetual `TimelineView` never lets the app reach idle, which stalls
            // XCUITest's element queries.
            if reduceMotion || SedimentRuntime.isUITesting {
                // Static, calm pose — no motion.
                FreddyCanvas(frame: timeline.frame(atMs: 0, blinkEnabled: false), look: look)
            } else {
                // 30 fps is plenty for Freddy's calm motion and keeps the
                // per-frame silhouette work well within the main-thread budget.
                SwiftUI.TimelineView(.periodic(from: start, by: 1.0 / 30.0)) { context in
                    let ms = context.date.timeIntervalSinceReferenceDate * 1000
                    FreddyCanvas(frame: timeline.frame(atMs: ms), look: look)
                }
            }
        } else {
            // Data missing: a soft tinted disc so the UI never shows an empty hole.
            Circle().fill(look.body.opacity(0.5))
        }
    }
}

// MARK: - Canvas

/// Renders one computed frame: ears behind, head, eyes clipped to the head, snout
/// in front. Engine space is a 300×300 box centred on the origin.
private struct FreddyCanvas: View {
    let frame: FreddyGeometry
    let look: FreddyLook

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            guard s > 0 else { return }
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: s / 300, y: s / 300)

            for ring in frame.backRings { ctx.fill(Self.smooth(ring), with: .color(look.body)) }
            ctx.fill(Self.smooth(frame.headRing), with: .color(look.body))

            // Eyes, clipped to the head silhouette.
            ctx.drawLayer { layer in
                layer.clip(to: Self.smooth(frame.headRing))
                if frame.leftVisible { layer.fill(Self.polygon(frame.leftEye), with: .color(look.eyes)) }
                if frame.rightVisible { layer.fill(Self.polygon(frame.rightEye), with: .color(look.eyes)) }
            }

            for ring in frame.frontRings { ctx.fill(Self.smooth(ring), with: .color(look.body)) }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Closed Catmull-Rom through the ring (matches the engine's smoothing).
    static func smooth(_ pts: [CGPoint]) -> Path {
        guard pts.count >= 3 else { return polygon(pts) }
        let n = pts.count
        func at(_ i: Int) -> CGPoint { pts[((i % n) + n) % n] }
        var path = Path()
        path.move(to: pts[0])
        for i in 0..<n {
            let cur = pts[i], prev = at(i - 1), next = at(i + 1), after = at(i + 2)
            let c1 = CGPoint(x: cur.x + (next.x - prev.x) / 6, y: cur.y + (next.y - prev.y) / 6)
            let c2 = CGPoint(x: next.x - (after.x - cur.x) / 6, y: next.y - (after.y - cur.y) / 6)
            path.addCurve(to: next, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    static func polygon(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for p in pts.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}

// MARK: - Mood → Freddy mapping

public extension DS.Mood {
    /// The Freddy animation that expresses this mood (names from the export).
    var freddyAnimation: String {
        switch self {
        case .sage: return "idle"        // content / calm
        case .amber: return "happy"      // happy / bright
        case .rose: return "shy"         // tender
        case .sky: return "listening"    // calm / clear
        case .lavender: return "thinking" // low / reflective
        case .lilac: return "curious"    // dreamy / creative
        }
    }
}
