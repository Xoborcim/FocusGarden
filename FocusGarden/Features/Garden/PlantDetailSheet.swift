#if !SKIP
import SwiftData
#endif
import SwiftUI

// MARK: - PlantDetailSheet

struct PlantDetailSheet: View {
    @Bindable var plant: GardenPlant
    #if !SKIP
    @Environment(\.modelContext) var modelContext: ModelContext
    #endif
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        heroCanvasCard
                        if plant.isWilted {
                            reviveActionCard
                        }
                        specificationsCard
                        timelineCard
                        removePlantButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("PLANT DOSSIER")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(FGTheme.green)
                }
            }
        }
    }

    // MARK: - Hero Canvas Card

    private var heroCanvasCard: some View {
        VStack(spacing: 12) {
            // Species & Rarity Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.species.displayName.uppercased())
                        .font(FGTheme.mono(.title2, weight: .bold))
                        .foregroundStyle(.white)
                    Text(plant.species.subjectHint)
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(plant.species.accentColor)
                }
                Spacer()
                RarityTag(rarity: plant.species.rarity)
            }

            // Large 200pt Animated Procedural Plant Canvas
            ZStack {
                Circle()
                    .fill(plant.species.accentColor.opacity(0.06))
                    .frame(width: 220, height: 220)

                PlantCanvasView(
                    plant: plant,
                    isAnimated: true,
                    size: 200
                )
            }
            .frame(height: 210)
            .padding(.vertical, 4)

            // Growth Stage Badge & Subtitle
            GrowthStagePill(stage: plant.growthStage, progress: plant.growthProgress)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FGTheme.surface, FGTheme.surface.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorderColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }

    private var cardBorderColor: Color {
        if plant.isWilted {
            return FGTheme.danger
        }
        if plant.isMature {
            return FGTheme.green
        }
        return plant.species.accentColor.opacity(0.6)
    }

    // MARK: - Revive Action Card

    private var reviveActionCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(FGTheme.danger)
                Text("GROWTH INTERRUPTED")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.danger)
                Spacer()
            }

            Text("This sprout wilted when the focus session was abandoned. Revive it to restore healthy botanical momentum.")
                .font(FGTheme.mono(.caption2))
                .foregroundStyle(FGTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            FGButton(title: "REVIVE SPROUT", accent: FGTheme.green) {
                #if !SKIP
                GardenService.revivePlant(plant: plant, context: modelContext)
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                #endif
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FGTheme.surface, FGTheme.danger.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FGTheme.danger.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: FGTheme.danger.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    // MARK: - Specifications Card

    private var specificationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPECIMEN SPECS")
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.green)

            VStack(spacing: 8) {
                SpecRow(
                    label: "SESSION TITLE",
                    value: plant.title.isEmpty ? plant.species.displayName : plant.title
                )
                SpecRow(
                    label: "COURSE CODE",
                    value: plant.courseCode.isEmpty ? "INDEPENDENT FOCUS" : plant.courseCode,
                    valueColor: plant.courseCode.isEmpty ? FGTheme.muted : FGTheme.green
                )
                SpecRow(
                    label: "SUBJECT CLUSTER",
                    value: plant.species.subjectHint
                )
                SpecRow(
                    label: "TARGET TIME",
                    value: "\(plant.targetMinutes)m"
                )
                SpecRow(
                    label: "FOCUSED TIME",
                    value: "\(plant.focusedMinutes)m (\(Int(plant.growthProgress * 100))%)",
                    valueColor: plant.isMature ? FGTheme.green : (plant.isWilted ? FGTheme.danger : FGTheme.amber)
                )
            }
        }
        .padding(16)
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
                .stroke(FGTheme.muted.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BOTANICAL TIMELINE")
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.green)

            VStack(spacing: 8) {
                SpecRow(
                    label: "PLANTED AT",
                    value: plant.plantedAt.formatted(date: .abbreviated, time: .shortened)
                )

                if let harvestedAt = plant.harvestedAt {
                    SpecRow(
                        label: "HARVESTED AT",
                        value: harvestedAt.formatted(date: .abbreviated, time: .shortened),
                        valueColor: FGTheme.green
                    )
                } else {
                    SpecRow(
                        label: "HARVEST STATUS",
                        value: plant.isWilted ? "Wilted · Needs Revival" : "Actively Growing",
                        valueColor: plant.isWilted ? FGTheme.danger : FGTheme.amber
                    )
                }
            }
        }
        .padding(16)
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
                .stroke(FGTheme.muted.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)
    }

    private var removePlantButton: some View {
        Button(role: .destructive) {
            #if !SKIP
            GardenService.deletePlant(plant: plant, context: modelContext)
            #endif
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("REMOVE FROM GARDEN")
            }
            .font(FGTheme.mono(.caption, weight: .bold))
            .foregroundStyle(FGTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FGTheme.danger.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FGTheme.danger.opacity(0.35), lineWidth: 1)
            )
        }
        .padding(.top, 4)
    }
}

// MARK: - Helper Components

struct RarityTag: View {
    let rarity: String

    var color: Color {
        switch rarity.lowercased() {
        case "legendary": return Color(red: 1.00, green: 0.80, blue: 0.20)
        case "rare": return Color(red: 0.20, green: 0.85, blue: 1.00)
        case "uncommon": return Color(red: 0.85, green: 0.60, blue: 1.00)
        default: return Color(white: 0.85)
        }
    }

    var body: some View {
        Text(rarity.uppercased())
            .font(FGTheme.mono(.caption2, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
    }
}

struct GrowthStagePill: View {
    let stage: PlantGrowthStage
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(stage.symbol)
                    .font(.system(size: 16))
                Text("STAGE: \(stage.title.uppercased())")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(stageColor)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(stageColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 5)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [stageColor.opacity(0.7), stageColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(CGFloat(0), min(geo.size.width, geo.size.width * CGFloat(progress))), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(stageColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var stageColor: Color {
        switch stage {
        case .mature: return FGTheme.green
        case .wilted: return FGTheme.danger
        case .blooming: return Color(red: 1.0, green: 0.55, blue: 0.75)
        case .budding: return FGTheme.amber
        case .sprout: return Color(red: 0.35, green: 0.85, blue: 0.45)
        case .seed: return Color(white: 0.75)
        }
    }
}

struct SpecRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)
            Spacer(minLength: 8)
            Text(value)
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}
