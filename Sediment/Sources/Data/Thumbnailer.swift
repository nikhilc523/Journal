import AVFoundation
import ImageIO
import QuickLookThumbnailing
import UIKit
import UniformTypeIdentifiers

/// Lazily renders thumbnails for media attachments off the main thread, routing
/// each kind to the cheapest correct generator:
/// - **photo** → ImageIO downsampling (memory-cheap, exact-size decode)
/// - **video** → `AVAssetImageGenerator` (representative early frame)
/// - **file / audio** → `QLThumbnailGenerator` (QuickLook's document preview)
///
/// Every entry point returns `nil` on failure (missing file, unsupported format)
/// rather than throwing, so the UI can fall back to an icon without try/catch.
public enum Thumbnailer {

    /// Downsample an image file to a thumbnail no larger than `maxPixel` on its
    /// longest edge, honoring EXIF orientation.
    public static func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Extract a representative frame from a video, scaled to fit `maxPixel`.
    public static func videoFrame(at url: URL, maxPixel: CGFloat) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        // A short offset avoids black leader frames some encoders emit at t=0.
        let time = CMTime(seconds: 0.2, preferredTimescale: 600)
        do {
            let cgImage = try await generator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    /// QuickLook thumbnail for an arbitrary file (documents, PDFs, etc.).
    public static func quickLook(at url: URL, size: CGSize, scale: CGFloat) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return representation.uiImage
        } catch {
            return nil
        }
    }

    /// Route an attachment to the right generator. `pointSize`/`scale` describe the
    /// on-screen target so the decoded bitmap is no bigger than needed.
    public static func thumbnail(
        for attachment: MediaAttachment,
        at url: URL,
        pointSize: CGSize,
        scale: CGFloat
    ) async -> UIImage? {
        let maxPixel = max(pointSize.width, pointSize.height) * scale
        switch attachment.kind {
        case .photo:
            return downsampledImage(at: url, maxPixel: maxPixel)
        case .video:
            return await videoFrame(at: url, maxPixel: maxPixel)
        case .file, .audio, .none:
            return await quickLook(at: url, size: pointSize, scale: scale)
        }
    }
}

/// A tiny in-memory thumbnail cache keyed by attachment id, so scrolling a strip
/// or re-opening the composer doesn't re-render frames. Bounded to the live
/// session (cleared on memory pressure by the OS holding weak view state); the
/// actor serializes access so the render happens once per id.
public actor ThumbnailCache {
    public static let shared = ThumbnailCache()

    private var images: [UUID: UIImage] = [:]

    public init() {}

    public func image(
        for attachment: MediaAttachment,
        at url: URL,
        pointSize: CGSize,
        scale: CGFloat
    ) async -> UIImage? {
        if let cached = images[attachment.id] { return cached }
        let rendered = await Thumbnailer.thumbnail(
            for: attachment,
            at: url,
            pointSize: pointSize,
            scale: scale
        )
        if let rendered { images[attachment.id] = rendered }
        return rendered
    }

    /// Drop a cached image (e.g. after an attachment is removed).
    public func invalidate(_ id: UUID) {
        images.removeValue(forKey: id)
    }
}
