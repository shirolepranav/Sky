# Sky — Development Roadmap

16 phases, ordered by dependency. Each phase is scoped tightly enough to fit in an AI coding tool's context window. Each phase has:
- **Code Development** — what to build
- **Automated Tests** — XCTest / XCUITest cases an AI assistant can write and run
- **Manual Tests** — checks that require a physical device (camera, GPS, sensors, Screen Time API, App Store)
- **Regression Tests** — only re-tests for features built in *earlier* phases that this phase could plausibly break

Do not start Phase N+1 until all four sections of Phase N are green.

---

## Phase 0 — Foundation Setup

### Code Development
- Create Xcode project with iOS app target, iOS 17.0 minimum, SwiftUI lifecycle, Swift 5.10+
- Create three additional targets: `DeviceActivityMonitorExtension`, `ShieldConfigurationExtension`, `ShieldActionExtension`
- Enable App Group `group.com.sky.shared` on all four targets
- Enable iCloud (CloudKit container) and Sign in with Apple capabilities on main app
- Add URL scheme `sky://` to main app `Info.plist`
- **Submit Family Controls Distribution entitlement requests for all four bundle IDs** (do this on day one — approval can take weeks)
- Create the folder structure from the Technical Spec
- Create `AppBranding.swift` with all constants (app name, mascot name, colors, product IDs)
- Set up Git, `.gitignore`, README

### Automated Tests
- `AppBrandingTests.testColorValuesParseCorrectly` — verifies hex colors decode without crashing
- `AppBrandingTests.testProductIDsAreUnique` — verifies the four StoreKit product IDs are distinct
- Build succeeds for all four targets in Debug and Release

### Manual Tests
- Open project in Xcode 16+; verify no signing errors after entitlement-pending state
- Confirm Family Controls request submitted (screenshot the confirmation page for records)
- Confirm App Group appears in all four target Capabilities

### Regression Tests
- None (first phase).

---

## Phase 1 — Design System & Mascot

### Code Development
- Implement `ColorTokens.swift` with `Color(hex:)` extension and all six brand colors
- Implement `Typography.swift` with SF Rounded styles at semantic sizes (largeTitle, title, body, caption)
- Build reusable components in `Core/DesignSystem/`:
  - `SkyPrimaryButton`, `SkySecondaryButton`, `SkyDestructiveButton`
  - `SkyCard` (rounded container with shadow)
  - `SkyProgressRing` (for daily usage and verification countdown)
- Build `NimbusView.swift` with `@State var mascotState: MascotState` parameter and 5 visual states (cloudy-grey, fluffy-white, sunny, rainbow, rainy)
  - v1.0 implementation: composable SwiftUI shapes (`Circle`, `Ellipse`, gradients) — no external assets required
  - Each state has a 2-second idle animation loop (gentle bob, soft pulse, etc.)
  - State transitions animate over 0.5s using `withAnimation`
- Build a `DesignSystemPreviewScreen` (hidden behind a debug menu) showing every component for visual QA

### Automated Tests
- `ColorTokensTests.testHexParsing` — known hex strings produce expected RGB values
- Snapshot tests for each `NimbusView` state using point-Free's swift-snapshot-testing or Xcode's built-in `assertSnapshot` if available (optional in v1.0; skip if it adds friction)
- `SkyButtonTests.testDisabledStateAppliesOpacity` — disabled buttons have reduced opacity

### Manual Tests
- Open the DesignSystemPreviewScreen on a physical iPhone 12+ and verify:
  - All five Nimbus states render and animate smoothly
  - Color rendering matches the spec under light AND dark mode
  - Typography is readable on both small (iPhone SE 3) and large (iPhone 16 Pro Max) screens

### Regression Tests
- Rebuild project — Phase 0's build still succeeds.

---

## Phase 2 — Onboarding Flow

### Code Development
- Build 5-screen onboarding sequence (no actual permission prompts yet — mock states):
  1. Welcome screen with Nimbus introduction
  2. "Pick which apps to limit" preview (illustrative)
  3. "Set your daily time budget" preview (illustrative)
  4. "When time's up, go outside" preview with verification illustration
  5. "Ready?" — final continue button to next phase (permission requests)
- Use `TabView` with `.page` style for swipe navigation
- Add `OnboardingCompleted` flag in `UserDefaults.standard` to skip on subsequent launches
- Wire `SkyApp.swift` to route between Onboarding and main app based on flag

