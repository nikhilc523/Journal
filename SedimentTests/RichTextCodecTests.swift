import Testing
import Foundation
import SwiftUI
@testable import Sediment

/// Stage 4 serialization tests. The composer's rich text must survive two
/// projections losslessly: Markdown (`body`, human-readable) for what Markdown can
/// carry, and the JSON archive (`bodyArchive`) for full fidelity including color.
@Suite struct RichTextCodecTests {

    // MARK: Markdown export (AttributedString → String)

    @Test func exportsBoldItalicAndLinks() {
        var text = AttributedString("Felt the ")
        var bold = AttributedString("fear")
        bold.inlinePresentationIntent = .stronglyEmphasized
        text.append(bold)
        text.append(AttributedString(" and did it "))
        var italic = AttributedString("anyway")
        italic.inlinePresentationIntent = .emphasized
        text.append(italic)

        #expect(RichTextCodec.markdown(from: text) == "Felt the **fear** and did it *anyway*")
    }

    @Test func exportsLinksAsMarkdown() {
        var link = AttributedString("Point-Free")
        link.link = URL(string: "https://pointfree.co")
        #expect(RichTextCodec.markdown(from: link) == "[Point-Free](https://pointfree.co)")
    }

    @Test func emphasisMarkersHugNonWhitespace() {
        // `** bold **` is not valid Markdown emphasis — the markers must hug the word.
        var bold = AttributedString(" spaced ")
        bold.inlinePresentationIntent = .stronglyEmphasized
        #expect(RichTextCodec.markdown(from: bold) == " **spaced** ")
    }

    // MARK: Markdown import (String → AttributedString)

    @Test func importsInlineStyles() {
        let parsed = RichTextCodec.attributedString(fromMarkdown: "a **b** and *c*")
        let bold = parsed.runs.contains { ($0.inlinePresentationIntent ?? []).contains(.stronglyEmphasized) }
        let italic = parsed.runs.contains { ($0.inlinePresentationIntent ?? []).contains(.emphasized) }
        #expect(bold)
        #expect(italic)
        #expect(String(parsed.characters) == "a b and c")
    }

    @Test func malformedMarkdownDegradesToText() {
        // Never throws — worst case is the literal string.
        let parsed = RichTextCodec.attributedString(fromMarkdown: "no [closing](")
        #expect(!String(parsed.characters).isEmpty)
    }

    // MARK: Round-trip

    @Test func markdownRoundTripPreservesStyles() {
        let source = "Launched the **side hustle** today, felt *the fear*, see [notes](https://x.co)"
        let out = RichTextCodec.markdown(from: RichTextCodec.attributedString(fromMarkdown: source))
        #expect(out.contains("**side hustle**"))
        #expect(out.contains("*the fear*"))
        #expect(out.contains("[notes](https://x.co)"))
    }

    // MARK: Lossless archive (full fidelity, incl. color)

    @Test func archiveRoundTripPreservesFoundationAttributes() throws {
        var text = AttributedString("emphatic")
        text.inlinePresentationIntent = .stronglyEmphasized
        let restored = try RichTextCodec.attributedString(fromArchive: RichTextCodec.archive(text))
        #expect(restored == text)
    }

    @Test func archivePreservesColorThatMarkdownCannot() throws {
        var text = AttributedString("sunset")
        text.foregroundColor = .orange
        let restored = try RichTextCodec.attributedString(fromArchive: RichTextCodec.archive(text))
        #expect(restored == text)
        // Markdown alone drops the color, proving why the archive exists.
        #expect(RichTextCodec.markdown(from: text) == "sunset")
    }

    // MARK: Combined loader

    @Test func loadPrefersArchiveOverMarkdown() throws {
        var text = AttributedString("kept")
        text.foregroundColor = .red
        let archive = try RichTextCodec.archive(text)
        #expect(RichTextCodec.load(archive: archive, markdown: "IGNORED") == text)
    }

    @Test func loadFallsBackToMarkdownWhenNoArchive() {
        let restored = RichTextCodec.load(archive: nil, markdown: "**bold**")
        #expect(String(restored.characters) == "bold")
        #expect(restored.runs.contains { ($0.inlinePresentationIntent ?? []).contains(.stronglyEmphasized) })
    }

    @Test func loadIgnoresCorruptArchiveAndUsesMarkdown() {
        let restored = RichTextCodec.load(archive: Data([0xDE, 0xAD]), markdown: "plain")
        #expect(String(restored.characters) == "plain")
    }

    // MARK: Plain-text projection (previews / search)

    @Test func plainTextStripsFormatting() {
        #expect(RichTextCodec.plainText(fromMarkdown: "**Bold** and [a link](https://x.co)") == "Bold and a link")
    }

    @Test func entryPreviewStripsMarkdownAndFallsBack() {
        #expect(entryPreview("**Launched** the [hustle](https://x.co)") == "Launched the hustle")
        #expect(entryPreview("   \n  ") == "New entry")
    }
}
