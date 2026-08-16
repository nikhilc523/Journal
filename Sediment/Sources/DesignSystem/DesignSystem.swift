import SwiftUI

// MARK: - Design System (Sediment)
//
// "Warm Oatmeal Minimalism" — the single source of truth for every visual
// token in the app. Values are copied **verbatim** from
// `docs/design/design-tokens.md`. Never hard-code a color/spacing/radius in a
// view: if a token is missing, add it to the tokens doc first, then here.
//
// Namespaced under `DS` so call sites read like `DS.Color.clay`, `DS.Radius.card`.

public enum DS {}

// MARK: - Color

public extension DS {
    enum Colors {
        // Neutrals — oatmeal / sand (chrome, surfaces, text)
        public static let canvasTop = Color(hex: 0xF3F0E9)
        public static let canvasBottom = Color(hex: 0xE7E2D7)
        public static let surface = Color(hex: 0xFBF9F4)
        public static let surfaceRaised = Color(hex: 0xFFFFFF)
        public static let surfaceSunken = Color(hex: 0xECEAE3)
        public static let hairline = Color(hex: 0xE0DDD3)
        public static let greige = Color(hex: 0xD0D1CC)

        // Ink (text) — warm, never pure black
        public static let ink = Color(hex: 0x2B2925)
        public static let inkSecondary = Color(hex: 0x6B675E)
        public static let inkTertiary = Color(hex: 0x9A968C)
        public static let inkOnAccent = Color(hex: 0xFBF9F4)

        // Primary accent — clay / terracotta (all interactive/active states)
        public static let clay = Color(hex: 0xB27C56)
        public static let clayPressed = Color(hex: 0x9C6A46)
        public static let claySoft = Color(hex: 0xEFE2D6)

        // Semantic
        public static let success = Color(hex: 0x7FA98A)
        public static let warning = Color(hex: 0xC89B5A)
        public static let danger = Color(hex: 0xB5675A)

        // Warm shadow tint
        public static let shadowTint = Color(hex: 0x3B3226)
    }
}

// MARK: - Mood pastels
//
// Each mood binds to a `fill` (face/chip tint) and a `wash` (card background
// when that mood is set). Pastels carry MEANING only — never chrome.

public extension DS {
    enum Mood: Int, CaseIterable, Identifiable, Sendable {
        case sage = 0    // content / calm
        case amber       // happy / bright
        case rose        // tender / anxious
        case sky         // calm / clear
        case lavender    // low / reflective
        case lilac       // dreamy / creative

        public var id: Int { rawValue }

        public var fill: Color {
            switch self {
            case .sage: return Color(hex: 0xAEC9B8)
            case .amber: return Color(hex: 0xE0CE9F)
            case .rose: return Color(hex: 0xD6B2A7)
            case .sky: return Color(hex: 0xA9C1CD)
            case .lavender: return Color(hex: 0xB4B2D2)
            case .lilac: return Color(hex: 0xC2B7D3)
            }
        }

        public var wash: Color {
            switch self {
            case .sage: return Color(hex: 0xE4EDE7)
            case .amber: return Color(hex: 0xF3ECDA)
            case .rose: return Color(hex: 0xF1E4DE)
            case .sky: return Color(hex: 0xE1EAEE)
            case .lavender: return Color(hex: 0xE9E8F1)
            case .lilac: return Color(hex: 0xEBE6F0)
            }
        }

        /// Human-readable label (VoiceOver + UI copy).
        public var label: String {
            switch self {
            case .sage: return "Calm"
            case .amber: return "Happy"
            case .rose: return "Tender"
            case .sky: return "Clear"
            case .lavender: return "Reflective"
            case .lilac: return "Dreamy"
            }
        }
    }
}

// MARK: - Radius (from primary.jpg — very rounded)

public extension DS {
    enum Radius {
        public static let card: CGFloat = 24
        public static let sheet: CGFloat = 28
        public static let capsule: CGFloat = 999
        public static let button: CGFloat = 16
        public static let chip: CGFloat = 12
        public static let input: CGFloat = 18
        public static let fab: CGFloat = 999
    }
}

