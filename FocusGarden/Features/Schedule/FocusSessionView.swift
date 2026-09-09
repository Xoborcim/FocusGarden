import SwiftData
import SwiftUI
import UIKit

// MARK: - Botanical Growth Stage

enum BotanicalGrowthStage: Int, CaseIterable {
    case seed = 1
    case sprout = 2
    case foliage = 3
    case blossom = 4
    case harvest = 5

    var symbol: String {
        switch self {
        case .seed: return "🌱"
        case .sprout: return "🌿"
        case .foliage: return "🪴"
        case .blossom: return "🌸"
        case .harvest: return "🌳"
        }
    }

    var title: String {
        switch self {
        case .seed: return "SEED SOWN"
        case .sprout: return "SPROUTING"
        case .foliage: return "DEEP FLOW"
        case .blossom: return "BUDDING BLOOM"
        case .harvest: return "HARVEST READY"
        }
    }

    var subtitle: String {
        switch self {
        case .seed: return "Setting intention & entering flow"
        case .sprout: return "Roots established · Building momentum"
        case .foliage: return "Peak concentration · Distraction-free zone"
        case .blossom: return "High clarity · Approaching finish line"
        case .harvest: return "Masterful session · Ready to harvest"
        }
    }

    static func stage(for progress: Double) -> BotanicalGrowthStage {
        switch progress {
        case ..<0.20: return .seed
        case ..<0.45: return .sprout
        case ..<0.75: return .foliage
        case ..<0.95: return .blossom
        default: return .harvest
        }
    }
}

// MARK: - FocusSessionView

