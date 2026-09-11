import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI
#if !SKIP && canImport(UIKit)
import UIKit
#endif

public struct FocusGardenRootView: View {
    let container: ModelContainer
    @State var services: AppServices

    public init() {
        let container = PersistenceController.sharedContainer
        self.container = container
        _services = State(initialValue: AppServices.shared)
    }

    public var body: some View {
        RootView()
            .environment(services)
            .modelContainer(container)
            .preferredColorScheme(ColorScheme.dark)
            .task { await services.bootstrap() }
    }
}

public final class FocusGardenAppDelegate: Sendable {
    public static let shared = FocusGardenAppDelegate()

    private init() {}

    public func onInit() {
        #if !SKIP && canImport(UIKit)
        UILabel.appearance().shadowColor = .clear
        UILabel.appearance().shadowOffset = .zero
        #endif
    }

    public func onLaunch() {}
    public func onResume() {}
    public func onPause() {}
    public func onStop() {}
    public func onDestroy() {}
    public func onLowMemory() {}
}

struct RootView: View {
    @Environment(AppServices.self) var services
    @Query var appState: [AppStateRecord]

    init() {}

    var body: some View {
        let onboarded = appState.first?.hasCompletedOnboarding ?? services.hasCompletedOnboarding
        Group {
            if !onboarded {
                OnboardingView()
            } else {
                RootTabView()
            }
        }
        .background(FGTheme.background.ignoresSafeArea())
        .sheet(isPresented: sessionPresented) {
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
    @State var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)
            QuickLogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(1)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                .tag(2)
            GardenView()
                .tabItem { Label("Garden", systemImage: "leaf.fill") }
                .tag(3)
        }
        .tint(FGTheme.green)
        .preferredColorScheme(ColorScheme.dark)
    }
}

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(FGTheme.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .blur(radius: 22)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FGTheme.green, FGTheme.green.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: FGTheme.green.opacity(0.35), radius: 14, x: 0, y: 4)
            }

            VStack(spacing: 6) {
                Text("Sprout")
                    .font(FGTheme.rounded(.title, weight: .bold))
                    .foregroundStyle(.white)

                Text("Make space. Do the work. Grow.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            }

            ProgressView()
                .tint(FGTheme.green)
                .scaleEffect(1.1)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FGTheme.background.ignoresSafeArea())
    }
}
