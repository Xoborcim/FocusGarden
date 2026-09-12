import Foundation
import SwiftUI

// MARK: - Zodiac Sign

public enum ZodiacSign: String, CaseIterable, Identifiable, Sendable {
    case aries = "Aries"
    case taurus = "Taurus"
    case gemini = "Gemini"
    case cancer = "Cancer"
    case leo = "Leo"
    case virgo = "Virgo"
    case libra = "Libra"
    case scorpio = "Scorpio"
    case sagittarius = "Sagittarius"
    case capricorn = "Capricorn"
    case aquarius = "Aquarius"
    case pisces = "Pisces"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .aries: return "♈︎"
        case .taurus: return "♉︎"
        case .gemini: return "♊︎"
        case .cancer: return "♋︎"
        case .leo: return "♌︎"
        case .virgo: return "♍︎"
        case .libra: return "♎︎"
        case .scorpio: return "♏︎"
        case .sagittarius: return "♐︎"
        case .capricorn: return "♑︎"
        case .aquarius: return "♒︎"
        case .pisces: return "♓︎"
        }
    }

    public var element: String {
        switch self {
        case .aries, .leo, .sagittarius: return "Fire"
        case .taurus, .virgo, .capricorn: return "Earth"
        case .gemini, .libra, .aquarius: return "Air"
        case .cancer, .scorpio, .pisces: return "Water"
        }
    }

    public var celestialRuler: String {
        switch self {
        case .aries: return "Mars"
        case .taurus: return "Venus"
        case .gemini: return "Mercury"
        case .cancer: return "The Moon"
        case .leo: return "The Sun"
        case .virgo: return "Mercury"
        case .libra: return "Venus"
        case .scorpio: return "Pluto"
        case .sagittarius: return "Jupiter"
        case .capricorn: return "Saturn"
        case .aquarius: return "Uranus"
        case .pisces: return "Neptune"
        }
    }

    public var dateRangeText: String {
        switch self {
        case .aries: return "Mar 21 – Apr 19"
        case .taurus: return "Apr 20 – May 20"
        case .gemini: return "May 21 – Jun 20"
        case .cancer: return "Jun 21 – Jul 22"
        case .leo: return "Jul 23 – Aug 22"
        case .virgo: return "Aug 23 – Sep 22"
        case .libra: return "Sep 23 – Oct 22"
        case .scorpio: return "Oct 23 – Nov 21"
        case .sagittarius: return "Nov 22 – Dec 21"
        case .capricorn: return "Dec 22 – Jan 19"
        case .aquarius: return "Jan 20 – Feb 18"
        case .pisces: return "Feb 19 – Mar 20"
        }
    }

    public var scholarlyMantra: String {
        switch self {
        case .aries: return "Pioneer breakthroughs through audacious intellectual initiative."
        case .taurus: return "Build unyielding conceptual foundations through patient endurance."
        case .gemini: return "Synthesize divergent ideas into agile, interconnected frameworks."
        case .cancer: return "Nurture quiet contemplative depths and protect deep memory retention."
        case .leo: return "Command the arena of knowledge with radiant creative courage."
        case .virgo: return "Refine logic into pristine precision through meticulous taxonomy."
        case .libra: return "Harmonize opposing theories to uncover balanced objective truth."
        case .scorpio: return "Pierce surface explanations to uncover occult underlying mechanics."
        case .sagittarius: return "Pursue boundless universal horizons and philosophical expansion."
        case .capricorn: return "Ascend rigorous academic summits through disciplined mastery."
        case .aquarius: return "Envision future systems and liberate thinking from obsolete paradigms."
        case .pisces: return "Dissolve analytical boundaries to grasp intuitive poetic unity."
        }
    }

    public var accentColor: Color {
        switch self {
        case .aries, .leo, .sagittarius: return FGTheme.stainedGlassRuby
        case .taurus, .virgo, .capricorn: return FGTheme.stainedGlassEmerald
        case .gemini, .libra, .aquarius: return FGTheme.stainedGlassAmber
        case .cancer, .scorpio, .pisces: return FGTheme.stainedGlassSapphire
        }
    }

    /// Determines the active solar zodiac sign for any given date
    public static func current(for date: Date = Date(), calendar: Calendar = .current) -> ZodiacSign {
        let month = calendar.component(Calendar.Component.month, from: date)
        let day = calendar.component(Calendar.Component.day, from: date)

        switch month {
        case 1: return day <= 19 ? .capricorn : .aquarius
        case 2: return day <= 18 ? .aquarius : .pisces
        case 3: return day <= 20 ? .pisces : .aries
        case 4: return day <= 19 ? .aries : .taurus
        case 5: return day <= 20 ? .taurus : .gemini
        case 6: return day <= 20 ? .gemini : .cancer
        case 7: return day <= 22 ? .cancer : .leo
        case 8: return day <= 22 ? .leo : .virgo
        case 9: return day <= 22 ? .virgo : .libra
        case 10: return day <= 22 ? .libra : .scorpio
        case 11: return day <= 21 ? .scorpio : .sagittarius
        case 12: return day <= 21 ? .sagittarius : .capricorn
        default: return .virgo
        }
    }
}

// MARK: - Tarot Major Arcana

public enum TarotArcana: String, CaseIterable, Identifiable, Sendable {
    case magician = "The Magician"
    case highPriestess = "The High Priestess"
    case empress = "The Empress"
    case emperor = "The Emperor"
    case hierophant = "The Hierophant"
    case lovers = "The Lovers"
    case chariot = "The Chariot"
    case strength = "Strength"
    case hermit = "The Hermit"
    case wheelOfFortune = "Wheel of Fortune"
    case justice = "Justice"
    case hangedMan = "The Hanged Man"
    case temperance = "Temperance"
    case star = "The Star"
    case moon = "The Moon"
    case sun = "The Sun"
    case judgement = "Judgement"
    case world = "The World"

