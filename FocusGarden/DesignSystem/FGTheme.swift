import SwiftUI
#if !SKIP && canImport(UIKit)
import UIKit
#endif

// MARK: - FGTheme: Dark Dramatic Gothic & Stained Glass System

enum FGTheme {
    // Core Obsidian & Stone Motifs
    static let obsidian = Color(red: 0.035, green: 0.025, blue: 0.065) // Deep void midnight black
    static let stoneSurface = Color(red: 0.08, green: 0.065, blue: 0.13) // Carved dark obsidian stone
    static let stoneElevated = Color(red: 0.125, green: 0.10, blue: 0.19) // Raised altar dais
    static let stoneBevel = Color(red: 0.22, green: 0.18, blue: 0.32) // Chiseled stone highlight

    // Cathedral Stained Glass & Jewel Accents
    static let stainedGlassViolet = Color(red: 0.76, green: 0.44, blue: 0.98) // Glowing cathedral amethyst
    static let stainedGlassDeepPurple = Color(red: 0.38, green: 0.14, blue: 0.62) // Royal bishop purple
    static let stainedGlassRuby = Color(red: 0.94, green: 0.24, blue: 0.38) // Gothic crimson / ruby
    static let stainedGlassSapphire = Color(red: 0.32, green: 0.58, blue: 0.98) // Celestial stained glass blue
    static let stainedGlassAmber = Color(red: 0.96, green: 0.76, blue: 0.32) // Warm altar candle / gold
    static let stainedGlassEmerald = Color(red: 0.28, green: 0.82, blue: 0.62) // Cloister jade / emerald

    // Semantic Mapping
    static let background = obsidian
    static let surface = stoneSurface
    static let green = stainedGlassViolet // Primary jewel glow across the app
    static let purple = stainedGlassViolet
    static let deepPurple = stainedGlassDeepPurple
    static let ruby = stainedGlassRuby
    static let sapphire = stainedGlassSapphire
    static let amber = stainedGlassAmber
    static let danger = stainedGlassRuby
    static let muted = Color(red: 0.62, green: 0.58, blue: 0.72) // Weathered parchment lavender
    static let stoneText = Color(red: 0.88, green: 0.85, blue: 0.94) // Alabaster stone text
    static let ink = Color(red: 0.035, green: 0.025, blue: 0.065) // Obsidian dark for buttons

    // Structural Geometry
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 14
    static let badgeCornerRadius: CGFloat = 8

    // MARK: - Typography

    /// Blackletter / Dramatic Gothic Serif for titles, headers, and chapter marks
    static func gothic(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 32
        case .title: size = 26
        case .title2: size = 22
        case .title3: size = 20
        case .headline: size = 17
        case .body: size = 16
        case .callout: size = 15
        case .subheadline: size = 15
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        default: size = 16
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// Alias for dramatic gothic serif font
    static func blackletter(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        gothic(style, weight: weight)
    }

    /// Monospaced Runic / Data Font
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 32
        case .title: size = 26
        case .title2: size = 22
        case .title3: size = 20
        case .headline: size = 17
        case .body: size = 16
        case .callout: size = 15
        case .subheadline: size = 15
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        default: size = 16
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    /// Rounded Auxiliary Font
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .medium) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 32
        case .title: size = 26
        case .title2: size = 22
        case .title3: size = 20
        case .headline: size = 17
        case .body: size = 16
        case .callout: size = 15
        case .subheadline: size = 15
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        default: size = 16
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Motion Feedback & Micro-interactions