### Automated Tests
- `OnboardingViewModelTests.testFirstLaunchShowsOnboarding`
- `OnboardingViewModelTests.testCompletingOnboardingSetsFlag`
- `OnboardingViewModelTests.testCompletedOnboardingRoutesToMainApp`
- XCUITest: `OnboardingUITests.testSwipeThroughAllFiveScreens`
- XCUITest: `OnboardingUITests.testFinalScreenContinueButtonDismisses`

### Manual Tests
- Fresh install on physical device → onboarding appears
- Complete onboarding → main app appears
- Force-quit and relaunch → onboarding does NOT appear
- Delete app and reinstall → onboarding appears again
- Test on iPhone SE 3 (smallest screen) — copy not truncated, mascot not clipped

### Regression Tests
- DesignSystemPreviewScreen still accessible via debug menu (Phase 1).
- All Nimbus states still render correctly inside onboarding screens (Phase 1).

---

## Phase 3 — Family Controls Authorization & App Selection

### Code Development
*Prerequisite: Family Controls entitlement has been approved by Apple. If not yet approved, build this phase against the local sandbox by enabling the entitlement manually in your provisioning profile.*

- Create `FamilyControlsService.swift`:
  - `func requestAuthorization() async throws` — wraps `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
  - `var authorizationStatus: AuthorizationStatus { get }` — checks current state
- Build authorization screen shown after onboarding:
  - Explains why Sky needs Screen Time access (one paragraph + Nimbus visual)
  - Tappable "Allow" button triggers the iOS system prompt
  - Handle denied state with a re-prompt + Settings deep link
- Build `AppSelectionView` wrapping `FamilyActivityPicker`:
  - User taps "Choose apps" → picker sheet presents
  - On dismiss, encode `FamilyActivitySelection` to `Data` and persist to App Group `UserDefaults`
  - Display a summary count ("4 apps selected") — Sky cannot display app names
- Persist via `SharedDefaults.familyActivitySelection`

### Automated Tests
- `FamilyControlsServiceTests.testAuthorizationStatusReadsFromCenter` — uses a mock injected center
- `SharedDefaultsTests.testEncodeDecodeFamilyActivitySelection` — round-trip a selection through Data and back
- `SharedDefaultsTests.testEmptySelectionDoesNotCrash`
- XCUITest: `AppSelectionUITests.testTappingChooseAppsOpensSystemPicker` — verifies the system picker appears (cannot interact with the picker itself in tests; can only verify presentation)

### Manual Tests
- Fresh install → onboarding → authorization prompt → tap Allow → iOS system prompt appears → grant
- Verify status persists across app relaunches
- Open app selection → pick 3–4 social apps → dismiss → count updates to "3 apps selected" or "4 apps selected"
- Force-quit and relaunch → selection still persisted (count unchanged)
- Test denied flow: deny on first prompt, verify re-prompt screen shows Settings deep link
- Test on iOS 17.0, 17.6, latest 18.x

### Regression Tests
- Onboarding still appears on fresh install (Phase 2).
- Skipping onboarding still works after completion (Phase 2).

---

## Phase 4 — Time Limit Configuration

### Code Development
- Build `LimitConfigurationView`:
  - Toggle at top: "Combined limit" vs "Per-app limits"
  - **Combined mode:** segmented picker for 1 hour / 2 hours / 3 hours
  - **Per-app mode:** For each app in the selection, a stepper from 15 min to 4 hours in 15-min steps. Sky shows app icons via the Family Controls token rendering (`Label(token)` from `FamilyControls`) — names still hidden
  - Save button persists `limitMode`, `combinedLimitSeconds`, `perAppLimits` to `SharedDefaults`
- Build a settings row deep-linking to this screen
- Add a "Daily reset" caption: *"Limits reset at midnight, your local time."*

### Automated Tests
- `LimitConfigurationViewModelTests.testCombinedLimitPersists`
- `LimitConfigurationViewModelTests.testPerAppLimitsPersist`
- `LimitConfigurationViewModelTests.testSwitchingModesPreservesPreviousValues`
- `LimitConfigurationViewModelTests.testMinimumLimitIs15Minutes`
- `LimitConfigurationViewModelTests.testMaximumLimitIs4Hours`

### Manual Tests
- Toggle modes — UI updates correctly
- Set combined limit to 1 hour, save, close app, reopen → 1 hour still selected
- Set per-app limits, save, reopen → all values persisted
- Per-app mode with 5 apps selected — UI scrolls properly on small screens

### Regression Tests
- App selection from Phase 3 still works (re-opening picker preserves prior selection).
- FamilyControlsService authorization still succeeds (Phase 3).

---

## Phase 5 — Screen Time Monitoring & App Blocking

### Code Development
- Implement `DeviceActivityService.swift` in the main app:
  - `func startMonitoring() throws` — builds the `DeviceActivitySchedule` (midnight-to-midnight, repeats) and `DeviceActivityEvent`s from current `SharedDefaults` state
  - `func stopMonitoring()` — calls `DeviceActivityCenter().stopMonitoring()`
- Implement `SkyDeviceActivityMonitor.swift` in the extension target:
  - `override func eventDidReachThreshold(_:activity:)` — reads `familyActivitySelection` from App Group, sets `ManagedSettingsStore().shield.applications`, writes `isCurrentlyBlocked = true`
  - `override func intervalDidStart(for:)` — at midnight: clears shields, writes `didVerifyToday = false`, `didEmergencyUnlockToday = false`, `isCurrentlyBlocked = false`, `todayResetToken = today's YYYY-MM-DD`
  - `override func intervalDidEnd(for:)` — no-op in v1.0 (handled by `intervalDidStart` of next day)
