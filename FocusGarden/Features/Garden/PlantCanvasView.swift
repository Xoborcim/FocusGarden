import SwiftUI

// MARK: - PlantCanvasView

/// A high-performance procedural vector graphics view for FocusGarden botanical growth.
/// Renders plants across 5 growth stages (.seed, .sprout, .budding, .blooming, .mature) plus wilted state,
/// featuring continuous harmonic wind swaying via `TimelineView(.animation)` and unique species silhouettes.
struct PlantCanvasView: View {
    var species: PlantSpecies
    var progress: Double
    var isWilted: Bool
    var isAnimated: Bool
    var size: CGFloat

    init(
        species: PlantSpecies = .sunflower,
        progress: Double = 0.0,
        isWilted: Bool = false,
        isAnimated: Bool = true,
        size: CGFloat = 160
    ) {
        self.species = species
        self.progress = min(1.0, max(0.0, progress))
        self.isWilted = isWilted
        self.isAnimated = isAnimated
        self.size = size
    }

    /// Convenience initializer accepting species name as String
    init(
        speciesName: String,
        progress: Double = 0.0,
        isWilted: Bool = false,
        isAnimated: Bool = true,
        size: CGFloat = 160
    ) {
        self.init(
            species: PlantSpecies(rawValue: speciesName) ?? .sunflower,
            progress: progress,
            isWilted: isWilted,
            isAnimated: isAnimated,
            size: size
        )
    }

    /// Convenience initializer accepting a GardenPlant model
    init(
        plant: GardenPlant,
        isAnimated: Bool = true,
        size: CGFloat = 160
    ) {
        self.init(
            species: plant.species,
            progress: plant.growthProgress,
            isWilted: plant.isWilted,
            isAnimated: isAnimated,
            size: size
        )
    }

    var body: some View {
        #if !SKIP
        Canvas { context, canvasSize in
            PlantRenderer.render(
                context: &context,
                size: canvasSize,
                species: species,
                progress: progress,
                isWilted: isWilted,
                date: Date(timeIntervalSinceReferenceDate: 0)
            )
        }
        .frame(width: size, height: size)
        #else
        ZStack {
            Circle()
                .fill(species.primaryColor.opacity(0.18))
            Image(systemName: species.sfSymbol)
                .font(.system(size: size * 0.45))
                .foregroundStyle(isWilted ? FGTheme.muted : species.primaryColor)
        }
        .frame(width: size, height: size)
        #endif
    }
}

// MARK: - PlantSpecies Extensions

extension PlantSpecies {
    /// Species-specific foliage green
    var leafColor: Color {
        switch self {
        case .bonsai: return Color(red: 0.16, green: 0.72, blue: 0.42)
        case .sunflower: return Color(red: 0.32, green: 0.76, blue: 0.28)
        case .fern: return Color(red: 0.22, green: 0.90, blue: 0.42)
        case .succulent: return Color(red: 0.22, green: 0.82, blue: 0.72)
        case .lavender: return Color(red: 0.42, green: 0.68, blue: 0.48)
        case .bamboo: return Color(red: 0.36, green: 0.86, blue: 0.38)
        case .cherryBlossom: return Color(red: 0.42, green: 0.72, blue: 0.35)
        }
    }

    var sfSymbol: String {
        switch self {
        case .bonsai: return "tree.fill"
        case .sunflower: return "sun.max.fill"
        case .fern: return "leaf.fill"
        case .succulent: return "circle.hexagongrid.fill"
        case .lavender: return "sparkles"
        case .bamboo: return "lines.measurement.vertical"
        case .cherryBlossom: return "flower.fill"
        }
    }
}

// MARK: - Procedural Plant Renderer

#if !SKIP
enum PlantRenderer {

    // MARK: Palette & Constants

    private static let wiltedStem = Color(red: 0.38, green: 0.33, blue: 0.25)
    private static let wiltedLeaf = Color(red: 0.48, green: 0.43, blue: 0.34)
    private static let wiltedPetal = Color(red: 0.54, green: 0.48, blue: 0.39)
    private static let wiltedSoil = Color(red: 0.24, green: 0.21, blue: 0.17)

    // MARK: Master Render Entry

    static func render(
        context: inout GraphicsContext,
        size: CGSize,
        species: PlantSpecies,
        progress: Double,
        isWilted: Bool,
        date: Date
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82

        // Time & sway physics
        let time = date.timeIntervalSinceReferenceDate
        let swayHarmonic = sin(time * 1.5) * 0.75 + sin(time * 2.8) * 0.25

        let stage = PlantGrowthStage.stage(for: progress, isWilted: isWilted)

        let maxSwayAngle: Double
        switch stage {
        case .seed: maxSwayAngle = 0.0
        case .sprout: maxSwayAngle = 0.05
        case .budding: maxSwayAngle = 0.08
        case .blooming: maxSwayAngle = 0.11
        case .mature: maxSwayAngle = 0.13
        case .wilted: maxSwayAngle = 0.02
        }

        let swayAngle: Double
        if isWilted {
            swayAngle = 0.35 + 0.03 * sin(time * 0.8)
        } else {
            swayAngle = swayHarmonic * maxSwayAngle
        }

        // 1. Sleek planter dish & soil mound base
        drawPlanter(context: &context, size: size, accent: species.accentColor, isWilted: isWilted)

        // 2. Growth Stage Rendering
        if isWilted && progress < 0.20 {
            drawSeedStage(context: &context, size: size, progress: progress, time: time, species: species, isWilted: true)
            return
        }

        switch stage {
        case .seed:
            drawSeedStage(context: &context, size: size, progress: progress, time: time, species: species, isWilted: false)

        case .sprout:
            drawSproutStage(context: &context, size: size, progress: progress, sway: CGFloat(swayAngle), species: species, isWilted: isWilted)

        case .budding:
            drawBuddingStage(context: &context, size: size, progress: progress, sway: CGFloat(swayAngle), species: species, isWilted: isWilted)

        case .blooming, .mature, .wilted:
            drawSpeciesBlossom(
                context: &context,
                size: size,
                species: species,
                progress: progress,
                stage: stage,
                sway: CGFloat(swayAngle),
                time: time,
                isWilted: isWilted
            )
        }

        // 3. Floating pollen particles or sakura motes (Mature only)
        if stage == .mature && !isWilted {
            drawFloatingPollen(
                context: &context,
                size: size,
                center: CGPoint(x: cx, y: dishY - h * 0.45),
                species: species,
                time: time
            )
        }
    }

    // MARK: - Planter Base & Soil

