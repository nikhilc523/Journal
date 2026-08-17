import Foundation

// MARK: - FreddyTimeline
//
// Plays an avatar animation as a pure function of time: it sequences the
// animation's expression steps (each a timed morph + hold, looping) and overlays
// a deterministic blink schedule, then asks ``FreddyEngine`` for that frame's
// geometry. Being time-pure means a SwiftUI `TimelineView(.animation)` can drive
// it with no mutable playback state.

struct FreddyTimeline {
    private let engine: FreddyEngine
    private let segments: [Segment]
    private let totalMs: Double
    private let blink: FreddyBlink
    private let blinkEvents: [BlinkEvent]

    private struct Segment {
        let from: FreddyExpression
        let to: FreddyExpression
        let transitionMs: Double
        let startMs: Double      // cumulative start within the loop
        let durationMs: Double   // transition + hold
    }

    private struct BlinkEvent { let startMs: Double; let durationMs: Double }

    init?(document: FreddyDocument, engine: FreddyEngine, animationName: String) {
        guard let animation = document.animations[animationName] ?? document.animations["idle"],
              !animation.steps.isEmpty else { return nil }
        self.engine = engine
        self.blink = animation.blink

        // Resolve each step's target expression; skip any unknown ids.
        let exprs = animation.steps.compactMap { document.expressions[$0.expressionId] }
        guard exprs.count == animation.steps.count else { return nil }

        var segs: [Segment] = []
        var cursor = 0.0
        let n = animation.steps.count
        for (i, step) in animation.steps.enumerated() {
            let from = exprs[(i - 1 + n) % n]   // previous step (loops)
            let to = exprs[i]
            let dur = step.transitionMs + step.holdMs
            segs.append(Segment(from: from, to: to, transitionMs: step.transitionMs, startMs: cursor, durationMs: dur))
            cursor += dur
        }
        self.segments = segs
        self.totalMs = max(cursor, 1)

        // Precompute a long, deterministic blink schedule (stable across frames).
        if animation.blink.enabled {
            var events: [BlinkEvent] = []
            var t = animation.blink.initialDelayMs
            var rng = SplitMix64(seed: 0x0000_F1E0_D0BE_0001)
            let range = max(0, animation.blink.maxIntervalMs - animation.blink.minIntervalMs)
            for _ in 0..<1200 {
                events.append(BlinkEvent(startMs: t, durationMs: animation.blink.durationMs))
                t += animation.blink.durationMs + animation.blink.minIntervalMs + rng.nextUnit() * range
            }
            self.blinkEvents = events
        } else {
            self.blinkEvents = []
        }
    }

    /// Geometry for the given absolute time (ms). `blinkEnabled` off pins eyes open.
    func frame(atMs ms: Double, blinkEnabled: Bool = true) -> FreddyGeometry {
        engine.geometry(expression: expression(atMs: ms), blink: blinkEnabled ? blinkAmount(atMs: ms) : 1)
    }

    /// The interpolated expression at time `ms` (animation loops on `totalMs`).
    private func expression(atMs ms: Double) -> FreddyExpression {
        let tLoop = ms.truncatingRemainder(dividingBy: totalMs)
        let t = tLoop < 0 ? tLoop + totalMs : tLoop
        let seg = segments.first { t >= $0.startMs && t < $0.startMs + $0.durationMs } ?? segments[segments.count - 1]
        let phase = t - seg.startMs
        guard seg.transitionMs > 0, phase < seg.transitionMs else { return seg.to }
        let eased = Self.smoothstep(phase / seg.transitionMs)
        return seg.from.interpolated(to: seg.to, eased)
    }

    /// Blink openness at time `ms`: 1 = open, dips to 0 mid-blink and back.
    private func blinkAmount(atMs ms: Double) -> Double {
        guard ms >= 0 else { return 1 }
        // Blink events are sorted; find the one whose window contains `ms`.
        for e in blinkEvents {
            if ms < e.startMs { break }
            if ms <= e.startMs + e.durationMs {
                let p = (ms - e.startMs) / e.durationMs
                if p <= 0.42 {
                    let close = p / 0.42
                    return 1 - close * close
                } else {
                    let open = (p - 0.42) / 0.58
                    return 1 - (1 - open) * (1 - open)
                }
            }
        }
        return 1
    }

    private static func smoothstep(_ p: Double) -> Double { p * p * (3 - 2 * p) }
}

/// Tiny deterministic RNG so the blink cadence is lively but stable per build.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func nextUnit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}
