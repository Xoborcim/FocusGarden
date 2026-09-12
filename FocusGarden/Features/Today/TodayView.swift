import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct TimelineItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case classBlock
        case activityLog(ActivityCategory)
        case openTime
    }

    var id: String
    var title: String
    var subtitle: String
    var startTime: Date
    var endTime: Date
    var kind: Kind
    var durationMinutes: Int
}

struct TodayView: View {
    @Environment(AppServices.self) var services
    @Query(sort: \ActivityLog.timestamp, order: .reverse) var allLogs: [ActivityLog]
    @Query var classBlocks: [ClassBlock]
    @Query(sort: \Course.code) var courses: [Course]

    @State var showingLogSheet = false
    @State var showingTimerSheet = false
    @State var showingCoursesSheet = false
    @State var showingSettingsSheet = false
    @State private var drawnArcana: TarotArcana? = nil

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection

                        // Celestial Alignment & Tarot Arcana Card
                        arcanaOracleCard

                        // Day Summary Reality Cards
                        realityCardsGrid

                        // Observational Timeline
                        timelineSection

                        // Action Buttons
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("SPROUT")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingCoursesSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "books.vertical.fill")
                                .font(.caption)
                            Text("Courses")
                                .font(FGTheme.mono(.caption, weight: .bold))
                        }
                        .foregroundStyle(FGTheme.muted)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.subheadline)
                            .foregroundStyle(FGTheme.muted)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                QuickLogView()
            }
            .sheet(isPresented: $showingTimerSheet) {
                FocusTimerView()
            }
            .sheet(isPresented: $showingCoursesSheet) {
                NavigationStack {
                    CoursesView()
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    // MARK: - Contextual Gothic Header & Adaptive Vigil Banner
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOCTURNAL VIGIL")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.stainedGlassViolet)
                        .tracking(1.5)

                    Text(dateText)
                        .font(FGTheme.gothic(.title2, weight: .bold))
                        .foregroundStyle(FGTheme.stoneText)
                }

                Spacer()

                // Contextual Stained Glass Hour Badge
                HStack(spacing: 5) {
                    Image(systemName: contextualVigil.icon)
                        .font(.system(size: 11))
                    Text(contextualVigil.title.uppercased())
                        .font(FGTheme.mono(.caption2, weight: .bold))
                }
                .foregroundStyle(contextualVigil.accent)
                .fgBadge(color: contextualVigil.accent, opacity: 0.22)
            }

            // Adaptive Contextual Banner
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(contextualVigil.accent.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: contextualVigil.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(contextualVigil.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(contextualVigil.ritual)
                        .font(FGTheme.gothic(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                    Text(contextualVigil.guidance)
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                }
                Spacer()
            }
            .padding(12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FGTheme.stoneSlabGradient)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FGTheme.stainedGlassSheen(accent: contextualVigil.accent))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [contextualVigil.accent.opacity(0.45), FGTheme.stoneBevel.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .padding(.top, 4)
    }

    private struct VigilContext {
        let title: String
        let ritual: String
        let guidance: String
        let icon: String
        let accent: Color
    }

    private var contextualVigil: VigilContext {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<12:
            return VigilContext(
                title: "Dawn Matins",
                ritual: "Morning Illumination",
                guidance: "Fresh hours for analytical focus and difficult texts.",
                icon: "sun.horizon.fill",
                accent: FGTheme.stainedGlassAmber
            )
        case 12..<17:
            return VigilContext(
                title: "Solar Zenith",
                ritual: "Midday Labors",
                guidance: "Channel deep momentum into problem sets and projects.",
                icon: "sun.max.fill",
                accent: FGTheme.stainedGlassRuby
            )
        case 17..<22:
            return VigilContext(
                title: "Twilight Vespers",
                ritual: "Evening Consolidation",
                guidance: "Review core concepts and synthesize the day's notes.",
                icon: "sunset.fill",
                accent: FGTheme.stainedGlassViolet
            )
        default:
            return VigilContext(
                title: "Nocturnal Compline",
                ritual: "Night Sanctum",
                guidance: "Silent study. Guard your quiet hours of contemplation.",
                icon: "moon.stars.fill",
                accent: FGTheme.stainedGlassSapphire
            )
        }
    }

    private static let dayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    private var dateText: String {
        Self.dayDateFormatter.string(from: now)
    }

    // MARK: - Celestial & Tarot Oracle Card
    private var currentZodiac: ZodiacSign {
        ZodiacSign.current(for: now, calendar: calendar)
    }

    private var activeArcana: TarotArcana {
        drawnArcana ?? TarotArcana.dailyCard(for: now, calendar: calendar)
    }

    private var arcanaOracleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Zodiac Sign & Element
            HStack {
                HStack(spacing: 6) {
                    Text(currentZodiac.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(currentZodiac.accentColor)
                    Text("SEASON OF \(currentZodiac.rawValue.uppercased())")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(currentZodiac.accentColor)
                        .tracking(1.2)
                }

                Spacer()

                Text("\(currentZodiac.element.uppercased()) · \(currentZodiac.celestialRuler.uppercased())")
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }

            // Tarot Arcana Display Card
            HStack(alignment: .top, spacing: 14) {
                // Card Miniature Crest
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(FGTheme.stoneElevated)
                        .frame(width: 48, height: 68)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    activeArcana.accentColor.opacity(0.8),
                                    FGTheme.stoneBevel
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                        .frame(width: 48, height: 68)

                    VStack(spacing: 2) {
                        Text(activeArcana.romanNumeral)
                            .font(FGTheme.gothic(.caption2, weight: .bold))
                            .foregroundStyle(activeArcana.accentColor)
                        Image(systemName: activeArcana.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(activeArcana.accentColor)
                    }
                }
                .shadow(color: activeArcana.accentColor.opacity(0.25), radius: 6)

                // Arcana Text & Meditation
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(activeArcana.rawValue.uppercased())
                            .font(FGTheme.gothic(.subheadline, weight: .bold))
                            .foregroundStyle(.white)

                        Text("ARCANA \(activeArcana.romanNumeral)")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(activeArcana.accentColor)
                            .fgBadge(color: activeArcana.accentColor, opacity: 0.18)
                    }

                    Text(activeArcana.domain)
                        .font(FGTheme.mono(.caption2, weight: .semibold))
                        .foregroundStyle(FGTheme.stainedGlassAmber)

                    Text("“\(activeArcana.contemplation)”")
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.stoneText.opacity(0.85))
                        .lineSpacing(2)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Interactive Tarot Card Draw Action
            HStack {
                Text(drawnArcana != nil ? "Drawn for this vigil" : "Daily scholarly alignment")
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)

                Spacer()

                Button {
                    FGTheme.triggerHaptic()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        let all = TarotArcana.allCases.filter { $0 != activeArcana }
                        drawnArcana = all.randomElement() ?? .hermit
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10))
                        Text(drawnArcana != nil ? "Draw Another Card" : "Draw Vigil Arcana")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                    }
                    .foregroundStyle(activeArcana.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(activeArcana.accentColor.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(activeArcana.accentColor.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(FGTheme.stoneSlabGradient)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(FGTheme.stainedGlassSheen(accent: activeArcana.accentColor))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            activeArcana.accentColor.opacity(0.45),
                            FGTheme.stoneBevel.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    // MARK: - Reality Cards
    private var todayLogs: [ActivityLog] {
        allLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
    }

    private var currentTerm: AcademicTerm {
        AcademicTerm.containing(now, calendar: calendar)
    }

    private var todayClasses: [ClassBlock] {
        let weekday = calendar.component(.weekday, from: now)
        return classBlocks.filter { block in
            block.dayOfWeek == weekday &&
            block.isActive(on: now, calendar: calendar) &&
            block.belongs(to: currentTerm, now: now, calendar: calendar)
        }
    }

    private var focusedMinutes: Int {
        todayLogs.filter { $0.isFocusedStudy }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var independentMinutes: Int {
        todayLogs.filter { $0.isFocusedStudy && $0.isIndependent }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var aiAssistedMinutes: Int {
        todayLogs.filter { $0.isFocusedStudy && $0.aiUsage.isAIAssisted }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var classMinutes: Int {
        let scheduledClassMinutes = todayClasses.reduce(0) { $0 + Int(($1.duration / 60).rounded()) }
        let loggedClassMinutes = todayLogs.filter { $0.category == .classMeeting }.reduce(0) { $0 + $1.durationMinutes }
        return max(scheduledClassMinutes, loggedClassMinutes)
    }

    private var exerciseMinutes: Int {
        todayLogs.filter { $0.category == .exercise }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var leisureMinutes: Int {
        todayLogs.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var realityCardsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY AT A GLANCE")
                .font(FGTheme.gothic(.caption, weight: .bold))
                .foregroundStyle(FGTheme.muted)
                .tracking(1.2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                realityCard(title: "Focused Work", minutes: focusedMinutes, icon: "brain.head.profile", color: FGTheme.stainedGlassViolet)
                realityCard(title: "Independent", minutes: independentMinutes, icon: "person.fill", color: FGTheme.stainedGlassSapphire)
                realityCard(title: "AI-Assisted", minutes: aiAssistedMinutes, icon: "sparkles", color: FGTheme.stainedGlassAmber)
                realityCard(title: "Classes", minutes: classMinutes, icon: "graduationcap.fill", color: FGTheme.stainedGlassEmerald)
                realityCard(title: "Exercise", minutes: exerciseMinutes, icon: "figure.run", color: FGTheme.stainedGlassRuby)
                realityCard(title: "Leisure & Rest", minutes: leisureMinutes, icon: "cup.and.saucer.fill", color: FGTheme.muted)
            }
        }
    }

    private func realityCard(title: String, minutes: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                Text(formatMinutes(minutes))
                    .font(FGTheme.mono(.headline, weight: .bold))
                    .foregroundStyle(minutes > 0 ? .white : FGTheme.muted)
            }

            Text(title)
                .font(FGTheme.mono(.caption, weight: .medium))
                .foregroundStyle(FGTheme.stoneText.opacity(0.8))
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FGTheme.stoneSlabGradient)
                if minutes > 0 {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FGTheme.stainedGlassSheen(accent: color))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            minutes > 0 ? color.opacity(0.5) : FGTheme.stoneBevel.opacity(0.35),
                            minutes > 0 ? color.opacity(0.2) : Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: minutes > 0 ? color.opacity(0.18) : Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
    }

    private func formatMinutes(_ total: Int) -> String {
        if total <= 0 { return "0m" }
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    // MARK: - Observational Timeline
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        let todayStart = calendar.startOfDay(for: now)

        // 1. Add class blocks today
        for block in todayClasses {
            let start = todayStart.addingTimeInterval(block.startTime)
            let end = start.addingTimeInterval(block.duration)
            let code = block.course?.code ?? block.summary
            items.append(
                TimelineItem(
                    id: "class-\(block.id)",
                    title: "\(code) (\(block.meetingType))",
                    subtitle: block.location.isEmpty ? "Class" : block.location,
                    startTime: start,
                    endTime: end,
                    kind: .classBlock,
                    durationMinutes: Int(block.duration / 60)
                )
            )
        }

        // 2. Add logged activities today
        for log in todayLogs {
            let end = log.timestamp
            let start = log.startTime ?? end.addingTimeInterval(-TimeInterval(max(1, log.durationMinutes) * 60))
            items.append(
                TimelineItem(
                    id: "log-\(log.id)",
                    title: log.title,
                    subtitle: log.notes.isEmpty ? log.category.displayName : "\(log.category.displayName) · \(log.notes)",
                    startTime: start,
                    endTime: end,
                    kind: .activityLog(log.category),
                    durationMinutes: log.durationMinutes
                )
            )
        }

        // Sort chronologically
        items.sort { $0.startTime < $1.startTime }

        // 3. Interlace open / unlogged periods between events if gap >= 20 mins
        var resolved: [TimelineItem] = []
        for (idx, item) in items.enumerated() {
            if idx > 0 {
                let prev = resolved.last ?? items[idx - 1]
                if item.startTime > prev.endTime {
                    let gapMinutes = Int(item.startTime.timeIntervalSince(prev.endTime) / 60)
                    if gapMinutes >= 20 {
                        resolved.append(
                            TimelineItem(
                                id: "open-\(prev.id)-\(item.id)",
                                title: "Free / unlogged",
                                subtitle: "\(gapMinutes)m available",
                                startTime: prev.endTime,
                                endTime: item.startTime,
                                kind: .openTime,
                                durationMinutes: gapMinutes
                            )
                        )
                    }
                }
            }
            resolved.append(item)
        }

        return resolved
    }

    private var timelineSection: some View {
        let currentTimeline = timelineItems
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TIMELINE")
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.muted)
                Spacer()
                Text("\(currentTimeline.count) events")
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }

            if currentTimeline.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(FGTheme.green.opacity(0.8))
                    Text("No activities logged yet today.")
                        .font(FGTheme.mono(.body))
                        .foregroundStyle(.white)
                    Text("Live your day first, then tap below to record what you did.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FGTheme.surface.opacity(0.6))
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(currentTimeline) { item in
                        timelineRow(for: item)
                    }
                }
            }
        }
    }

    private func timelineRow(for item: TimelineItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString(from: item.startTime))
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(.white)
                Text(timeString(from: item.endTime))
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }
            .frame(width: 54, alignment: .trailing)

            // Timeline dot & line
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor(for: item.kind))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(FGTheme.mono(.body, weight: .bold))
                        .foregroundStyle(item.kind == .openTime ? FGTheme.muted : .white)
                    Spacer()
                    Text("\(item.durationMinutes)m")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(item.kind == .openTime ? FGTheme.muted.opacity(0.6) : FGTheme.green)
                }
                Text(item.subtitle)
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.kind == .openTime ? Color.clear : FGTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(item.kind == .openTime ? FGTheme.muted.opacity(0.15) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func dotColor(for kind: TimelineItem.Kind) -> Color {
        switch kind {
        case .classBlock: return Color.cyan
        case .activityLog(let cat):
            switch cat {
            case .study, .project: return FGTheme.green
            case .exercise: return Color.orange
            case .leisure: return FGTheme.amber
            default: return FGTheme.muted
            }
        case .openTime: return FGTheme.muted.opacity(0.3)
        }
    }

    private func timeString(from date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                FGTheme.triggerHaptic()
                showingLogSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                    Text("LOG VIGIL ACTIVITY")
                        .font(FGTheme.mono(.headline, weight: .bold))
                }
                .foregroundStyle(FGTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    FGTheme.stainedGlassViolet,
                                    FGTheme.stainedGlassViolet.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    FGTheme.stoneBevel.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: FGTheme.stainedGlassViolet.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .fgTactileButton(fill: true, accent: FGTheme.stainedGlassViolet, cornerRadius: 12)

            Button {
                FGTheme.triggerHaptic()
                showingTimerSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.subheadline)
                    Text("Sanctum Focus Timer")
                        .font(FGTheme.mono(.subheadline, weight: .bold))
                }
                .foregroundStyle(FGTheme.stainedGlassViolet)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FGTheme.stoneSlabGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    FGTheme.stainedGlassViolet.opacity(0.45),
                                    FGTheme.stoneBevel.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .fgTactileButton(fill: false, accent: FGTheme.stainedGlassViolet, cornerRadius: 12)
        }
        .padding(.top, 10)
    }
}
