import SwiftUI

/// A grid of every attachment on the entry, presented as a sheet from the
/// composer. Tapping a cell opens the full-screen ``MediaViewer`` (photo zoom /
/// video playback / file preview); each cell can be removed with a long-press
/// menu. Reads its data from the shared ``EntryComposerMediaModel``.
struct MediaGridView: View {
    @Bindable var model: EntryComposerMediaModel
    let onClose: () -> Void

    @State private var viewing: MediaAttachment?

    private let columns = [GridItem(.adaptive(minimum: DS.Sizes.mediaGridMin), spacing: DS.Spacing.sm)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if model.attachments.isEmpty {
                    empty
                } else {
                    LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                        ForEach(model.attachments) { attachment in
                            cell(attachment)
                        }
                    }
                    .padding(DS.Spacing.screenInset)
                }
            }
            .background(GradientCanvas())
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .accessibilityIdentifier("mediaGrid.done")
                }
            }
        }
        .fullScreenCover(item: $viewing) { attachment in
            MediaViewer(
                attachment: attachment,
                url: model.resolvedURL(for: attachment),
                onClose: { viewing = nil }
            )
        }
    }

    private func cell(_ attachment: MediaAttachment) -> some View {
        Button {
            viewing = attachment
        } label: {
            MediaThumbnailView(
                attachment: attachment,
                url: model.resolvedURL(for: attachment),
                side: DS.Sizes.mediaGridMin
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Open \(attachment.kind?.rawValue ?? "file")")
        .accessibilityIdentifier("mediaGrid.item")
        .contextMenu {
            Button(role: .destructive) {
                Task { await model.remove(attachment) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var empty: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(DS.Colors.inkTertiary)
            Text("No attachments yet.")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl)
        .accessibilityIdentifier("mediaGrid.empty")
    }
}
