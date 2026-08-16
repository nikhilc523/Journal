import SwiftUI

// MARK: - EntryComposerView
//
// The full-surface rich-text composer. One day = one page: a New York serif
// writing field over the sand canvas, using the iOS 26 native rich-text
// `TextEditor(text:selection:)` (system bold/italic/link/color via the selection
// menu, Markdown parsing) — no third-party editor. Autosave lives in
// ``EntryComposerModel``; this view is the presentation + chrome.
public struct EntryComposerView: View {
    @Bindable private var model: EntryComposerModel
    private let title: String
    private let onClose: () -> Void

    /// Native rich-text selection, owned by the view. Drives the system
    /// formatting affordances; the persisted text lives on the model.
    @State private var selection = AttributedTextSelection()
    @FocusState private var editorFocused: Bool

    public init(model: EntryComposerModel, title: String, onClose: @escaping () -> Void) {
        self.model = model
        self.title = title
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            GradientCanvas()

            VStack(spacing: DS.Spacing.lg) {
                header
                editor
            }
            .padding(.top, DS.Spacing.sm)
        }
        .accessibilityIdentifier("composer.root")
        .onAppear { editorFocused = true }
        .onDisappear { Task { await model.flush() } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.ink)
                Text(savedStatus)
                    .font(DS.Typography.meta)
                    .foregroundStyle(DS.Colors.inkSecondary)
                    .accessibilityIdentifier("composer.status")
                    .animation(DS.Motion.tap, value: savedStatus)
            }
            Spacer()
            CircularIconButton(systemImage: "checkmark", label: "Done", action: onClose)
        }
        .padding(.horizontal, DS.Spacing.screenInset)
        .accessibilityAddTraits(.isHeader)
    }

    private var editor: some View {
        TextEditor(text: $model.text, selection: $selection)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.ink)
            .tint(DS.Colors.clay)
            .lineSpacing(DS.Spacing.xs)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .focused($editorFocused)
            .padding(.horizontal, DS.Spacing.screenInset)
            .padding(.bottom, DS.Spacing.md)
            .accessibilityIdentifier("composer.editor")
            .accessibilityLabel("Entry body")
            .overlay(alignment: .topLeading) { placeholder }
    }

    /// Calm prompt shown only when the page is empty and unfocused-or-fresh.
    @ViewBuilder
    private var placeholder: some View {
        if model.text.characters.isEmpty {
            Text("Begin today's page…")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.inkTertiary)
                .padding(.horizontal, DS.Spacing.screenInset + DS.Spacing.xs)
                .padding(.top, DS.Spacing.sm)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var savedStatus: String {
        if model.isSaving { return "Saving…" }
        return model.lastSavedAt == nil ? "Draft" : "Saved"
    }
}