    private static func drawPlanter(
        context: inout GraphicsContext,
        size: CGSize,
        accent: Color,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82
        let dishH = h * 0.08
        let dishBottomY = dishY + dishH
        let dishW = w * 0.58
        let dishBottomW = w * 0.44

        let left = cx - dishW * 0.5
        let right = cx + dishW * 0.5
        let bLeft = cx - dishBottomW * 0.5
        let bRight = cx + dishBottomW * 0.5

        // Drop shadow under planter
        var shadowPath = Path()
        shadowPath.addEllipse(in: CGRect(x: cx - dishW * 0.45, y: dishBottomY - 1, width: dishW * 0.90, height: h * 0.035))
        context.fill(shadowPath, with: .color(Color.black.opacity(0.50)))

        // Planter Dish Body (trapezoid with subtle bevel)
        var dishPath = Path()
        dishPath.move(to: CGPoint(x: left, y: dishY))
        dishPath.addLine(to: CGPoint(x: right, y: dishY))
        dishPath.addLine(to: CGPoint(x: bRight, y: dishBottomY))
        dishPath.addLine(to: CGPoint(x: bLeft, y: dishBottomY))
        dishPath.closeSubpath()

        let dishGradient = Gradient(colors: [
            Color(red: 0.13, green: 0.14, blue: 0.16),
            Color(red: 0.06, green: 0.07, blue: 0.08)
        ])
        context.fill(
            dishPath,
            with: .linearGradient(
                dishGradient,
                startPoint: CGPoint(x: cx, y: dishY),
                endPoint: CGPoint(x: cx, y: dishBottomY)
            )
        )
        context.stroke(dishPath, with: .color(Color.white.opacity(0.09)), lineWidth: 1)

        // Rim highlight line
        var rimPath = Path()
        rimPath.move(to: CGPoint(x: left, y: dishY))
        rimPath.addLine(to: CGPoint(x: right, y: dishY))
        let rimColor = isWilted ? Color.white.opacity(0.12) : accent.opacity(0.42)
        context.stroke(rimPath, with: .color(rimColor), lineWidth: 1.5)

        // Rich dark soil mound
        let soilMoundHeight = h * 0.032
        var soilPath = Path()
        soilPath.move(to: CGPoint(x: left + 2, y: dishY))
        soilPath.addQuadCurve(
            to: CGPoint(x: right - 2, y: dishY),
            control: CGPoint(x: cx, y: dishY - soilMoundHeight)
        )
        soilPath.closeSubpath()

        let soilTop = isWilted ? wiltedSoil : Color(red: 0.18, green: 0.15, blue: 0.12)
        let soilBottom = isWilted ? Color(red: 0.16, green: 0.13, blue: 0.10) : Color(red: 0.09, green: 0.08, blue: 0.06)
        context.fill(
            soilPath,
            with: .linearGradient(
                Gradient(colors: [soilTop, soilBottom]),
                startPoint: CGPoint(x: cx, y: dishY - soilMoundHeight),
                endPoint: CGPoint(x: cx, y: dishY)
            )
        )
    }

    // MARK: - Stage 1: Seed

    private static func drawSeedStage(
        context: inout GraphicsContext,
        size: CGSize,
        progress: Double,
        time: TimeInterval,
        species: PlantSpecies,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82
        let seedCenter = CGPoint(x: cx, y: dishY - h * 0.012)

        let pulse = isWilted ? 0.0 : (0.5 + 0.5 * sin(time * 3.0))

        // Glowing pulsing aura behind seed
        if !isWilted {
            let glowRadius = w * (0.07 + 0.03 * pulse)
            var glowContext = context
            glowContext.addFilter(.blur(radius: 5))
            var glowPath = Path()
            glowPath.addEllipse(in: CGRect(
                x: seedCenter.x - glowRadius,
                y: seedCenter.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            ))
            glowContext.fill(glowPath, with: .color(species.accentColor.opacity(0.38 * pulse)))
        }

        // Seed Kernel (tilted almond shape)
        let kernelW = w * 0.046
        let kernelH = h * 0.032
        var seedContext = context
        seedContext.translateBy(x: seedCenter.x, y: seedCenter.y)
        seedContext.rotate(by: .degrees(16))

        var kernelPath = Path()
        kernelPath.addEllipse(in: CGRect(x: -kernelW * 0.5, y: -kernelH * 0.5, width: kernelW, height: kernelH))
        let kernelColor = isWilted ? Color(red: 0.38, green: 0.34, blue: 0.28) : Color(red: 0.88, green: 0.74, blue: 0.36)
        seedContext.fill(kernelPath, with: .color(kernelColor))
        seedContext.stroke(kernelPath, with: .color(Color.white.opacity(0.22)), lineWidth: 0.8)

        // Tiny emerging green tip
        let t = max(0.0, min(1.0, progress / 0.20))
        if t > 0.18 {
            let tipProgress = (t - 0.18) / 0.82
            let tipHeight = h * 0.055 * tipProgress
            var tipPath = Path()
            tipPath.move(to: CGPoint(x: cx + w * 0.005, y: seedCenter.y))
            tipPath.addQuadCurve(
                to: CGPoint(x: cx + w * 0.014, y: seedCenter.y - tipHeight),
                control: CGPoint(x: cx + w * 0.002, y: seedCenter.y - tipHeight * 0.5)
            )
            let tipColor = isWilted ? wiltedLeaf : FGTheme.green
            context.stroke(
                tipPath,
                with: .color(tipColor),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )

            // Emerging cotyledon specks
            if tipProgress > 0.40 {
                let tipTop = CGPoint(x: cx + w * 0.014, y: seedCenter.y - tipHeight)
                let microSize = w * 0.016 * tipProgress
                var lLeaf = Path()
                lLeaf.addEllipse(in: CGRect(x: tipTop.x - microSize * 1.5, y: tipTop.y - microSize * 0.8, width: microSize * 1.6, height: microSize))
                context.fill(lLeaf, with: .color(tipColor))

                var rLeaf = Path()
                rLeaf.addEllipse(in: CGRect(x: tipTop.x, y: tipTop.y - microSize * 0.9, width: microSize * 1.6, height: microSize))
                context.fill(rLeaf, with: .color(tipColor.opacity(0.85)))
            }
        }
    }

    // MARK: - Stage 2: Sprout

    private static func drawSproutStage(
        context: inout GraphicsContext,
        size: CGSize,
        progress: Double,
        sway: CGFloat,
        species: PlantSpecies,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82
        let soilCenter = CGPoint(x: cx, y: dishY - h * 0.015)

        let t = min(1.0, max(0.0, (progress - 0.20) / 0.30))
        let stemHeight = h * (0.18 + 0.18 * t)

        let tipX: CGFloat
        let tipY: CGFloat
        let ctrl1: CGPoint
        let ctrl2: CGPoint

        if isWilted {
            tipX = cx + w * 0.16
            tipY = dishY - stemHeight * 0.55
            ctrl1 = CGPoint(x: cx + w * 0.03, y: dishY - stemHeight * 0.30)
            ctrl2 = CGPoint(x: cx + w * 0.14, y: dishY - stemHeight * 0.75)
        } else {
            let swayOffset = sway * stemHeight * 0.8
            tipX = cx + swayOffset
            tipY = dishY - stemHeight
            ctrl1 = CGPoint(x: cx + swayOffset * 0.25, y: dishY - stemHeight * 0.40)
            ctrl2 = CGPoint(x: cx + swayOffset * 0.70, y: dishY - stemHeight * 0.80)
        }

        var stemPath = Path()
        stemPath.move(to: soilCenter)
        stemPath.addCurve(to: CGPoint(x: tipX, y: tipY), control1: ctrl1, control2: ctrl2)

        let stemColor = isWilted ? wiltedStem : species.stemColor
        context.stroke(
            stemPath,
            with: .color(stemColor),
            style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
        )

        // 2 symmetrical leaves unfurling
        let leafLen = w * (0.065 + 0.055 * t)
        let leafWid = leafLen * 0.54
        let spreadDeg: Double = isWilted ? 75.0 : (25.0 + 35.0 * t)
        let leafColor = isWilted ? wiltedLeaf : species.leafColor

        drawLeaf(
            context: &context,
            origin: CGPoint(x: tipX, y: tipY),
            length: leafLen,
            width: leafWid,
            angleDeg: isWilted ? 100.0 : (-90.0 - spreadDeg),
            color: leafColor
        )

        drawLeaf(
            context: &context,
            origin: CGPoint(x: tipX, y: tipY),
            length: leafLen,
            width: leafWid,
            angleDeg: isWilted ? 80.0 : (-90.0 + spreadDeg),
            color: leafColor
        )
    }

