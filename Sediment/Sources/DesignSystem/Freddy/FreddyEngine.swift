import CoreGraphics
import Foundation
import simd

// MARK: - FreddyEngine
//
// Native reimplementation of the avatar geometry: it turns an expression + the
// avatar's parametric surfaces into 2D outlines to draw. This is standard 3D
// math — superquadric surface sampling, quaternion rotation, perspective
// projection, convex-hull silhouettes, Catmull-Rom smoothing — reworked in Swift
// so Freddy renders in a plain SwiftUI `Canvas` (no web view, no runtime dep).
//
// Only the shapes Freddy actually uses are implemented (rounded-box head, sphere
// ears, morphed-cylinder snout); other primitive types aren't needed.
//
// Coordinate space matches the source: a 300×300 box centred on the origin
// (SVG viewBox -150 -150 300 300). Callers map that to view points.

/// The drawable result for one frame: silhouettes (as point rings) plus eyes.
struct FreddyGeometry {
    /// Closed rings drawn behind the head (Freddy's ears), body-tinted.
    var backRings: [[CGPoint]] = []
    /// The head silhouette ring, body-tinted.
    var headRing: [CGPoint] = []
    /// Closed rings drawn in front of the head (snout), body-tinted.
    var frontRings: [[CGPoint]] = []
    /// Eye polygons (eye-tinted, clipped to the head).
    var leftEye: [CGPoint] = []
    var rightEye: [CGPoint] = []
    var leftVisible = false
    var rightVisible = false
}

final class FreddyEngine {
    private let avatar: FreddyAvatar
    // Pose-independent surface sample grids, computed once.
    private let headGrid: [SIMD3<Double>]
    private let nodeGrids: [[SIMD3<Double>]]
    private let nodeOrientations: [simd_quatd]

    private static let projectionDistance = 620.0

    init(avatar: FreddyAvatar) {
        self.avatar = avatar
        // Silhouette resolution: a convex hull only needs the outline, so a coarse
        // grid renders identically after Catmull-Rom smoothing but is far cheaper
        // to rotate/project/hull every frame.
        self.headGrid = FreddyEngine.grid(avatar.surface, lat: 17, lon: 37)
        self.nodeGrids = avatar.bodyNodes.map { FreddyEngine.grid($0.surface, lat: 11, lon: 25) }
        self.nodeOrientations = avatar.bodyNodes.map {
            FreddyEngine.eulerQuat(rad($0.rotation[0]), rad($0.rotation[1]), rad($0.rotation[2]))
        }
    }

    // MARK: Per-frame geometry

    func geometry(expression e: FreddyExpression, blink: Double) -> FreddyGeometry {
        let orientation = FreddyEngine.eulerQuat(rad(e.headX), rad(e.headY), rad(e.headZ))
        let persp = e.perspective
        var g = FreddyGeometry()

        // Head silhouette: rotate+project the grid, hull, resample.
        let headProjected = headGrid.map { project(rotate(orientation, $0), persp) }
        g.headRing = resample(convexHull(headProjected)).map { CGPoint(x: $0.x, y: $0.y) }

        // Eyes.
        let left = eyePoints(e, side: -1, blink: blink, orientation: orientation, persp: persp)
        let right = eyePoints(e, side: 1, blink: blink, orientation: orientation, persp: persp)
        g.leftEye = left.map { CGPoint(x: $0.point.x, y: $0.point.y) }
        g.rightEye = right.map { CGPoint(x: $0.point.x, y: $0.point.y) }
        g.leftVisible = left.reduce(0) { $0 + $1.normal.z } > 0
        g.rightVisible = right.reduce(0) { $0 + $1.normal.z } > 0

        // Body nodes (ears/snout), depth-sorted into back/front.
        var nodes: [(ring: [CGPoint], depth: Double, front: Bool)] = []
        for (i, node) in avatar.bodyNodes.enumerated() {
            let pos = SIMD3(node.position[0], node.position[1], node.position[2])
            let nodeOrient = nodeOrientations[i]
            let projected = nodeGrids[i].map { pt -> SIMD3<Double> in
                let rotated = rotate(nodeOrient, pt) + pos
                return project(rotate(orientation, rotated), persp)
            }
            let ring = resample(convexHull(projected)).map { CGPoint(x: $0.x, y: $0.y) }
            let depth = rotate(orientation, pos).z
            let front = depth > nodeFrontThreshold(node, orientation: orientation, nodeOrient: nodeOrient) * 0.1
            nodes.append((ring, depth, front))
        }
        nodes.sort { $0.depth < $1.depth }
        g.backRings = nodes.filter { !$0.front }.map(\.ring)
        g.frontRings = nodes.filter { $0.front }.map(\.ring)
        return g
    }

