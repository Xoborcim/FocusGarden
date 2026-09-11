import Foundation
#if !SKIP
import SwiftData
#endif

// MARK: - Garden Summary

struct GardenSummary: Equatable, Sendable {
    let totalPlants: Int
    let matureCount: Int
    let totalFocusedMinutes: Int
    let speciesCounts: [PlantSpecies: Int]

    init(
        totalPlants: Int = 0,
        matureCount: Int = 0,
        totalFocusedMinutes: Int = 0,
        speciesCounts: [PlantSpecies: Int] = [:]
    ) {
        self.totalPlants = totalPlants
        self.matureCount = matureCount
        self.totalFocusedMinutes = totalFocusedMinutes
        self.speciesCounts = speciesCounts
    }
}

// MARK: - Harvest Result

struct HarvestResult: @unchecked Sendable {
    let plant: GardenPlant
    let xpEarned: Int
    let newTotalXP: Int
    let currentStreakDays: Int
    let isNewDailyStreak: Bool

    init(
        plant: GardenPlant,
        xpEarned: Int,
        newTotalXP: Int,
        currentStreakDays: Int,
        isNewDailyStreak: Bool
    ) {
        self.plant = plant
        self.xpEarned = xpEarned
        self.newTotalXP = newTotalXP
        self.currentStreakDays = currentStreakDays
        self.isNewDailyStreak = isNewDailyStreak
    }
}

// MARK: - Garden Service

@MainActor
struct GardenService {
    private init() {}

    #if !SKIP
    /// Seeds a new plant linked to the given focus task, setting species, target minutes, and next grid index.
    @discardableResult
    static func plantSeed(for task: FocusTask, in context: ModelContext) -> GardenPlant {
        let descriptor = FetchDescriptor<GardenPlant>()
        let existingPlants = (try? context.fetch(descriptor)) ?? []

        // Find the lowest non-negative grid index not currently occupied
        let occupiedIndices = Set(existingPlants.map(\.gridIndex))
        var nextIndex = 0
        while occupiedIndices.contains(nextIndex) {
            nextIndex += 1
        }

        let targetMinutes = task.estimatedMinutes > 0 ? task.estimatedMinutes : 30
        let species = PlantSpecies.species(for: task.subjectCluster, taskKind: task.kind)
        let courseCode = task.linkedCourse?.code ?? ""

        let plant = GardenPlant(
            taskID: task.id,
            courseCode: courseCode,
            title: task.title,
            species: species,
            plantedAt: Date(),
            harvestedAt: nil,
            targetMinutes: targetMinutes,
            focusedMinutes: 0,
            growthProgress: 0.0,
            isWilted: false,
            gridIndex: nextIndex
        )

        context.insert(plant)
        try? context.save()
        return plant
    }

    /// Updates focused minutes and recomputes progress as min(1.0, Double(focusedMinutes) / Double(max(1, targetMinutes))).
    static func updateProgress(plant: GardenPlant, focusedMinutes: Int, context: ModelContext) {
        let sanitizedMinutes = max(0, focusedMinutes)
        plant.focusedMinutes = sanitizedMinutes
        let divisor = Double(max(1, plant.targetMinutes))
        plant.growthProgress = min(1.0, Double(sanitizedMinutes) / divisor)
        try? context.save()
    }

    /// Marks the plant as harvested with full progress at the current timestamp.
    static func harvestPlant(plant: GardenPlant, context: ModelContext) {
        plant.harvestedAt = Date()
        plant.growthProgress = 1.0
        try? context.save()
    }

