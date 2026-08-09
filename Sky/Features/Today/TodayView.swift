// TodayView.swift
// S-TODAY-01 + S-TODAY-02 — The primary home screen. Shows Nimbus, today's
// status banner, a usage ring, and context-sensitive actions.
// Sky_App_Workflow.md §Group C S-TODAY-01/S-TODAY-02; Roadmap Phase 11.
//
// Note: DeviceActivity only delivers usage data to the monitor extension via
// callbacks; the main app cannot read live screen-time in real time. The progress
// ring is therefore a state indicator (blocked/verified/idle) rather than a precise
// usage percentage. Phase 12+ can refine this by having the extension write
// incremental usage to SharedDefaults.

import SwiftUI

// MARK: - App state enum

private enum TodayAppState {
    case paused          // 24-hour Pro pause active — shields off
    case entitlementMissing // Screen Time authorization revoked while configured
    case noApps          // No app selection persisted yet
    case noLimit         // Selection exists but monitoring not active
    case unblocked       // Monitoring active, under budget
    case blocked         // Over budget, not yet verified
    case verifiedToday   // Successfully verified
    case emergencyUnlocked // Emergency unlock used
}

// MARK: - View

struct TodayView: View {
    @EnvironmentObject private var mascotManager: MascotStateManager
    @EnvironmentObject private var deviceActivity: DeviceActivityService
    @EnvironmentObject private var streakManager: StreakManager
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var familyControls: FamilyControlsService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // SharedDefaults is read at body evaluation time; refresh triggers @State change.
    @State private var store = SharedDefaults()
    @State private var nimbusScale: CGFloat = 1.0
    @State private var revealed = false
    @State private var showingVerification = false
    @State private var showingEmergency = false
    @State private var showingAppSelection = false
    @State private var showingLimitConfig = false
    @State private var pendingBadge: BadgeID? = nil
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif

    // MARK: Derived state

    private var appState: TodayAppState {
        // An active pause overrides everything — all shields are off.
        if store.isPaused                 { return .paused }
        // Screen Time access lost while configured — nothing can be enforced until
        // the user re-grants it (top-level routing also recovers on next foreground).
        if store.hasSelection && !familyControls.isApproved { return .entitlementMissing }
        // Emergency takes highest display priority to match mascot state.
        if store.didEmergencyUnlockToday  { return .emergencyUnlocked }
        if store.didVerifyToday           { return .verifiedToday }
        if store.isCurrentlyBlocked       { return .blocked }
        if !store.hasSelection            { return .noApps }
        if !deviceActivity.isMonitoring   { return .noLimit }
        return .unblocked
    }

    private var ringProgress: Double {
        switch appState {
        case .blocked, .emergencyUnlocked: return 1.0
        case .verifiedToday:               return 1.0
        default:                           return 0.0
        }
    }