- Wire the "Start" button in main app to call `DeviceActivityService.startMonitoring()`
- Show a status banner in the main app: "Sky is watching" (active) or "Sky is paused" (inactive)

### Automated Tests
- `DeviceActivityServiceTests.testScheduleBuildsCorrectly` — schedule covers full 24 hours
- `DeviceActivityServiceTests.testEventThresholdMatchesCombinedLimit`
- `DeviceActivityServiceTests.testPerAppModeCreatesOneEventPerApp`
- `SharedDefaultsTests.testIsCurrentlyBlockedWriteAndRead`

### Manual Tests (mostly manual — requires real device usage over time)
- On a real device, set a tiny combined limit (e.g. 2 minutes for testing) — open a selected social app and use it for 2 minutes
- Verify the app gets shielded — system shield (Apple default) should appear since Sky's custom shield isn't built until Phase 6
- Verify `isCurrentlyBlocked` becomes true (check via debug menu)
- At local midnight (or simulated by changing device time): apps should unshield automatically
- Test with 3+ apps selected
- Test with both combined and per-app modes

### Regression Tests
- App selection still loads correctly when entering this phase (Phase 3).
- Limit configuration values are read correctly by the new monitoring service (Phase 4).
- Authorization status still persists (Phase 3).

---

## Phase 6 — Custom Shield UI & Shield Actions

### Code Development
- Implement `SkyShieldConfiguration.swift` in the ShieldConfigurationExtension target:
  - Override `configuration(shielding:)` and `configuration(shielding:in:)`
  - Return a `ShieldConfiguration` with:
    - Background: `AppBranding.warmCream`
    - Icon: Nimbus rendered as a UIImage (note: ShieldConfiguration uses UIKit, not SwiftUI — render Nimbus once as a static PNG at build time and ship it as an asset bundled with the extension)
    - Title: `"\(AppBranding.appName) — Time's up"`
    - Subtitle: `"\(AppBranding.mascotName) is waiting outside for you ☁️"`
    - Primary button: `"Go outside to unlock"` with deep-link payload `sky://verify`
    - Auxiliary button: `"I can't go outside right now"` with deep-link payload `sky://emergency`
- Implement `SkyShieldAction.swift` in the ShieldActionExtension target:
  - Override `handle(action:for:completionHandler:)`
  - On primary button: open `sky://verify` URL
  - On auxiliary button: open `sky://emergency` URL
  - Call `completionHandler(.close)` after opening URL
- Update main app to handle the `sky://` URL scheme via `.onOpenURL` and route to a placeholder verification or emergency screen (full screens come in later phases)

### Automated Tests
- `ShieldConfigurationTests.testConfigurationHasCorrectTitle` — assuming you can instantiate the extension's view model directly
- `ShieldConfigurationTests.testConfigurationHasGoOutsideButton`
- Unit test the URL parser in main app: `sky://verify` and `sky://emergency` route to the correct enum cases

