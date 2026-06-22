// SkyApp.swift
// @main entry point.
//
// Phase 3: drives the root from AppCoordinator across three destinations — a
// brief splash (S-ONB-01) crossfades into onboarding, the post-onboarding setup
// gate (S-PERM-01 → S-CFG-01), or the temporary main placeholder, based on the
// onboarding flag, Screen Time authorization, and the persisted app selection
// (Sky_App_Workflow.md §0.1/§0.2). On every foreground the auth status is
// refreshed so a permission change made in Settings re-routes the app.
//
// Phase 5: DeviceActivityService is created here and passed as an environment
// object. Monitoring is re-armed on every foreground while in the .main route so
// limit edits and app relaunches always reflect the latest configuration.

import SwiftUI

@main
struct SkyApp: App {
    @StateObject private var coordinator: AppCoordinator
    @StateObject private var deviceActivity = DeviceActivityService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isReady = false

    init() {
        let args = ProcessInfo.processInfo.arguments
        let onboarding = OnboardingViewModel()
        // UI tests pass -resetOnboarding to force a fresh onboarding run.
        if args.contains("-resetOnboarding") {
            onboarding.resetForTesting()
        }

        var familyControls = FamilyControlsService()
        #if DEBUG
        // UI-test hooks: land directly on S-CFG-01 with a clean selection.
        if args.contains("-mockAuthorized") {
            familyControls = FamilyControlsService(center: MockApprovedAuthorizationCenter())
        }
        if args.contains("-skipOnboarding") {
            onboarding.completeOnboarding()
        }
        if args.contains("-resetSelection") {
            SharedDefaults().selection = nil
        }
        #endif

        _coordinator = StateObject(
            wrappedValue: AppCoordinator(onboarding: onboarding, familyControls: familyControls)
        )
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isReady {
                    routedView
                        .transition(.opacity)
                } else {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isReady)
            .onAppear { isReady = true }
            .onChange(of: scenePhase) { _, phase in
                // Catch a permission toggled in Settings (S-PERM-02 recovery).
                if phase == .active {
                    coordinator.familyControls.refreshStatus()
                    coordinator.recomputeRoute()
                    // Re-arm monitoring on every foreground when configured, so
                    // limit edits and relaunches always use the latest values.
                    if coordinator.route == .main {
                        try? deviceActivity.startMonitoring()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var routedView: some View {
        switch coordinator.route {
        case .onboarding:
            OnboardingView(viewModel: coordinator.onboarding)
        case .setup:
            SetupFlowView(
                familyControls: coordinator.familyControls,
                onComplete: { coordinator.recomputeRoute() }
            )
        case .main:
            MainPlaceholderView()
                .environmentObject(deviceActivity)
        }
    }
}