    /// Triggers tactile haptic feedback on devices that support it
    static func triggerHaptic() {
        #if !SKIP && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// Stained glass luminous multi-tone gradient sheen
    static func stainedGlassSheen(accent: Color = stainedGlassViolet) -> LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.24),
                stainedGlassRuby.opacity(0.10),
                stainedGlassSapphire.opacity(0.14),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Carved stone slab background gradient
    static var stoneSlabGradient: LinearGradient {
        LinearGradient(
            colors: [
                stoneElevated,
                stoneSurface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers

extension View {
    /// Disables default drop shadows on iOS labels
    func fgPlain() -> some View {
        shadow(color: .clear, radius: 0, x: 0, y: 0)
    }

    /// Stained glass translucent pill badge with chiselled border
    func fgBadge(color: Color = FGTheme.stainedGlassViolet, opacity: Double = 0.16) -> some View {
        self
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: FGTheme.badgeCornerRadius, style: .continuous)
                    .fill(color.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FGTheme.badgeCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.55), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    /// Gothic stone plate background modifier with stained glass glow
    func fgStonePlate(accent: Color = FGTheme.stainedGlassViolet, cornerRadius: CGFloat = FGTheme.cornerRadius) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FGTheme.stoneSlabGradient)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FGTheme.stainedGlassSheen(accent: accent))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.4),
                                FGTheme.stoneBevel.opacity(0.6),
                                accent.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 5)
    }

    /// Motion-feedback tactile spring button styling
    func fgTactileButton(fill: Bool = true, accent: Color = FGTheme.stainedGlassViolet, cornerRadius: CGFloat = FGTheme.buttonCornerRadius) -> some View {
        #if !SKIP
        return self.buttonStyle(FGTactileButtonStyle(fill: fill, accent: accent, cornerRadius: cornerRadius))
        #else
        return self.buttonStyle(.plain)
        #endif
    }
}

#if !SKIP
// MARK: - Interactive Button Style with Spring Motion Feedback

struct FGTactileButtonStyle: ButtonStyle {
    var fill: Bool
    var accent: Color
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(Animation.spring(response: 0.24, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
#endif

// MARK: - Gothic Stone Card

struct FGCard<Content: View>: View {
    var accent: Color = FGTheme.stainedGlassViolet
    var cornerRadius: CGFloat = FGTheme.cornerRadius
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FGTheme.stoneSlabGradient)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FGTheme.stainedGlassSheen(accent: accent))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.45),
                                FGTheme.stoneBevel.opacity(0.6),
                                accent.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 5)
    }
}

// MARK: - Gothic Interactive Button

struct FGButton: View {
    var title: String
    var accent: Color = FGTheme.stainedGlassViolet
    var fill: Bool = true
    var cornerRadius: CGFloat = FGTheme.buttonCornerRadius
    var action: () -> Void

    var body: some View {
        Button(action: {
            FGTheme.triggerHaptic()
            action()
        }) {
            Text(title)
                .font(FGTheme.mono(.subheadline, weight: .bold))
                .foregroundStyle(fill ? FGTheme.ink : accent)
                .fgPlain()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            fill ?
                            LinearGradient(
                                colors: [
                                    accent,
                                    accent.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.14),
                                    accent.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accent.opacity(fill ? 0.6 : 0.4),
                                    FGTheme.stoneBevel.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: fill ? accent.opacity(0.32) : Color.clear, radius: 10, x: 0, y: 4)
        }
        .fgTactileButton(fill: fill, accent: accent, cornerRadius: cornerRadius)
    }
}

// MARK: - Screen Scaffold with Atmospheric Vignette

struct FGScreen<Content: View>: View {
    var title: String
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                // Ambient cathedral glow vignette
                RadialGradient(
                    colors: [
                        FGTheme.deepPurple.opacity(0.22),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 30,
                    endRadius: 460
                )
                .ignoresSafeArea()

                content
            }
            .navigationTitle(title)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if let trailing {
                    ToolbarItem(placement: .primaryAction) { trailing }
                }
            }
            #if !os(macOS)
            .toolbarBackground(FGTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
        }
    }
}

// MARK: - Shared Utilities

extension Array {
    /// Safely accesses the element at the specified index, returning `nil` if out of bounds.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Int {
    /// Formats a minute count into human-readable duration like "45m" or "2h 15m".
    var durationFormatted: String {
        let hours = self / 60
        let mins = self % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

extension TimeInterval {
    /// Formats a second count into a monospaced clock display like "25:00" or "04:32".
    var clockFormatted: String {
        let total = max(0, Int(rounded()))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