### Manual Tests
- Reduce the test limit and trigger a block; tap a shielded app — Sky's custom shield appears (NOT the default iOS one)
- Verify Nimbus image renders correctly (PNG at @2x and @3x)
- Tap "Go outside to unlock" → Sky main app opens to verification placeholder
- Tap "I can't go outside right now" → Sky main app opens to emergency placeholder
- Test on iOS 17.0, 17.6, latest 18.x — shield UI is one of the historically unstable parts of the API

### Regression Tests
- Monitoring still triggers blocks at the configured threshold (Phase 5).
- Apps still unshield at midnight (Phase 5).
- App selection and limits still persist (Phases 3, 4).

---

## Phase 7 — Video Recording UI

### Code Development
- Build `VideoRecordingView` using `AVCaptureSession`:
  - Back camera, 1080p, 30fps
  - Full-screen preview with rounded corners
  - 30-second countdown ring overlay
  - On-screen prompts that fade in/out at scheduled times:
    - 0s: "Hold steady, point your camera up"
    - 6s: "Now slowly look around"
    - 14s: "Point at the sky for 5 seconds"
    - 22s: "Last bit — show where you are"
    - 30s: "Processing…"
  - Cancel button (returns to previous screen, deletes any partial recording)
- Save the recorded video to `FileManager.default.temporaryDirectory` as `verification_\(UUID()).mov`
- Request `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` in `Info.plist` (video recording needs both)
- Request `NSLocationWhenInUseUsageDescription` for the sensor pipeline that follows
- Show a permissions-rationale screen before the first launch of this screen

### Automated Tests
- `VideoRecordingViewModelTests.testRecordingStartsTimer`
- `VideoRecordingViewModelTests.testRecordingStopsAt30Seconds`
- `VideoRecordingViewModelTests.testCancelDeletesFile`
- `VideoRecordingViewModelTests.testPromptsAdvanceOnSchedule` — uses a virtual clock

### Manual Tests
- Trigger recording → camera permission prompt appears → grant → recording begins
- Record a full 30-second video — prompts appear at correct times
- Cancel mid-recording — file is deleted (verify via debug menu file listing)
- Test in low light — preview is still visible
- Test on iPhone 12, 14, 16 — performance is smooth at 30fps
- Verify temporary directory is empty after each completed or cancelled recording

### Regression Tests
- Shield deep links still route to verification screen (Phase 6) — they now go to the real video recording UI.
- Onboarding still completes correctly (Phase 2).

---

## Phase 8 — Sensor Fusion Verification

### Code Development
- Implement `SensorRecorder.swift` started concurrently with the video recording:
  - `CLLocationManager` configured `kCLLocationAccuracyBest`, samples every 2 seconds
  - `CMAltimeter.startRelativeAltitudeUpdates(to:)` if available (most iPhones)
  - Camera `AVCaptureDevice.exposureTargetOffset` and ISO samples every 0.5 second
  - Records start-time and end-time
- Implement spoof detection:
  - `CLLocation.sourceInformation?.isProducedByAccessory` check at every GPS sample (iOS 15+)
- Implement sunrise/sunset check:
  - Use the user's GPS coordinates and current date with a simple Solar Position Algorithm (small Swift implementation or a known small library)
  - Pass if current time is between sunrise and sunset; fail otherwise (unless night-mode opt-in is enabled in settings — defer the toggle to Phase 15)
- Aggregate all data into a `SensorReading` struct at the end of recording
- Display a friendly loading state while data aggregates ("Checking your surroundings…")

### Automated Tests
- `SensorReadingTests.testSpeedCalculatedCorrectly` — given mock GPS samples, compute speed
- `SensorReadingTests.testAltitudeDeltaCalculated`
- `SensorReadingTests.testGPSSpoofDetected`
- `SunriseSunsetTests.testKnownLocationsAndDates` — test 5 known lat/lng/date combinations against published sunrise/sunset times (must be accurate within ±2 minutes)

### Manual Tests
- Record a video standing still indoors — sensor reading should show low speed, no altitude delta, low light, high GPS uncertainty
- Record a video walking outside — sensor reading should show speed > 0.3 m/s, altitude delta, daylight
- Test in a basement — GPS accuracy should be poor (> 25m) or unavailable
- Test in a moving car — should detect motion (but later phases should reject for other reasons — we want walking, not driving; this is a refinement for v1.1)

### Regression Tests
- Video recording still functions and saves to temp directory (Phase 7).
- Camera and location permissions still requested and granted (Phase 7).

---

## Phase 9 — Vision-Based Outdoor Classification