    // MARK: - Stage 3: Budding

    private static func drawBuddingStage(
        context: inout GraphicsContext,
        size: CGSize,
        progress: Double,
        sway: CGFloat,
        species: PlantSpecies,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82
        let soilCenter = CGPoint(x: cx, y: dishY - h * 0.015)

        let t = min(1.0, max(0.0, (progress - 0.50) / 0.30))
        let stemHeight = h * (0.36 + 0.16 * t)

        let tipX: CGFloat
        let tipY: CGFloat
        let ctrl1: CGPoint
        let ctrl2: CGPoint

        if isWilted {
            tipX = cx + w * 0.20
            tipY = dishY - stemHeight * 0.52
            ctrl1 = CGPoint(x: cx + w * 0.04, y: dishY - stemHeight * 0.32)
            ctrl2 = CGPoint(x: cx + w * 0.18, y: dishY - stemHeight * 0.72)
        } else {
            let swayOffset = sway * stemHeight * 0.85
            tipX = cx + swayOffset
            tipY = dishY - stemHeight
            ctrl1 = CGPoint(x: cx + swayOffset * 0.28, y: dishY - stemHeight * 0.42)
            ctrl2 = CGPoint(x: cx + swayOffset * 0.72, y: dishY - stemHeight * 0.78)
        }

        var stemPath = Path()
        stemPath.move(to: soilCenter)
        stemPath.addCurve(to: CGPoint(x: tipX, y: tipY), control1: ctrl1, control2: ctrl2)

        let stemColor = isWilted ? wiltedStem : species.stemColor
        context.stroke(
            stemPath,
            with: .color(stemColor),
            style: StrokeStyle(lineWidth: 3.6, lineCap: .round)
        )

        let leafColor = isWilted ? wiltedLeaf : species.leafColor

        // Lower node leaves (35% height)
        let node1X = cx + (tipX - cx) * 0.35
        let node1Y = dishY - stemHeight * 0.35
        drawLeaf(context: &context, origin: CGPoint(x: node1X, y: node1Y), length: w * 0.13, width: w * 0.065, angleDeg: isWilted ? 100 : -140, color: leafColor)
        drawLeaf(context: &context, origin: CGPoint(x: node1X, y: node1Y), length: w * 0.13, width: w * 0.065, angleDeg: isWilted ? 80 : -40, color: leafColor)

        // Mid node leaves (65% height)
        let node2X = cx + (tipX - cx) * 0.65
        let node2Y = dishY - stemHeight * 0.65
        drawLeaf(context: &context, origin: CGPoint(x: node2X, y: node2Y), length: w * 0.10, width: w * 0.05, angleDeg: isWilted ? 110 : -130, color: leafColor)
        drawLeaf(context: &context, origin: CGPoint(x: node2X, y: node2Y), length: w * 0.10, width: w * 0.05, angleDeg: isWilted ? 70 : -50, color: leafColor)

        // Swelling Flower Bud at tip
        let budRadius = w * (0.040 + 0.025 * t)
        var budCtx = context
        budCtx.translateBy(x: tipX, y: tipY)
        let budAngle = isWilted ? 95.0 : (Double(sway) * 18.0)
        budCtx.rotate(by: .degrees(budAngle))

        // Protective green sepals
        var sepalPath = Path()
        sepalPath.move(to: CGPoint(x: -budRadius * 0.7, y: 0))
        sepalPath.addQuadCurve(to: CGPoint(x: 0, y: -budRadius * 1.3), control: CGPoint(x: -budRadius * 0.8, y: -budRadius * 0.7))
        sepalPath.addQuadCurve(to: CGPoint(x: budRadius * 0.7, y: 0), control: CGPoint(x: budRadius * 0.8, y: -budRadius * 0.7))
        sepalPath.closeSubpath()
        budCtx.fill(sepalPath, with: .color(isWilted ? wiltedLeaf : species.stemColor))

        // Peeking petal color
        let petalColor = isWilted ? wiltedPetal : species.primaryColor
        var budPetal = Path()
        budPetal.addEllipse(in: CGRect(x: -budRadius * 0.45, y: -budRadius * 1.5, width: budRadius * 0.9, height: budRadius * 1.1))
        budCtx.fill(budPetal, with: .color(petalColor))
    }

    // MARK: - Stage 4 & 5: Species Blossom Dispatcher

    private static func drawSpeciesBlossom(
        context: inout GraphicsContext,
        size: CGSize,
        species: PlantSpecies,
        progress: Double,
        stage: PlantGrowthStage,
        sway: CGFloat,
        time: TimeInterval,
        isWilted: Bool
    ) {
        let bloomT = min(1.0, max(0.0, (progress - 0.80) / 0.20))

        switch species {
        case .sunflower:
            drawSunflower(context: &context, size: size, bloomT: bloomT, sway: sway, isMature: stage == .mature, isWilted: isWilted)
        case .bonsai:
            drawBonsai(context: &context, size: size, bloomT: bloomT, sway: sway, isMature: stage == .mature, isWilted: isWilted)
        case .lavender:
            drawLavender(context: &context, size: size, bloomT: bloomT, sway: sway, isMature: stage == .mature, isWilted: isWilted)
        case .succulent:
            drawSucculent(context: &context, size: size, bloomT: bloomT, sway: sway, isMature: stage == .mature, isWilted: isWilted)
        case .fern:
            drawFern(context: &context, size: size, bloomT: bloomT, sway: sway, isMature: stage == .mature, isWilted: isWilted)
        case .bamboo:
            drawBamboo(context: &context, size: size, bloomT: bloomT, sway: sway, isMature: stage == .mature, isWilted: isWilted)
        case .cherryBlossom:
            drawCherryBlossom(context: &context, size: size, bloomT: bloomT, sway: sway, isMature: stage == .mature, isWilted: isWilted)
        }
    }

    // MARK: - Silhouette 1: Sunflower

