import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(AppServices.self) private var services
    @State private var showingImporter = false

    var body: some View {
        ZStack {
            FGTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text("FOCUSGARDEN")
                    .font(FGTheme.mono(.largeTitle, weight: .bold))
                    .foregroundStyle(FGTheme.green)
                    .fgPlain()
                Text("Import a timetable. Get a study week.")
                    .font(FGTheme.mono(.title3, weight: .bold))
                    .foregroundStyle(FGTheme.amber)
                    .fgPlain()
                Text("Drop in a .ics from Canvas, ACORN, or Google Calendar. Class times stay fixed. Study blocks are placed around them. Tests and homework get extra slots before they’re due.")
                    .font(FGTheme.mono(.body))
                    .foregroundStyle(FGTheme.muted)
                    .fgPlain()

                Spacer()
                FGButton(title: "IMPORT .ICS") {
                    showingImporter = true
                }
                Button("Skip for now") {
                    services.completeOnboarding()
                }
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.muted)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .calendarImporter(isPresented: $showingImporter)
    }
}