    /// Adds growth to the garden from a logged activity.
    static func recordActivityLogGrowth(log: ActivityLog, in context: ModelContext) {
        guard log.durationMinutes > 0 else { return }
        let appState = fetchOrCreateAppState(in: context)
        appState.totalFocusXP += log.durationMinutes
        appState.lastFocusDate = log.timestamp

        if log.isFocusedStudy || log.focusRating >= 3 {
            let descriptor = FetchDescriptor<GardenPlant>(sortBy: [SortDescriptor(\.plantedAt, order: .reverse)])
            let existingPlants = (try? context.fetch(descriptor)) ?? []
            if let activePlant = existingPlants.first(where: { !$0.isHarvested && $0.growthProgress < 1.0 }) {
                let updatedMinutes = activePlant.focusedMinutes + log.durationMinutes
                activePlant.focusedMinutes = updatedMinutes
                let divisor = Double(max(1, activePlant.targetMinutes))
                let newProgress = min(1.0, Double(updatedMinutes) / divisor)
                activePlant.growthProgress = newProgress
                if newProgress >= 1.0 {
                    activePlant.harvestedAt = log.timestamp
                }
            } else {
                let occupiedIndices = Set(existingPlants.map(\.gridIndex))
                var nextIndex = 0
                while occupiedIndices.contains(nextIndex) {
                    nextIndex += 1
                }
                let courseCode = log.linkedCourse?.code ?? ""
                let species = PlantSpecies.species(for: log.linkedCourse?.subjectCluster ?? SubjectCluster.cluster(for: log.title), taskKind: .study)
                let targetMinutes = max(45, log.durationMinutes)
                let plant = GardenPlant(
                    taskID: log.id,
                    courseCode: courseCode,
                    title: log.title,
                    species: species,
                    plantedAt: log.timestamp,
                    harvestedAt: log.durationMinutes >= targetMinutes ? log.timestamp : nil,
                    targetMinutes: targetMinutes,
                    focusedMinutes: log.durationMinutes,
                    growthProgress: min(1.0, Double(log.durationMinutes) / Double(targetMinutes)),
                    isWilted: false,
                    gridIndex: nextIndex
                )
                context.insert(plant)
            }
        }
        try? context.save()
    }

    /// Marks a plant as wilted.
    static func wiltPlant(plant: GardenPlant, context: ModelContext) {
        plant.isWilted = true
        try? context.save()
    }

    /// Restores a plant back to healthy growing status.
    static func revivePlant(plant: GardenPlant, context: ModelContext) {
        plant.isWilted = false
        try? context.save()
    }

    /// Fetches all plants and computes comprehensive summary metrics.
    static func fetchGardenSummary(in context: ModelContext) -> GardenSummary {
        let descriptor = FetchDescriptor<GardenPlant>()
        let plants = (try? context.fetch(descriptor)) ?? []

        let totalPlants = plants.count
        let matureCount = plants.filter { $0.growthStage == PlantGrowthStage.mature || $0.growthProgress >= 1.0 }.count
        let totalFocusedMinutes = plants.reduce(0) { $0 + $1.focusedMinutes }

        var speciesCounts: [PlantSpecies: Int] = [:]
        for species in PlantSpecies.allCases {
            speciesCounts[species] = 0
        }
        for plant in plants {
            speciesCounts[plant.species] = (speciesCounts[plant.species] ?? 0) + 1
        }

        return GardenSummary(
            totalPlants: totalPlants,
            matureCount: matureCount,
            totalFocusedMinutes: totalFocusedMinutes,
            speciesCounts: speciesCounts
        )
    }

    /// Fetches active plants currently growing in the garden (not yet harvested).
    static func fetchActivePlants(in context: ModelContext) -> [GardenPlant] {
        let descriptor = FetchDescriptor<GardenPlant>(
            sortBy: [SortDescriptor(\.gridIndex)]
        )
        let plants = (try? context.fetch(descriptor)) ?? []
        return plants.filter { $0.harvestedAt == nil }
    }

    /// Fetches a plant associated with a specific task ID.
    static func fetchPlant(for taskID: UUID, in context: ModelContext) -> GardenPlant? {
        let descriptor = FetchDescriptor<GardenPlant>()
        let plants = (try? context.fetch(descriptor)) ?? []
        return plants.first { $0.taskID == taskID }
    }

    /// Deletes a plant from the garden.
    static func deletePlant(plant: GardenPlant, context: ModelContext) {
        context.delete(plant)
        try? context.save()
    }
    #endif

    // MARK: - Pure Progression Functions

    /// Calculates XP earned for a completed focus duration.
    /// Standard: 1 focus minute = 1 XP (minimum 1 XP on completed session).
    /// Test prep: 1.2x bonus (e.g., 25 mins * 1.2 = 30 XP).
    nonisolated static func calculateXP(focusedMinutes: Int, isTestPrep: Bool = false) -> Int {
        let sanitizedMinutes = max(1, focusedMinutes)
        if isTestPrep {
            return max(1, Int(round(Double(sanitizedMinutes) * 1.2)))
        } else {
            return max(1, sanitizedMinutes)
        }
    }