    public var id: String { rawValue }

    public var romanNumeral: String {
        switch self {
        case .magician: return "I"
        case .highPriestess: return "II"
        case .empress: return "III"
        case .emperor: return "IV"
        case .hierophant: return "V"
        case .lovers: return "VI"
        case .chariot: return "VII"
        case .strength: return "VIII"
        case .hermit: return "IX"
        case .wheelOfFortune: return "X"
        case .justice: return "XI"
        case .hangedMan: return "XII"
        case .temperance: return "XIV"
        case .star: return "XVII"
        case .moon: return "XVIII"
        case .sun: return "XIX"
        case .judgement: return "XX"
        case .world: return "XXI"
        }
    }

    public var icon: String {
        switch self {
        case .magician: return "wand.and.stars"
        case .highPriestess: return "book.closed.fill"
        case .empress: return "leaf.circle.fill"
        case .emperor: return "crown.fill"
        case .hierophant: return "building.columns.fill"
        case .lovers: return "heart.fill"
        case .chariot: return "shield.lefthalf.filled"
        case .strength: return "hand.raised.fill"
        case .hermit: return "lantern.fill"
        case .wheelOfFortune: return "circle.dashed"
        case .justice: return "scale.3d"
        case .hangedMan: return "eye.circle.fill"
        case .temperance: return "drop.degreesign.fill"
        case .star: return "sparkles"
        case .moon: return "moon.stars.fill"
        case .sun: return "sun.max.fill"
        case .judgement: return "bell.badge.fill"
        case .world: return "globe.europe.africa.fill"
        }
    }

    public var domain: String {
        switch self {
        case .magician: return "Willpower & Synthesis"
        case .highPriestess: return "Intuition & Deep Reading"
        case .empress: return "Creative Genesis & Flow"
        case .emperor: return "Structure & Discipline"
        case .hierophant: return "Scholarly Tradition & Mastery"
        case .lovers: return "Devotion to the Craft"
        case .chariot: return "Triumph Over Distraction"
        case .strength: return "Patience with Difficulty"
        case .hermit: return "Solitary Contemplation"
        case .wheelOfFortune: return "Momentum & Cycles"
        case .justice: return "Analytical Rigor"
        case .hangedMan: return "Shifting Perspective"
        case .temperance: return "Alchemy of Rest & Work"
        case .star: return "Intellectual Clarity"
        case .moon: return "Nocturnal Exploration"
        case .sun: return "Illumination & Breakthrough"
        case .judgement: return "Culmination & Awakening"
        case .world: return "Holistic Mastery"
        }
    }

    public var contemplation: String {
        switch self {
        case .magician:
            return "Assemble your instruments. Focus turns abstract thoughts into materialized code and prose."
        case .highPriestess:
            return "Trust the quiet retention of your mind. Silent reading reveals the hidden patterns between lines."
        case .empress:
            return "Let creative thoughts flourish without premature editing. Growth requires generous soil."
        case .emperor:
            return "Erect boundaries around your attention. Impose sovereign architecture over scattered impulses."
        case .hierophant:
            return "Respect foundational theorems. Study canonical proofs before attempting radical revisions."
        case .lovers:
            return "Align your study block with deep purpose. Half-hearted attention invites immediate fatigue."
        case .chariot:
            return "Harness conflicting distractions into forward momentum. Drive the session directly to completion."
        case .strength:
            return "Do not war violently with hard problems. Approach complex proofs with calm, unrelenting resolve."
        case .hermit:
            return "Step inside your quiet cell. Solitude is the sanctuary where profound intellect takes shape."
        case .wheelOfFortune:
            return "Ride the natural tides of energy. If focus surges, deepen your labors without hesitation."
        case .justice:
            return "Eliminate biases in your reasoning. Verify assumptions and let factual rigor govern each conclusion."
        case .hangedMan:
            return "When stuck on a problem set, invert your angle. Pausing is often the catalyst for sudden insight."
        case .temperance:
            return "Blend rigorous focus sprints with restorative silence. Sustainable scholarship is an alchemical balance."
        case .star:
            return "Hold the beacon of your long-term goal. Hope and clarity dissolve the fog of dense research."
        case .moon:
            return "Traverse the enigmatic nocturnal hours. Let intuition guide your contemplation into the unknown."
        case .sun:
            return "Radiant clarity crowns your labors. Mastered concepts shine with unmistakable lucidity."
        case .judgement:
            return "The trial approaches. Summon all previous vigils and syntheses into unified readiness."
        case .world:
            return "A milestone cycle completes. Celebrate your botanical harvest and integrate total comprehension."
        }
    }

    public var accentColor: Color {
        switch self {
        case .magician, .star: return FGTheme.stainedGlassSapphire
        case .highPriestess, .hermit, .moon: return FGTheme.stainedGlassViolet
        case .empress, .temperance: return FGTheme.stainedGlassEmerald
        case .emperor, .chariot, .judgement: return FGTheme.stainedGlassRuby
        case .hierophant, .sun: return FGTheme.stainedGlassAmber
        case .lovers, .strength, .wheelOfFortune, .justice, .hangedMan, .world: return FGTheme.stainedGlassViolet
        }
    }

    /// Generates a deterministic Daily Arcana based on day of year
    public static func dailyCard(for date: Date = Date(), calendar: Calendar = .current) -> TarotArcana {
        let month = calendar.component(Calendar.Component.month, from: date)
        let day = calendar.component(Calendar.Component.day, from: date)
        let seed = month * 31 + day
        let all = Self.allCases
        let index = abs(seed) % all.count
        return all[index]
    }
}