    private static func drawSunflower(
        context: inout GraphicsContext,
        size: CGSize,
        bloomT: Double,
        sway: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82
        let stemHeight = h * 0.52

        let tipX: CGFloat
        let tipY: CGFloat
        let ctrl1: CGPoint
        let ctrl2: CGPoint

        if isWilted {
            tipX = cx + w * 0.22
            tipY = dishY - stemHeight * 0.50
            ctrl1 = CGPoint(x: cx + w * 0.04, y: dishY - stemHeight * 0.32)
            ctrl2 = CGPoint(x: cx + w * 0.20, y: dishY - stemHeight * 0.72)
        } else {
            let swayOffset = sway * stemHeight * 0.9
            tipX = cx + swayOffset
            tipY = dishY - stemHeight
            ctrl1 = CGPoint(x: cx + swayOffset * 0.25, y: dishY - stemHeight * 0.40)
            ctrl2 = CGPoint(x: cx + swayOffset * 0.70, y: dishY - stemHeight * 0.80)
        }

        // Stem
        var stemPath = Path()
        stemPath.move(to: CGPoint(x: cx, y: dishY - h * 0.015))
        stemPath.addCurve(to: CGPoint(x: tipX, y: tipY), control1: ctrl1, control2: ctrl2)
        let stemColor = isWilted ? wiltedStem : Color(red: 0.30, green: 0.65, blue: 0.22)
        context.stroke(stemPath, with: .color(stemColor), style: StrokeStyle(lineWidth: 4.0, lineCap: .round))

        // Leaves
        let leafColor = isWilted ? wiltedLeaf : PlantSpecies.sunflower.leafColor
        let node1X = cx + (tipX - cx) * 0.35
        let node1Y = dishY - stemHeight * 0.35
        drawLeaf(context: &context, origin: CGPoint(x: node1X, y: node1Y), length: w * 0.15, width: w * 0.08, angleDeg: isWilted ? 100 : -140, color: leafColor)
        drawLeaf(context: &context, origin: CGPoint(x: node1X, y: node1Y), length: w * 0.15, width: w * 0.08, angleDeg: isWilted ? 80 : -40, color: leafColor)

        let node2X = cx + (tipX - cx) * 0.65
        let node2Y = dishY - stemHeight * 0.65
        drawLeaf(context: &context, origin: CGPoint(x: node2X, y: node2Y), length: w * 0.12, width: w * 0.065, angleDeg: isWilted ? 110 : -130, color: leafColor)
        drawLeaf(context: &context, origin: CGPoint(x: node2X, y: node2Y), length: w * 0.12, width: w * 0.065, angleDeg: isWilted ? 70 : -50, color: leafColor)

        // Flower Head
        var headCtx = context
        headCtx.translateBy(x: tipX, y: tipY)
        let headAngle = isWilted ? 105.0 : (Double(sway) * 15.0)
        headCtx.rotate(by: .degrees(headAngle))

        // Subtle glowing aura for mature
        if isMature && !isWilted {
            let auraRadius = w * 0.22
            var auraCtx = headCtx
            auraCtx.addFilter(.blur(radius: 8))
            var auraPath = Path()
            auraPath.addEllipse(in: CGRect(x: -auraRadius, y: -auraRadius, width: auraRadius * 2, height: auraRadius * 2))
            auraCtx.fill(auraPath, with: .color(FGTheme.amber.opacity(0.24)))
        }

        let petalCount = 14
        let petalLen = w * (0.08 + 0.10 * bloomT)
        let petalWid = petalLen * 0.36
        let angleStep = 360.0 / Double(petalCount)

        // Layer 1: Back petals (warm amber)
        let backColor = isWilted ? wiltedPetal : Color(red: 0.94, green: 0.60, blue: 0.10)
        for i in 0..<petalCount {
            let angle = Double(i) * angleStep + (angleStep * 0.5)
            var pCtx = headCtx
            pCtx.rotate(by: .degrees(angle))
            var p = Path()
            p.addEllipse(in: CGRect(x: -petalWid * 0.5, y: -petalLen, width: petalWid, height: petalLen))
            pCtx.fill(p, with: .color(backColor))
        }

        // Layer 2: Front petals (bright radiant gold)
        let frontColor = isWilted ? wiltedPetal.opacity(0.85) : FGTheme.amber
        for i in 0..<petalCount {
            let angle = Double(i) * angleStep
            var pCtx = headCtx
            pCtx.rotate(by: .degrees(angle))
            var p = Path()
            p.addEllipse(in: CGRect(x: -petalWid * 0.5, y: -petalLen * 0.95, width: petalWid, height: petalLen * 0.95))
            pCtx.fill(p, with: .color(frontColor))
        }

        // Center disk (dark cocoa chocolate with concentric rings)
        let diskRadius = w * (0.07 + 0.03 * bloomT)
        let centerColor = isWilted ? Color(red: 0.26, green: 0.22, blue: 0.18) : Color(red: 0.22, green: 0.14, blue: 0.08)
        var diskPath = Path()
        diskPath.addEllipse(in: CGRect(x: -diskRadius, y: -diskRadius, width: diskRadius * 2, height: diskRadius * 2))
        headCtx.fill(diskPath, with: .color(centerColor))
        headCtx.stroke(diskPath, with: .color(Color(red: 0.15, green: 0.09, blue: 0.05)), lineWidth: 1.5)

        // Seed ring dots
        if !isWilted {
            let dotRingRadius = diskRadius * 0.58
            let dotCount = 10
            for i in 0..<dotCount {
                let dotAngle = (Double(i) / Double(dotCount)) * .pi * 2.0
                let dx = cos(dotAngle) * dotRingRadius
                let dy = sin(dotAngle) * dotRingRadius
                var dot = Path()
                dot.addEllipse(in: CGRect(x: dx - 1.2, y: dy - 1.2, width: 2.4, height: 2.4))
                headCtx.fill(dot, with: .color(FGTheme.amber.opacity(0.65)))
            }
        }
    }

    // MARK: - Silhouette 2: Bonsai

