import SwiftUI

// MARK: - Color Tokens

extension Color {
    // Backgrounds
    static let bgPrimary = Color("bgPrimary")
    static let bgSecondary = Color("bgSecondary")
    static let bgSidebar = Color("bgSidebar")

    // Text
    static let textPrimary = Color("textPrimary")
    static let textSecondary = Color("textSecondary")

    // Semantic
    static let accent = Color("accentBlue") // Gold: #E5BF3F
    static let positive = Color("positive")
    static let negative = Color("negative")
    static let warning = Color("warning")

    // Gold palette
    static let gold = Color(hex: "E5BF3F")
    static let goldLight = Color(hex: "F2D978")
    static let goldSubtle = Color(hex: "E5BF3F").opacity(0.15)

    // Category palette (refined for dark backgrounds)
    static let categoryColors: [Color] = [
        Color(hex: "5B9CF6"),
        Color(hex: "4ECB71"),
        Color(hex: "F0A040"),
        Color(hex: "F06060"),
        Color(hex: "A06FF0"),
        Color(hex: "F05A7E"),
        Color(hex: "5AC8E8"),
        Color(hex: "E8D040"),
        Color(hex: "C4A882"),
        Color(hex: "7070E8"),
        Color(hex: "F08098"),
        Color(hex: "B09878"),
    ]
}

// MARK: - Hex Color Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

enum AppFont {
    static func hero(_ size: CGFloat = 42) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func title(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func heading(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func mono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

// MARK: - Spacing

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

// MARK: - Card Style (Glassmorphism)

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.xl)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(colorScheme == .dark
                        ? Color(hex: "1C1C20").opacity(0.85)
                        : Color.white.opacity(0.9))
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .strokeBorder(
                                LinearGradient(
                                    colors: colorScheme == .dark
                                        ? [Color.white.opacity(0.08), Color.white.opacity(0.02)]
                                        : [Color.white.opacity(0.7), Color.black.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: colorScheme == .dark
                            ? .black.opacity(0.3)
                            : .black.opacity(0.06),
                        radius: 12, y: 4
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? .clear
                            : .black.opacity(0.02),
                        radius: 1, y: 1
                    )
            }
    }
}

extension View {
    func card() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Accent Glow Card

struct AccentGlowCardModifier: ViewModifier {
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.xl)
            .background {
                ZStack {
                    // Subtle glow behind
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(accent.opacity(colorScheme == .dark ? 0.06 : 0.03))

                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(colorScheme == .dark
                            ? Color(hex: "1C1C20").opacity(0.9)
                            : Color.white.opacity(0.92))
                        .overlay {
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            accent.opacity(colorScheme == .dark ? 0.25 : 0.15),
                                            accent.opacity(colorScheme == .dark ? 0.05 : 0.03),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                }
                .shadow(
                    color: accent.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    radius: 16, y: 4
                )
                .shadow(
                    color: colorScheme == .dark
                        ? .black.opacity(0.2)
                        : .black.opacity(0.04),
                    radius: 8, y: 2
                )
            }
    }
}

extension View {
    func accentGlowCard(_ accent: Color) -> some View {
        modifier(AccentGlowCardModifier(accent: accent))
    }
}

// MARK: - Hover Scale Effect

struct HoverScaleModifier: ViewModifier {
    let scale: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverScale(_ scale: CGFloat = 1.015) -> some View {
        modifier(HoverScaleModifier(scale: scale))
    }
}

// MARK: - Hover Highlight Effect

struct HoverHighlightModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.04)
                            : Color.black.opacity(0.03))
                }
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlightModifier())
    }
}

// MARK: - Gradient Progress Bar

struct GradientProgressBar: View {
    let progress: Double
    let colors: [Color]
    var height: CGFloat = 6
    var showGlow: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.06))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * min(progress, 1.0)))
                    .shadow(
                        color: showGlow ? colors.first?.opacity(0.4) ?? .clear : .clear,
                        radius: 4, y: 0
                    )
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(AppFont.heading())
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}

// MARK: - Shimmer Effect (for loading states)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.08),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.3 + geo.size.width * 1.6 * phase)
                    .animation(
                        .linear(duration: 1.8).repeatForever(autoreverses: false),
                        value: phase
                    )
                }
                .clipped()
            }
            .onAppear { phase = 1 }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Staggered Entrance Animation

struct StaggeredEntrance: ViewModifier {
    let index: Int
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .scaleEffect(appeared ? 1 : 0.97, anchor: .top)
            .animation(
                .spring(response: 0.45, dampingFraction: 0.8)
                    .delay(Double(index) * delay),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

extension View {
    func staggered(index: Int, delay: Double = 0.06) -> some View {
        modifier(StaggeredEntrance(index: index, delay: delay))
    }
}

// MARK: - Amount Formatting

struct CurrencyFormatter {
    static let shared = CurrencyFormatter()

    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "fr_FR")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    func format(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "0,00 \u{20AC}"
    }
}

extension Decimal {
    var formatted: String {
        CurrencyFormatter.shared.format(self)
    }
}