### Code Development
- Implement `VisionAnalyzer.swift`:
  - Takes a saved video file URL
  - Extracts every 5th frame via `AVAssetImageGenerator` (yields ~6 frames per second)
  - Runs `VNClassifyImageRequest` on each frame
  - Filters classifications for outdoor-related identifiers: `outdoor`, `sky`, `tree`, `grass`, `park`, `street`, `field`, `mountain`, `cloud`, `forest`, `beach`, `lake`, `garden`
  - Computes a per-frame "outdoor confidence" score (max confidence among matching identifiers)
- Implement `SkyPixelCounter.swift`:
  - For each sampled frame, count pixels matching sky-color HSV ranges (blue-sky AND overcast-grey)
  - Return the highest single-frame sky percent across the video
- Both analyzers run concurrently using Swift `async let` and produce `FrameAnalysisResult`

### Automated Tests
- `VisionAnalyzerTests.testOutdoorImageScoresHigh` — bundle 3 known outdoor test images and verify > 0.5 confidence
- `VisionAnalyzerTests.testIndoorImageScoresLow` — 3 indoor test images verify < 0.3
- `SkyPixelCounterTests.testBlueSkyImageReturnsHighPercent` — known sky image returns > 0.5
- `SkyPixelCounterTests.testIndoorImageReturnsLowPercent` — known indoor image returns < 0.05
- `VisionAnalyzerTests.testSampling` — given a 30s mock video, exactly 180 frames are sampled (or whatever the math works out to at 30fps every 5th frame)

### Manual Tests
- Record video outdoors in 5 different real environments:
  1. Urban park with grass and trees
  2. Suburban street with sky visible
  3. Indoor near a sunny window (should produce mixed scores)
  4. Basement (should produce low scores)
  5. Outdoor at dusk (should produce moderate scores)
- Inspect the per-frame scores logged in debug mode and verify they make intuitive sense
- Performance: full 30-second video processed in < 5 seconds on iPhone 12

### Regression Tests
- Sensor fusion (Phase 8) still produces correct readings when run alongside vision analysis.
- Video recording still cleans up temp files (Phase 7).

---

## Phase 10 — Verification Decision Engine & Unlock

### Code Development
- Implement `VerificationDecisionEngine.swift`:
  - Takes `SensorReading` + `FrameAnalysisResult` as input
  - Returns `Result<Verified, FailureReason>`
  - Thresholds defined in a separate `VerificationThresholds.swift` file (single source of truth, tunable)
- Implement `FailureReason` enum with cases: `gpsSpoofingDetected`, `outsideDaylightWindow`, `poorGPSSignal`, `notEnoughMovement`, `notBrightEnough`, `sceneNotOutdoor`, `noSkyVisible`
- Build the verification result screen:
  - **Success state:** rainbow Nimbus animation, "Verified! ☀️ Apps unlocked for today", streak count animation, dismiss button
  - **Failure state:** sad Nimbus, the specific reason in friendly language, "Try Again" button, "I can't go outside" emergency link
- On success, call `ShieldService.unlockApps()`:
  - `ManagedSettingsStore().shield.applications = nil`
  - `SharedDefaults().didVerifyToday = true`
  - `SharedDefaults().isCurrentlyBlocked = false`
  - Mark verification in `SharedDefaults().verificationCompletedAt = Date()`
- **Threshold tuning is a manual sub-task here** — run real-world tests, adjust `VerificationThresholds.swift`, repeat

### Automated Tests
- `DecisionEngineTests.testAllSignalsPassReturnsSuccess`
- `DecisionEngineTests.testGPSSpoofFails`
- `DecisionEngineTests.testIndoorLowLightFails`
- `DecisionEngineTests.testNoSkyFails`
- `DecisionEngineTests.testInsufficientMovementFails`
- `DecisionEngineTests.testNightTimeWithoutOptInFails`
- `ShieldServiceTests.testUnlockClearsShield` — using a mock `ManagedSettingsStore`

### Manual Tests
- **The critical phase for real-world tuning.** Test in 5 environments minimum:
  1. Urban park midday: must pass
  2. Suburban sidewalk midday: must pass
  3. Indoor near sunny window: must fail (close call — verifies the bar is set correctly)
  4. Indoor in dim room: must fail
  5. Outdoor at twilight: must pass if before sunset
- Iterate on thresholds in `VerificationThresholds.swift` until all 5 pass correctly
- After a successful verification, manually open one of the previously blocked apps — it should open without a shield

