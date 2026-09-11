#if !SKIP
import Foundation
import XCTest
import SwiftData
@testable import FocusGarden

@MainActor
final class ActivityLogTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var services: AppServices!

    override func setUp() {
        super.setUp()
        container = PersistenceController.inMemory()
        context = container.mainContext
        services = AppServices(container: container)
    }

    override func tearDown() {
        services = nil
        context = nil
        container = nil
        super.tearDown()
    }

    func testLogActivityCreation() {
        let log = services.logActivity(
            title: "MAT305 Problem Set",
            category: .study,
            durationMinutes: 55,
            focusRating: 4,
            energyRating: 3,
            aiUsage: .none,
            independentAttemptFirst: true,
            notes: "Solved problems 1 to 6"
        )

        XCTAssertEqual(log.title, "MAT305 Problem Set")
        XCTAssertEqual(log.category, .study)
        XCTAssertEqual(log.durationMinutes, 55)
        XCTAssertEqual(log.focusRating, 4)
        XCTAssertEqual(log.energyRating, 3)
        XCTAssertEqual(log.aiUsage, .none)
        XCTAssertTrue(log.isIndependent)
        XCTAssertTrue(log.isFocusedStudy)

        // Verifies Garden Growth accumulated
        XCTAssertEqual(services.totalFocusXP, 55)
    }

    func testRecentActivityTitlesOrderAndUniqueness() {
        services.logActivity(title: "MAT305", category: .study, durationMinutes: 30)
        services.logActivity(title: "Gym", category: .exercise, durationMinutes: 45)
        services.logActivity(title: "MAT305", category: .study, durationMinutes: 60)
        services.logActivity(title: "Reading", category: .leisure, durationMinutes: 20)

        let recents = services.recentActivityTitles(limit: 5)
        XCTAssertFalse(recents.isEmpty)
        XCTAssertEqual(recents.first, "Reading")
        XCTAssertTrue(recents.contains("MAT305"))
        XCTAssertTrue(recents.contains("Gym"))

        // Ensure no duplicates
        let duplicates = recents.filter { $0.uppercased() == "MAT305" }
        XCTAssertEqual(duplicates.count, 1)
    }

    func testGardenGrowthWithoutWilting() {
        _ = services.logActivity(
            title: "Differential Equations",
            category: .study,
            durationMinutes: 45
        )

        let plants = (try? context.fetch(FetchDescriptor<GardenPlant>())) ?? []
        XCTAssertFalse(plants.isEmpty)
        let plant = plants.first!
        XCTAssertFalse(plant.isWilted)
        XCTAssertGreaterThan(plant.focusedMinutes, 0)
    }
}
#endif