// MARK: - Spacing (4pt grid)

public extension DS {
    enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32

        /// Screen horizontal inset.
        public static let screenInset: CGFloat = 20
        /// Vertical gap between stacked cards.
        public static let cardGap: CGFloat = 12
        /// Padding inside a card.
        public static let cardPadding: CGFloat = 16

        // Small optical metrics — deliberately off the 4pt display grid, kept here
        // as named tokens so views never hardcode raw literals (repo rule).
        /// Gap between a chip's leading icon and its label.
        public static let chipGap: CGFloat = 6
        /// Horizontal padding inside an attachment chip.
        public static let chipPaddingH: CGFloat = 10
        /// Vertical padding inside an attachment chip.
        public static let chipPaddingV: CGFloat = 6
        /// Top nudge that optically centers a todo title against the 44pt checkbox.
        public static let todoTitleOpticalTop: CGFloat = 10
    }
}

// MARK: - Typography
//
// SF Pro for UI chrome; New York (serif) for journal body/reading. Everything
// scales with Dynamic Type via `.system(size:relativeTo:)`.

public extension DS {
    enum Typography {
        /// Serif journal body font (New York). System fonts created with
        /// `.system(size:)` scale with Dynamic Type automatically.
        public static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }

        /// SF Pro UI font.
        public static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        // Named roles (design-tokens.md §4).
        public static let largeTitle = ui(34, weight: .bold)
        public static let title = ui(22, weight: .semibold)
        public static let headline = ui(17, weight: .semibold)
        public static let body = serif(17, weight: .regular)
        public static let bodySans = ui(17, weight: .regular)
        public static let callout = ui(16, weight: .regular)
        public static let subhead = ui(15, weight: .regular)
        public static let meta = ui(13, weight: .medium)
        public static let caption = ui(12, weight: .regular)
        public static let sectionLabel = ui(12, weight: .semibold)
    }
}

// MARK: - Shadow (soft, low, warm-tinted)

public extension DS {
    struct ShadowStyle: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let y: CGFloat

        /// design-tokens.md §5 expresses shadows as y / blur / opacity. SwiftUI's
        /// shadow `radius` ≈ blur / 2, so we halve the blur here.
        init(blur: CGFloat, y: CGFloat, opacity: Double) {
            self.color = DS.Colors.shadowTint.opacity(opacity)
            self.radius = blur / 2
            self.y = y
        }

        public static let card = ShadowStyle(blur: 8, y: 2, opacity: 0.06)
        public static let raised = ShadowStyle(blur: 24, y: 8, opacity: 0.08)
        public static let fab = ShadowStyle(blur: 18, y: 6, opacity: 0.12)
    }
}

public extension View {
    /// Apply a design-system shadow token.
    func dsShadow(_ style: DS.ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }
}

// MARK: - Motion (springs, not durations)

public extension DS {
    enum Motion {
        public static let tap: Animation = .snappy(duration: 0.25)
        public static let transition: Animation = .smooth(duration: 0.35)
        public static let moodPop: Animation = .spring(response: 0.4, dampingFraction: 0.6)
        /// Scale applied on press (paired with `.tap`).
        public static let pressScale: CGFloat = 0.96
    }
}

// MARK: - Glass (Liquid Glass helper)
//
// Floating chrome (top buttons, tab bar, FAB) uses Liquid Glass. Cards stay on
// a frosted `surface` so text is legible over the sand canvas.

public extension View {
    /// Liquid Glass background clipped to a shape. On iOS 26 this uses the native
    /// `.glassEffect`; the capsule/roundedRect shape is caller-provided. Named
    /// `dsGlass` to avoid overloading Apple's `glassEffect(_:in:)`.
    func dsGlass(in shape: some Shape = Capsule()) -> some View {
        glassEffect(.regular, in: shape)
    }
}

// MARK: - Hex Color initializer

public extension Color {
    /// Create a Color from a 24-bit RGB hex literal, e.g. `Color(hex: 0xB27C56)`.
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