    private var ringAccent: Color {
        switch appState {
        case .blocked, .emergencyUnlocked, .entitlementMissing: return SkyColor.coralStreak
        case .verifiedToday:               return SkyColor.sunYellow
        default:                           return SkyColor.mossGreen
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SkyColor.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SkySpacing.s6) {
                        // Hero Nimbus
                        let heroSize = min(geo.size.height * 0.35, 220)
                        NimbusView(state: mascotManager.state, size: heroSize)
                            .scaleEffect(nimbusScale)
                            .animation(SkyMotion.squishSpring, value: nimbusScale)
                            .padding(.top, SkySpacing.s8)
                            .accessibilityLabel(mascotManager.state.accessibilityDescription)
                            .onTapGesture { squishNimbus() }
                            // Long-press → debug menu (S-SET-09), DEBUG builds only.
                            #if DEBUG
                            .onLongPressGesture(minimumDuration: 2) { showingDebugMenu = true }
                            #endif
                            .skyEntrance(0, revealed: revealed)

                        // Status banner (S-TODAY-02 variants)
                        statusBanner
                            .padding(.horizontal, SkyLayout.screenMargin)
                            .transition(.opacity.animation(SkyMotion.fadeEase))
                            .id(appState == .blocked || appState == .emergencyUnlocked ? "urgent" : "calm")
                            .skyEntrance(1, revealed: revealed)

                        // Usage progress ring — tap opens the daily-limit editor (S-SET-02).
                        ZStack {
                            SkyProgressRing(progress: ringProgress, accent: ringAccent)
                                .frame(width: 96, height: 96)

                            Text(ringLabel)
                                .skyText(.caption, color: SkyColor.inkSoft)
                                .multilineTextAlignment(.center)
                                .contentTransition(.numericText())
                                .animation(reduceMotion ? nil : SkyMotion.quickEase, value: ringLabel)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showingLimitConfig = true }
                        .accessibilityValue(ringAccessibilityValue)
                        .accessibilityLabel("Daily usage ring")
                        .accessibilityHint("Opens the session limit editor")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("today.usageRing")
                        .skyEntrance(2, revealed: revealed)

                        // Streak chip — live count from StreakManager
                        SkyStreakChip(days: streakManager.progress.currentStreak)
                            .skyEntrance(3, revealed: revealed)

                        // Action buttons
                        actionButtons
                            .padding(.horizontal, SkyLayout.screenMargin)
                            .skyEntrance(4, revealed: revealed)

                        Spacer(minLength: SkySpacing.s10)
                    }
                }
                .refreshable {
                    store = SharedDefaults()
                    mascotManager.refreshState()
                }
            }
        }
        .onAppear {
            store = SharedDefaults()
            mascotManager.refreshState()
            revealed = true
        }
        .fullScreenCover(isPresented: $showingVerification) {
            VerificationCoordinatorView {
                showingVerification = false
            }
            .environmentObject(mascotManager)
            .environmentObject(streakManager)
        }
        .fullScreenCover(isPresented: $showingEmergency) {
            EmergencyUnlockCoordinatorView(
                onDismiss:    { showingEmergency = false },
                onTryOutside: { showingEmergency = false; showingVerification = true }
            )
            .environmentObject(mascotManager)
            .environmentObject(streakManager)
        }
        // S-CFG-01 · App selection editor. On save the state flips to `.noLimit`.
        .sheet(isPresented: $showingAppSelection) {
            TodayEditAppsSheet { store = SharedDefaults() }
                .environmentObject(storeKit)
        }
        // S-CFG-03 · Daily-limit editor. On save, re-arm monitoring so the new
        // configuration takes effect and the state flips to `.unblocked`.
        .sheet(isPresented: $showingLimitConfig) {
            TodayEditLimitSheet {
                store = SharedDefaults()
                try? deviceActivity.startMonitoring()
            }
            .environmentObject(storeKit)
        }
        #if DEBUG
        .sheet(isPresented: $showingDebugMenu) {
            NavigationStack { DebugMenuView() }
        }
        #endif
        // Badge celebration overlay shown after verification fullScreenCover dismisses.
        .onChange(of: showingVerification) { _, isShowing in
            if !isShowing {
                store = SharedDefaults()
                mascotManager.refreshState()
                // Dequeue the first pending badge (rest follow via cascading onChange).
                dequeueBadge()
            }
        }
        .onChange(of: showingEmergency) { _, isShowing in
            if !isShowing {
                store = SharedDefaults()
                mascotManager.refreshState()
            }
        }
        .fullScreenCover(item: $pendingBadge) { badge in
            BadgeUnlockOverlayView(badge: badge) {
                pendingBadge = nil
                // Show next badge after a brief pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dequeueBadge()
                }
            }
        }
        .accessibilityIdentifier("today.home")
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var statusBanner: some View {
        SkyCard {
            HStack(spacing: SkySpacing.s3) {
                Rectangle()
                    .fill(bannerStripeColor)
                    .frame(width: 4)
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: SkySpacing.s1) {
                    Text(bannerTitle)
                        .skyText(.headline, color: SkyColor.ink)

                    Text(bannerBody)
                        .skyText(.bodyS, color: SkyColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.vertical, SkySpacing.s2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bannerTitle). \(bannerBody)")
        .accessibilityIdentifier("today.statusBanner")
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: SkySpacing.s3) {
            switch appState {
            case .blocked:
                SkyPrimaryButton("Verify now") { showingVerification = true }
                    .accessibilityHint("Opens the 30-second outdoor video recording")
                    .accessibilityIdentifier("today.verifyButton")
                SkySecondaryButton("I can't go outside") { showingEmergency = true }
                    .accessibilityHint("Opens the emergency unlock flow. This resets your streak.")
                    .accessibilityIdentifier("today.emergencyButton")

            case .entitlementMissing:
                SkyCoralButton("Reauthorize") {
                    Task { await familyControls.requestAuthorization() }
                }
                .accessibilityHint("Re-grants Screen Time access so Sky can block your apps")
                .accessibilityIdentifier("today.reauthorizeButton")

            case .noApps:
                SkyPrimaryButton("Choose apps") { showingAppSelection = true }
                    .accessibilityHint("Opens the app picker")
                    .accessibilityIdentifier("today.chooseAppsButton")

            case .noLimit:
                SkyPrimaryButton("Set your limit") { showingLimitConfig = true }
                    .accessibilityHint("Opens the session limit editor")
                    .accessibilityIdentifier("today.setLimitButton")

            case .verifiedToday, .emergencyUnlocked, .unblocked, .paused:
                EmptyView()
            }
        }
    }

    // MARK: - Banner content (S-TODAY-02)

    private var bannerTitle: String {
        switch appState {
        case .entitlementMissing: return "Screen Time access needed."
        case .paused:           return "Paused."
        case .unblocked:        return "Sky is watching."
        case .blocked:          return "Time's up."
        case .verifiedToday:    return "Verified ☀"
        case .emergencyUnlocked: return "Emergency unlock used."
        case .noApps:           return "Nothing selected yet."
        case .noLimit:          return "Almost there."
        }
    }

    private var bannerBody: String {
        let session = store.sessionLengthLabel
        switch appState {
        case .entitlementMissing: return "Sky needs Screen Time access again to block your apps."
        case .paused:           return pausedBannerBody
        case .unblocked:        return "\(session) of use, then a trip outside."
        case .blocked:          return "Verify outside for another \(session) of use."
        case .verifiedToday:    return "Apps are open for your next \(session) of use. Nice work."
        case .emergencyUnlocked: return "Streak reset. Tomorrow's a fresh start."
        case .noApps:           return "Choose the apps you'd like Sky to manage."
        case .noLimit:          return "Set your session limit to start."
        }
    }

    private var pausedBannerBody: String {
        guard let ends = store.pauseEndsAt else { return "Shields are off." }
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return "Shields are off until \(fmt.string(from: ends))."
    }

    private var bannerStripeColor: Color {
        switch appState {
        case .entitlementMissing: return SkyColor.coralStreak
        case .paused:           return SkyColor.cloudGrey
        case .unblocked:        return SkyColor.mossGreen
        case .blocked:          return SkyColor.coralStreak
        case .verifiedToday:    return SkyColor.sunYellow
        case .emergencyUnlocked: return SkyColor.cloudGrey
        case .noApps, .noLimit: return SkyColor.primarySky
        }
    }

    // MARK: - Ring label

    private var ringLabel: String {
        switch appState {
        case .entitlementMissing: return "Off"
        case .paused:           return "Off"
        case .verifiedToday:    return "Done"
        case .blocked:          return "0 left"
        default:
            let h = store.combinedLimitSeconds / 3600
            return "\(h)h"
        }
    }

    private var ringAccessibilityValue: String {
        let limitHours = store.combinedLimitSeconds / 3600
        return "Limit: \(limitHours) hour\(limitHours == 1 ? "" : "s")"
    }

    // MARK: - Badge celebration queue

    private func dequeueBadge() {
        guard !streakManager.pendingBadgeCelebrations.isEmpty else { return }
        pendingBadge = streakManager.pendingBadgeCelebrations.removeFirst()
    }

    // MARK: - Micro-interaction

    private func squishNimbus() {
        guard !reduceMotion else { return }
        nimbusScale = 0.88
        withAnimation(SkyMotion.squishSpring.delay(0.05)) {
            nimbusScale = 1.0
        }
    }
}

