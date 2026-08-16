import SwiftUI

/// A small chip representing an attachment (photo / video / audio / file) or an
/// inline indicator. Sunken surface, chip radius, leading SF Symbol + label.
public struct AttachmentChip: View {
    public enum Kind: Sendable {
        case photo, video, audio, file

        var systemImage: String {
            switch self {
            case .photo: return "photo"
            case .video: return "video"
            case .audio: return "waveform"
            case .file: return "doc"
            }
        }

        var accessibilityName: String {
            switch self {
            case .photo: return "Photo"
            case .video: return "Video"
            case .audio: return "Audio"
            case .file: return "File"
            }
        }
    }

    private let kind: Kind
    private let title: String?

    public init(_ kind: Kind, title: String? = nil) {
        self.kind = kind
        self.title = title
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.chipGap) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 13, weight: .medium))
            if let title {
                Text(title)
                    .font(DS.Typography.caption)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(DS.Colors.inkSecondary)
        .padding(.horizontal, DS.Spacing.chipPaddingH)
        .padding(.vertical, DS.Spacing.chipPaddingV)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(DS.Colors.surfaceSunken)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.map { "\(kind.accessibilityName): \($0)" } ?? kind.accessibilityName)
        .accessibilityIdentifier("attachmentChip.\(kind.accessibilityName)")
    }
}

#Preview {
    GradientCanvas {
        HStack(spacing: 8) {
            AttachmentChip(.photo, title: "3")
            AttachmentChip(.audio, title: "0:42")
            AttachmentChip(.file, title: "report.pdf")
        }
    }
}
