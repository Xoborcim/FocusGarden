import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

// MARK: - GardenPlant Model

@Model
final class GardenPlant {
    var id: UUID = UUID()
    var taskID: UUID?
    var courseCode: String = ""
    var title: String = ""
    var speciesRaw: String = PlantSpecies.bonsai.rawValue
    var plantedAt: Date = Date()
    var harvestedAt: Date?
    var targetMinutes: Int = 30
    var focusedMinutes: Int = 0
    var growthProgress: Double = 0.0
    var isWilted: Bool = false
    var gridIndex: Int = 0

    init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        courseCode: String = "",
        title: String = "",
        species: PlantSpecies = .bonsai,
        plantedAt: Date = Date(),
        harvestedAt: Date? = nil,
        targetMinutes: Int = 30,
        focusedMinutes: Int = 0,
        growthProgress: Double = 0.0,
        isWilted: Bool = false,
        gridIndex: Int = 0
    ) {
        self.id = id
        self.taskID = taskID
        self.courseCode = courseCode
        self.title = title
        self.speciesRaw = species.rawValue
        self.plantedAt = plantedAt
        self.harvestedAt = harvestedAt
        self.targetMinutes = targetMinutes > 1 ? targetMinutes : 1
        self.focusedMinutes = focusedMinutes > 0 ? focusedMinutes : 0
        if growthProgress < 0.0 {
            self.growthProgress = 0.0
        } else if growthProgress > 1.0 {
            self.growthProgress = 1.0
        } else {
            self.growthProgress = growthProgress
        }
        self.isWilted = isWilted
        self.gridIndex = gridIndex
    }

    // MARK: - Computed Properties

    var species: PlantSpecies {
        get { PlantSpecies(rawValue: speciesRaw) ?? .bonsai }
        set { speciesRaw = newValue.rawValue }
    }

    var growthStage: PlantGrowthStage {
        PlantGrowthStage.stage(for: growthProgress, isWilted: isWilted)
    }

    var isHarvested: Bool {
        harvestedAt != nil
    }

    var isMature: Bool {
        growthProgress >= 1.0 && !isWilted
    }
}

// MARK: - Plant Growth Stage

enum PlantGrowthStage: String, Codable, CaseIterable, Sendable {
    case seed
    case sprout
    case budding
    case blooming
    case mature
    case wilted

    var title: String {
        switch self {
        case .seed: return "Seed"
        case .sprout: return "Sprout"
        case .budding: return "Budding"
        case .blooming: return "Blooming"
        case .mature: return "Mature"
        case .wilted: return "Wilted"
        }
    }

    var symbol: String {
        switch self {
        case .seed: return "🌱"
        case .sprout: return "🌿"
        case .budding: return "🪴"
        case .blooming: return "🌸"
        case .mature: return "🌳"
        case .wilted: return "🥀"
        }
    }

    var sfSymbol: String {
        switch self {
        case .seed: return "circle.dotted"
        case .sprout: return "leaf"
        case .budding: return "leaf.fill"
        case .blooming: return "camera.macro"
        case .mature: return "crown.fill"
        case .wilted: return "exclamationmark.triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .seed:
            return "Intention set. Planted in fertile soil, ready to grow."
        case .sprout:
            return "First green shoots appear as focus momentum builds."
        case .budding:
            return "Stems and leaf clusters expand through deep study."
        case .blooming:
            return "Vibrant petals opening as deep flow state is reached."
        case .mature:
            return "Fully grown and harvested; concepts mastered."
        case .wilted:
            return "Session paused or abandoned; ready for mindful renewal."
        }
    }

    static func stage(for progress: Double, isWilted: Bool = false) -> PlantGrowthStage {
        if isWilted {
            return .wilted
        }
        if progress < 0.20 {
            return .seed
        } else if progress < 0.50 {
            return .sprout
        } else if progress < 0.80 {
            return .budding
        } else if progress < 1.0 {
            return .blooming
        } else {
            return .mature
        }
    }
}

// MARK: - Plant Species

