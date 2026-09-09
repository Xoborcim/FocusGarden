import SwiftUI

enum FGTheme {
    static let background = Color.black
    static let surface = Color(red: 0.05, green: 0.06, blue: 0.05)
    static let green = Color(red: 0.20, green: 0.98, blue: 0.42)
    static let amber = Color(red: 1.00, green: 0.75, blue: 0.12)
    static let danger = Color(red: 1.00, green: 0.28, blue: 0.28)
    static let muted = Color(white: 0.58)
    static let ink = Color.black
    static let borderWidth: CGFloat = 2

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
}

extension View {
    /// iOS 26 applies a default drop shadow to prominent text; keep type flat.
    func fgPlain() -> some View {
        shadow(color: .clear, radius: 0, x: 0, y: 0)
    }
}

struct FGCard<Content: View>: View {
    var accent: Color = FGTheme.green
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FGTheme.surface)
            .overlay(Rectangle().stroke(accent, lineWidth: FGTheme.borderWidth))
    }
}

struct FGButton: View {
    var title: String
    var accent: Color = FGTheme.green
    var fill: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FGTheme.mono(.subheadline, weight: .bold))
                .foregroundStyle(fill ? FGTheme.ink : accent)
                .fgPlain()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(fill ? accent : Color.clear)
                .overlay(Rectangle().stroke(accent, lineWidth: FGTheme.borderWidth))
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