// MARK: - Config editor sheets (own their view model + a Cancel affordance)
//
// Mirror the EditAppsScreen / EditLimitsScreen wrappers in SettingsAppsAndLimitsView
// so the Today CTAs reuse the exact same S-CFG-01 / S-CFG-03 editors. `onSaved` runs
// before dismissal so the caller can refresh state / re-arm monitoring.

private struct TodayEditAppsSheet: View {
    var onSaved: () -> Void
    @StateObject private var viewModel = AppSelectionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppSelectionView(viewModel: viewModel, onContinue: { onSaved(); dismiss() })
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

private struct TodayEditLimitSheet: View {
    var onSaved: () -> Void
    @StateObject private var viewModel = LimitConfigurationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LimitConfigurationView(viewModel: viewModel, onSave: { onSaved(); dismiss() })
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Previews

#Preview("S-TODAY-01 — Unblocked") {
    TodayView()
        .environmentObject(MascotStateManager())
        .environmentObject(DeviceActivityService())
        .environmentObject(StreakManager())
        .environmentObject(StoreKitService())
        .environmentObject(FamilyControlsService())
}

#Preview("S-TODAY-01 — Blocked") {
    let store = SharedDefaults()
    store.isCurrentlyBlocked = true
    return TodayView()
        .environmentObject(MascotStateManager())
        .environmentObject(DeviceActivityService())
        .environmentObject(StreakManager())
        .environmentObject(StoreKitService())
        .environmentObject(FamilyControlsService())
}

#Preview("S-TODAY-01 — Verified") {
    let store = SharedDefaults()
    store.didVerifyToday = true
    return TodayView()
        .environmentObject(MascotStateManager())
        .environmentObject(DeviceActivityService())
        .environmentObject(StreakManager())
        .environmentObject(StoreKitService())
        .environmentObject(FamilyControlsService())
}

#Preview("S-TODAY-01 — Dark mode") {
    TodayView()
        .environmentObject(MascotStateManager())
        .environmentObject(DeviceActivityService())
        .environmentObject(StreakManager())
        .environmentObject(StoreKitService())
        .environmentObject(FamilyControlsService())
        .preferredColorScheme(.dark)
}
