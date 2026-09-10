import SwiftData
import SwiftUI

// MARK: - Garden Filter

enum GardenFilter: String, CaseIterable, Identifiable {
    case all = "ALL"
    case blooming = "BLOOMING"
    case mature = "MATURE"
    case wilted = "WILTED"

    var id: String { rawValue }
}

// MARK: - GardenView

struct GardenView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\GardenPlant.gridIndex), SortDescriptor(\GardenPlant.plantedAt, order: .reverse)])
    private var allPlants: [GardenPlant]

    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.scheduledStart)
    private var pendingTasks: [FocusTask]

    @State private var selectedFilter: GardenFilter = .all
    @State private var selectedPlant: GardenPlant? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 155), spacing: 12)
    ]

    var body: some View {
        FGScreen(title: "GARDEN") {
            VStack(spacing: 0) {
                GardenMetricsHeader(
                    summary: gardenSummary,
                    streakDays: services.currentStreakDays,
                    totalXP: services.totalFocusXP
                )

                GardenFilterBar(selectedFilter: $selectedFilter)

                ScrollView {
                    if allPlants.isEmpty {
                        emptyGardenCallout
                            .padding(16)
                    } else if filteredPlants.isEmpty {
                        emptyFilterCallout
                            .padding(16)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredPlants) { plant in
                                GardenPotCard(plant: plant) {
                                    selectedPlant = plant
                                }
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
        .sheet(item: $selectedPlant) { plant in
            PlantDetailSheet(plant: plant)
        }
    }

    // MARK: - Computed Properties

    private var gardenSummary: GardenSummary {
        GardenService.fetchGardenSummary(in: modelContext)
    }

    private var filteredPlants: [GardenPlant] {
        switch selectedFilter {
        case .all:
            return allPlants
        case .blooming:
            return allPlants.filter { !$0.isMature && !$0.isWilted }
        case .mature:
            return allPlants.filter { $0.isMature && !$0.isWilted }
        case .wilted:
            return allPlants.filter { $0.isWilted }
        }
    }

    // MARK: - Empty States

    private var emptyGardenCallout: some View {
        FGCard(accent: FGTheme.green) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("🌱")
                        .font(.system(size: 24))
                    Text("NO BOTANICAL SEEDS YET")
                        .font(FGTheme.mono(.subheadline, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                }

                Text("Every focus session plants and nurtures a unique plant specimen tied to your study course. Complete sprints to watch your garden flourish.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
                    .lineSpacing(2)

                FGButton(title: "START FOCUS SESSION", accent: FGTheme.green) {
                    startSessionFromGarden()
                }
                .padding(.top, 4)
            }
        }
    }

    private var emptyFilterCallout: some View {
        FGCard(accent: FGTheme.muted) {
            VStack(alignment: .leading, spacing: 10) {
                Text("NO \(selectedFilter.rawValue) SPECIMENS")
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.white)

                Text("There are no botanical specimens currently matching the \(selectedFilter.rawValue.lowercased()) filter criteria.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)

                FGButton(title: "VIEW ALL PLANTS", accent: FGTheme.green, fill: false) {
                    selectedFilter = .all
                }
            }
        }
    }

    private func startSessionFromGarden() {
        if let task = pendingTasks.first {
            services.startFocusSession(task)
        } else {
            services.addTask(title: "Deep Study Sprint", estimatedMinutes: 25)
            if let newTask = try? modelContext.fetch(FetchDescriptor<FocusTask>()).first(where: { !$0.isCompleted }) {
                services.startFocusSession(newTask)
            }
        }
    }
}

// MARK: - Metrics Header

private struct GardenMetricsHeader: View {
    let summary: GardenSummary
    let streakDays: Int
    let totalXP: Int

    private var bloomedFormatted: String {
        let totalMins = summary.totalFocusedMinutes
        let hours = totalMins / 60
        let mins = totalMins % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    private var diversityString: String {
        let discovered = summary.speciesCounts.filter { $0.value > 0 }.count
        let total = PlantSpecies.allCases.count
        return "\(discovered)/\(total) DISCOVERED"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: Bloom Time & Mature Count
            HStack(spacing: 12) {
                metricCell(
                    title: "HOURS BLOOMED",
                    value: bloomedFormatted,
                    accent: FGTheme.green
                )
                metricCell(
                    title: "MATURE / TOTAL",
                    value: "\(summary.matureCount) / \(summary.totalPlants)",
                    accent: summary.matureCount > 0 ? FGTheme.green : .white
                )
            }

            // Row 2: Diversity & Streak/XP
            HStack(spacing: 12) {
                metricCell(
                    title: "SPECIES DIVERSITY",
                    value: diversityString,
                    accent: FGTheme.amber
                )
                metricCell(
                    title: "STREAK & XP",
                    value: "🔥\(streakDays)d · ⚡️\(totalXP) XP",
                    accent: FGTheme.green
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FGTheme.surface, FGTheme.surface.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FGTheme.green.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func metricCell(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)
            Text(value)
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Filter Bar

private struct GardenFilterBar: View {
    @Binding var selectedFilter: GardenFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GardenFilter.allCases) { item in
                let isSelected = selectedFilter == item
                Button {
                    selectedFilter = item
                } label: {
                    Text(item.rawValue)
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(isSelected ? FGTheme.ink : FGTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? FGTheme.green : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(FGTheme.green.opacity(isSelected ? 0.4 : 0.18), lineWidth: 1)
                        )
                        .shadow(color: isSelected ? FGTheme.green.opacity(0.25) : Color.clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Garden Pot Card

private struct GardenPotCard: View {
    let plant: GardenPlant
    let onTap: () -> Void

    private var borderColor: Color {
        if plant.isWilted {
            return FGTheme.danger.opacity(0.7)
        }
        if plant.isMature {
            return FGTheme.green.opacity(0.6)
        }
        return plant.species.accentColor.opacity(0.35)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Top Badges: Course Code & Stage Symbol
                HStack(spacing: 4) {
                    Text(plant.courseCode.isEmpty ? "FOCUS" : plant.courseCode)
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(plant.species.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(plant.species.accentColor.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(plant.species.accentColor.opacity(0.35), lineWidth: 1)
                        )
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Text(plant.growthStage.symbol)
                        .font(.system(size: 11))
                }

                // Botanical Vector Canvas (size: 84)
                PlantCanvasView(
                    plant: plant,
                    isAnimated: false,
                    size: 84
                )
                .frame(width: 84, height: 84)

                // Plant Title
                Text(plant.title.isEmpty ? plant.species.displayName : plant.title)
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                // Progress Indicator or Mature Checkmark
                statusIndicator
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if plant.isMature {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(FGTheme.green)
                Text("MATURE")
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.green)
            }
        } else if plant.isWilted {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(FGTheme.danger)
                Text("WILTED")
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.danger)
            }
        } else {
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        Capsule()
                            .fill(plant.species.accentColor)
                            .frame(width: geo.size.width * CGFloat(plant.growthProgress), height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(plant.growthStage.title.uppercased())
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                    Spacer()
                    Text("\(Int(plant.growthProgress * 100))%")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(plant.species.accentColor)
                }
            }
        }
    }
}