enum PlantSpecies: String, Codable, CaseIterable, Identifiable, Sendable {
    case bonsai
    case sunflower
    case fern
    case succulent
    case lavender
    case bamboo
    case cherryBlossom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bonsai: return "Bonsai"
        case .sunflower: return "Sunflower"
        case .fern: return "Fern"
        case .succulent: return "Succulent"
        case .lavender: return "Lavender"
        case .bamboo: return "Bamboo"
        case .cherryBlossom: return "Cherry Blossom"
        }
    }

    var primaryColorHex: String {
        switch self {
        case .bonsai: return "#33FA6B"        // FGTheme green / logic & algorithmic precision
        case .sunflower: return "#FFD54F"     // Radiant amber-yellow / mathematical modeling
        case .fern: return "#4CAF50"          // Emerald forest / life sciences & biology
        case .succulent: return "#26A69A"     // Sage teal / engineering & physical sciences
        case .lavender: return "#BA68C8"      // Violet / humanities & creative prose
        case .bamboo: return "#66BB6A"        // Bamboo stalk / social sciences & languages
        case .cherryBlossom: return "#FF80AB" // Sakura pink / special prep & milestone exam review
        }
    }

    var accentColorHex: String {
        switch self {
        case .bonsai: return "#1DE9B6"        // Cyan mint highlights
        case .sunflower: return "#FFA000"     // Deep golden amber
        case .fern: return "#81C784"          // Spring foliage highlight
        case .succulent: return "#80DEEA"     // Frost aqua tips
        case .lavender: return "#E1BEE7"      // Pale lilac highlight
        case .bamboo: return "#C8E6C9"        // Soft jade shoot
        case .cherryBlossom: return "#FF4081" // Radiant magenta
        }
    }

    var stemColorHex: String {
        switch self {
        case .bonsai: return "#5D4037"        // Rich miniature wood trunk
        case .sunflower: return "#558B2F"     // Sturdy olive stalk
        case .fern: return "#2E7D32"          // Deep forest green stem
        case .succulent: return "#00695C"     // Muted slate teal stem
        case .lavender: return "#689F38"      // Herbal sage stem
        case .bamboo: return "#33691E"        // Segmented bamboo stalk
        case .cherryBlossom: return "#4E342E" // Dark branch wood
        }
    }

    var subjectHint: String {
        switch self {
        case .bonsai: return "Computer Science / Logic"
        case .sunflower: return "Mathematics / Modeling"
        case .fern: return "Natural Sciences / Biology"
        case .succulent: return "Engineering / Physics"
        case .lavender: return "Humanities / Writing"
        case .bamboo: return "Social Sciences / Languages"
        case .cherryBlossom: return "Special Prep / Milestones"
        }
    }

    var rarity: String {
        switch self {
        case .bonsai: return "Rare"
        case .sunflower: return "Common"
        case .fern: return "Common"
        case .succulent: return "Common"
        case .lavender: return "Uncommon"
        case .bamboo: return "Common"
        case .cherryBlossom: return "Legendary"
        }
    }

    static func species(for cluster: SubjectCluster, taskKind: TaskKind) -> PlantSpecies {
        if taskKind == .testPrep {
            return .cherryBlossom
        }
        switch cluster {
        case .computerScience:
            return .bonsai
        case .mathematics:
            return .sunflower
        case .physicalSciences:
            return .succulent
        case .lifeSciences:
            return .fern
        case .humanities:
            return .lavender
        case .socialSciences:
            return .bamboo
        case .general:
            return .bonsai
        }
    }

    // MARK: - SwiftUI Color Accessors

    var primaryColor: Color {
        Color.fromHex(primaryColorHex)
    }

    var accentColor: Color {
        Color.fromHex(accentColorHex)
    }

    var stemColor: Color {
        Color.fromHex(stemColorHex)
    }
}

// MARK: - Color Hex Initializer

extension Color {
    private static func hexToInt(_ hex: String) -> Int? {
        var val = 0
        for ch in hex {
            let digit: Int
            switch ch {
            case "0": digit = 0
            case "1": digit = 1
            case "2": digit = 2
            case "3": digit = 3
            case "4": digit = 4
            case "5": digit = 5
            case "6": digit = 6
            case "7": digit = 7
            case "8": digit = 8
            case "9": digit = 9
            case "a", "A": digit = 10
            case "b", "B": digit = 11
            case "c", "C": digit = 12
            case "d", "D": digit = 13
            case "e", "E": digit = 14
            case "f", "F": digit = 15
            default: return nil
            }
            val = val * 16 + digit
        }
        return val
    }

    static func fromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean = String(clean.dropFirst())
        }
        guard let int = hexToInt(clean) else {
            return Color.clear
        }
        var a = 255
        var r = 0
        var g = 0
        var b = 0
        switch clean.count {
        case 3:
            r = (int >> 8) * 17
            g = (int >> 4 & 0xF) * 17
            b = (int & 0xF) * 17
        case 6:
            r = int >> 16
            g = int >> 8 & 0xFF
            b = int & 0xFF
        case 8:
            a = int >> 24
            r = int >> 16 & 0xFF
            g = int >> 8 & 0xFF
            b = int & 0xFF
        default:
            break
        }
        return Color(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
