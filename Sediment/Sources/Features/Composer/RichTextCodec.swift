import Foundation
import SwiftUI
import Markdown

// MARK: - RichTextCodec
//
// The serialization boundary for the entry composer. An entry's rich text is an
// `AttributedString`; the database stores two projections of it:
//
//   • `body`        — Markdown (human-readable). Drives timeline previews, search,
//                     and the human-readable export (privacy invariant #3).
//   • `bodyArchive` — a lossless JSON archive of the `AttributedString` (SwiftUI
//                     attribute scope), so reopening the composer restores exactly
//                     what the editor produced — including styling Markdown can't
//                     carry, such as text color.
//
// On load we prefer the archive and fall back to parsing `body` as Markdown, so
// pre-Stage-4 rows (archive = nil) and externally-authored Markdown both open.
public enum RichTextCodec {

    // MARK: Markdown → AttributedString (Foundation-native import)

    /// Parse a Markdown string into styled text. Inline-only (bold/italic/links)
    /// with whitespace preserved, so a journal body round-trips without gaining
    /// block chrome. Never throws — malformed Markdown degrades to literal text.
    public static func attributedString(fromMarkdown markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: markdown, options: options))
            ?? AttributedString(markdown)
    }

    // MARK: AttributedString → Markdown (export projection)

    /// Render styled text back to Markdown, emitting `**bold**`, `*italic*`, and
    /// `[text](url)` for the inline intents the composer produces. Foundation has
    /// no built-in export, so we walk the runs ourselves. Emphasis markers hug the
    /// non-whitespace span (`**bold**`, not `** bold **`) to stay valid Markdown.
    public static func markdown(from text: AttributedString) -> String {
        var out = ""
        for run in text.runs {
            let raw = String(text[run.range].characters)
            if raw.isEmpty { continue }

            if let url = run.link {
                out += "[\(escapeLinkText(raw))](\(url.absoluteString))"
                continue
            }

            let intent = run.inlinePresentationIntent ?? []
            let bold = intent.contains(.stronglyEmphasized)
            let italic = intent.contains(.emphasized)
            let marker = bold && italic ? "***" : bold ? "**" : italic ? "*" : ""
            out += marker.isEmpty ? raw : wrap(raw, in: marker)
        }
        return out
    }

    // MARK: Lossless archive (fidelity source)

    /// Encode the full `AttributedString` (SwiftUI attribute scope) to JSON.
    public static func archive(_ text: AttributedString) throws -> Data {
        try JSONEncoder().encode(Archive(text: text))
    }

    /// Decode an archive produced by ``archive(_:)``.
    public static func attributedString(fromArchive data: Data) throws -> AttributedString {
        try JSONDecoder().decode(Archive.self, from: data).text
    }

    // MARK: Combined helpers

    /// Both persisted projections for a save. The archive is best-effort — if it
    /// somehow fails to encode, the Markdown projection still preserves the text
    /// so no content is lost.
    public static func serialize(_ text: AttributedString) -> (markdown: String, archive: Data?) {
        (markdown(from: text), try? archive(text))
    }

    /// Restore the editor's text: prefer the lossless archive, fall back to
    /// parsing the Markdown `body` (legacy rows / external Markdown).
    public static func load(archive data: Data?, markdown body: String) -> AttributedString {
        if let data, let restored = try? attributedString(fromArchive: data) {
            return restored
        }
        return attributedString(fromMarkdown: body)
    }

    /// Collapse a Markdown `body` to plain, formatting-free text for previews and
    /// search. Uses swift-markdown so `**bold**`, `[links](…)`, etc. render as the
    /// words a reader sees, never the raw syntax.
    public static func plainText(fromMarkdown markdown: String) -> String {
        var walker = PlainTextWalker()
        walker.visit(Document(parsing: markdown))
        return walker.text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    /// Codable wrapper that pins the encoding to the SwiftUI attribute scope, so
    /// SwiftUI-only attributes (foreground color, font) survive the round-trip
    /// alongside the Foundation ones (links, emphasis).
    private struct Archive: Codable {
        @CodableConfiguration(from: AttributeScopes.SwiftUIAttributes.self)
        var text = AttributedString()
    }

    private static func wrap(_ raw: String, in marker: String) -> String {
        let leading = raw.prefix { $0.isWhitespace }
        let trailing = raw.reversed().prefix { $0.isWhitespace }.reversed()
        let core = raw.dropFirst(leading.count).dropLast(trailing.count)
        guard !core.isEmpty else { return raw }
        return "\(leading)\(marker)\(core)\(marker)\(String(trailing))"
    }

    private static func escapeLinkText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "]", with: "\\]")
    }
}

// MARK: - Plain-text extraction (swift-markdown)

/// Flattens a Markdown document to reader-facing text: keeps `Text`/`InlineCode`
/// content, turns breaks and block boundaries into spaces.
private struct PlainTextWalker: MarkupWalker {
    var text = ""

    mutating func visitText(_ text: Markdown.Text) { self.text += text.string }
    mutating func visitInlineCode(_ inlineCode: InlineCode) { text += inlineCode.code }
    mutating func visitSoftBreak(_ softBreak: SoftBreak) { text += " " }
    mutating func visitLineBreak(_ lineBreak: LineBreak) { text += " " }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if !text.isEmpty { text += " " }
        descendInto(paragraph)
    }
}
