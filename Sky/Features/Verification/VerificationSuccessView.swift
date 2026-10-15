// VerificationSuccessView.swift
// S-VER-06 — Rewards the user, clears the shield, and writes today-state flags.
// Sky_App_Workflow.md §Part 2 S-VER-06; Tech Spec §7.6.
//
// A pass unlocks the apps until the next lock time (DAILY_LOCK_PLAN.md); the
// copy names that time so it never reads as "until midnight".
//
// Sky Pop (Sky Pop canvas board "CelebratePop"): full-bleed popSky, a tilted
// instant-photo sticker of today's sky with a sun "Day N!" badge, display-face
// title, then Share sky (cream) + Done (primary) Pop buttons.

import SwiftUI

struct VerificationSuccessView: View {
    var onDone: () -> Void
    var store: SharedDefaults = SharedDefaults()
    /// The streak after this verification, passed in by
    /// `VerificationCoordinatorView` from `StreakManager.handleVerificationSuccess`.
    /// The default is only for previews — a real presentation always supplies it.
    var currentStreak: Int = 1

    @State private var mascotState: MascotState = .rainbow
    @State private var displayedStreak: Int = 0
    @State private var showUnlockError: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Today's sky still, saved by the verification pipeline before this
    /// screen appears (SkyPhotoStore). Nil at night (camera check waived) or
    /// if the frame couldn't be kept — Nimbus fills the frame instead.
    @State private var skyPhoto: UIImage? = SkyPhotoStore.shared.image(on: Date())

    var body: some View {
        ZStack {
            // The one loud moment: full-bleed sky (stays bright in dark mode,
            // so everything on it uses the fixed-ink "on accent" tokens).
            SkyColor.popSky.ignoresSafeArea()

            // Spec: "Confetti optional (Reduce Motion off)" — S-VER-06.
            if !reduceMotion {
                SkyConfettiBurst()
                    .ignoresSafeArea()
            }

            VStack(spacing: SkySpacing.s5) {
                Spacer(minLength: SkySpacing.s4)

                polaroid

                Text("That's the stuff.")
                    .skyText(.display, color: SkyColor.inkOnAccent)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Apps are open until your next lock, \(store.lockTimeLabel). Enjoy.")
                    .skyText(.body, color: SkyColor.inkOnAccent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SkyLayout.screenMargin)

                SkyPopStreakBadge(days: displayedStreak)

                Spacer(minLength: SkySpacing.s4)

                if showUnlockError {
                    Text("Couldn't fully clear shields — restart Sky if apps remain blocked.")
                        .skyText(.bodyS, color: SkyColor.inkOnAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SkyLayout.screenMargin)
                }

                HStack(spacing: SkySpacing.s3) {
                    if let skyPhoto {
                        // The still leaves the phone only through the user's own
                        // share sheet (CLAUDE.md privacy invariants).
                        let image = Image(uiImage: skyPhoto)
                        ShareLink(item: image, preview: SharePreview("Today's sky", image: image)) {
                            Text("Share sky")
                        }
                        .buttonStyle(SkyPopButtonStyle(kind: .cream, onAccent: true))
                        .accessibilityIdentifier("verification.shareSky")
                    }
                    Button("Done", action: onDone)
                        .buttonStyle(SkyPopButtonStyle(kind: .primary, onAccent: true))
                        .accessibilityIdentifier("verification.done")
                }
                .padding(.horizontal, SkyLayout.screenMargin)
                .padding(.bottom, SkySpacing.s6)
            }
        }
        .accessibilityIdentifier("verification.success")
        .onAppear {
            #if os(iOS)
            UIAccessibility.post(
                notification: .announcement,
                argument: "Verified. Apps are open until your next lock, \(store.lockTimeLabel)."
            )
            #endif
        }
        .task { await performUnlock() }
    }

    /// A tilted instant-photo "sticker" of today's sky with a sun "Day N!"
    /// badge — outlined like a sticker, but not a button.
    private var polaroid: some View {
        let frame = RoundedRectangle(cornerRadius: SkyRadius.card, style: .continuous)
        let photoShape = RoundedRectangle(cornerRadius: SkyRadius.chip, style: .continuous)
        return VStack(spacing: SkySpacing.s3) {
            ZStack {
                SkyColor.primarySky
                if let skyPhoto {
                    Image(uiImage: skyPhoto)
                        .resizable()
                        .scaledToFill()
                        .accessibilityLabel("Photo of today's sky")
                } else {
                    NimbusView(state: mascotState, size: 160)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(photoShape)
            .overlay(photoShape.strokeBorder(SkyColor.outlineOnAccent, lineWidth: SkyStroke.outline))

            Text(Date().formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .skyText(.button, color: SkyColor.ink)
        }
        .padding(SkySpacing.s3)
        .skyPopSurface(frame, fill: SkyColor.surface, outline: SkyColor.outlineOnAccent,
                       lineWidth: SkyStroke.outlineHeavy, shadow: SkyPopShadow.chip)
        .overlay(alignment: .topTrailing) {
            SkyPopPill("Day \(max(displayedStreak, 1))!", fill: SkyColor.popSun,
                       textColor: SkyColor.inkOnAccent, raised: true, onAccent: true)
                .rotationEffect(.degrees(10))
                .offset(x: SkySpacing.s3, y: -SkySpacing.s4)
                .accessibilityHidden(true) // the streak badge below says it
        }
        .frame(maxWidth: 300)
        .rotationEffect(.degrees(-3))
        .padding(.horizontal, SkySpacing.s10)
    }

    private func performUnlock() async {
        // 0. Roll the day over first if a midnight passed while this flow was open.
        //    Writing today's flags on top of a stale day stamp strands the recovery
        //    in `.stampOnly`, where yesterday can no longer be evaluated.
        MidnightResetRecovery.rollDayOverBeforeWritingTodayState(store: store)

        // 1. Write today-state flags
        store.didVerifyToday = true
        store.isCurrentlyBlocked = false
        store.verificationCompletedAt = Date()
        // Marks this state as today's, so a late midnight reset doesn't mistake it
        // for yesterday's and clear it (MidnightResetRecovery).
        store.stampTodayState()

        // 2. Clear the ManagedSettings shield
        ShieldService.unlockApps(source: .verificationSuccess)

        // 3. Animate streak chip after short delay
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(reduceMotion ? nil : SkyMotion.chipSpring) {
            displayedStreak = currentStreak
        }

        // 4. Transition Nimbus rainbow → sunny after 5s. NimbusView animates
        // the state change itself (0.5s morph; 0.2s crossfade under Reduce
        // Motion) — no withAnimation needed here.
        try? await Task.sleep(for: .seconds(5))
        mascotState = .sunny
    }
}

#Preview("S-VER-06") {
    VerificationSuccessView(onDone: {}, currentStreak: 7)
}

#Preview("S-VER-06 dark") {
    VerificationSuccessView(onDone: {}, currentStreak: 3)
        .preferredColorScheme(.dark)
}
