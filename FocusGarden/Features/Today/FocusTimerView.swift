import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct FocusTimerView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Course.code) var courses: [Course]

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
                            ForEach(services.recentActivityTitles(), id: \.self) { item in
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

            // Botanical Sprout Icon
            ZStack {
                Circle()
                    .fill(FGTheme.green.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(FGTheme.green)
            }

            VStack(spacing: 8) {
                Text(title.isEmpty ? category.displayName : title)
                    .font(FGTheme.mono(.title3, weight: .bold))
                    .foregroundStyle(.white)

                Text(category.displayName.uppercased())
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.muted)
            }

            // Time Display
            VStack(spacing: 4) {
                Text(formattedTimerString)
                    .font(.system(size: 58, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)

                Text("Elapsed: \(elapsedSeconds / 60)m \(elapsedSeconds % 60)s")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            }

            Spacer()

            // Timer Controls
            HStack(spacing: 16) {
                Button {
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
                    .background(FGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    finishTimer()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Finish & Log")
                    }
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(FGTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FGTheme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var formattedTimerString: String {
        let mins = secondsRemaining / 60
        let secs = secondsRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func startTimer() {
        isRunning = true
        isPaused = false
        elapsedSeconds = 0
        secondsRemaining = timerPresetMinutes * 60
    }

    private func finishTimer() {
        isRunning = false
        showingLogCompletion = true
    }
}
