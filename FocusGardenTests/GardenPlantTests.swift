import XCTest
import SwiftData
@testable import FocusGarden

@MainActor
final class GardenPlantTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PersistenceController.inMemory()
        context = container.mainContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Growth Stage Tests

    func testGrowthStageCalculations() {
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.0), .seed)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.19), .seed)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.20), .sprout)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.49), .sprout)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.50), .budding)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.79), .budding)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.80), .blooming)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.99), .blooming)
        XCTAssertEqual(PlantGrowthStage.stage(for: 1.0), .mature)
        XCTAssertEqual(PlantGrowthStage.stage(for: 1.2), .mature)

        // Wilted state overrides progress
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.90, isWilted: true), .wilted)
        XCTAssertEqual(PlantGrowthStage.stage(for: 0.0, isWilted: true), .wilted)
        XCTAssertEqual(PlantGrowthStage.stage(for: 1.0, isWilted: true), .wilted)
    }

    func testGrowthStageMetadata() {
        for stage in PlantGrowthStage.allCases {
            XCTAssertFalse(stage.title.isEmpty)
            XCTAssertFalse(stage.symbol.isEmpty)
            XCTAssertFalse(stage.description.isEmpty)
        }
        XCTAssertEqual(PlantGrowthStage.seed.title, "Seed")
        XCTAssertEqual(PlantGrowthStage.sprout.title, "Sprout")
        XCTAssertEqual(PlantGrowthStage.budding.title, "Budding")
        XCTAssertEqual(PlantGrowthStage.blooming.title, "Blooming")
        XCTAssertEqual(PlantGrowthStage.mature.title, "Mature")
        XCTAssertEqual(PlantGrowthStage.wilted.title, "Wilted")
    }

    // MARK: - Plant Species Tests

    func testPlantSpeciesMapping() {
        // Test prep always yields Cherry Blossom
        XCTAssertEqual(PlantSpecies.species(for: .computerScience, taskKind: .testPrep), .cherryBlossom)
        XCTAssertEqual(PlantSpecies.species(for: .mathematics, taskKind: .testPrep), .cherryBlossom)

        // Subject cluster species mappings for standard study
        XCTAssertEqual(PlantSpecies.species(for: .computerScience, taskKind: .study), .bonsai)
        XCTAssertEqual(PlantSpecies.species(for: .mathematics, taskKind: .study), .sunflower)
        XCTAssertEqual(PlantSpecies.species(for: .physicalSciences, taskKind: .study), .succulent)
        XCTAssertEqual(PlantSpecies.species(for: .lifeSciences, taskKind: .study), .fern)
        XCTAssertEqual(PlantSpecies.species(for: .humanities, taskKind: .study), .lavender)
        XCTAssertEqual(PlantSpecies.species(for: .socialSciences, taskKind: .study), .bamboo)
        XCTAssertEqual(PlantSpecies.species(for: .general, taskKind: .study), .bonsai)
    }

    func testPlantSpeciesColorAndMetadata() {
        for species in PlantSpecies.allCases {
            XCTAssertFalse(species.displayName.isEmpty)
            XCTAssertTrue(species.primaryColorHex.hasPrefix("#"))
            XCTAssertTrue(species.accentColorHex.hasPrefix("#"))
            XCTAssertTrue(species.stemColorHex.hasPrefix("#"))
            XCTAssertFalse(species.subjectHint.isEmpty)
            XCTAssertFalse(species.rarity.isEmpty)
            // Verify color accessors instantiate without crashing
            _ = species.primaryColor
            _ = species.accentColor
            _ = species.stemColor
        }
    }

    // MARK: - GardenPlant Model Tests

    func testGardenPlantProperties() {
        let plant = GardenPlant(
            title: "Calculus Review",
            species: .sunflower,
            targetMinutes: 60,
            cognitiveMode: .activeRecall
        )

        XCTAssertEqual(plant.title, "Calculus Review")
        XCTAssertEqual(plant.species, .sunflower)
        XCTAssertEqual(plant.targetMinutes, 60)
        XCTAssertEqual(plant.focusedMinutes, 0)
        XCTAssertEqual(plant.growthProgress, 0.0)
        XCTAssertEqual(plant.growthStage, .seed)
        XCTAssertEqual(plant.cognitiveMode, .activeRecall)
        XCTAssertFalse(plant.isHarvested)
        XCTAssertFalse(plant.isMature)
        XCTAssertFalse(plant.isWilted)

        // Mutation of species and cognitiveMode
        plant.species = .lavender
        XCTAssertEqual(plant.species, .lavender)
        XCTAssertEqual(plant.speciesRaw, PlantSpecies.lavender.rawValue)

        plant.cognitiveMode = .workedExample
        XCTAssertEqual(plant.cognitiveMode, .workedExample)
        XCTAssertEqual(plant.cognitiveModeRaw, CognitiveMode.workedExample.rawValue)
    }

    // MARK: - GardenService Tests

    func testPlantSeedCreatesCorrectPlantAndGridIndex() {
        let task1 = FocusTask(title: "CSC207 Architecture", priority: 2, estimatedMinutes: 45)
        let plant1 = GardenService.plantSeed(for: task1, in: context)

        XCTAssertEqual(plant1.title, "CSC207 Architecture")
        XCTAssertEqual(plant1.species, .bonsai)
        XCTAssertEqual(plant1.targetMinutes, 45)
        XCTAssertEqual(plant1.gridIndex, 0)
        XCTAssertEqual(plant1.growthStage, .seed)
        XCTAssertEqual(plant1.taskID, task1.id)

        let task2 = FocusTask(title: "MAT223 Linear Algebra", priority: 3, estimatedMinutes: 60)
        let plant2 = GardenService.plantSeed(for: task2, in: context)

        XCTAssertEqual(plant2.title, "MAT223 Linear Algebra")
        XCTAssertEqual(plant2.species, .sunflower)
        XCTAssertEqual(plant2.gridIndex, 1)
    }

    func testUpdateProgress() {
        let task = FocusTask(title: "BIO120 Cells", priority: 2, estimatedMinutes: 50)
        let plant = GardenService.plantSeed(for: task, in: context)
        XCTAssertEqual(plant.species, .fern)

        // 25 / 50 minutes = 50% -> budding stage
        GardenService.updateProgress(plant: plant, focusedMinutes: 25, context: context)
        XCTAssertEqual(plant.focusedMinutes, 25)
        XCTAssertEqual(plant.growthProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(plant.growthStage, .budding)

        // 45 / 50 minutes = 90% -> blooming stage
        GardenService.updateProgress(plant: plant, focusedMinutes: 45, context: context)
        XCTAssertEqual(plant.growthProgress, 0.9, accuracy: 0.001)
        XCTAssertEqual(plant.growthStage, .blooming)

        // 60 / 50 minutes = clamped to 100% -> mature stage
        GardenService.updateProgress(plant: plant, focusedMinutes: 60, context: context)
        XCTAssertEqual(plant.growthProgress, 1.0, accuracy: 0.001)
        XCTAssertEqual(plant.growthStage, .mature)
        XCTAssertTrue(plant.isMature)
    }

    func testHarvestPlant() {
        let task = FocusTask(title: "SOC100 Intro", priority: 1, estimatedMinutes: 30)
        let plant = GardenService.plantSeed(for: task, in: context)

        XCTAssertNil(plant.harvestedAt)
        XCTAssertFalse(plant.isHarvested)

        GardenService.harvestPlant(plant: plant, context: context)

        XCTAssertNotNil(plant.harvestedAt)
        XCTAssertTrue(plant.isHarvested)
        XCTAssertEqual(plant.growthProgress, 1.0)
        XCTAssertEqual(plant.growthStage, .mature)
    }

    func testWiltAndRevivePlant() {
        let task = FocusTask(title: "PHY131 Lab", priority: 2, estimatedMinutes: 40)
        let plant = GardenService.plantSeed(for: task, in: context)
        GardenService.updateProgress(plant: plant, focusedMinutes: 30, context: context)

        XCTAssertFalse(plant.isWilted)
        XCTAssertEqual(plant.growthStage, .budding)

        GardenService.wiltPlant(plant: plant, context: context)
        XCTAssertTrue(plant.isWilted)
        XCTAssertEqual(plant.growthStage, .wilted)

        GardenService.revivePlant(plant: plant, context: context)
        XCTAssertFalse(plant.isWilted)
        XCTAssertEqual(plant.growthStage, .budding)
    }

    func testFetchGardenSummary() {
        // Initial empty summary
        let initialSummary = GardenService.fetchGardenSummary(in: context)
        XCTAssertEqual(initialSummary.totalPlants, 0)
        XCTAssertEqual(initialSummary.matureCount, 0)
        XCTAssertEqual(initialSummary.totalFocusedMinutes, 0)

        // Add plants
        let t1 = FocusTask(title: "CSC108 Python", priority: 2, estimatedMinutes: 30)
        let p1 = GardenService.plantSeed(for: t1, in: context)
        GardenService.updateProgress(plant: p1, focusedMinutes: 30, context: context) // Mature

        let t2 = FocusTask(title: "MAT137 Proofs", priority: 3, estimatedMinutes: 60)
        let p2 = GardenService.plantSeed(for: t2, in: context)
        GardenService.updateProgress(plant: p2, focusedMinutes: 30, context: context) // 50%

        let summary = GardenService.fetchGardenSummary(in: context)
        XCTAssertEqual(summary.totalPlants, 2)
        XCTAssertEqual(summary.matureCount, 1)
        XCTAssertEqual(summary.totalFocusedMinutes, 60)
        XCTAssertEqual(summary.speciesCounts[.bonsai], 1)
        XCTAssertEqual(summary.speciesCounts[.sunflower], 1)
        XCTAssertEqual(summary.speciesCounts[.lavender], 0)
    }

    // MARK: - AppState Botanical Progression Tests

    func testAppStateBotanicalProgressionDefaultAndPersistence() throws {
        let appState = AppStateRecord()
        XCTAssertEqual(appState.totalFocusXP, 0)
        XCTAssertEqual(appState.currentStreakDays, 0)
        XCTAssertEqual(appState.longestStreakDays, 0)
        XCTAssertNil(appState.lastFocusDate)

        // Mutate progression
        let now = Date()
        appState.totalFocusXP = 150
        appState.currentStreakDays = 5
        appState.longestStreakDays = 7
        appState.lastFocusDate = now

        context.insert(appState)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AppStateRecord>())
        XCTAssertFalse(fetched.isEmpty)
        let record = fetched.first!
        XCTAssertEqual(record.totalFocusXP, 150)
        XCTAssertEqual(record.currentStreakDays, 5)
        XCTAssertEqual(record.longestStreakDays, 7)
        XCTAssertEqual(record.lastFocusDate, now)
    }

    // MARK: - XP Pure Function Tests

    func testCalculateXPStandardProgression() {
        // Standard: 1 focus minute = 1 XP
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 25, isTestPrep: false), 25)
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 45, isTestPrep: false), 45)
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 60, isTestPrep: false), 60)
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 1, isTestPrep: false), 1)

        // Minimum 1 XP on completed session
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 0, isTestPrep: false), 1)
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: -10, isTestPrep: false), 1)
    }

    func testCalculateXPTestPrepMultiplier() {
        // Test prep: 1.2x bonus
        // 25 mins * 1.2 = 30 XP
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 25, isTestPrep: true), 30)
        // 10 mins * 1.2 = 12 XP
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 10, isTestPrep: true), 12)
        // 50 mins * 1.2 = 60 XP
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 50, isTestPrep: true), 60)
        // 15 mins * 1.2 = 18 XP
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 15, isTestPrep: true), 18)

        // Minimum 1 XP on completed session
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 1, isTestPrep: true), 1)
        XCTAssertEqual(GardenService.calculateXP(focusedMinutes: 0, isTestPrep: true), 1)
    }

    // MARK: - Streak Progression Pure Function Tests

    private var testCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        return testCalendar.date(from: comps)!
    }

    func testEvaluateStreakFirstSession() {
        let cal = testCalendar
        let now = makeDate(year: 2026, month: 9, day: 10, hour: 10)

        // First session ever (nil lastFocusDate) should yield 1 day streak
        let (newStreak, isNewDay) = GardenService.evaluateStreak(
            lastFocusDate: nil,
            now: now,
            currentStreak: 0,
            calendar: cal
        )
        XCTAssertEqual(newStreak, 1)
        XCTAssertTrue(isNewDay)

        // Even if existing streak was somehow non-zero, nil lastFocusDate resets/initializes to 1
        let (resetStreak, resetNewDay) = GardenService.evaluateStreak(
            lastFocusDate: nil,
            now: now,
            currentStreak: 5,
            calendar: cal
        )
        XCTAssertEqual(resetStreak, 1)
        XCTAssertTrue(resetNewDay)
    }

    func testEvaluateStreakSameDayMultipleSessionsIdempotency() {
        let cal = testCalendar
        let morning = makeDate(year: 2026, month: 9, day: 10, hour: 9)
        let afternoon = makeDate(year: 2026, month: 9, day: 10, hour: 14)
        let evening = makeDate(year: 2026, month: 9, day: 10, hour: 21)

        // Second session on same day
        let session2 = GardenService.evaluateStreak(
            lastFocusDate: morning,
            now: afternoon,
            currentStreak: 1,
            calendar: cal
        )
        XCTAssertEqual(session2.newStreak, 1)
        XCTAssertFalse(session2.isNewDay)

        // Third session on same day preserves streak
        let session3 = GardenService.evaluateStreak(
            lastFocusDate: afternoon,
            now: evening,
            currentStreak: 1,
            calendar: cal
        )
        XCTAssertEqual(session3.newStreak, 1)
        XCTAssertFalse(session3.isNewDay)
    }

    func testEvaluateStreakNextDayConsecutive() {
        let cal = testCalendar
        let day1 = makeDate(year: 2026, month: 9, day: 10, hour: 20)
        let day2 = makeDate(year: 2026, month: 9, day: 11, hour: 8)
        let day3 = makeDate(year: 2026, month: 9, day: 12, hour: 15)

        // Consecutive next-day session increments streak
        let resDay2 = GardenService.evaluateStreak(
            lastFocusDate: day1,
            now: day2,
            currentStreak: 1,
            calendar: cal
        )
        XCTAssertEqual(resDay2.newStreak, 2)
        XCTAssertTrue(resDay2.isNewDay)

        // Another consecutive day increments again
        let resDay3 = GardenService.evaluateStreak(
            lastFocusDate: day2,
            now: day3,
            currentStreak: 2,
            calendar: cal
        )
        XCTAssertEqual(resDay3.newStreak, 3)
        XCTAssertTrue(resDay3.isNewDay)
    }

    func testEvaluateStreakBrokenStreakAfterMissedDay() {
        let cal = testCalendar
        let day1 = makeDate(year: 2026, month: 9, day: 10, hour: 20)
        let day3 = makeDate(year: 2026, month: 9, day: 12, hour: 9) // Skipped day 2 (Sept 11)

        let broken = GardenService.evaluateStreak(
            lastFocusDate: day1,
            now: day3,
            currentStreak: 5,
            calendar: cal
        )
        XCTAssertEqual(broken.newStreak, 1)
        XCTAssertTrue(broken.isNewDay)

        // Many days later also resets to 1
        let day10 = makeDate(year: 2026, month: 9, day: 20, hour: 11)
        let older = GardenService.evaluateStreak(
            lastFocusDate: day1,
            now: day10,
            currentStreak: 10,
            calendar: cal
        )
        XCTAssertEqual(older.newStreak, 1)
        XCTAssertTrue(older.isNewDay)
    }

    // MARK: - Harvest and Duplicate Harvest Protection Tests

    func testCompleteHarvestStandardProgression() {
        let cal = testCalendar
        let day1 = makeDate(year: 2026, month: 9, day: 10, hour: 10)
        let task = FocusTask(title: "CSC207 Architecture", priority: 2, estimatedMinutes: 25)
        let plant = GardenService.plantSeed(for: task, in: context)

        let result = GardenService.completeHarvest(
            plant: plant,
            task: task,
            focusedMinutes: 25,
            now: day1,
            calendar: cal,
            context: context
        )

        XCTAssertEqual(result.xpEarned, 25)
        XCTAssertEqual(result.newTotalXP, 25)
        XCTAssertEqual(result.currentStreakDays, 1)
        XCTAssertTrue(result.isNewDailyStreak)

        // Plant properties
        XCTAssertTrue(plant.isHarvested)
        XCTAssertEqual(plant.harvestedAt, day1)
        XCTAssertEqual(plant.growthProgress, 1.0)
        XCTAssertEqual(plant.growthStage, .mature)
        XCTAssertEqual(plant.focusedMinutes, 25)

        // AppState persistence
        let appState = try? context.fetch(FetchDescriptor<AppStateRecord>()).first
        XCTAssertNotNil(appState)
        XCTAssertEqual(appState?.totalFocusXP, 25)
        XCTAssertEqual(appState?.currentStreakDays, 1)
        XCTAssertEqual(appState?.longestStreakDays, 1)
        XCTAssertEqual(appState?.lastFocusDate, day1)
    }

    func testCompleteHarvestDuplicateProtection() {
        let cal = testCalendar
        let day1 = makeDate(year: 2026, month: 9, day: 10, hour: 10)
        let task = FocusTask(title: "MAT223 Linear Algebra", priority: 2, estimatedMinutes: 25)
        let plant = GardenService.plantSeed(for: task, in: context)

        // First harvest succeeds
        let initialResult = GardenService.completeHarvest(
            plant: plant,
            task: task,
            focusedMinutes: 25,
            now: day1,
            calendar: cal,
            context: context
        )
        XCTAssertEqual(initialResult.xpEarned, 25)
        XCTAssertEqual(initialResult.newTotalXP, 25)
        XCTAssertEqual(initialResult.currentStreakDays, 1)
        XCTAssertTrue(initialResult.isNewDailyStreak)

        // Second harvest attempt on the same plant must be rejected
        let laterSameDay = makeDate(year: 2026, month: 9, day: 10, hour: 12)
        let duplicateResult = GardenService.completeHarvest(
            plant: plant,
            task: task,
            focusedMinutes: 30,
            now: laterSameDay,
            calendar: cal,
            context: context
        )

        // Must earn 0 XP and leave totals unchanged
        XCTAssertEqual(duplicateResult.xpEarned, 0)
        XCTAssertEqual(duplicateResult.newTotalXP, 25)
        XCTAssertEqual(duplicateResult.currentStreakDays, 1)
        XCTAssertFalse(duplicateResult.isNewDailyStreak)

        // Harvest timestamp was not overwritten
        XCTAssertEqual(plant.harvestedAt, day1)

        // AppState total XP remained at 25
        let appState = try? context.fetch(FetchDescriptor<AppStateRecord>()).first
        XCTAssertEqual(appState?.totalFocusXP, 25)
    }

    func testCompleteHarvestTestPrepBonus() {
        let cal = testCalendar
        let day1 = makeDate(year: 2026, month: 9, day: 10, hour: 10)
        let prepTask = FocusTask(
            title: "Calculus Midterm Review",
            priority: 3,
            estimatedMinutes: 25,
            taskKind: TaskKind.testPrep.rawValue
        )
        let plant = GardenService.plantSeed(for: prepTask, in: context)
        XCTAssertEqual(plant.species, .cherryBlossom)

        let result = GardenService.completeHarvest(
            plant: plant,
            task: prepTask,
            focusedMinutes: 25,
            now: day1,
            calendar: cal,
            context: context
        )

        // 25 mins * 1.2 = 30 XP
        XCTAssertEqual(result.xpEarned, 30)
        XCTAssertEqual(result.newTotalXP, 30)
        XCTAssertEqual(result.currentStreakDays, 1)
        XCTAssertTrue(result.isNewDailyStreak)

        let appState = try? context.fetch(FetchDescriptor<AppStateRecord>()).first
        XCTAssertEqual(appState?.totalFocusXP, 30)
    }

    func testCompleteHarvestMultiDaySequence() {
        let cal = testCalendar
        let day1 = makeDate(year: 2026, month: 9, day: 10, hour: 10)
        let day1Later = makeDate(year: 2026, month: 9, day: 10, hour: 15)
        let day2 = makeDate(year: 2026, month: 9, day: 11, hour: 11)

        // Day 1: Session 1
        let task1 = FocusTask(title: "Task 1", estimatedMinutes: 25)
        let plant1 = GardenService.plantSeed(for: task1, in: context)
        let res1 = GardenService.completeHarvest(
            plant: plant1,
            task: task1,
            focusedMinutes: 25,
            now: day1,
            calendar: cal,
            context: context
        )
        XCTAssertEqual(res1.xpEarned, 25)
        XCTAssertEqual(res1.newTotalXP, 25)
        XCTAssertEqual(res1.currentStreakDays, 1)
        XCTAssertTrue(res1.isNewDailyStreak)

        // Day 1: Session 2 (same day, accumulates XP, streak unchanged)
        let task2 = FocusTask(title: "Task 2", estimatedMinutes: 25)
        let plant2 = GardenService.plantSeed(for: task2, in: context)
        let res2 = GardenService.completeHarvest(
            plant: plant2,
            task: task2,
            focusedMinutes: 25,
            now: day1Later,
            calendar: cal,
            context: context
        )
        XCTAssertEqual(res2.xpEarned, 25)
        XCTAssertEqual(res2.newTotalXP, 50)
        XCTAssertEqual(res2.currentStreakDays, 1)
        XCTAssertFalse(res2.isNewDailyStreak)

        // Day 2: Session 3 (next day, streak increments to 2)
        let task3 = FocusTask(title: "Task 3", estimatedMinutes: 25)
        let plant3 = GardenService.plantSeed(for: task3, in: context)
        let res3 = GardenService.completeHarvest(
            plant: plant3,
            task: task3,
            focusedMinutes: 25,
            now: day2,
            calendar: cal,
            context: context
        )
        XCTAssertEqual(res3.xpEarned, 25)
        XCTAssertEqual(res3.newTotalXP, 75)
        XCTAssertEqual(res3.currentStreakDays, 2)
        XCTAssertTrue(res3.isNewDailyStreak)

        let appState = try? context.fetch(FetchDescriptor<AppStateRecord>()).first
        XCTAssertEqual(appState?.longestStreakDays, 2)
    }

    // MARK: - Session Exit Handling Tests

    func testHandleSessionExitUnderTwoMinutesDeletesPlant() throws {
        let task = FocusTask(title: "Quick Abort", estimatedMinutes: 30)
        let plant = GardenService.plantSeed(for: task, in: context)
        let taskID = task.id

        XCTAssertNotNil(GardenService.fetchPlant(for: taskID, in: context))

        // Intentional abandon under 2 minutes (< 2 mins)
        GardenService.handleSessionExit(
            plant: plant,
            focusedMinutes: 1,
            intentionalAbandon: true,
            context: context
        )

        // Unsprouted seed should be deleted from context to prevent clutter
        let fetchedPlant = GardenService.fetchPlant(for: taskID, in: context)
        XCTAssertNil(fetchedPlant)
    }

    func testHandleSessionExitZeroMinutesDeletesPlant() throws {
        let task = FocusTask(title: "Instant Abort", estimatedMinutes: 30)
        let plant = GardenService.plantSeed(for: task, in: context)
        let taskID = task.id

        GardenService.handleSessionExit(
            plant: plant,
            focusedMinutes: 0,
            intentionalAbandon: true,
            context: context
        )

        let fetchedPlant = GardenService.fetchPlant(for: taskID, in: context)
        XCTAssertNil(fetchedPlant)
    }

    func testHandleSessionExitTwoMinutesOrMoreMarksWilted() throws {
        let task = FocusTask(title: "Abandoned Mid-Study", estimatedMinutes: 30)
        let plant = GardenService.plantSeed(for: task, in: context)
        let taskID = task.id

        // Exactly 2 minutes: >= 2 mins should wilt, not delete
        GardenService.handleSessionExit(
            plant: plant,
            focusedMinutes: 2,
            intentionalAbandon: true,
            context: context
        )

        let fetchedPlant = GardenService.fetchPlant(for: taskID, in: context)
        XCTAssertNotNil(fetchedPlant)
        XCTAssertTrue(plant.isWilted)
        XCTAssertEqual(plant.growthStage, .wilted)
        XCTAssertEqual(plant.focusedMinutes, 2)

        // Abandon at 15 minutes: progress preserved and plant wilted
        let task2 = FocusTask(title: "Halfway Study", estimatedMinutes: 30)
        let plant2 = GardenService.plantSeed(for: task2, in: context)

        GardenService.handleSessionExit(
            plant: plant2,
            focusedMinutes: 15,
            intentionalAbandon: true,
            context: context
        )

        XCTAssertTrue(plant2.isWilted)
        XCTAssertEqual(plant2.focusedMinutes, 15)
        XCTAssertEqual(plant2.growthProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(plant2.growthStage, .wilted)
    }

    func testHandleSessionExitPausePreservesProgressWithoutWilting() throws {
        let task = FocusTask(title: "Paused Session", estimatedMinutes: 30)
        let plant = GardenService.plantSeed(for: task, in: context)
        let taskID = task.id

        // Pause (not abandon)
        GardenService.handleSessionExit(
            plant: plant,
            focusedMinutes: 15,
            intentionalAbandon: false,
            context: context
        )

        let fetchedPlant = GardenService.fetchPlant(for: taskID, in: context)
        XCTAssertNotNil(fetchedPlant)
        XCTAssertFalse(plant.isWilted)
        XCTAssertEqual(plant.focusedMinutes, 15)
        XCTAssertEqual(plant.growthProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(plant.growthStage, .budding)
    }
}
