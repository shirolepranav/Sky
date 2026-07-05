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
//
// Phase 6: .onOpenURL intercepts sky://verify and sky://emergency deep links
// sent by SkyShieldAction when the user taps a shield button. The destination
// is surfaced as a fullScreenCover over whichever route is active (S-SHIELD-02,
// S-SHIELD-03). AppCoordinator.Route is unchanged — deep-link destinations are
// transient overlays, not top-level routing states.
//
// Phase 11: MascotStateManager is created here and passed as an environment
// object to MainTabView (which replaced MainPlaceholderView). It is also
// refreshed on every foreground so overnight midnight resets and external flag
// changes are picked up without requiring a cold launch.
//
// Phase 12: StreakManager and CloudKitSyncService are created here and injected
// as environment objects alongside MascotStateManager. StreakManager.refreshOnForeground
// is called on every active-phase transition so midnight-reset hand-offs written
// by DeviceActivityMonitor are consumed promptly.
//
// Phase 13: sky://emergency deep link now routes to EmergencyUnlockCoordinatorView
// (real 3-screen flow) instead of the Phase 6 placeholder. "Try outside again"
// in S-EMG-01 dismisses the emergency cover and re-presents the verify cover
// after a brief delay so SwiftUI can sequence the two fullScreenCovers.
//
// Phase 14: StoreKitService created here and injected as an environment object.
// listenForTransactions() starts a long-running background task; products and
// entitlements are refreshed on every app foreground.

import SwiftUI

@main
struct SkyApp: App {
    @StateObject private var coordinator: AppCoordinator
    @StateObject private var deviceActivity = DeviceActivityService()
    @StateObject private var mascotManager = MascotStateManager()
    @StateObject private var streakManager = StreakManager()
    @StateObject private var cloudKitSync = CloudKitSyncService()
    @StateObject private var storeKit = StoreKitService()
    @StateObject private var scheduler = LocalNotificationScheduler()
    @StateObject private var appearance = AppearanceManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isReady = false
    @State private var deepLinkDestination: SkyDeepLink? = nil
    @State private var showNotificationPrimer = false

    init() {
        // Wire CloudKitSyncService into StreakManager after construction.
        // (Can't reference _streakManager / _cloudKitSync yet — use a post-init hook.)
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
            // Phase 16: apply the user's appearance choice app-wide. `nil` follows
            // the device; .light/.dark force the theme. Adaptive SkyColor tokens
            // resolve against whatever interface style this yields.
            .preferredColorScheme(appearance.mode.colorScheme)
            // Phase 16: support Dynamic Type but cap growth so the tight hero,
            // progress ring, and camera overlays stay intact at large sizes.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .onAppear { isReady = true }
            .onChange(of: scenePhase) { _, phase in
                // Catch a permission toggled in Settings (S-PERM-02 recovery).
                if phase == .active {
                    coordinator.familyControls.refreshStatus()
                    coordinator.recomputeRoute()
                    mascotManager.refreshState()
                    // Consume the midnight-reset hand-off from DeviceActivityMonitor
                    // and re-evaluate streak for the previous day (Phase 12).
                    streakManager.refreshOnForeground()
                    // Re-arm monitoring on every foreground when configured, so
                    // limit edits and relaunches always use the latest values.
                    if coordinator.route == .main {
                        try? deviceActivity.startMonitoring()
                        // Re-arm local notifications and show the one-time primer
                        // once setup is complete (Phase 15, S-PERM-03 / S-SET-04).
                        rescheduleNotifications()
                        maybeShowNotificationPrimer()
                    }
                    // Consume a shield-button tap recorded by ShieldActionExtension
                    // (it can't open the app directly) — S-SHIELD-02 / S-SHIELD-03.
                    consumePendingDeepLink()
                }
            }
            .task {
                // Link streak manager to CloudKit on first appear and kick off
                // the initial fetch (non-blocking — UI uses local cache).
                streakManager.setCloudKit(cloudKitSync)
                cloudKitSync.fetchOnLaunch()
                // StoreKit: start listener, load products, refresh entitlement.
                storeKit.listenForTransactions()
                try? await storeKit.loadProducts()
                await storeKit.refreshEntitlement()
            }
            .onOpenURL { url in
                deepLinkDestination = SkyDeepLink(url: url)
            }
            .fullScreenCover(item: $deepLinkDestination) { link in
                switch link {
                case .verify:
                    VerificationCoordinatorView { deepLinkDestination = nil }
                        .environmentObject(mascotManager)
                        .environmentObject(streakManager)
                        .environmentObject(storeKit)
                case .emergency:
                    EmergencyUnlockCoordinatorView(
                        onDismiss: { deepLinkDestination = nil },
                        onTryOutside: {
                            deepLinkDestination = nil
                            // Brief delay lets the emergency cover finish dismissing
                            // before SwiftUI can present the verification cover.
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(350))
                                deepLinkDestination = .verify
                            }
                        }
                    )
                    .environmentObject(streakManager)
                    .environmentObject(mascotManager)
                }
            }
            .fullScreenCover(isPresented: $showNotificationPrimer) {
                NotificationPermissionView { showNotificationPrimer = false }
                    .environmentObject(scheduler)
                    .environmentObject(storeKit)
                    .environmentObject(streakManager)
            }
        }
    }

    /// Re-arms the calendar-triggered local notifications from current prefs.
    private func rescheduleNotifications() {
        let store = SharedDefaults()
        let atRisk = streakManager.progress.currentStreak > 0 && !store.didVerifyToday
        Task { await scheduler.rescheduleAll(store: store, isPro: storeKit.isPro, streakAtRisk: atRisk) }
    }

    /// Presents S-PERM-03 once, after the user has completed app selection.
    private func maybeShowNotificationPrimer() {
        let store = SharedDefaults()
        guard !store.notificationPrimerShown, store.hasSelection else { return }
        showNotificationPrimer = true
    }

    /// Reads and clears the pending shield-button destination from the App Group,
    /// presenting the matching screen. No-op when nothing is pending.
    private func consumePendingDeepLink() {
        let store = SharedDefaults()
        guard let pending = store.pendingDeepLink,
              let link = SkyDeepLink(rawValue: pending)
        else { return }
        store.pendingDeepLink = nil
        deepLinkDestination = link
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
            .environmentObject(storeKit)
        case .main:
            MainTabView()
                .environmentObject(deviceActivity)
                .environmentObject(mascotManager)
                .environmentObject(streakManager)
                .environmentObject(cloudKitSync)
                .environmentObject(storeKit)
                .environmentObject(scheduler)
                // TodayView reads this to surface the entitlementMissing state (S-TODAY-01).
                .environmentObject(coordinator.familyControls)
                // SettingsView → AppearanceView reads this to change the theme (S-SET-10).
                .environmentObject(appearance)
        }
    }
}
