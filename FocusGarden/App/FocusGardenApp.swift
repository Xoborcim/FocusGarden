import SwiftData
import SwiftUI
import UIKit

@main
struct FocusGardenApp: App {
    let container: ModelContainer
    @State private var services: AppServices

    init() {
        Self.configureAppearance()
        let container = PersistenceController.makeContainer()
        self.container = container
        _services = State(initialValue: AppServices(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .task { await services.bootstrap() }
        }
    }

    private static func configureAppearance() {
        UILabel.appearance().shadowColor = .clear
        UILabel.appearance().shadowOffset = .zero
    }
}

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Query private var appState: [AppStateRecord]

    var body: some View {
        let onboarded = appState.first?.hasCompletedOnboarding ?? services.hasCompletedOnboarding
        Group {
            if !onboarded {
                OnboardingView()
            } else if !services.isReady {
                LaunchView()
            } else {
                RootTabView()
            }
        }
        .background(FGTheme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: sessionPresented) {
            if let task = services.activeSessionTask {
                FocusSessionView(task: task)
            }
        }
    }

    private var sessionPresented: Binding<Bool> {
        Binding(
            get: { services.activeSessionTaskID != nil },
            set: { presented in
                if !presented {
                    services.endFocusSession(clearStart: false)
                }
            }
        )
    }
}

struct RootTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(0)
            GardenView()
                .tabItem { Label("Garden", systemImage: "leaf.fill") }
                .tag(1)
            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(2)
            CoursesView()
                .tabItem { Label("Courses", systemImage: "books.vertical.fill") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "square.and.arrow.down") }
                .tag(4)
        }
        .tint(FGTheme.green)
        .preferredColorScheme(.dark)
    }
}

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(FGTheme.green)
            Text("FocusGarden")
                .font(FGTheme.mono(.title, weight: .bold))
                .foregroundStyle(.white)
            ProgressView()
                .tint(FGTheme.green)
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FGTheme.background.ignoresSafeArea())
    }
}
