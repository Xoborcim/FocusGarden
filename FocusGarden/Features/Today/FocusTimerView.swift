import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct FocusTimerView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Course.code) var courses: [Course]
    @Query(sort: \ActivityLog.timestamp, order: .reverse) private var recentLogs: [ActivityLog]

    @State var title: String = ""
    @State var category: ActivityCategory = .study
    @State var selectedCourseID: UUID?
    @State var timerPresetMinutes: Int = 25
    @State var isRunning: Bool = false
    @State var isPaused: Bool = false
    @State var secondsRemaining: Int = 25 * 60
    @State var elapsedSeconds: Int = 0
    @State var showingLogCompletion: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    if !isRunning {
                        setupStateView
                    } else {
                        activeTimerStateView
                    }
                }
                .padding(24)
            }
            .navigationTitle(isRunning ? "FOCUS" : "START FOCUS")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isRunning ? "Cancel" : "Close") {
                        dismiss()
                    }
                    .font(FGTheme.mono(.subheadline))
                    .foregroundStyle(FGTheme.muted)
                }
            }
            .onReceive(timer) { _ in
                guard isRunning && !isPaused else { return }
                elapsedSeconds += 1
                if secondsRemaining > 0 {
                    secondsRemaining -= 1
                }
            }
            .sheet(isPresented: $showingLogCompletion, onDismiss: { dismiss() }) {
                QuickLogView(
                    initialTitle: title.isEmpty ? "Focus session" : title,
                    initialCategory: category,
                    initialDuration: max(1, Int((Double(elapsedSeconds) / 60.0).rounded())),
                    initialCourse: courses.first(where: { $0.id == selectedCourseID })
                )
            }
        }
    }

    // MARK: - Setup View
    private var setupStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Activity Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVITY NAME")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.green)

                    TextField("What are you focusing on?", text: $title)
                        .font(FGTheme.mono(.body))
                        .padding(12)
                        .background(FGTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(FGTheme.green.opacity(0.6), lineWidth: 1)
                        )
                        .foregroundStyle(.white)
                }

                // Recent Activity Chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("QUICK SELECTION")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.muted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(displayedRecentTitles, id: \.self) { item in
                                Button {
                                    title = item
                                    if let match = courses.first(where: { $0.code.uppercased() == item.uppercased() }) {
                                        selectedCourseID = match.id
                                    }
                                } label: {
                                    Text(item)
                                        .font(FGTheme.mono(.caption, weight: .bold))
                                        .foregroundStyle(title.uppercased() == item.uppercased() ? FGTheme.green : .white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(FGTheme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(title.uppercased() == item.uppercased() ? FGTheme.green : FGTheme.muted.opacity(0.3), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Category
                VStack(alignment: .leading, spacing: 6) {
                    Text("CATEGORY")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.amber)

                    HStack(spacing: 8) {
                        ForEach([ActivityCategory.study, .project, .exercise, .leisure]) { cat in
                            let selected = category == cat
                            Button {
                                category = cat
                            } label: {
                                Text(cat.displayName)
                                    .font(FGTheme.mono(.caption, weight: .bold))
                                    .foregroundStyle(selected ? FGTheme.ink : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selected ? FGTheme.amber : FGTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Duration Presets
                VStack(alignment: .leading, spacing: 6) {
                    Text("TARGET INTERVAL")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.green)

                    HStack(spacing: 8) {
                        ForEach([25, 45, 60, 90], id: \.self) { mins in
                            let selected = timerPresetMinutes == mins
                            Button {
                                timerPresetMinutes = mins
                                secondsRemaining = mins * 60
                            } label: {
                                Text("\(mins)m")
                                    .font(FGTheme.mono(.subheadline, weight: .bold))
                                    .foregroundStyle(selected ? FGTheme.ink : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selected ? FGTheme.green : FGTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 20)

                // Start Button
                Button {
                    startTimer()
                } label: {
                    Text("START FOCUS")
                        .font(FGTheme.mono(.headline, weight: .bold))
                        .foregroundStyle(FGTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(FGTheme.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: FGTheme.green.opacity(0.3), radius: 8, x: 0, y: 3)
                }
            }
        }
    }

    // MARK: - Active Timer View
    private var activeTimerStateView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Stained Glass Rosace Timer Dial
            ZStack {
                // Outer Carved Stone Ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [FGTheme.stoneBevel, FGTheme.stoneSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 16
                    )
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 6)

                // Stained Glass Cathedral Aura
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                FGTheme.stainedGlassViolet.opacity(isPaused ? 0.08 : 0.26),
                                FGTheme.stainedGlassRuby.opacity(isPaused ? 0.04 : 0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                // Stained Glass Rose Perimeter Tracery
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                FGTheme.stainedGlassViolet,
                                FGTheme.stainedGlassRuby,
                                FGTheme.stainedGlassSapphire,
                                FGTheme.stainedGlassAmber,
                                FGTheme.stainedGlassViolet
                            ]),
                            center: .center
                        ),
                        lineWidth: 3.5
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: FGTheme.stainedGlassViolet.opacity(isPaused ? 0.2 : 0.6), radius: 10)

                VStack(spacing: 6) {
                    Image(systemName: isPaused ? "pause.circle.fill" : "flame.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FGTheme.stainedGlassAmber, FGTheme.stainedGlassRuby],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: FGTheme.stainedGlassAmber.opacity(0.5), radius: 8)

                    Text(formattedTimerString)
                        .font(.system(size: 42, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("VIGIL IN PROGRESS")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                        .tracking(1.4)
                }
            }
            .padding(.top, 16)

            VStack(spacing: 6) {
                Text(title.isEmpty ? category.displayName : title)
                    .font(FGTheme.gothic(.title3, weight: .bold))
                    .foregroundStyle(FGTheme.stoneText)

                HStack(spacing: 8) {
                    Text(category.displayName.uppercased())
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.stainedGlassViolet)
                        .fgBadge(color: FGTheme.stainedGlassViolet, opacity: 0.2)

                    let arcana = TarotArcana.dailyCard(for: services.clock.now, calendar: services.configuration.calendar())
                    Text("ARCANA \(arcana.romanNumeral) · \(arcana.rawValue.uppercased())")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(arcana.accentColor)
                        .fgBadge(color: arcana.accentColor, opacity: 0.18)
                }
            }

            Text("Elapsed: \(elapsedSeconds / 60)m \(elapsedSeconds % 60)s")
                .font(FGTheme.mono(.caption))
                .foregroundStyle(FGTheme.muted)

            Spacer()

            // Stone & Stained Glass Controls
            HStack(spacing: 16) {
                Button {
                    FGTheme.triggerHaptic()
                    isPaused.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        Text(isPaused ? "Resume" : "Pause")
                    }
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FGTheme.stoneSlabGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(FGTheme.stoneBevel, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .fgTactileButton(fill: false, accent: FGTheme.stoneBevel, cornerRadius: 12)

                Button {
                    FGTheme.triggerHaptic()
                    finishTimer()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "seal.fill")
                        Text("Seal & Log")
                    }
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(FGTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [FGTheme.stainedGlassViolet, FGTheme.stainedGlassViolet.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: FGTheme.stainedGlassViolet.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .fgTactileButton(fill: true, accent: FGTheme.stainedGlassViolet, cornerRadius: 12)
            }
        }
    }

    private var displayedRecentTitles: [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(8)
        for log in recentLogs.prefix(30) {
            let t = log.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && seen.insert(t.uppercased()).inserted {
                result.append(t)
                if result.count >= 8 { break }
            }
        }
        if result.isEmpty {
            var fallback: [String] = []
            for course in courses {
                let code = course.code.trimmingCharacters(in: .whitespacesAndNewlines)
                if !code.isEmpty && seen.insert(code.uppercased()).inserted {
                    fallback.append(code)
                    if fallback.count >= 8 { break }
                }
            }
            let standard = ["Study", "Problem Set", "Reading", "Gym", "Leisure", "Personal Project"]
            for s in standard where seen.insert(s.uppercased()).inserted {
                fallback.append(s)
                if fallback.count >= 8 { break }
            }
            return fallback
        }
        return result
    }

    private var formattedTimerString: String {
        let mins = secondsRemaining / 60
        let secs = secondsRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func startTimer() {
        FGTheme.triggerHaptic()
        isRunning = true
        isPaused = false
        elapsedSeconds = 0
        secondsRemaining = timerPresetMinutes * 60
    }

    private func finishTimer() {
        FGTheme.triggerHaptic()
        isRunning = false
        showingLogCompletion = true
    }
}