### Regression Tests
- Video recording, sensor capture, and vision analysis still work and feed into this engine correctly (Phases 7, 8, 9).
- Shield is applied when threshold is hit (Phase 5).
- Custom shield UI still renders (Phase 6).

---

## Phase 11 — Mascot Reactions & State Management

### Code Development
- Implement `MascotStateManager.swift`:
  - Reads current mascot state from CloudKit/local cache
  - Determines next state based on event: `.verifiedToday`, `.emergencyUnlockUsed`, `.streakHitMilestone(days:)`, `.dayPassedWithoutVerification`
  - Writes new state and triggers UI animation
- Hook into post-verification success: state → `.celebrating` for 5 seconds, then → `.happy` for 24 hours, then → `.idle`
- Hook into post-emergency-unlock: state → `.sad`
- Add a Home view ("Today" tab) that shows the mascot prominently with the current state
- Implement mascot transition animations using SwiftUI `.transition(.scale.combined(with: .opacity))`

### Automated Tests
- `MascotStateManagerTests.testVerificationTransitionsToHappy`
- `MascotStateManagerTests.testEmergencyUnlockTransitionsToSad`
- `MascotStateManagerTests.testMilestoneStreakTriggersRainbow`
- `MascotStateManagerTests.testStatePersistsAcrossAppRelaunches`

### Manual Tests
- After a successful verification, Nimbus should transition: rainbow celebration → sunny → next day, back to cloudy-grey before next verification
- After an emergency unlock, Nimbus should appear rainy for the rest of the day
- Force-quit and relaunch — mascot state persists
- Visual check: animations are smooth, never janky

### Regression Tests
- Verification success still unlocks apps (Phase 10).
- Verification failure still shows the failure UI with friendly messaging (Phase 10).
- Shield service still toggles correctly (Phase 5, 6).

---

## Phase 12 — Daily Reset, Streaks & Badges

### Code Development
- Implement `StreakManager.swift`:
  - On every successful verification: if `lastVerificationDate` was yesterday, increment current streak; if it was today, no change; otherwise reset to 1
  - On every emergency unlock: reset current streak to 0
  - On day end (midnight, via `DeviceActivityMonitor.intervalDidStart`): if `didVerifyToday == false` and `didEmergencyUnlockToday == false`, reset streak to 0 (the user just skipped a day silently)
  - Update `longestStreak` if current exceeds it
- Implement `BadgeEngine.swift`:
  - Define `enum BadgeID` with all 10 launch badges
  - After every verification, check all badge conditions and add to `unlockedBadges` if newly earned
  - Trigger a UI celebration when a new badge is earned ("Badge unlocked: Sunburst")
- Build `BadgesView` — grid of all 10 badges, locked badges greyed out
- Implement `CloudKitSyncService.swift`:
  - Save `UserProgress` record on every change
  - Fetch on app launch; subscribe to changes
  - Conflict resolution: last-writer-wins for counters; union for badge list
- Verify the midnight reset writes to `SharedDefaults` and the main app picks up the new values on next foreground

### Automated Tests
- `StreakManagerTests.testFirstVerificationStartsStreakAt1`
- `StreakManagerTests.testConsecutiveDaysIncrementStreak`
- `StreakManagerTests.testMissedDayResetsStreak`
- `StreakManagerTests.testEmergencyUnlockResetsStreak`
- `StreakManagerTests.testLongestStreakUpdatesWhenExceeded`
- `BadgeEngineTests.testFirstLightUnlocksOnFirstVerification`
- `BadgeEngineTests.testStreakBadgesUnlockAtCorrectThresholds`
- `BadgeEngineTests.testWandererBadgeRequires5DistinctLocations`
- `CloudKitSyncServiceTests.testSaveAndFetchUserProgress` — requires a CloudKit test environment

### Manual Tests
- Verify successfully two days in a row → streak shows 2
- Verify, then next day use emergency unlock → streak shows 0
- Verify, then skip a day, then verify → streak shows 1 (not 2)
- Hit a streak milestone → badge celebration appears
- Install on a second device with same iCloud account → progress syncs within 30 seconds
- Manually change device clock to next day → midnight reset triggers via DeviceActivityMonitor (or simulate by waiting)

### Regression Tests
- Mascot state transitions still work alongside streak changes (Phase 11).
- Verification still unlocks apps (Phase 10).
- Shield still applies at threshold (Phase 5).