    /// Front/back classification threshold: the node's half-extent along the
    /// viewer's z after rotation.
    private func nodeFrontThreshold(_ node: FreddyBodyNode, orientation: simd_quatd, nodeOrient: simd_quatd) -> Double {
        let axes = [SIMD3(1.0, 0, 0), SIMD3(0, 1.0, 0), SIMD3(0, 0, 1.0)]
        let z = axes.map { rotate(orientation, rotate(nodeOrient, $0)).z }
        let dx = z[0] * node.surface.width / 2
        let dy = z[1] * node.surface.height / 2
        let dz = z[2] * node.surface.depth / 2
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    // MARK: Eyes

    private struct EyeSample { let point: SIMD3<Double>; let normal: SIMD3<Double> }

    private func eyePoints(_ e: FreddyExpression, side: Double, blink: Double,
                           orientation: simd_quatd, persp: Double) -> [EyeSample] {
        let isLeft = side < 0
        let width = isLeft ? e.widthLeft : e.widthRight
        let heightBase = isLeft ? e.heightLeft : e.heightRight
        let height = 5 + (heightBase - 5) * blink
        let posX = isLeft ? e.positionXLeft : e.positionXRight
        let posY = isLeft ? e.positionYLeft : e.positionYRight
        let cx = side * e.spacing / 2 + posX
        let cy = posY
        let angle = rad(isLeft ? e.leftAngle : e.rightAngle)
        let ca = cos(angle), sa = sin(angle)

        return roundedRect(width: width, height: height).map { p -> EyeSample in
            let rx = p.x * ca - p.y * sa
            let ry = p.x * sa + p.y * ca
            // Map eye-plane coords onto the head surface, then rotate+project.
            let sample = cubeSurfaceAt(avatar.surface, x: cx + rx, y: cy + ry)
            return EyeSample(point: project(rotate(orientation, sample.point), persp),
                             normal: rotate(orientation, sample.normal))
        }
    }

    /// Rounded-rectangle outline in eye-plane space.
    private func roundedRect(width: Double, height: Double) -> [SIMD2<Double>] {
        let hw = width / 2, hh = height / 2
        let r = min(hh, hw)
        var pts: [SIMD2<Double>] = []
        func line(_ a: SIMD2<Double>, _ b: SIMD2<Double>) {
            let n = max(2, Int(ceil(hypot(b.x - a.x, b.y - a.y) / 1.5)))
            for i in 0..<n { let t = Double(i) / Double(n); pts.append(a + (b - a) * t) }
        }
        func arc(_ cx: Double, _ cy: Double, _ start: Double) {
            let segs = 14
            for i in 0..<segs { let a = start + Double(i) / Double(segs) * (.pi / 2); pts.append(SIMD2(cx + cos(a) * r, cy + sin(a) * r)) }
        }
        line(SIMD2(-hw + r, -hh), SIMD2(hw - r, -hh)); arc(hw - r, -hh + r, -.pi / 2)
        line(SIMD2(hw, -hh + r), SIMD2(hw, hh - r)); arc(hw - r, hh - r, 0)
        line(SIMD2(hw - r, hh), SIMD2(-hw + r, hh)); arc(-hw + r, hh - r, .pi / 2)
        line(SIMD2(-hw, hh - r), SIMD2(-hw, -hh + r)); arc(-hw + r, -hh + r, .pi)
        return pts
    }

    /// Project an eye-plane (x,y) onto the rounded-box head, returning point+normal.
    private func cubeSurfaceAt(_ s: FreddySurface, x: Double, y: Double) -> (point: SIMD3<Double>, normal: SIMD3<Double>) {
        // Eye-plane → surface angles (matches the engine's `xe`).
        let nx = x / 120, ny = y / 120
        let sx = 120 * cos(ny) * sin(nx)
        let sy = 120 * sin(ny)
        // Cube surfaceSampleAt (`ae` with finite exponent).
        let exp = cubeExponent(s)
        let a = s.width / 2, o = s.height / 2, d = s.depth / 2
        let c = clampD(sy / o, -1, 1)
        let l = pow(max(0, 1 - pow(abs(c), exp)), 1 / exp)
        let u = clampD(sx, -a * l, a * l)
        let dd = u / (a == 0 ? 1 : a)
        let f = pow(max(0, 1 - pow(abs(dd), exp) - pow(abs(c), exp)), 1 / exp)
        let point = SIMD3(u, c * o, d * f)
        let normal = cubeNormal(s, point, exp: exp)
        return (point, normal)
    }

    private func cubeNormal(_ s: FreddySurface, _ p: SIMD3<Double>, exp: Double) -> SIMD3<Double> {
        let r = s.width / 2 == 0 ? 1 : s.width / 2
        let i = s.height / 2 == 0 ? 1 : s.height / 2
        let a = s.depth / 2 == 0 ? 1 : s.depth / 2
        return normalize3(SIMD3(signedPow(p.x / r, exp - 1) / r,
                                signedPow(p.y / i, exp - 1) / i,
                                signedPow(p.z / a, exp - 1) / a))
    }

    // MARK: Surface sampling

    /// Sample a surface at spherical (theta, phi). Supports the primitives Freddy
    /// uses: cube (rounded box), sphere, cylinder (with morph).
    private static func surfacePoint(_ s: FreddySurface, theta: Double, phi: Double) -> SIMD3<Double> {
        switch s.type {
        case "sphere", "mickey":
            let c = cos(phi)
            return SIMD3(s.width / 2 * c * sin(theta), s.height / 2 * sin(phi), s.depth / 2 * c * cos(theta))
        case "cube":
            let exp = cubeExponentStatic(s)
            let ix = cos(phi) * sin(theta), ay = sin(phi), oz = cos(phi) * cos(theta)
            let denom = pow(pow(abs(ix), exp) + pow(abs(ay), exp) + pow(abs(oz), exp), 1 / exp)
            let dv = denom == 0 ? 1 : denom
            return SIMD3(s.width / 2 * ix / dv, s.height / 2 * ay / dv, s.depth / 2 * oz / dv)
        case "cylinder":
            let prof = cylinderProfile(s, (phi + .pi / 2) / .pi)
            return SIMD3(s.width / 2 * prof.radius * sin(theta),
                         -s.height / 2 + s.height * prof.vertical,
                         s.depth / 2 * prof.radius * cos(theta))
        default:
            // Fallback: treat as sphere so an unknown primitive still renders.
            let c = cos(phi)
            return SIMD3(s.width / 2 * c * sin(theta), s.height / 2 * sin(phi), s.depth / 2 * c * cos(theta))
        }
    }

    /// Cylinder vertical/radius profile with morph blend (engine `y = h(v)`).
    private static func cylinderProfile(_ s: FreddySurface, _ t: Double) -> (radius: Double, vertical: Double) {
        let n = clampD(t, 0, 1)
        let r = s.roundness * 0.22
        var radius: Double
        var vertical: Double
        if r <= 0 {
            radius = 1
            vertical = (sin((n - 0.5) * .pi) + 1) / 2
        } else if n < r {
            let e = -Double.pi / 2 + n / r * (.pi / 2)
            radius = 1 - r + r * cos(e)
            vertical = (r + r * sin(e)) / 2
        } else if n > 1 - r {
            let e = (n - (1 - r)) / r * (.pi / 2)
            radius = 1 - r + r * cos(e)
            vertical = 1 - r / 2 + r * sin(e) / 2
        } else {
            let i = (n - r) / (1 - r * 2)
            radius = 1
            vertical = r / 2 + i * (1 - r)
        }
        // Morph blend toward a rounded profile.
        let morph = clampRoundness(s.morphRoundness ?? 0) / 2
        let i = clampD(t, 0, 1)
        let ar = sin(i * .pi)
        let ov = (1 - cos(i * .pi)) / 2
        return (radius + (ar - radius) * morph, vertical + (ov - vertical) * morph)
    }

    private static func grid(_ s: FreddySurface, lat: Int, lon: Int) -> [SIMD3<Double>] {
        var out: [SIMD3<Double>] = []
        out.reserveCapacity(lat * lon)
        for n in 0..<lat {
            let phi = -Double.pi / 2 + Double(n) / Double(lat - 1) * .pi
            for m in 0..<lon {
                let theta = -Double.pi + Double(m) / Double(lon - 1) * .pi * 2
                out.append(surfacePoint(s, theta: theta, phi: phi))
            }
        }
        return out
    }

    private func cubeExponent(_ s: FreddySurface) -> Double { FreddyEngine.cubeExponentStatic(s) }
    private static func cubeExponentStatic(_ s: FreddySurface) -> Double {
        s.roundness <= 0 ? .infinity : 2 / (0.04 + clampRoundness(s.roundness) / 2 * 0.96)
    }

    // MARK: Quaternion + projection

    private static func eulerQuat(_ x: Double, _ y: Double, _ z: Double) -> simd_quatd {
        // Engine order: (qz * qx) * qy.
        let qx = simd_quatd(angle: x, axis: SIMD3(1, 0, 0))
        let qy = simd_quatd(angle: y, axis: SIMD3(0, 1, 0))
        let qz = simd_quatd(angle: z, axis: SIMD3(0, 0, 1))
        return (qz * qx) * qy
    }

    private func rotate(_ q: simd_quatd, _ v: SIMD3<Double>) -> SIMD3<Double> { q.act(v) }

    /// Perspective projection (keeps z for depth ordering). Matches engine `I`.
    private func project(_ p: SIMD3<Double>, _ perspective: Double) -> SIMD3<Double> {
        let n = FreddyEngine.projectionDistance - p.z * perspective
        let r = abs(n) < 1e-4 ? FreddyEngine.projectionDistance / 1e-4 : FreddyEngine.projectionDistance / n
        return SIMD3(p.x * r, p.y * r, p.z)
    }

    // MARK: Hull + resample (silhouette)

    /// Convex hull by (x, y) via monotone chain; z is carried along.
    private func convexHull(_ pts: [SIMD3<Double>]) -> [SIMD3<Double>] {
        let sorted = pts.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        func cross(_ o: SIMD3<Double>, _ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        func half(_ input: [SIMD3<Double>]) -> [SIMD3<Double>] {
            var hull: [SIMD3<Double>] = []
            for p in input {
                while hull.count >= 2, cross(hull[hull.count - 2], hull[hull.count - 1], p) <= 0 { hull.removeLast() }
                hull.append(p)
            }
            return hull
        }
        let lower = half(sorted).dropLast()
        let upper = half(sorted.reversed()).dropLast()
        return Array(lower) + Array(upper)
    }

    /// Resample each hull edge into ~`step`px segments (engine `K`).
    private func resample(_ pts: [SIMD3<Double>], step: Double = 7) -> [SIMD3<Double>] {
        guard pts.count > 1 else { return pts }
        var out: [SIMD3<Double>] = []
        for (i, a) in pts.enumerated() {
            let b = pts[(i + 1) % pts.count]
            let segs = max(1, Int(ceil(hypot(b.x - a.x, b.y - a.y) / step)))
            for s in 0..<segs { let t = Double(s) / Double(segs); out.append(a + (b - a) * t) }
        }
        return out
    }
}

// MARK: - Scalar helpers

private func rad(_ deg: Double) -> Double { deg * .pi / 180 }
private func clampD(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
private func clampRoundness(_ v: Double) -> Double { min(max(v, 0), 2) }
private func signedPow(_ base: Double, _ exp: Double) -> Double {
    (base < 0 ? -1.0 : (base > 0 ? 1.0 : 0.0)) * pow(abs(base), exp)
}
private func normalize3(_ v: SIMD3<Double>) -> SIMD3<Double> {
    let len = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
    return len == 0 ? v : v / len
}