struct FocusSessionView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \FocusTask.scheduledStart) private var allTasks: [FocusTask]
    let task: FocusTask

    enum Phase {
        case focus
        case studyBreak
        case sessionFinished
    }

    @State private var phase: Phase = .focus
    @State private var now = Date()

    // Focus sprint tracking
    @State private var sprintDurationMinutes: Int = 25
    @State private var sprintStartedAt: Date = Date()
    @State private var focusSecondsAccumulated: TimeInterval = 0
    @State private var breathingPulse = false

    // Break tracking
    @State private var breakDurationMinutes: Int = 5
    @State private var breakStartedAt: Date = Date()
    @State private var breakSecondsAccumulated: TimeInterval = 0
    @State private var isTransitionBreak = false
    @State private var breaksTakenCount: Int = 0

    // Modals
    @State private var showingIntervalPicker = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            // Ambient background glow for organic feeling
            ambientGlowLayer

            VStack(spacing: 16) {
                topBar
                Spacer(minLength: 4)

                switch phase {
                case .focus:
                    focusContent
                case .studyBreak:
                    breakContent
                case .sessionFinished:
                    finishedContent
                }

                Spacer(minLength: 4)
                bottomActions
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .onAppear {
            setupInitialState()
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathingPulse = true
            }
        }
        .onReceive(tick) { date in
            now = date
        }
        .sheet(isPresented: $showingIntervalPicker) {
            TimerIntervalConfigSheet(
                sprintMinutes: $sprintDurationMinutes,
                breakMinutes: $breakDurationMinutes,
                onSave: { s, b in
                    services.setTimerIntervals(focus: s, breakMinutes: b)
                }
            )
        }
    }

    private func setupInitialState() {
        sprintDurationMinutes = min(
            max(5, task.estimatedMinutes),
            max(5, services.configuration.timerFocusMinutes)
        )
        breakDurationMinutes = max(1, services.configuration.timerBreakMinutes)
        sprintStartedAt = task.sessionStartedAt ?? services.clock.now
    }

    // MARK: - Ambient Glow

    @ViewBuilder
    private var ambientGlowLayer: some View {
        if phase == .focus {
            RadialGradient(
                colors: [accent.opacity(0.12), Color.clear],
                center: .center,
                startRadius: 40,
                endRadius: 280
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        } else if phase == .studyBreak {
            RadialGradient(
                colors: [FGTheme.amber.opacity(0.14), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 8) {
            // Phase indicator pill
            HStack(spacing: 6) {
                Circle()
                    .fill(phase == .focus ? accent : FGTheme.amber)
                    .frame(width: 8, height: 8)
                    .scaleEffect(breathingPulse ? 1.25 : 0.85)

                Text(topBarPhaseLabel)
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(phase == .studyBreak ? FGTheme.amber : accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(FGTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(phase == .studyBreak ? FGTheme.amber.opacity(0.5) : accent.opacity(0.5), lineWidth: 1)
            )

            // Course & Cluster Tag
            if let course = task.linkedCourse {
                HStack(spacing: 4) {
                    Image(systemName: course.subjectCluster.icon)
                        .font(.system(size: 10))
                    Text(course.code.isEmpty ? course.title : course.code)
                        .font(FGTheme.mono(.caption2, weight: .bold))
                }
                .foregroundStyle(course.subjectCluster.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(FGTheme.surface)
                .overlay(Rectangle().stroke(course.subjectCluster.accentColor.opacity(0.4), lineWidth: 1))
            } else {
                let cluster = task.subjectCluster
                HStack(spacing: 4) {
                    Image(systemName: cluster.icon)
                        .font(.system(size: 10))
                    Text(cluster.shortTag)
                        .font(FGTheme.mono(.caption2, weight: .bold))
                }
                .foregroundStyle(cluster.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(FGTheme.surface)
                .overlay(Rectangle().stroke(cluster.accentColor.opacity(0.4), lineWidth: 1))
            }

            Spacer()

            // Timer Interval Configuration Button
            Button {
                showingIntervalPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("\(sprintDurationMinutes)m/\(breakDurationMinutes)m")
                }
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(FGTheme.surface)
                .overlay(Rectangle().stroke(FGTheme.muted.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var topBarPhaseLabel: String {
        switch phase {
        case .focus: return "FOCUS SESSION"
        case .studyBreak: return "STUDY BREAK"
        case .sessionFinished: return "COMPLETED"
        }
    }

    // MARK: - Focus Content

    private var focusContent: some View {
        VStack(spacing: 18) {
            // Task info card
            VStack(spacing: 4) {
                Text(task.title)
                    .font(FGTheme.mono(.headline, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let code = task.linkedCourse?.code, !code.isEmpty {
                    Text(task.linkedCourse?.displayName ?? code)
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                }
            }
            .padding(.horizontal, 12)

            // Botanical Radial Gauge Centerpiece
            BotanicalRadialGauge(
                progress: sprintProgress,
                accentColor: accent,
                pulse: breathingPulse,
                stage: currentGrowthStage,
                timeString: currentSprintRemaining.clockFormatted,
                timeSubtitle: sprintRemainingLabel
            )
            .frame(width: 250, height: 250)

            // Stage Description & Growth Progress
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Text(currentGrowthStage.symbol)
                    Text("STAGE \(currentGrowthStage.rawValue)/5 · \(currentGrowthStage.title)")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(accent)
                }

                Text(currentGrowthStage.subtitle)
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(FGTheme.surface)
            .overlay(Rectangle().stroke(accent.opacity(0.35), lineWidth: 1))

            // Task Total & Daily Focus Metrics
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("TASK TIME")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                    Text("\(totalSessionMinutes.durationFormatted) / \(taskPlannedMinutes)m")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(FGTheme.muted.opacity(0.3))
                    .frame(width: 1, height: 26)

                VStack(spacing: 2) {
                    Text("BREAKS TAKEN")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                    Text("\(breaksTakenCount) (\(totalBreakMinutes.durationFormatted))")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.amber)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(FGTheme.surface)
            .overlay(Rectangle().stroke(FGTheme.green.opacity(0.2), lineWidth: 1))

            // Quick Break Action Buttons
            HStack(spacing: 10) {
                Button {
                    startBreak(minutes: breakDurationMinutes)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("TAKE \(breakDurationMinutes)M BREAK")
                    }
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FGTheme.amber)
                }
                .buttonStyle(.plain)

                Button {
                    startBreak(minutes: 10)
                } label: {
                    Text("+10m")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.amber)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(FGTheme.surface)
                        .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Break Content (Zen & Mindfulness)

    private var breakContent: some View {
        VStack(spacing: 18) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(FGTheme.amber)
                Text(isTransitionBreak ? "BREAK BETWEEN SESSIONS" : "MINDFUL STUDY BREAK")
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(FGTheme.amber)
            }

            // Interactive Guided Box-Breathing Centerpiece
            GuidedBreathingCenterpiece(
                elapsedSeconds: currentBreakElapsed,
                remainingSeconds: currentBreakRemaining,
                totalBreakSeconds: breakTotalSeconds
            )
            .frame(width: 250, height: 250)

            // Rotating Mindfulness Prompt Card
            MindfulRestPromptCard(elapsedSeconds: currentBreakElapsed)

            // Break Adjustment Controls
            HStack(spacing: 12) {
                Button("+2m break") {
                    extendBreak(minutes: 2)
                }
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(FGTheme.surface)
                .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.6), lineWidth: 1))
                .buttonStyle(.plain)

                Button("+5m break") {
                    extendBreak(minutes: 5)
                }
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(FGTheme.surface)
                .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.6), lineWidth: 1))
                .buttonStyle(.plain)
            }

            FGButton(title: "RESUME FOCUS NOW", accent: FGTheme.green) {
                endBreak()
            }
        }
    }

    // MARK: - Finished Content

    private var finishedContent: some View {
        VStack(spacing: 18) {
            Text("🌳")
                .font(.system(size: 54))
                .scaleEffect(breathingPulse ? 1.1 : 0.95)

            VStack(spacing: 4) {
                Text("HARVEST COMPLETE!")
                    .font(FGTheme.mono(.title3, weight: .bold))
                    .foregroundStyle(FGTheme.green)
                Text("Your garden flourished with deep focus today.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            }

            VStack(spacing: 8) {
                Text(task.title)
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("FOCUSED")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.green)
                        Text(totalSessionMinutes.durationFormatted)
                            .font(FGTheme.mono(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(spacing: 2) {
                        Text("RESTED")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.amber)
                        Text(totalBreakMinutes.durationFormatted)
                            .font(FGTheme.mono(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(spacing: 2) {
                        Text("STAGE")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(accent)
                        Text(currentGrowthStage.symbol)
                            .font(.system(size: 18))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(FGTheme.surface)
            .overlay(Rectangle().stroke(FGTheme.green.opacity(0.5), lineWidth: 1))

            if let next = nextScheduledTaskToday {
                let gap = max(0, Int(next.scheduledStart!.timeIntervalSince(now) / 60))
                FGCard(accent: FGTheme.amber) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("UPCOMING BREAK BUFFER")
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(FGTheme.amber)
                            Spacer()
                            Text("\(gap)m gap")
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("Next: \(next.title)")
                            .font(FGTheme.mono(.subheadline, weight: .bold))
                            .foregroundStyle(.white)

                        if let code = next.linkedCourse?.code, !code.isEmpty {
                            Text("Course: \(code) · \(next.subjectCluster.shortTag)")
                                .font(FGTheme.mono(.caption2))
                                .foregroundStyle(next.subjectCluster.accentColor)
                        }

                        Text("Starts at \(next.scheduledStart!.formatted(date: .omitted, time: .shortened))")
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(FGTheme.muted)

                        if gap > 0 {
                            FGButton(title: "START \(gap)M REST TIMER", accent: FGTheme.amber) {
                                isTransitionBreak = true
                                startBreak(minutes: gap)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            if phase == .focus {
                FGButton(title: "MARK TASK COMPLETE", accent: accent) {
                    completeSession()
                }

                FGButton(title: "PAUSE & LEAVE", accent: FGTheme.muted, fill: false) {
                    services.endFocusSession(clearStart: false)
                }
            } else if phase == .studyBreak {
                FGButton(title: "LEAVE SESSION", accent: FGTheme.muted, fill: false) {
                    services.endFocusSession(clearStart: false)
                }
            } else if phase == .sessionFinished {
                FGButton(title: "CLOSE", accent: FGTheme.green) {
                    services.endFocusSession(clearStart: false)
                }
            }
        }
    }

    // MARK: - Actions & Timer Logic

    private func startBreak(minutes: Int) {
        focusSecondsAccumulated += max(0, now.timeIntervalSince(sprintStartedAt))
        breakDurationMinutes = max(1, minutes)
        breakStartedAt = now
        breaksTakenCount += 1
        phase = .studyBreak
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func extendBreak(minutes: Int) {
        breakDurationMinutes += minutes
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func endBreak() {
        breakSecondsAccumulated += max(0, now.timeIntervalSince(breakStartedAt))
        sprintStartedAt = now
        phase = .focus
        isTransitionBreak = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func completeSession() {
        focusSecondsAccumulated += max(0, now.timeIntervalSince(sprintStartedAt))
        services.markTaskDone(task)
        phase = .sessionFinished
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Calculations

    private var currentGrowthStage: BotanicalGrowthStage {
        BotanicalGrowthStage.stage(for: sprintProgress)
    }

    private var sprintTotalSeconds: TimeInterval {
        TimeInterval(sprintDurationMinutes * 60)
    }

    private var currentSprintElapsed: TimeInterval {
        max(0, now.timeIntervalSince(sprintStartedAt))
    }

    private var currentSprintRemaining: TimeInterval {
        max(0, sprintTotalSeconds - currentSprintElapsed)
    }

    private var sprintProgress: Double {
        min(1.0, currentSprintElapsed / max(1.0, sprintTotalSeconds))
    }

    private var sprintRemainingLabel: String {
        if currentSprintRemaining > 0 {
            return "\(currentSprintRemaining.clockFormatted) left in sprint"
        }
        return "Sprint completed · take a mindful break!"
    }

    private var breakTotalSeconds: TimeInterval {
        TimeInterval(breakDurationMinutes * 60)
    }

    private var currentBreakElapsed: TimeInterval {
        max(0, now.timeIntervalSince(breakStartedAt))
    }

    private var currentBreakRemaining: TimeInterval {
        max(0, breakTotalSeconds - currentBreakElapsed)
    }

    private var totalSessionMinutes: Int {
        Int((focusSecondsAccumulated + (phase == .focus ? currentSprintElapsed : 0)) / 60)
    }

    private var totalBreakMinutes: Int {
        Int((breakSecondsAccumulated + (phase == .studyBreak ? currentBreakElapsed : 0)) / 60)
    }

    private var taskPlannedMinutes: Int {
        if let start = task.scheduledStart, let end = task.scheduledEnd, end > start {
            return max(15, Int(end.timeIntervalSince(start) / 60))
        }
        return max(15, task.estimatedMinutes)
    }

    private var nextScheduledTaskToday: FocusTask? {
        let calendar = services.configuration.calendar()
        let today = services.clock.now
        return allTasks.first { other in
            other.id != task.id
            && !other.isCompleted
            && other.scheduledStart != nil
            && calendar.isDate(other.scheduledStart!, inSameDayAs: today)
            && other.scheduledStart! >= (task.scheduledEnd ?? today)
        }
    }

    private var backgroundColor: Color {
        if phase == .studyBreak {
            return Color(red: 0.04, green: 0.05, blue: 0.08)
        }
        return FGTheme.background
    }

    private var accent: Color {
        switch task.kind {
        case .testPrep: return FGTheme.danger
        case .homework: return Color(red: 0.45, green: 0.75, blue: 1.0)
        case .study: return FGTheme.green
        }
    }
}

// MARK: - Botanical Radial Gauge Component

private struct BotanicalRadialGauge: View {
    let progress: Double
    let accentColor: Color
    let pulse: Bool
    let stage: BotanicalGrowthStage
    let timeString: String
    let timeSubtitle: String

    private let tickCount = 60

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = (size / 2) - 18

            ZStack {
                // Background Track
                Circle()
                    .stroke(FGTheme.surface, lineWidth: 10)
                    .overlay(Circle().stroke(accentColor.opacity(0.12), lineWidth: 1))

                // Radial Tick Marks
                ForEach(0..<tickCount, id: \.self) { tick in
                    let isMajor = tick % 5 == 0
                    let angle = Angle.degrees(Double(tick) / Double(tickCount) * 360.0 - 90.0)
                    let tickLen: CGFloat = isMajor ? 8 : 4
                    let innerR = radius - 14
                    let outerR = innerR + tickLen

                    Path { path in
                        let startX = center.x + CGFloat(cos(angle.radians)) * innerR
                        let startY = center.y + CGFloat(sin(angle.radians)) * innerR
                        let endX = center.x + CGFloat(cos(angle.radians)) * outerR
                        let endY = center.y + CGFloat(sin(angle.radians)) * outerR
                        path.move(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: endX, y: endY))
                    }
                    .stroke(
                        isMajor ? accentColor.opacity(0.6) : FGTheme.muted.opacity(0.25),
                        lineWidth: isMajor ? 1.5 : 1
                    )
                }

                // Animated Progress Stroke
                Circle()
                    .trim(from: 0, to: max(0.001, min(1.0, CGFloat(progress))))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                accentColor.opacity(0.6),
                                accentColor,
                                accentColor
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accentColor.opacity(0.45), radius: 8)

                // Center Content: Plant & Countdown
                VStack(spacing: 6) {
                    // Botanical Mascot with breathing scale
                    Text(stage.symbol)
                        .font(.system(size: 42))
                        .scaleEffect(pulse ? 1.08 : 0.94)
                        .shadow(color: accentColor.opacity(0.3), radius: 10)

                    // Countdown
                    Text(timeString)
                        .font(FGTheme.mono(.largeTitle, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .fgPlain()

                    Text(timeSubtitle)
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Guided Breathing Centerpiece Component

private struct GuidedBreathingCenterpiece: View {
    let elapsedSeconds: TimeInterval
    let remainingSeconds: TimeInterval
    let totalBreakSeconds: TimeInterval

    // 16-second box breathing cycle:
    // 0..<4s: Inhale
    // 4..<8s: Hold
    // 8..<12s: Exhale
    // 12..<16s: Rest
    private var cycleSeconds: Double {
        elapsedSeconds.truncatingRemainder(dividingBy: 16.0)
    }

    private var breathPhase: (title: String, cue: String, scale: CGFloat, color: Color) {
        switch cycleSeconds {
        case 0..<4:
            let pct = cycleSeconds / 4.0
            return ("INHALE", "Breathe in deeply through nose", 0.85 + (0.35 * pct), FGTheme.amber)
        case 4..<8:
            return ("HOLD", "Hold breath gently & relax", 1.20, Color(red: 1.0, green: 0.85, blue: 0.35))
        case 8..<12:
            let pct = (cycleSeconds - 8.0) / 4.0
            return ("EXHALE", "Slow, steady release through mouth", 1.20 - (0.35 * pct), FGTheme.amber)
        default:
            return ("REST", "Rest before the next breath", 0.85, Color(white: 0.6))
        }
    }

    private var quadrantSecondsRemaining: Int {
        let sec = Int(cycleSeconds) % 4
        return 4 - sec
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // Track
                Circle()
                    .stroke(FGTheme.surface, lineWidth: 8)
                    .overlay(Circle().stroke(FGTheme.amber.opacity(0.2), lineWidth: 1))

                // Overall Break Progress Ring
                let progress = min(1.0, elapsedSeconds / max(1.0, totalBreakSeconds))
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        FGTheme.amber,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Pulsing Zen Breathing Orb
                Circle()
                    .fill(breathPhase.color.opacity(0.15))
                    .frame(width: size * 0.65, height: size * 0.65)
                    .scaleEffect(breathPhase.scale)
                    .overlay(
                        Circle()
                            .stroke(breathPhase.color.opacity(0.5), lineWidth: 1.5)
                            .scaleEffect(breathPhase.scale)
                    )
                    .animation(.easeInOut(duration: 1.0), value: breathPhase.title)

                // Center Box Breathing Content
                VStack(spacing: 4) {
                    Text(breathPhase.title)
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(breathPhase.color)

                    Text("\(quadrantSecondsRemaining)s")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.muted)

                    Text(remainingSeconds.clockFormatted)
                        .font(FGTheme.mono(.title, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .fgPlain()
                        .padding(.top, 2)

                    Text("break remaining")
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Mindful Rest Prompt Card

private struct MindfulRestPromptCard: View {
    let elapsedSeconds: TimeInterval

    private let prompts: [(icon: String, text: String)] = [
        ("drop.fill", "Take a long sip of cool water and hydrate."),
        ("eye.fill", "Look at an object 20 feet away to relax eye muscles."),
        ("figure.walk", "Stand up, gently roll your shoulders, and stretch."),
        ("mouth.fill", "Unclench your jaw and let your facial muscles soften."),
        ("wind", "Take a slow 4-count breath down into your belly.")
    ]

    private var currentPrompt: (icon: String, text: String) {
        let index = (Int(elapsedSeconds) / 10) % prompts.count
        return prompts[index]
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: currentPrompt.icon)
                .font(.system(size: 16))
                .foregroundStyle(FGTheme.amber)
                .frame(width: 24)

            Text(currentPrompt.text)
                .font(FGTheme.mono(.caption2))
                .foregroundStyle(Color.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(FGTheme.surface)
        .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Timer Interval Config Sheet

private struct TimerIntervalConfigSheet: View {
    @Binding var sprintMinutes: Int
    @Binding var breakMinutes: Int
    let onSave: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var tempSprint: Int = 25
    @State private var tempBreak: Int = 5

    private let sprintPresets = [15, 20, 25, 30, 45, 50, 60]
    private let breakPresets = [3, 5, 10, 15]

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    // Quick Combo Presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STUDY CADENCE PRESETS")
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(FGTheme.green)

                        HStack(spacing: 8) {
                            presetButton(title: "Pomodoro", sprint: 25, rest: 5)
                            presetButton(title: "Deep Flow", sprint: 50, rest: 10)
                            presetButton(title: "Extended", sprint: 45, rest: 15)
                        }
                    }

                    // Sprint Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FOCUS SPRINT DURATION (\(tempSprint)m)")
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(FGTheme.green)

                        HStack(spacing: 6) {
                            ForEach(sprintPresets, id: \.self) { mins in
                                let selected = tempSprint == mins
                                Button("\(mins)m") {
                                    tempSprint = mins
                                }
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(selected ? FGTheme.ink : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selected ? FGTheme.green : FGTheme.surface)
                                .overlay(Rectangle().stroke(FGTheme.green.opacity(0.5), lineWidth: 1))
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Break Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BREAK DURATION (\(tempBreak)m)")
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(FGTheme.amber)

                        HStack(spacing: 8) {
                            ForEach(breakPresets, id: \.self) { mins in
                                let selected = tempBreak == mins
                                Button("\(mins)m") {
                                    tempBreak = mins
                                }
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(selected ? FGTheme.ink : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selected ? FGTheme.amber : FGTheme.surface)
                                .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.5), lineWidth: 1))
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    FGButton(title: "APPLY CADENCE", accent: FGTheme.green) {
                        sprintMinutes = tempSprint
                        breakMinutes = tempBreak
                        onSave(tempSprint, tempBreak)
                        dismiss()
                    }
                }
                .padding(20)
            }
            .navigationTitle("TIMER CADENCE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FGTheme.muted)
                }
            }
            .onAppear {
                tempSprint = sprintMinutes
                tempBreak = breakMinutes
            }
        }
    }

    private func presetButton(title: String, sprint: Int, rest: Int) -> some View {
        let selected = tempSprint == sprint && tempBreak == rest
        return Button {
            tempSprint = sprint
            tempBreak = rest
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(FGTheme.mono(.caption2, weight: .bold))
                Text("\(sprint)/\(rest)m")
                    .font(FGTheme.mono(.caption2))
            }
            .foregroundStyle(selected ? FGTheme.ink : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? FGTheme.green : FGTheme.surface)
            .overlay(Rectangle().stroke(FGTheme.green.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
