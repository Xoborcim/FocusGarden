import SwiftData
import SwiftUI

// MARK: - PlantDetailSheet

struct PlantDetailSheet: View {
    @Bindable var plant: GardenPlant
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        .padding(16)
        .background(FGTheme.surface)
        .overlay(Rectangle().stroke(cardBorderColor, lineWidth: FGTheme.borderWidth))
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
                GardenService.revivePlant(plant: plant, context: modelContext)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .padding(14)
        .background(FGTheme.surface)
        .overlay(Rectangle().stroke(FGTheme.danger.opacity(0.6), lineWidth: FGTheme.borderWidth))
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
        .padding(14)
        .background(FGTheme.surface)
        .overlay(Rectangle().stroke(FGTheme.muted.opacity(0.3), lineWidth: 1))
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
        .padding(14)
        .background(FGTheme.surface)
        .overlay(Rectangle().stroke(FGTheme.muted.opacity(0.3), lineWidth: 1))
    }

    private var removePlantButton: some View {
        Button(role: .destructive) {
            GardenService.deletePlant(plant: plant, context: modelContext)
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
            .background(FGTheme.danger.opacity(0.08))
            .overlay(Rectangle().stroke(FGTheme.danger.opacity(0.4), lineWidth: 1))
        }
        .padding(.top, 4)
    }
}

// MARK: - Helper Components

private struct RarityTag: View {
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .overlay(Rectangle().stroke(color.opacity(0.6), lineWidth: 1))
    }
}

private struct GrowthStagePill: View {
    let stage: PlantGrowthStage
    let progress: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(stage.symbol)
                    .font(.system(size: 16))
                Text("STAGE: \(stage.title.uppercased())")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(stageColor)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(stage.description)
                .font(FGTheme.mono(.caption2))
                .foregroundStyle(FGTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.black.opacity(0.4))
        .overlay(Rectangle().stroke(stageColor.opacity(0.4), lineWidth: 1))
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

private struct SpecRow: View {
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
