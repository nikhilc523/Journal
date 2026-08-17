import Foundation

// MARK: - Freddy avatar data
//
// The parametric definition of Freddy (the user's avatar, designed in the studio
// and exported to `freddy.avatar.json`): a primary surface (his head) plus body
// nodes (ears + snout), a library of expressions, and named animations that
// sequence those expressions. This is pure data — the geometry that turns it into
// on-screen shapes lives in ``FreddyEngine`` (a native reimplementation of the
// avatar math; no web view, no third-party runtime).

/// A parametric surface (superquadric): a rounded box / sphere / cylinder.
struct FreddySurface: Decodable, Equatable, Sendable {
    let type: String
    let width: Double
    let height: Double
    let depth: Double
    let roundness: Double
    let morphRoundness: Double?
    let tipRoundness: Double?
    let baseRoundness: Double?
}

/// An extra shape attached to the head (Freddy's two ears + snout).
struct FreddyBodyNode: Decodable, Equatable, Sendable {
    let id: String
    let surface: FreddySurface
    let position: [Double]   // [x, y, z]
    let rotation: [Double]   // degrees [x, y, z]
}

struct FreddyColors: Decodable, Equatable, Sendable {
    let body: String
    let eyes: String
}

struct FreddyAvatar: Decodable, Equatable, Sendable {
    let name: String
    let surface: FreddySurface
    let bodyNodes: [FreddyBodyNode]
    let colors: FreddyColors
}

/// One facial pose: head orientation + per-eye shape/position. (Freddy's
/// `eyeMotion`/`bodyMotion` are always "none", so ambient jitter is omitted.)
struct FreddyExpression: Decodable, Equatable, Sendable {
    var id: String
    var headX, headY, headZ: Double
    var widthLeft, widthRight: Double
    var heightLeft, heightRight: Double
    var spacing: Double
    var positionXLeft, positionXRight: Double
    var positionYLeft, positionYRight: Double
    var leftAngle, rightAngle: Double
    var perspective: Double

    /// Interpolate every field from `self` toward `to` by eased `t` (0…1). Head
    /// and eye angles take the nearest rotational path so they never spin the
    /// long way round.
    func interpolated(to: FreddyExpression, _ t: Double) -> FreddyExpression {
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        func lerpAngle(_ a: Double, _ b: Double) -> Double { a + (Self.nearest(b, to: a) - a) * t }
        var r = self
        r.headX = lerpAngle(headX, to.headX)
        r.headY = lerpAngle(headY, to.headY)
        r.headZ = lerpAngle(headZ, to.headZ)
        r.widthLeft = lerp(widthLeft, to.widthLeft)
        r.widthRight = lerp(widthRight, to.widthRight)
        r.heightLeft = lerp(heightLeft, to.heightLeft)
        r.heightRight = lerp(heightRight, to.heightRight)
        r.spacing = lerp(spacing, to.spacing)
        r.positionXLeft = lerp(positionXLeft, to.positionXLeft)
        r.positionXRight = lerp(positionXRight, to.positionXRight)
        r.positionYLeft = lerp(positionYLeft, to.positionYLeft)
        r.positionYRight = lerp(positionYRight, to.positionYRight)
        r.leftAngle = lerpAngle(leftAngle, to.leftAngle)
        r.rightAngle = lerpAngle(rightAngle, to.rightAngle)
        r.perspective = lerp(perspective, to.perspective)
        return r
    }

    /// The angle equivalent to `target` closest to `current` (unwrapped to ±180).
    private static func nearest(_ target: Double, to current: Double) -> Double {
        var resolved = target
        while resolved - current > 180 { resolved -= 360 }
        while resolved - current < -180 { resolved += 360 }
        return resolved
    }
}

struct FreddyBlink: Decodable, Equatable, Sendable {
    let enabled: Bool
    let initialDelayMs: Double
    let minIntervalMs: Double
    let maxIntervalMs: Double
    let durationMs: Double
}

struct FreddyStep: Decodable, Equatable, Sendable {
    let expressionId: String
    let holdMs: Double
    let transitionMs: Double
    let transition: String   // "smooth" | "snappy" | ...
}

struct FreddyAnimation: Decodable, Equatable, Sendable {
    let name: String
    let playbackMode: String
    let blink: FreddyBlink
    let steps: [FreddyStep]
}

/// The whole exported document.
struct FreddyDocument: Decodable, Sendable {
    let avatar: FreddyAvatar
    let expressions: [String: FreddyExpression]
    let animations: [String: FreddyAnimation]

    /// Load & decode the bundled `freddy.avatar.json`. Returns `nil` if missing or
    /// malformed (callers fall back gracefully — never force-unwrapped).
    static func loadBundled(_ bundle: Bundle = .main) -> FreddyDocument? {
        guard let url = bundle.url(forResource: "freddy.avatar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(FreddyDocument.self, from: data)
        else { return nil }
        return doc
    }
}
