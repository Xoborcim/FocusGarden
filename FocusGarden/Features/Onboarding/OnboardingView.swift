#if !SKIP
import SwiftData
#endif
import SwiftUI

struct OnboardingView: View {
    @Environment(AppServices.self) var services
    @State var showingImporter = false

    var body: some View {
        ZStack {
            FGTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text("SPROUT")
                    .font(FGTheme.mono(.largeTitle, weight: .bold))
                    .foregroundStyle(FGTheme.green)
                    .fgPlain()
                Text("Make space. Do the work. Grow.")
                    .font(FGTheme.mono(.title3, weight: .bold))
                    .foregroundStyle(FGTheme.amber)
                    .fgPlain()
                Text("Live your day first. Log what you did in seconds. Observe your focus, leisure, and AI independence without pressure, tasks, or artificial schedules.")
                    .font(FGTheme.mono(.body))
                    .foregroundStyle(FGTheme.muted)
                    .fgPlain()

                Spacer()
                FGButton(title: "IMPORT TIMETABLE (.ICS)") {
                    showingImporter = true
                }
                Button("Start Logging") {
                    services.completeOnboarding()
                }
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.green)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .calendarImporter(isPresented: $showingImporter)
    }
}
