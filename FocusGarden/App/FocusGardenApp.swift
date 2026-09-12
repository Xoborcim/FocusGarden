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
    }
}

struct RootTabView: View {
    @Environment(AppServices.self) var services

    private var selectedTabBinding: Binding<Int> {
        Binding(
            get: { services.selectedTab },
            set: { services.selectedTab = $0 }
        )
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            TodayView()
                .tabItem { Label("Sanctum", systemImage: "flame.fill") }
                .tag(0)
            QuickLogView()
                .tabItem { Label("Record", systemImage: "plus.circle.fill") }
                .tag(1)
            InsightsView()
                .tabItem { Label("Tome", systemImage: "chart.bar.xaxis") }
                .tag(2)
            GardenView()
                .tabItem { Label("Arboretum", systemImage: "sparkles") }
                .tag(3)
        }
        .tint(FGTheme.stainedGlassViolet)
        .preferredColorScheme(ColorScheme.dark)
    }
}

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(FGTheme.deepPurple.opacity(0.35))
                    .frame(width: 140, height: 140)
                    .blur(radius: 25)

                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                FGTheme.stainedGlassViolet,
                                FGTheme.stainedGlassRuby,
                                FGTheme.stainedGlassSapphire,
                                FGTheme.stainedGlassAmber,
                                FGTheme.stainedGlassViolet
                            ]),
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "flame.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FGTheme.stainedGlassAmber, FGTheme.stainedGlassViolet],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: FGTheme.stainedGlassViolet.opacity(0.6), radius: 16, x: 0, y: 4)
            }

            VStack(spacing: 8) {
                Text("SPROUT")
                    .font(FGTheme.gothic(.title, weight: .bold))
                    .foregroundStyle(FGTheme.stoneText)
                    .tracking(2.0)

                Text("Enter the quiet sanctum of contemplation")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            }

            ProgressView()
                .tint(FGTheme.stainedGlassViolet)
                .scaleEffect(1.1)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FGTheme.background.ignoresSafeArea())
    }
}