    /// Evaluates streak progression across calendar boundaries.
    /// - If nil lastFocusDate: returns (1, true).
    /// - If in same day: returns (currentStreak, false).
    /// - If yesterday: returns (currentStreak + 1, true).
    /// - If older: returns (1, true).
    nonisolated static func evaluateStreak(
        lastFocusDate: Date?,
        now: Date,
        currentStreak: Int,
        calendar: Calendar = .current
    ) -> (newStreak: Int, isNewDay: Bool) {
        guard let lastFocusDate = lastFocusDate else {
            return (newStreak: 1, isNewDay: true)
        }

        let startOfNow = calendar.startOfDay(for: now)

        if calendar.isDate(lastFocusDate, inSameDayAs: now) {
            return (newStreak: currentStreak, isNewDay: false)
        }

        if let expectedYesterday = calendar.date(byAdding: .day, value: -1, to: startOfNow),
           calendar.isDate(lastFocusDate, inSameDayAs: expectedYesterday) {
            return (newStreak: currentStreak + 1, isNewDay: true)
        }

        return (newStreak: 1, isNewDay: true)
    }

    #if !SKIP
    // MARK: - Botanical Progression & Harvest

    /// Completes the harvest for a plant, updating XP, streaks, and model state.
    /// Guards against duplicate harvest.
    @discardableResult
    static func completeHarvest(
        plant: GardenPlant,
        task: FocusTask,
        focusedMinutes: Int,
        now: Date = Date(),
        calendar: Calendar = .current,
        context: ModelContext
    ) -> HarvestResult {
        let appState = fetchOrCreateAppState(in: context)

        // Guard against duplicate harvest (if already harvested, return 0 xpEarned and current streak)
        guard !plant.isHarvested else {
            return HarvestResult(
                plant: plant,
                xpEarned: 0,
                newTotalXP: appState.totalFocusXP,
                currentStreakDays: appState.currentStreakDays,
                isNewDailyStreak: false
            )
        }

        let isTestPrep = (task.kind == .testPrep)
        let effectiveMinutes = max(plant.focusedMinutes, focusedMinutes)
        let xpEarned = calculateXP(focusedMinutes: effectiveMinutes, isTestPrep: isTestPrep)

        let streakEval = evaluateStreak(
            lastFocusDate: appState.lastFocusDate,
            now: now,
            currentStreak: appState.currentStreakDays,
            calendar: calendar
        )

        // Marks harvestedAt = now, growthProgress = 1.0, focusedMinutes = max(plant.focusedMinutes, focusedMinutes)
        plant.harvestedAt = now
        plant.growthProgress = 1.0
        plant.focusedMinutes = effectiveMinutes

        // Updates AppStateRecord (totalFocusXP += xpEarned, currentStreakDays, longestStreakDays = max(longestStreakDays, currentStreakDays), lastFocusDate = now)
        appState.totalFocusXP += xpEarned
        appState.currentStreakDays = streakEval.newStreak
        appState.longestStreakDays = max(appState.longestStreakDays, streakEval.newStreak)
        appState.lastFocusDate = now

        try? context.save()

        return HarvestResult(
            plant: plant,
            xpEarned: xpEarned,
            newTotalXP: appState.totalFocusXP,
            currentStreakDays: appState.currentStreakDays,
            isNewDailyStreak: streakEval.isNewDay
        )
    }

    /// Handles session exit:
    /// - If intentionalAbandon and focusedMinutes < 2: delete unsprouted seed to prevent clutter.
    /// - If intentionalAbandon and focusedMinutes >= 2: mark plant.isWilted = true.
    /// - If pause (not abandon): preserve progress without wilting.
    static func handleSessionExit(
        plant: GardenPlant,
        focusedMinutes: Int,
        intentionalAbandon: Bool,
        context: ModelContext
    ) {
        guard !plant.isHarvested else { return }
        if intentionalAbandon {
            if focusedMinutes < 2 {
                context.delete(plant)
                try? context.save()
                return
            } else {
                plant.isWilted = true
            }
        }
        let updatedMinutes = max(plant.focusedMinutes, max(0, focusedMinutes))
        plant.focusedMinutes = updatedMinutes
        let divisor = Double(max(1, plant.targetMinutes))
        plant.growthProgress = min(1.0, Double(updatedMinutes) / divisor)
        try? context.save()
    }

    private static func fetchOrCreateAppState(in context: ModelContext) -> AppStateRecord {
        let descriptor = FetchDescriptor<AppStateRecord>()
        if let existing = try? context.fetch(descriptor), let record = existing.first {
            return record
        }
        let record = AppStateRecord()
        context.insert(record)
        return record
    }
    #endif
}