    private static func drawBonsai(
        context: inout GraphicsContext,
        size: CGSize,
        bloomT: Double,
        sway: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82

        // Thick gnarled S-curved trunk
        let trunkSway = sway * 12.0
        let soilPt = CGPoint(x: cx, y: dishY - h * 0.015)
        let bend1 = CGPoint(x: cx + w * 0.08 + trunkSway * 0.3, y: dishY - h * 0.15)
        let bend2 = CGPoint(x: cx - w * 0.05 + trunkSway * 0.7, y: dishY - h * 0.30)
        let apex = CGPoint(x: cx + w * 0.02 + trunkSway, y: dishY - h * 0.46)

        var trunkPath = Path()
        trunkPath.move(to: soilPt)
        trunkPath.addCurve(to: bend2, control1: bend1, control2: CGPoint(x: cx + w * 0.02, y: dishY - h * 0.22))
        trunkPath.addQuadCurve(to: apex, control: CGPoint(x: cx - w * 0.02, y: dishY - h * 0.38))

        let trunkColor = isWilted ? Color(red: 0.38, green: 0.32, blue: 0.26) : Color(red: 0.44, green: 0.28, blue: 0.18)
        context.stroke(trunkPath, with: .color(trunkColor), style: StrokeStyle(lineWidth: 6.0, lineCap: .round, lineJoin: .round))

        // Branch 1 (Lower Left)
        let branch1Start = CGPoint(x: cx - w * 0.02 + trunkSway * 0.5, y: dishY - h * 0.24)
        let branch1End = CGPoint(x: cx - w * 0.18 + trunkSway * 0.4, y: dishY - h * 0.28)
        var b1Path = Path()
        b1Path.move(to: branch1Start)
        b1Path.addQuadCurve(to: branch1End, control: CGPoint(x: cx - w * 0.10, y: dishY - h * 0.24))
        context.stroke(b1Path, with: .color(trunkColor), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

        // Branch 2 (Mid Right)
        let branch2Start = CGPoint(x: cx - w * 0.01 + trunkSway * 0.7, y: dishY - h * 0.34)
        let branch2End = CGPoint(x: cx + w * 0.18 + trunkSway * 0.8, y: dishY - h * 0.38)
        var b2Path = Path()
        b2Path.move(to: branch2Start)
        b2Path.addQuadCurve(to: branch2End, control: CGPoint(x: cx + w * 0.08, y: dishY - h * 0.33))
        context.stroke(b2Path, with: .color(trunkColor), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

        // Foliage Clouds
        let baseCloudRadius = w * (0.07 + 0.04 * bloomT)

        // Lower left cloud
        drawCloudPad(
            context: &context,
            center: branch1End,
            radius: baseCloudRadius * 0.90,
            isMature: isMature,
            isWilted: isWilted
        )

        // Mid right cloud
        drawCloudPad(
            context: &context,
            center: branch2End,
            radius: baseCloudRadius * 0.95,
            isMature: isMature,
            isWilted: isWilted
        )

        // Apex top cloud (largest crown)
        drawCloudPad(
            context: &context,
            center: apex,
            radius: baseCloudRadius * 1.15,
            isMature: isMature,
            isWilted: isWilted
        )
    }

    private static func drawCloudPad(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let baseColor = isWilted ? Color(red: 0.40, green: 0.38, blue: 0.30) : Color(red: 0.10, green: 0.52, blue: 0.28)
        let highlightColor = isWilted ? Color(red: 0.48, green: 0.44, blue: 0.35) : Color(red: 0.22, green: 0.85, blue: 0.48)

        let lobes = [
            CGPoint(x: -radius * 0.6, y: radius * 0.1),
            CGPoint(x: -radius * 0.3, y: -radius * 0.4),
            CGPoint(x: radius * 0.1, y: -radius * 0.5),
            CGPoint(x: radius * 0.5, y: -radius * 0.2),
            CGPoint(x: radius * 0.6, y: radius * 0.2),
            CGPoint(x: 0, y: 0)
        ]

        // Base cluster
        for offset in lobes {
            let lobePt = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            let lobeR = radius * 0.55
            var p = Path()
            p.addEllipse(in: CGRect(x: lobePt.x - lobeR, y: lobePt.y - lobeR, width: lobeR * 2, height: lobeR * 2))
            context.fill(p, with: .color(baseColor))
        }

        // Top highlight arcs
        if !isWilted {
            for offset in lobes.prefix(4) {
                let lobePt = CGPoint(x: center.x + offset.x, y: center.y + offset.y - 2)
                let lobeR = radius * 0.45
                var p = Path()
                p.addEllipse(in: CGRect(x: lobePt.x - lobeR, y: lobePt.y - lobeR, width: lobeR * 2, height: lobeR * 2))
                context.fill(p, with: .color(highlightColor.opacity(0.85)))
            }
        }
    }

    // MARK: - Silhouette 3: Lavender

    private static func drawLavender(
        context: inout GraphicsContext,
        size: CGSize,
        bloomT: Double,
        sway: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82

        // Base needle foliage tufts
        let needleColor = isWilted ? wiltedLeaf : Color(red: 0.38, green: 0.62, blue: 0.42)
        let needleCount = 8
        for i in 0..<needleCount {
            let deg = Double(i) * 20.0 - 70.0
            drawLeaf(
                context: &context,
                origin: CGPoint(x: cx, y: dishY - h * 0.015),
                length: w * 0.09,
                width: w * 0.022,
                angleDeg: deg,
                color: needleColor
            )
        }

        // 3 flower spikes: Left, Center, Right
        let spikes: [(offsetAngle: Double, heightFactor: CGFloat, startX: CGFloat)] = [
            (-9.0, 0.46, cx - w * 0.04),
            (0.0, 0.56, cx),
            (9.0, 0.48, cx + w * 0.04)
        ]

        for spike in spikes {
            let spikeHeight = h * spike.heightFactor
            let spikeSway = sway * spikeHeight * 0.85
            let tipX = spike.startX + spikeSway + CGFloat(sin(spike.offsetAngle * .pi / 180.0)) * (w * 0.08)
            let tipY = isWilted ? (dishY - spikeHeight * 0.55) : (dishY - spikeHeight)

            var stemPath = Path()
            stemPath.move(to: CGPoint(x: spike.startX, y: dishY - h * 0.015))
            stemPath.addQuadCurve(
                to: CGPoint(x: tipX, y: tipY),
                control: CGPoint(x: spike.startX + spikeSway * 0.4, y: dishY - spikeHeight * 0.5)
            )

            let stemColor = isWilted ? wiltedStem : Color(red: 0.38, green: 0.68, blue: 0.42)
            context.stroke(stemPath, with: .color(stemColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            // Florets tiers along upper 55% of the spike
            let floretTiers = 7
            let floretColor = isWilted ? wiltedPetal : Color(red: 0.72, green: 0.48, blue: 0.98)
            let highlightFloret = isWilted ? wiltedPetal.opacity(0.8) : Color(red: 0.88, green: 0.70, blue: 1.00)

            for tier in 0..<floretTiers {
                let tierRatio = 0.45 + 0.55 * (Double(tier) / Double(floretTiers))
                let fX = spike.startX + (tipX - spike.startX) * CGFloat(tierRatio)
                let fY = dishY - (dishY - tipY) * CGFloat(tierRatio)

                let floretSize = w * (0.024 + 0.014 * bloomT)
                let spread = w * (0.012 + 0.010 * bloomT)

                // Left floret
                var lFloret = Path()
                lFloret.addEllipse(in: CGRect(x: fX - spread - floretSize, y: fY - floretSize * 0.5, width: floretSize, height: floretSize * 0.7))
                context.fill(lFloret, with: .color(floretColor))

                // Right floret
                var rFloret = Path()
                rFloret.addEllipse(in: CGRect(x: fX + spread, y: fY - floretSize * 0.5, width: floretSize, height: floretSize * 0.7))
                context.fill(rFloret, with: .color(floretColor))

                // Center tip highlight
                var cFloret = Path()
                cFloret.addEllipse(in: CGRect(x: fX - floretSize * 0.35, y: fY - floretSize * 0.6, width: floretSize * 0.7, height: floretSize * 0.7))
                context.fill(cFloret, with: .color(highlightFloret))
            }
        }
    }

    // MARK: - Silhouette 4: Succulent

    private static func drawSucculent(
        context: inout GraphicsContext,
        size: CGSize,
        bloomT: Double,
        sway: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82
        let rosetteCenter = CGPoint(x: cx + sway * 4.0, y: dishY - h * 0.07)

        let bodyColor = isWilted ? Color(red: 0.42, green: 0.44, blue: 0.38) : Color(red: 0.22, green: 0.82, blue: 0.72)
        let tipColor = isWilted ? Color(red: 0.52, green: 0.44, blue: 0.38) : Color(red: 0.98, green: 0.45, blue: 0.62)

        // Tier 1: Outer leaves (8 petals)
        let r1 = w * (0.13 + 0.08 * bloomT)
        drawSucculentRosetteTier(context: &context, center: rosetteCenter, radius: r1, count: 8, rotationOffset: 0, bodyColor: bodyColor, tipColor: tipColor)

        // Tier 2: Middle leaves (6 petals, offset)
        let r2 = r1 * 0.72
        drawSucculentRosetteTier(context: &context, center: rosetteCenter, radius: r2, count: 6, rotationOffset: 25.0, bodyColor: bodyColor, tipColor: tipColor)

        // Tier 3: Inner heart leaves (5 petals)
        let r3 = r1 * 0.42
        drawSucculentRosetteTier(context: &context, center: rosetteCenter, radius: r3, count: 5, rotationOffset: 12.0, bodyColor: bodyColor, tipColor: tipColor)

        // Mature Stage: Delicate arching flower stalk
        if isMature && !isWilted {
            let stalkEnd = CGPoint(x: cx + w * 0.22, y: dishY - h * 0.38)
            var stalkPath = Path()
            stalkPath.move(to: rosetteCenter)
            stalkPath.addQuadCurve(to: stalkEnd, control: CGPoint(x: cx + w * 0.08, y: dishY - h * 0.26))
            context.stroke(stalkPath, with: .color(Color(red: 0.25, green: 0.70, blue: 0.60)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            // Coral bell blossoms
            for i in 0..<3 {
                let bellX = stalkEnd.x - CGFloat(i) * 10
                let bellY = stalkEnd.y + CGFloat(i) * 8
                var bell = Path()
                bell.addEllipse(in: CGRect(x: bellX - 3.5, y: bellY - 3.5, width: 7, height: 7))
                context.fill(bell, with: .color(Color(red: 0.98, green: 0.45, blue: 0.62)))
            }
        }
    }

    private static func drawSucculentRosetteTier(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        count: Int,
        rotationOffset: Double,
        bodyColor: Color,
        tipColor: Color
    ) {
        let angleStep = 360.0 / Double(count)
        for i in 0..<count {
            let angle = Double(i) * angleStep + rotationOffset
            var pCtx = context
            pCtx.translateBy(x: center.x, y: center.y)
            pCtx.rotate(by: .degrees(angle))

            // Fleshy diamond leaf
            let leafW = radius * 0.48
            var leaf = Path()
            leaf.move(to: .zero)
            leaf.addLine(to: CGPoint(x: -leafW * 0.5, y: -radius * 0.6))
            leaf.addLine(to: CGPoint(x: 0, y: -radius))
            leaf.addLine(to: CGPoint(x: leafW * 0.5, y: -radius * 0.6))
            leaf.closeSubpath()

            pCtx.fill(leaf, with: .color(bodyColor))

            // Rosy acute tip
            var tip = Path()
            tip.move(to: CGPoint(x: -leafW * 0.25, y: -radius * 0.8))
            tip.addLine(to: CGPoint(x: 0, y: -radius))
            tip.addLine(to: CGPoint(x: leafW * 0.25, y: -radius * 0.8))
            tip.closeSubpath()
            pCtx.fill(tip, with: .color(tipColor))
        }
    }

    // MARK: - Silhouette 5: Fern

    private static func drawFern(
        context: inout GraphicsContext,
        size: CGSize,
        bloomT: Double,
        sway: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82
        let crown = CGPoint(x: cx, y: dishY - h * 0.015)

        let frondDefs: [(angleDeg: Double, lengthFactor: CGFloat)] = [
            (-65.0, 0.38),
            (-35.0, 0.48),
            (0.0, 0.54),
            (35.0, 0.48),
            (65.0, 0.38)
        ]

        let frondColor = isWilted ? wiltedLeaf : FGTheme.green
        let rachisColor = isWilted ? wiltedStem : Color(red: 0.16, green: 0.62, blue: 0.28)

        for def in frondDefs {
            let frondLen = h * def.lengthFactor * CGFloat(0.85 + 0.15 * bloomT)
            let frondSway = sway * 18.0
            let targetAngle = def.angleDeg + (isWilted ? (def.angleDeg > 0 ? 30 : -30) : frondSway)

            var frondCtx = context
            frondCtx.translateBy(x: crown.x, y: crown.y)
            frondCtx.rotate(by: .degrees(targetAngle))

            // Rachis (central spine)
            var rachis = Path()
            rachis.move(to: .zero)
            rachis.addQuadCurve(
                to: CGPoint(x: 0, y: -frondLen),
                control: CGPoint(x: frondLen * 0.1, y: -frondLen * 0.5)
            )
            frondCtx.stroke(rachis, with: .color(rachisColor), lineWidth: 2.0)

            // Leaflets (pinnules)
            let pinnaeCount = 8
            for i in 1..<pinnaeCount {
                let ratio = Double(i) / Double(pinnaeCount)
                let py = -frondLen * CGFloat(ratio)
                let pLen = w * (0.05 + 0.04 * (1.0 - ratio)) * CGFloat(bloomT)
                let pWid = pLen * 0.35

                // Left pinnule
                drawLeaf(context: &frondCtx, origin: CGPoint(x: 0, y: py), length: pLen, width: pWid, angleDeg: -135, color: frondColor)

                // Right pinnule
                drawLeaf(context: &frondCtx, origin: CGPoint(x: 0, y: py), length: pLen, width: pWid, angleDeg: -45, color: frondColor)
            }
        }

        // Center unfurling fiddlehead crozier
        if !isWilted {
            var crozierCtx = context
            crozierCtx.translateBy(x: crown.x, y: crown.y - 4)
            var crozier = Path()
            crozier.addArc(
                center: CGPoint(x: 0, y: -h * 0.03),
                radius: w * 0.016,
                startAngle: .degrees(0),
                endAngle: .degrees(270),
                clockwise: false
            )
            crozierCtx.stroke(crozier, with: .color(FGTheme.green), lineWidth: 2.2)
        }
    }

    // MARK: - Silhouette 6: Bamboo

    private static func drawBamboo(
        context: inout GraphicsContext,
        size: CGSize,
        bloomT: Double,
        sway: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82

        let canes: [(xOffset: CGFloat, heightFactor: CGFloat, width: CGFloat)] = [
            (-w * 0.08, 0.44, 4.2),
            (w * 0.02, 0.56, 5.0),
            (w * 0.12, 0.34, 3.5)
        ]

        let caneColor = isWilted ? wiltedStem : Color(red: 0.30, green: 0.78, blue: 0.32)
        let ringColor = isWilted ? wiltedStem.opacity(0.7) : Color(red: 0.55, green: 0.95, blue: 0.45)
        let leafColor = isWilted ? wiltedLeaf : PlantSpecies.bamboo.leafColor

        for cane in canes {
            let caneHeight = h * cane.heightFactor
            let caneX = cx + cane.xOffset
            let tipSway = sway * caneHeight * 0.75
            let tipX = caneX + tipSway
            let tipY = dishY - caneHeight

            // Cane segmented sections
            var canePath = Path()
            canePath.move(to: CGPoint(x: caneX, y: dishY - h * 0.015))
            canePath.addLine(to: CGPoint(x: tipX, y: tipY))
            context.stroke(canePath, with: .color(caneColor), style: StrokeStyle(lineWidth: cane.width, lineCap: .butt))

            // Bamboo node rings
            let nodeCount = 4
            for n in 1...nodeCount {
                let ratio = Double(n) / Double(nodeCount + 1)
                let nX = caneX + tipSway * CGFloat(ratio)
                let nY = dishY - caneHeight * CGFloat(ratio)

                var ring = Path()
                ring.move(to: CGPoint(x: nX - cane.width * 0.8, y: nY))
                ring.addLine(to: CGPoint(x: nX + cane.width * 0.8, y: nY))
                context.stroke(ring, with: .color(ringColor), lineWidth: 2.0)

                // Bamboo leaf sprays from alternating nodes
                let spraySide: Double = (n % 2 == 0) ? 1.0 : -1.0
                let sprayAngle = spraySide * 42.0 + (Double(sway) * 12.0)
                let sprayLen = w * (0.08 + 0.05 * bloomT)

                drawLeaf(
                    context: &context,
                    origin: CGPoint(x: nX, y: nY),
                    length: sprayLen,
                    width: sprayLen * 0.22,
                    angleDeg: isWilted ? (spraySide * 75) : sprayAngle,
                    color: leafColor
                )
            }
        }
    }

    // MARK: - Silhouette 7: Cherry Blossom

    private static func drawCherryBlossom(
        context: inout GraphicsContext,
        size: CGSize,
        bloomT: Double,
        sway: CGFloat,
        isMature: Bool,
        isWilted: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5
        let dishY = h * 0.82

        // Rustic cherry wood branch
        let branchSway = sway * 12.0
        let soilPt = CGPoint(x: cx, y: dishY - h * 0.015)
        let midPt = CGPoint(x: cx - w * 0.04 + branchSway * 0.4, y: dishY - h * 0.26)
        let mainBloomPt = CGPoint(x: cx + w * 0.06 + branchSway, y: dishY - h * 0.45)
        let sideBloomPt = CGPoint(x: cx - w * 0.16 + branchSway * 0.6, y: dishY - h * 0.33)

        var branchPath = Path()
        branchPath.move(to: soilPt)
        branchPath.addCurve(to: mainBloomPt, control1: midPt, control2: CGPoint(x: cx + w * 0.02, y: dishY - h * 0.36))

        // Side fork
        branchPath.move(to: midPt)
        branchPath.addQuadCurve(to: sideBloomPt, control: CGPoint(x: cx - w * 0.10, y: dishY - h * 0.28))

        let woodColor = isWilted ? Color(red: 0.38, green: 0.30, blue: 0.24) : Color(red: 0.42, green: 0.26, blue: 0.20)
        context.stroke(branchPath, with: .color(woodColor), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

        // Secondary blossom
        let sideRadius = w * (0.06 + 0.04 * bloomT)
        drawSakuraFlower(context: &context, center: sideBloomPt, radius: sideRadius, bloomT: bloomT, isMature: isMature, isWilted: isWilted)

        // Main primary blossom
        let mainRadius = w * (0.09 + 0.06 * bloomT)
        drawSakuraFlower(context: &context, center: mainBloomPt, radius: mainRadius, bloomT: bloomT, isMature: isMature, isWilted: isWilted)
    }

    private static func drawSakuraFlower(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        bloomT: Double,
        isMature: Bool,
        isWilted: Bool
    ) {
        var flowerCtx = context
        flowerCtx.translateBy(x: center.x, y: center.y)

        // Mature radiant aura
        if isMature && !isWilted {
            var auraCtx = flowerCtx
            auraCtx.addFilter(.blur(radius: 8))
            var aura = Path()
            aura.addEllipse(in: CGRect(x: -radius * 1.4, y: -radius * 1.4, width: radius * 2.8, height: radius * 2.8))
            auraCtx.fill(aura, with: .color(PlantSpecies.cherryBlossom.primaryColor.opacity(0.30)))
        }

        let petalColor = isWilted ? wiltedPetal : PlantSpecies.cherryBlossom.primaryColor
        let heartColor = isWilted ? wiltedPetal.opacity(0.7) : PlantSpecies.cherryBlossom.accentColor

        // 5 Heart-cleft sakura petals
        for i in 0..<5 {
            let angle = Double(i) * 72.0
            var pCtx = flowerCtx
            pCtx.rotate(by: .degrees(angle))

            // Petal with cleft at the tip
            let pWid = radius * 0.55
            var petal = Path()
            petal.move(to: .zero)
            petal.addCurve(to: CGPoint(x: -pWid * 0.5, y: -radius * 0.9), control1: CGPoint(x: -pWid * 0.3, y: -radius * 0.3), control2: CGPoint(x: -pWid * 0.6, y: -radius * 0.6))
            // Cleft
            petal.addLine(to: CGPoint(x: 0, y: -radius * 0.78))
            petal.addLine(to: CGPoint(x: pWid * 0.5, y: -radius * 0.9))
            petal.addCurve(to: .zero, control1: CGPoint(x: pWid * 0.6, y: -radius * 0.6), control2: CGPoint(x: pWid * 0.3, y: -radius * 0.3))
            petal.closeSubpath()

            pCtx.fill(petal, with: .color(petalColor))
        }

        // Blossom core
        var core = Path()
        core.addEllipse(in: CGRect(x: -radius * 0.22, y: -radius * 0.22, width: radius * 0.44, height: radius * 0.44))
        flowerCtx.fill(core, with: .color(heartColor))

        // Central stamen dots
        if !isWilted {
            for i in 0..<8 {
                let stamenAngle = Double(i) * 45.0 * .pi / 180.0
                let sx = cos(stamenAngle) * radius * 0.28
                let sy = sin(stamenAngle) * radius * 0.28
                var stamen = Path()
                stamen.addEllipse(in: CGRect(x: sx - 1.0, y: sy - 1.0, width: 2.0, height: 2.0))
                flowerCtx.fill(stamen, with: .color(FGTheme.amber))
            }
        }
    }

    // MARK: - Floating Pollen / Sakura Petals

    private static func drawFloatingPollen(
        context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        species: PlantSpecies,
        time: TimeInterval
    ) {
        let w = size.width
        let h = size.height
        let count = 8

        for i in 0..<count {
            let fi = Double(i)
            let loopDuration = 3.2
            let offsetTime = time + fi * (loopDuration / Double(count))
            let raw = (offsetTime / loopDuration).truncatingRemainder(dividingBy: 1.0)
            let t = raw < 0 ? raw + 1.0 : raw

            let driftY = CGFloat(t) * (h * 0.35)
            let py = center.y + (h * 0.05) - driftY
            let swayX = CGFloat(sin(time * 1.4 + fi * 1.5)) * (w * 0.16) + CGFloat(cos(fi * 2.7)) * (w * 0.08)
            let px = center.x + swayX

            let alpha = sin(t * .pi) * 0.85
            guard alpha > 0.05 else { continue }

            if species == .cherryBlossom {
                // Drifting sakura petal mote
                var petalCtx = context
                petalCtx.translateBy(x: px, y: py)
                petalCtx.rotate(by: .degrees(time * 60.0 + fi * 45.0))
                var petal = Path()
                petal.addEllipse(in: CGRect(x: -3, y: -1.8, width: 6, height: 3.6))
                petalCtx.fill(petal, with: .color(species.primaryColor.opacity(alpha)))
            } else {
                // Glowing pollen dot
                let radius: CGFloat = (i % 2 == 0) ? 2.2 : 1.6
                let color = (i % 3 == 0) ? FGTheme.amber : species.accentColor
                var p = Path()
                p.addEllipse(in: CGRect(x: px - radius, y: py - radius, width: radius * 2, height: radius * 2))
                context.fill(p, with: .color(color.opacity(alpha)))
            }
        }
    }

    // MARK: - Leaf Geometry Helper

    private static func drawLeaf(
        context: inout GraphicsContext,
        origin: CGPoint,
        length: CGFloat,
        width: CGFloat,
        angleDeg: Double,
        color: Color
    ) {
        var leafCtx = context
        leafCtx.translateBy(x: origin.x, y: origin.y)
        leafCtx.rotate(by: .degrees(angleDeg))

        var leafPath = Path()
        leafPath.move(to: .zero)
        leafPath.addCurve(
            to: CGPoint(x: length, y: 0),
            control1: CGPoint(x: length * 0.35, y: -width * 0.7),
            control2: CGPoint(x: length * 0.75, y: -width * 0.5)
        )
        leafPath.addCurve(
            to: .zero,
            control1: CGPoint(x: length * 0.75, y: width * 0.5),
            control2: CGPoint(x: length * 0.35, y: width * 0.7)
        )
        leafPath.closeSubpath()

        leafCtx.fill(leafPath, with: .color(color))

        // Center vein
        var vein = Path()
        vein.move(to: .zero)
        vein.addLine(to: CGPoint(x: length * 0.85, y: 0))
        leafCtx.stroke(vein, with: .color(Color.white.opacity(0.24)), lineWidth: 0.8)
    }
}

// MARK: - SwiftUI Preview

#Preview("Plant Canvas - Interactive Studio") {
    PlantCanvasPreviewStudio()
}

struct PlantCanvasPreviewStudio: View {
    @State var progress: Double = 0.85
    @State var isWilted: Bool = false
    @State var isAnimated: Bool = true
    @State var selectedSpecies: PlantSpecies = .sunflower

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("BOTANICAL GROWTH SYSTEM")
                    .font(FGTheme.mono(.headline, weight: .bold))
                    .foregroundStyle(FGTheme.green)

                // Interactive Centerpiece
                VStack(spacing: 12) {
                    PlantCanvasView(
                        species: selectedSpecies,
                        progress: progress,
                        isWilted: isWilted,
                        isAnimated: isAnimated,
                        size: 180
                    )

                    HStack(spacing: 16) {
                        Text(selectedSpecies.displayName.uppercased())
                            .font(FGTheme.mono(.subheadline, weight: .bold))
                            .foregroundStyle(selectedSpecies.primaryColor)

                        Text("STAGE: \(PlantGrowthStage.stage(for: progress, isWilted: isWilted).title.uppercased())")
                            .font(FGTheme.mono(.caption, weight: .semibold))
                            .foregroundStyle(FGTheme.muted)

                        Text("\(Int(progress * 100))%")
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Slider(value: $progress, in: 0.0...1.0)
                        .tint(selectedSpecies.primaryColor)
                        .padding(.horizontal, 24)

                    HStack(spacing: 16) {
                        Toggle("Wilted", isOn: $isWilted)
                            .toggleStyle(.button)
                            .tint(FGTheme.danger)
                            .font(FGTheme.mono(.caption))

                        Toggle("Animated", isOn: $isAnimated)
                            .toggleStyle(.button)
                            .tint(FGTheme.green)
                            .font(FGTheme.mono(.caption))
                    }

                    // Species selector pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PlantSpecies.allCases) { species in
                                Button {
                                    selectedSpecies = species
                                } label: {
                                    Text(species.displayName)
                                        .font(FGTheme.mono(.caption2, weight: selectedSpecies == species ? .bold : .regular))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedSpecies == species ? species.primaryColor.opacity(0.25) : FGTheme.surface)
                                        .foregroundStyle(selectedSpecies == species ? species.primaryColor : FGTheme.muted)
                                        .overlay(
                                            Rectangle()
                                                .stroke(selectedSpecies == species ? species.primaryColor : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding()
                .background(FGTheme.surface)
                .overlay(Rectangle().stroke(Color.white.opacity(0.1), lineWidth: 1))

                // Growth Stage Progression
                Text("GROWTH STAGES")
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        let stages: [(Double, String)] = [
                            (0.10, "Seed"),
                            (0.35, "Sprout"),
                            (0.65, "Budding"),
                            (0.90, "Blooming"),
                            (1.00, "Mature")
                        ]
                        ForEach(stages, id: \.1) { step in
                            VStack(spacing: 6) {
                                PlantCanvasView(species: selectedSpecies, progress: step.0, size: 85)
                                Text(step.1)
                                    .font(FGTheme.mono(.caption2))
                                    .foregroundStyle(step.0 >= 1.0 ? FGTheme.green : FGTheme.muted)
                            }
                            .padding(8)
                            .background(FGTheme.surface)
                        }
                    }
                    .padding(.horizontal)
                }

                // All Species Mature Showcase
                Text("ALL SPECIES SILHOUETTES")
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 14) {
                    ForEach(PlantSpecies.allCases) { species in
                        VStack(spacing: 6) {
                            PlantCanvasView(species: species, progress: 1.0, size: 95)
                            Text(species.displayName)
                                .font(FGTheme.mono(.caption2))
                                .foregroundStyle(species.primaryColor)
                        }
                        .padding(8)
                        .background(FGTheme.surface)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(FGTheme.background.ignoresSafeArea())
    }
}
#endif

