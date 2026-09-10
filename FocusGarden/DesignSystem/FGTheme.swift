import SwiftUI

enum FGTheme {
    // Night garden palette — deep indigo base, soft sage-lavender accents, warm gold
    static let background = Color(red: 0.06, green: 0.05, blue: 0.12)
    static let surface = Color(red: 0.09, green: 0.08, blue: 0.16)
    static let green = Color(red: 0.55, green: 0.82, blue: 0.60)
    static let amber = Color(red: 0.96, green: 0.78, blue: 0.38)
    static let danger = Color(red: 0.92, green: 0.38, blue: 0.35)
    static let muted = Color(red: 0.58, green: 0.55, blue: 0.65)
    static let ink = Color(red: 0.06, green: 0.05, blue: 0.12)
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 14
    static let badgeCornerRadius: CGFloat = 8

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
}

extension View {
    /// iOS applies a default drop shadow to prominent text; keep type flat.
    func fgPlain() -> some View {
        shadow(color: .clear, radius: 0, x: 0, y: 0)
    }

    /// Soft UI pill badge modifier with translucent frosted background and soft border
    func fgBadge(color: Color = FGTheme.green, opacity: Double = 0.14) -> some View {
        self
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: FGTheme.badgeCornerRadius, style: .continuous)
                    .fill(color.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FGTheme.badgeCornerRadius, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

struct FGCard<Content: View>: View {
    var accent: Color = FGTheme.green
    var cornerRadius: CGFloat = FGTheme.cornerRadius
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                FGTheme.surface,
                                FGTheme.surface.opacity(0.88)
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
                                accent.opacity(0.35),
                                accent.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 4)
    }
}

struct FGButton: View {
    var title: String
    var accent: Color = FGTheme.green
    var fill: Bool = true
    var cornerRadius: CGFloat = FGTheme.buttonCornerRadius
    var action: () -> Void

    var body: some View {
        Button(action: action) {
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
                                colors: [accent, accent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [accent.opacity(0.08), accent.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(accent.opacity(fill ? 0.35 : 0.5), lineWidth: 1)
                )
                .shadow(color: fill ? accent.opacity(0.25) : Color.clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct FGScreen<Content: View>: View {
    var title: String
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()
                content
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let trailing {
                    ToolbarItem(placement: .topBarTrailing) { trailing }
                }
            }
            .toolbarBackground(FGTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Shared Utilities

extension Collection {
    /// Safely accesses the element at the specified index, returning `nil` if out of bounds.
    subscript(safe index: Index) -> Element? {
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

