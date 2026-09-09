import Foundation
import SwiftUI

enum SubjectCluster: String, CaseIterable, Identifiable, Sendable {
    case computerScience = "Computer Science"
    case mathematics = "Mathematics & Stats"
    case physicalSciences = "Physical Sciences"
    case lifeSciences = "Life Sciences"
    case socialSciences = "Social Sciences"
    case humanities = "Humanities & Languages"
    case general = "General"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .computerScience: return "CS/TECH"
        case .mathematics: return "MATH"
        case .physicalSciences: return "PHYS/ENG"
        case .lifeSciences: return "BIO/MED"
        case .socialSciences: return "SOC/ECON"
        case .humanities: return "HUMANITIES"
        case .general: return "GENERAL"
        }
    }

    var icon: String {
        switch self {
        case .computerScience: return "laptopcomputer"
        case .mathematics: return "function"
        case .physicalSciences: return "atom"
        case .lifeSciences: return "leaf.fill"
        case .socialSciences: return "chart.bar.xaxis"
        case .humanities: return "book.closed.fill"
        case .general: return "folder"
        }
    }

    var accentColor: Color {
        switch self {
        case .computerScience: return FGTheme.green
        case .mathematics: return Color(red: 0.35, green: 0.85, blue: 1.00)
        case .physicalSciences: return Color(red: 0.95, green: 0.55, blue: 0.25)
        case .lifeSciences: return Color(red: 0.40, green: 0.95, blue: 0.65)
        case .socialSciences: return FGTheme.amber
        case .humanities: return Color(red: 0.85, green: 0.60, blue: 1.00)
        case .general: return FGTheme.muted
        }
    }

    static func cluster(for codeOrTitle: String) -> SubjectCluster {
        let clean = codeOrTitle.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = String(clean.prefix(while: { $0.isLetter }))

        // Computer Science & Software Engineering
        if ["CSC", "CS", "ECE", "INF", "ROB", "SWE", "CIS", "COMP", "PROG"].contains(letters)
            || clean.contains("COMPUTER") || clean.contains("PROGRAM") || clean.contains("SOFTWARE") {
            return .computerScience
        }

        // Mathematics & Statistics
        if ["MAT", "MATH", "STA", "STAT", "ACT", "APM", "CALC", "ALG"].contains(letters)
            || clean.contains("CALCULUS") || clean.contains("ALGEBRA") || clean.contains("STATISTICS") || clean.contains("MATH") {
            return .mathematics
        }

        // Physical Sciences & Engineering
        if ["PHY", "PHYS", "CHM", "CHEM", "ENG", "ENGR", "AER", "MSE", "CIV", "MIE", "ESC", "AST", "GEO"].contains(letters)
            || clean.contains("PHYSIC") || clean.contains("CHEM") || clean.contains("ENGINEER") {
            return .physicalSciences
        }

        // Life Sciences & Medicine
        if ["BIO", "BIOL", "BCH", "PSL", "IMM", "ANA", "CSB", "EEB", "HMB", "NFS", "PHC", "MED"].contains(letters)
            || clean.contains("BIOLOGY") || clean.contains("BIOCHEM") || clean.contains("ANATOMY") {
            return .lifeSciences
        }

        // Social Sciences, Economics, Commerce, Psychology
        if ["ECO", "ECON", "MGT", "RSM", "POL", "SOC", "ANT", "GGR", "PSY", "PSYC", "CRIM", "IRE", "BUS"].contains(letters)
            || clean.contains("ECON") || clean.contains("PSYCH") || clean.contains("SOCIOL") || clean.contains("FINANCE") {
            return .socialSciences
        }

        // Humanities, Languages, Philosophy, History
        if ["HIS", "HIST", "ENG", "ENGL", "PHL", "PHIL", "CLA", "FRE", "SPA", "GER", "ITA", "EAS", "RLG", "FAH", "CIN"].contains(letters)
            || clean.contains("HISTORY") || clean.contains("PHILOSOPHY") || clean.contains("LITERATURE") {
            return .humanities
        }

        return .general
    }

    func isRelated(to other: SubjectCluster) -> Bool {
        if self == other { return true }
        switch (self, other) {
        case (.computerScience, .mathematics), (.mathematics, .computerScience): return true
        case (.computerScience, .physicalSciences), (.physicalSciences, .computerScience): return true
        case (.mathematics, .physicalSciences), (.physicalSciences, .mathematics): return true
        case (.mathematics, .socialSciences), (.socialSciences, .mathematics): return true
        case (.lifeSciences, .physicalSciences), (.physicalSciences, .lifeSciences): return true
        case (.socialSciences, .humanities), (.humanities, .socialSciences): return true
        default: return false
        }
    }
}
