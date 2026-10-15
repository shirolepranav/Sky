// TodayView.swift
// S-TODAY-01 + S-TODAY-02 — The primary home screen. Shows Nimbus, today's
// status, the lock time, and context-sensitive actions.
// Sky_App_Workflow.md §Group C S-TODAY-01/S-TODAY-02; Roadmap Phase 11.
//
// Sky Pop layout (DESIGN_SYSTEM §1; Sky Pop canvas board "TodayPop"): a
// full-bleed Pop ground on top with the sticker Nimbus and a speech bubble —
// the screen's one loud moment — over a cream bottom sheet holding the status,
// the walk requirements, the lock-time chip and the actions.
//
// The old usage ring is gone: since the daily-lock pivot (DAILY_LOCK_PLAN.md)
// there is no usage to count, so a tappable lock-time chip opens the editor.

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
    /// Today's saved sky photo (Phase F), refreshed whenever the day's state may change.
    @State private var todaysSky: UIImage? = nil
    @State private var showingSkyShare = false
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

    /// The hero ground — the screen's one loud moment (DESIGN_SYSTEM §1.4).
    /// One colour, one meaning: sun = verified, grey = paused / emergency,
    /// sky otherwise. The Pop grounds stay bright in dark mode.
    private var heroGround: Color {
        switch appState {
        case .verifiedToday:               return SkyColor.popSun
        case .paused, .emergencyUnlocked:  return SkyColor.cloudGrey
        default:                           return SkyColor.popSky
        }
    }

    /// Nimbus's speech bubble — decorative, kind, never guilt-tripping.
    private var bubbleText: String {
        switch appState {
        case .blocked:            return "come out & play!"
        case .unblocked:          return "see you at \(store.lockTimeLabel)!"
        case .verifiedToday:      return "that's the stuff!"
        case .emergencyUnlocked:  return "tomorrow's fresh!"
        case .paused:             return "taking a breather"
        case .noApps, .noLimit:   return "let's set up!"
        case .entitlementMissing: return "need a hand?"
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    hero(height: geo.size.height)
                    sheet
                }
                // Fill at least the screen so the sheet reaches the tab bar.
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable {
                store = SharedDefaults()
                mascotManager.refreshState()
            }
            // Ground behind the status bar on top, cream under the sheet below,
            // so over-scroll at either end shows the right colour.
            .background(
                VStack(spacing: 0) { heroGround; SkyColor.surface }
                    .ignoresSafeArea()
            )
            .animation(reduceMotion ? nil : SkyMotion.fadeEase, value: appState)
        }
        .onAppear {
            store = SharedDefaults()
            mascotManager.refreshState()
            revealed = true
            todaysSky = SkyPhotoStore.shared.image(on: Date())
        }
        // A pass changes the mascot; that is also when today's photo appears.
        .onChange(of: mascotManager.state) {
            store = SharedDefaults()
            todaysSky = SkyPhotoStore.shared.image(on: Date())
        }
        .sheet(isPresented: $showingSkyShare) {
            StreakShareSheetView(progress: streakManager.progress) { showingSkyShare = false }
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
        // S-CFG-03 · Lock-time editor. On save, re-arm monitoring so the new
        // configuration takes effect and the state flips to `.unblocked`.
        .sheet(isPresented: $showingLimitConfig) {
            TodayEditLimitSheet {
                store = SharedDefaults()
                try? deviceActivity.startMonitoring()
                // A lock time moved to an hour already past today applies now.
                ShieldService.reconcile()
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

    // MARK: - Hero (top half: Pop ground, stickers, Nimbus)

    private func hero(height: CGFloat) -> some View {
        let nimbusSize = min(height * 0.3, 230)
        return VStack(spacing: SkySpacing.s4) {
            // Date sticker (info, flat) + streak badge.
            HStack {
                SkyPopPill(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                           onAccent: true)
                Spacer()
                SkyPopStreakBadge(days: streakManager.progress.currentStreak)
            }
            .padding(.horizontal, SkySpacing.s5)
            .padding(.top, SkySpacing.s4)
            .skyEntrance(0, revealed: revealed)

            ZStack(alignment: .topTrailing) {
                NimbusView(state: mascotManager.state, size: nimbusSize)
                    .scaleEffect(nimbusScale)
                    .animation(SkyMotion.squishSpring, value: nimbusScale)
                    .frame(maxWidth: .infinity)
                    .padding(.top, SkySpacing.s10)
                    .accessibilityLabel(mascotManager.state.accessibilityDescription)
                    .onTapGesture { squishNimbus() }
                    // Long-press → debug menu (S-SET-09), DEBUG builds only.
                    #if DEBUG
                    .onLongPressGesture(minimumDuration: 2) { showingDebugMenu = true }
                    #endif

                SkySpeechBubble(text: bubbleText)
                    .padding(.trailing, SkySpacing.s6)
                    .id(bubbleText)
                    .transition(.opacity)
            }
            .padding(.bottom, SkySpacing.s4)
            .skyEntrance(1, revealed: revealed)
        }
    }

    // MARK: - Sheet (bottom half: status, steps, actions)

    private var sheet: some View {
        SkyPopSheet(padding: SkySpacing.s5) {
            VStack(alignment: .leading, spacing: SkySpacing.s4) {
                statusBanner
                    .id(appState == .blocked || appState == .emergencyUnlocked ? "urgent" : "calm")
                    .transition(.opacity)
                    .skyEntrance(2, revealed: revealed)

                if appState == .blocked {
                    unlockRequirements
                        .skyEntrance(3, revealed: revealed)
                }

                if appState == .verifiedToday, let todaysSky {
                    todaysSkyCard(todaysSky)
                }

                lockTimeChip
                    .skyEntrance(3, revealed: revealed)

                Spacer(minLength: SkySpacing.s4)

                actionButtons
                    .skyEntrance(4, revealed: revealed)
            }
            .padding(.bottom, SkySpacing.s4)
        }
    }

    /// Title + body for the current state (S-TODAY-02). Informational, so no
    /// outline — the outline is reserved for things you can tap.
    private var statusBanner: some View {
        VStack(alignment: .leading, spacing: SkySpacing.s2) {
            Text(bannerTitle)
                .skyText(.titleXL)
                .fixedSize(horizontal: false, vertical: true)
            Text(bannerBody)
                .skyText(.bodyS, color: SkyColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bannerTitle). \(bannerBody)")
        .accessibilityIdentifier("today.statusBanner")
    }

    /// What the walk takes: two info tiles (hairline cards, not tappable).
    /// Values come from VerificationThresholds — never duplicated here.
    private var unlockRequirements: some View {
        HStack(spacing: SkySpacing.s3) {
            requirementTile(overline: "STEPS",
                            value: "\(VerificationThresholds.minRecentSteps)",
                            unit: "steps",
                            spoken: "\(VerificationThresholds.minRecentSteps) steps outside")
            requirementTile(overline: "SKY CLIP",
                            value: "\(VerificationThresholds.clipSeconds)",
                            unit: "sec",
                            spoken: "A \(VerificationThresholds.clipSeconds) second clip of the sky")
        }
    }

    private func requirementTile(overline: String, value: String, unit: String, spoken: String) -> some View {
        SkyCard(secondary: true, padding: SkySpacing.s4) {
            VStack(alignment: .leading, spacing: SkySpacing.s2) {
                Text(overline).skyText(.overline, color: SkyColor.inkSoft)
                HStack(alignment: .firstTextBaseline, spacing: SkySpacing.s1) {
                    Text(value).skyText(.numeral)
                    Text(unit).skyText(.label, color: SkyColor.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// Tappable lock-time chip → lock-time editor (S-CFG-03). Replaces the old
    /// usage ring: with the daily lock there's no usage to show, only the time.
    private var lockTimeChip: some View {
        Button { showingLimitConfig = true } label: {
            HStack(spacing: SkySpacing.s2) {
                Image(systemName: "lock.fill").accessibilityHidden(true)
                Text(lockChipLabel)
                Image(systemName: "pencil").accessibilityHidden(true)
            }
            .skyText(.label, color: SkyColor.ink)
        }
        .buttonStyle(SkyChipButtonStyle())
        .fixedSize()
        .accessibilityLabel(lockChipLabel)
        .accessibilityHint("Opens the lock time editor")
        .accessibilityIdentifier("today.lockTime")
    }

    private var lockChipLabel: String {
        switch appState {
        case .paused, .entitlementMissing: return "Lock is off"
        default: return "Locks daily at \(store.lockTimeLabel)"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: SkySpacing.s3) {
            switch appState {
            case .blocked:
                SkyPopButton("Let's go outside", systemImage: "arrow.right") { showingVerification = true }
                    .accessibilityHint("Opens the outdoor verification")
                    .accessibilityIdentifier("today.verifyButton")
                Button("I can't go outside right now") { showingEmergency = true }
                    .skyText(.label, color: SkyColor.inkSoft)
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: SkyLayout.minTouchTarget)
                    .accessibilityHint("Opens the emergency unlock flow. This resets your streak.")
                    .accessibilityIdentifier("today.emergencyButton")

            case .entitlementMissing:
                SkyPopButton("Reauthorize", kind: .coral) {
                    Task { await familyControls.requestAuthorization() }
                }
                .accessibilityHint("Re-grants Screen Time access so Sky can block your apps")
                .accessibilityIdentifier("today.reauthorizeButton")

            case .noApps:
                SkyPopButton("Choose apps") { showingAppSelection = true }
                    .accessibilityHint("Opens the app picker")
                    .accessibilityIdentifier("today.chooseAppsButton")

            case .noLimit:
                SkyPopButton("Set your lock time") { showingLimitConfig = true }
                    .accessibilityHint("Opens the lock time editor")
                    .accessibilityIdentifier("today.setLimitButton")

            case .verifiedToday, .emergencyUnlocked, .unblocked, .paused:
                EmptyView()
            }
        }
    }

    // MARK: - Today's sky (Phase F)

    private func todaysSkyCard(_ image: UIImage) -> some View {
        SkyCard {
            VStack(alignment: .leading, spacing: SkySpacing.s3) {
                Text("Today's sky")
                    .skyText(.label, color: SkyColor.inkSoft)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: SkyRadius.cardSecondary, style: .continuous))
                    .accessibilityLabel("Photo of today's sky")
                SkyPopButton("Share today's sky", kind: .cream) { showingSkyShare = true }
                    .accessibilityIdentifier("today.shareSky")
            }
        }
    }

    // MARK: - Banner content (S-TODAY-02)

    private var bannerTitle: String {
        switch appState {
        case .entitlementMissing: return "Screen Time access needed."
        case .paused:           return "Paused."
        case .unblocked:        return "Sky is watching."
        case .blocked:          return "Apps are napping."
        case .verifiedToday:    return "Verified ☀"
        case .emergencyUnlocked: return "Emergency unlock used."
        case .noApps:           return "Nothing selected yet."
        case .noLimit:          return "Almost there."
        }
    }

    private var bannerBody: String {
        let lock = store.lockTimeLabel
        switch appState {
        case .entitlementMissing: return "Sky needs Screen Time access again to block your apps."
        case .paused:           return pausedBannerBody
        case .unblocked:        return "Apps pause at \(lock). A short walk outside unlocks them for the day."
        case .blocked:          return "Nimbus is waiting outside. A short walk unlocks your apps for the day."
        case .verifiedToday:    return "Apps stay open until your next lock, \(lock). Nice work."
        case .emergencyUnlocked: return "Streak reset. Tomorrow's a fresh start."
        case .noApps:           return "Choose the apps you'd like Sky to manage."
        case .noLimit:          return "Pick your lock time to start."
        }
    }

    private var pausedBannerBody: String {
        guard let ends = store.pauseEndsAt else { return "Shields are off." }
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return "Shields are off until \(fmt.string(from: ends))."
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