---

## Phase 13 — Emergency Unlock with Typed Reason

### Code Development
- Implement `PasteBlockedTextField.swift` UIViewRepresentable per the Technical Spec:
  - Override `canPerformAction(_:withSender:)` to block paste, copy, cut, share, dictation
  - Reject single-insertion strings > 5 characters
  - Reject newlines
- Build `EmergencyUnlockView`:
  - Sad Nimbus illustration at top
  - Title: "Are you sure?"
  - Body: "If you can't go outside right now, type why you need to unlock the apps. \(AppBranding.mascotName) will remember."
  - `PasteBlockedTextField` for the reason input (min 20 chars, max 200 chars)
  - 5-second countdown timer below the field (disables Unlock button until 0)
  - Character counter
  - "Cancel" and "Unlock anyway" buttons
- On Unlock confirmed:
  - Save `EmergencyUnlockEntry` to local-only store (NEVER CloudKit)
  - Call `ShieldService.unlockApps()`
  - Set `SharedDefaults().didEmergencyUnlockToday = true`
  - Trigger mascot transition to `.sad`
  - Reset streak via `StreakManager`
- Build a weekly insight screen showing the user their top 3 emergency-unlock reasons (read from local store only)

### Automated Tests
- `PasteBlockedTextFieldTests.testPasteActionRejected` — using a mock UIView, verify `canPerformAction(.paste:)` returns false
- `PasteBlockedTextFieldTests.testLongInsertionRejected` — insertion > 5 chars returns false from delegate method
- `EmergencyUnlockViewModelTests.testUnlockButtonDisabledBefore5Seconds`
- `EmergencyUnlockViewModelTests.testUnlockButtonDisabledBelow20Chars`
- `EmergencyUnlockViewModelTests.testEntryIsSavedLocally`
- `EmergencyUnlockViewModelTests.testEntryIsNeverWrittenToCloudKit` — verify CloudKit save is never called with emergency reason data

### Manual Tests
- Tap "I can't go outside" on shield → Emergency screen appears
- Try to paste from clipboard → nothing pastes
- Try to use dictation → unavailable
- Type 19 chars → Unlock button stays disabled
- Type 20+ chars + wait 5s → Unlock button enables
- Tap Unlock → apps unlock, Nimbus becomes rainy, streak resets
- Open weekly insight screen → reasons displayed

### Regression Tests
- Successful verification still unlocks apps and updates mascot to happy (Phases 10, 11).
- Streak increments correctly on verification day after emergency unlock day (Phase 12).
- Shield still applies at threshold (Phase 5).

---

## Phase 14 — StoreKit 2 Subscriptions & Paywall

### Code Development
- Configure all 4 products in App Store Connect:
  - `com.sky.pro.monthly` — Auto-renewable subscription, $4.99/month
  - `com.sky.pro.annual` — Auto-renewable subscription, $29.99/year, 7-day free trial
  - `com.sky.pro.lifetime` — Non-consumable IAP, $79
  - `com.sky.pro.founder` — Non-consumable IAP, $39, limited availability (manually enable until cap)
- Enroll in App Store Small Business Program (15% commission from day one)
- Implement `StoreKitService.swift`:
  - `loadProducts()` — fetches the 4 products
  - `purchase(_:)` — initiates a purchase
  - `refreshEntitlement()` — checks `Transaction.currentEntitlements` for any active Pro entitlement
  - `listenForTransactions()` — long-running task started at app launch
- Build `PaywallView`:
  - Annual highlighted as default (largest, centered, "Best Value")
  - Monthly to the left, Lifetime to the right
  - Founder's lifetime appears below as a separate card with a "Limited — 500 seats" badge IF still available
  - Three feature comparison rows: free vs Pro
  - Restore purchases button
- Gate Pro features (per-app limits, all badges, all mascot states, weekly insights) via `if storeKit.isPro`
- Show paywall after the first successful verification (one-shot "Sky Pro" upsell)

### Automated Tests
- `StoreKitServiceTests.testLoadProductsFetchesAll4` — using a test product list
- `StoreKitServiceTests.testPurchaseFlowSucceeds` — using StoreKit's Xcode test framework
- `StoreKitServiceTests.testRefreshEntitlementDetectsActiveLifetime`
- `StoreKitServiceTests.testRefreshEntitlementDetectsActiveSubscription`
- `PaywallViewModelTests.testFreeUserSeesAllTiers`
- `PaywallViewModelTests.testProUserSeesNoPaywall`
- `GatingTests.testPerAppLimitsBlockedForFreeUsers`

