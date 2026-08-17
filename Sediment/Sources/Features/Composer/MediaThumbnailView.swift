import SwiftUI

/// A square thumbnail for one attachment. Renders the lazily-generated preview
/// (photo downsample / video frame / QuickLook), falling back to a kind icon
/// while it loads or when no preview exists. Video thumbnails carry a play badge.
struct MediaThumbnailView: View {
    let attachment: MediaAttachment
    /// Resolved on-disk original, or `nil` if missing/invalid.
    let url: URL?
    let side: CGFloat

    @State private var image: UIImage?
    @State private var didAttemptLoad = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(DS.Colors.surfaceSunken)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: side * 0.32, weight: .regular))
                    .foregroundStyle(DS.Colors.inkTertiary)
            }

            if attachment.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: side * 0.34))
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .shadow(radius: 2)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .stroke(DS.Colors.hairline, lineWidth: 1)
        )
        .task(id: attachment.id) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard !didAttemptLoad, let url else { return }
        didAttemptLoad = true
        image = await ThumbnailCache.shared.image(
            for: attachment,
            at: url,
            pointSize: CGSize(width: side, height: side),
            scale: displayScale
        )
    }

    private var fallbackIcon: String {
        switch attachment.kind {
        case .photo: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .file, .none: return "doc"
        }
    }
}
