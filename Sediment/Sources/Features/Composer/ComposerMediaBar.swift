import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The composer's attachment affordance: a row that lets you add photos/video
/// (zero-permission `PhotosPicker`) and arbitrary files (document picker — our
/// differentiator), plus a horizontal strip of the current attachments. Tapping a
/// thumbnail opens the full-screen viewer; the count chip opens the media grid.
struct ComposerMediaBar: View {
    @Bindable var model: EntryComposerMediaModel

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isFileImporterPresented = false
    @State private var viewing: MediaAttachment?
    @State private var isGridPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            controls

            if !model.attachments.isEmpty {
                strip
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case let .success(urls) = result {
                Task { await model.addFiles(urls) }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPickedItems(items) }
        }
        .fullScreenCover(item: $viewing) { attachment in
            MediaViewer(
                attachment: attachment,
                url: model.resolvedURL(for: attachment),
                onClose: { viewing = nil }
            )
        }
        .sheet(isPresented: $isGridPresented) {
            MediaGridView(model: model, onClose: { isGridPresented = false })
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: DS.Spacing.sm) {
            PhotosPicker(
                selection: $pickerItems,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            ) {
                ControlLabel(systemImage: "photo.badge.plus", title: "Photo")
            }
            .accessibilityIdentifier("composer.addPhoto")

            Button {
                isFileImporterPresented = true
            } label: {
                ControlLabel(systemImage: "paperclip", title: "File")
            }
            .accessibilityIdentifier("composer.addFile")

            Spacer()

            if model.isImporting {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityIdentifier("composer.mediaImporting")
            } else if !model.attachments.isEmpty {
                Button {
                    isGridPresented = true
                } label: {
                    AttachmentChip(.photo, title: "\(model.attachments.count)")
                }
                .accessibilityIdentifier("composer.mediaGrid")
            }
        }
    }

    /// Capsule "Add …" affordance shared by the photo and file buttons.
    private struct ControlLabel: View {
        let systemImage: String
        let title: String

        var body: some View {
            Label(title, systemImage: systemImage)
                .font(DS.Typography.subhead)
                .foregroundStyle(DS.Colors.clay)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule().fill(DS.Colors.surfaceSunken)
                )
        }
    }

    // MARK: Strip

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(model.attachments) { attachment in
                    Button {
                        viewing = attachment
                    } label: {
                        MediaThumbnailView(
                            attachment: attachment,
                            url: model.resolvedURL(for: attachment),
                            side: DS.Sizes.mediaThumb
                        )
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Open \(attachment.kind?.rawValue ?? "file")")
                    .accessibilityIdentifier("composer.mediaThumbnail")
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await model.remove(attachment) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.vertical, DS.Spacing.xs)
        }
        .accessibilityIdentifier("composer.mediaStrip")
    }

    // MARK: Import helpers

    private func importPickedItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let type = item.supportedContentTypes.first,
                  let data = try? await item.loadTransferable(type: Data.self) else { continue }
            await model.addData(data, utType: type)
        }
        pickerItems = []
    }
}