### Manual Tests
- In Xcode, create a StoreKit configuration file with all 4 products
- Test purchase of each tier in the sandbox environment
- Test the 7-day free trial flow → cancel before trial ends → entitlement revoked
- Test restoring purchases on a fresh install
- Verify the paywall does NOT appear for Pro users
- Verify the founder tier shows the "Limited" badge

### Regression Tests
- Verification flow still works for free users (limited to 2 apps and combined mode) — Phases 10–13.
- Emergency unlock still works for free users (Phase 13).
- Streak and badge logic still works for free users (Phase 12).
- CloudKit sync still works (Phase 12).

---

## Phase 15 — Settings, Notifications, App Store Readiness

### Code Development
- Build `SettingsView` with sections:
  - **Apps & Limits:** Re-open app picker, re-open limit configuration
  - **Pause Sky:** Pause for 24 hours (Pro only, max once per week, requires typed confirmation similar to emergency unlock)
  - **Notifications:** Toggles for morning reminder, 30-min warning, streak warning
  - **Night Mode:** Toggle to allow verification between sunset and sunrise (separate from the existing daylight check)
  - **Account:** Sign in with Apple status, iCloud sync status indicator
  - **Subscription:** Current tier, deep link to manage in App Store
  - **About:** Version, privacy policy, terms, support email
- Implement `LocalNotificationScheduler.swift`:
  - Morning reminder at 8:30 AM local
  - 30-minute pre-block warning (computed dynamically based on user's projected usage)
  - Streak warning at 10 PM if user hasn't verified and streak is at risk
  - Block-start notification (always on)
- Prepare App Store assets:
  - 6 screenshots (one per key flow: onboarding, app picker, mascot, verification, success, paywall)
  - App icon (1024x1024 source + all required sizes)
  - App Store description, keywords (ASO: "screen time", "block apps", "touch grass", "digital detox", "focus", "go outside")
  - Privacy Nutrition Label declarations
  - App Review notes explaining the use of Family Controls

### Automated Tests
- `SettingsViewModelTests.testPauseBlockedAfterRecentUse`
- `SettingsViewModelTests.testNightModeToggle`
- `LocalNotificationSchedulerTests.testMorningReminderScheduled`
- `LocalNotificationSchedulerTests.testStreakWarningOnlyForProUsers`
- `LocalNotificationSchedulerTests.testNoRemotePushRequested`

### Manual Tests
- Toggle each notification — verify notification arrives at the scheduled time (use Xcode's "Schedule Notification" debug feature for fast testing)
- Pause Sky — verify shields are removed for 24 hours
- Try to pause twice in a week as a Pro user — second attempt blocked with explanation
- Enable Night Mode → verify a 10 PM verification passes the daylight check
- Take all 6 screenshots on iPhone 14 Pro Max in light mode AND dark mode
- Submit a TestFlight build → install on a clean device → run end-to-end flow

### Regression Tests
- All previous flows complete successfully end-to-end with the new settings in place (Phases 0–14).
- Pausing and unpausing does not corrupt any state (Phases 5, 11, 12).
- Notifications do not request remote push permission (privacy commitment, Section 14 of spec).
- Family Controls entitlement still works on a fresh TestFlight install.

---

## Final Pre-Submission Checklist (not a phase — a gate)

Before submitting to App Store Review:

- [ ] Family Controls Distribution entitlement approved for **all four bundle IDs**
- [ ] Tested on iOS 17.0, 17.6, and the latest iOS 18.x release
- [ ] Tested on iPhone SE 3, iPhone 14, iPhone 16 Pro Max
- [ ] No paid users in the StoreKit sandbox have leaked entitlements
- [ ] App Store Connect Privacy Nutrition Label matches actual data handling
- [ ] App Review notes explain that Family Controls is used for individual self-management, not parental controls
- [ ] CloudKit production schema deployed
- [ ] Founder's Lifetime SKU configured with limited availability
- [ ] Crash-free for 7 consecutive days in TestFlight with at least 20 beta testers
- [ ] No third-party SDKs in the build (verify via `otool -L` on the binary)
- [ ] Privacy policy and terms of service hosted and linked
- [ ] Support email account active and monitored

If any item is unchecked, do not submit.
