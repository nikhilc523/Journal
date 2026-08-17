import Testing
import Foundation
import CoreGraphics
@testable import Sediment

/// Validates the native ``FreddyEngine`` against ground truth captured from the
/// original JS avatar engine (see `scratchpad/reference.json`). Bounding boxes
/// are compared with a tolerance that absorbs the difference between the raw
/// silhouette knots (native) and the reference's smoothed control points.
@MainActor
struct FreddyEngineTests {

    private func makeEngine() throws -> (FreddyEngine, FreddyDocument) {
        let doc = try #require(FreddyDocument.loadBundled(.main) ?? FreddyDocument.loadBundled(Bundle(for: BundleToken.self)))
        return (FreddyEngine(avatar: doc.avatar), doc)
    }

    private func bbox(_ pts: [CGPoint]) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        let xs = pts.map { Double($0.x) }, ys = pts.map { Double($0.y) }
        return (xs.min() ?? 0, xs.max() ?? 0, ys.min() ?? 0, ys.max() ?? 0)
    }

    @Test func headAndNodesMatchReference_expression13() throws {
        let (engine, doc) = try makeEngine()
        let expr = try #require(doc.expressions["expression-13"])
        let g = engine.geometry(expression: expr, blink: 1)

        // Structure: two ears behind, one snout in front, both eyes visible.
        #expect(g.backRings.count == 2)
        #expect(g.frontRings.count == 1)
        #expect(g.leftVisible && g.rightVisible)
        #expect(g.headRing.count > 20)

        // Head silhouette bbox vs reference {x:-100.2…93.4, y:-83.5…88.1}.
        let b = bbox(g.headRing)
        #expect(abs(b.minX - -100.2) < 15)
        #expect(abs(b.maxX - 93.4) < 15)
        #expect(abs(b.minY - -83.5) < 15)
        #expect(abs(b.maxY - 88.1) < 15)

        // Left eye bbox vs reference {x:-80.2…-16.7, y:4.7…38.5}.
        let e = bbox(g.leftEye)
        #expect(abs(e.minX - -80.2) < 12)
        #expect(abs(e.maxX - -16.7) < 12)
        #expect(abs(e.minY - 4.7) < 12)
        #expect(abs(e.maxY - 38.5) < 12)
    }

    @Test func blinkClosesEyes() throws {
        let (engine, doc) = try makeEngine()
        let expr = try #require(doc.expressions["expression-00"])
        let open = engine.geometry(expression: expr, blink: 1)
        let closed = engine.geometry(expression: expr, blink: 0)
        // A closed blink squashes eye height.
        let openH = bbox(open.leftEye).maxY - bbox(open.leftEye).minY
        let closedH = bbox(closed.leftEye).maxY - bbox(closed.leftEye).minY
        #expect(closedH < openH)
    }

    @Test func allMoodAnimationsResolve() throws {
        let (engine, doc) = try makeEngine()
        for mood in DS.Mood.allCases {
            let timeline = try #require(FreddyTimeline(document: doc, engine: engine, animationName: mood.freddyAnimation))
            let frame = timeline.frame(atMs: 1234)
            #expect(!frame.headRing.isEmpty)
        }
    }
}

/// Locates the bundle that carries `freddy.avatar.json` when tests run as a
/// host-injected bundle.
private final class BundleToken {}
