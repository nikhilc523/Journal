import AVKit
import QuickLook
import SwiftUI

/// Full-screen viewer for a single attachment, presented over the composer:
/// - **photo** → pinch-to-zoom `Image`
/// - **video** → `VideoPlayer` (AVKit)
/// - **file / audio** → QuickLook preview (native document rendering)
struct MediaViewer: View {
    let attachment: MediaAttachment
    let url: URL?
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if let url {
                    content(url: url)
                } else {
                    missing
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("mediaViewer.close")
                    .padding(DS.Spacing.lg)
                }
                Spacer()
            }
        }
        .accessibilityIdentifier("mediaViewer.root")
    }

    @ViewBuilder
    private func content(url: URL) -> some View {
        switch attachment.kind {
        case .photo:
            ZoomableImage(url: url)
        case .video, .audio:
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .accessibilityIdentifier("mediaViewer.video")
        case .file, .none:
            QuickLookPreview(url: url)
                .ignoresSafeArea(edges: .bottom)
                .accessibilityIdentifier("mediaViewer.file")
        }
    }

    private var missing: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.8))
            Text("This attachment is unavailable.")
                .font(DS.Typography.callout)
                .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityIdentifier("mediaViewer.missing")
    }
}

// MARK: - Zoomable photo

/// A pinch/double-tap zoomable, pannable image for full-screen photo viewing.
private struct ZoomableImage: View {
    let url: URL

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value.magnification, 1), 5)
                                }
                                .onEnded { _ in lastScale = scale }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(DS.Motion.tap) {
                                scale = scale > 1 ? 1 : 2.5
                                lastScale = scale
                            }
                        }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityIdentifier("mediaViewer.photo")
        .task {
            // Decode at display resolution on a background task.
            image = await Task.detached(priority: .userInitiated) { [url] in
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }
}

// MARK: - QuickLook preview

/// Wraps `QLPreviewController` so arbitrary files render with native previews.
private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
