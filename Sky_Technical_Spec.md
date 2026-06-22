# Sky — Technical Specification

This document describes Sky's iOS-only implementation: architecture, frameworks, data model, key APIs, extension targets, and privacy implementation. It assumes the reader is familiar with SwiftUI, modern Swift concurrency, and Apple's screen-time APIs.

---

## 1. Platform & Minimum Requirements

- **Platform:** iOS only
- **Minimum iOS:** 17.0 (covers ~90% of active iPhones)
- **Architecture:** Universal (iPhone-first; iPad supported but not optimized)
- **Language:** Swift 5.10+
- **UI framework:** SwiftUI (UIKit interop only where unavoidable — paste-blocking text field and shield extensions)
- **IDE:** Xcode 16.0+
- **Build system:** Native Xcode project (no SwiftPM workspace, no CocoaPods, no Carthage)

---

## 2. Apple Frameworks Used

| Framework | Purpose |
|---|---|
| **SwiftUI** | All UI (with two UIKit-bridged components) |
| **FamilyControls** | User authorization (`AuthorizationCenter`) and app picker (`FamilyActivityPicker`) |
| **ManagedSettings** | Applying shields to user-selected apps (`ManagedSettingsStore.shield.applications`) |
| **DeviceActivity** | Monitoring time spent and triggering threshold events (`DeviceActivityCenter`, `DeviceActivitySchedule`, `DeviceActivityEvent`) |
| **AVFoundation** | 30-second video recording (`AVCaptureSession`) |
| **Vision** | Scene classification (`VNClassifyImageRequest`), sky segmentation (`VNGenerateForegroundInstanceMaskRequest` adapted, plus color analysis fallback) |
| **CoreLocation** | GPS for outdoor signal (`CLLocationManager`, accuracy and `sourceInformation.isProducedByAccessory`) |
| **CoreMotion** | Barometric pressure delta (`CMAltimeter.startRelativeAltitudeUpdates`) |
| **CloudKit** | Cross-device sync of user progress (private database) |
| **StoreKit 2** | In-app purchases and subscriptions (`Product`, `Transaction`) |
| **UserNotifications** | Local-only morning/streak notifications |
| **AuthenticationServices** | Sign in with Apple (required for CloudKit user identity) |

**Explicitly NOT used in v1.0:** RevenueCat, Firebase, Supabase, OneSignal, Mixpanel, PostHog, Sentry, any third-party SDK that sends data off-device.

---

## 3. Apple Entitlements & Capabilities Required

Apply for these in Phase 0; do not wait. Approval can take 3–6 weeks per Apple Developer Forum threads.

| Entitlement | Bundle ID applies to | Apply via |
|---|---|---|
| `com.apple.developer.family-controls` | Main app + each extension | developer.apple.com/contact/request/family-controls-distribution |
| iCloud (CloudKit container) | Main app | Xcode → Signing & Capabilities |
| Sign in with Apple | Main app | Xcode → Signing & Capabilities |
| App Groups (`group.com.shirolepranav.sky`) | Main app + DeviceActivityMonitor + ShieldConfiguration + ShieldAction | Xcode → Signing & Capabilities |

A single Family Controls request for the main app is not enough — each extension target needs its own entitlement request submitted separately. Plan for this.

---

## 4. Target Architecture

Sky ships as one app target and **three extension targets**:

```
SkyApp (main iOS app)
├── DeviceActivityMonitorExtension (background — receives threshold callbacks)
├── ShieldConfigurationExtension (UI — renders the shield when user taps a blocked app)
└── ShieldActionExtension (UI — handles "Verify outdoor" and "Emergency unlock" buttons)
```

All four targets share data through the App Group `group.com.shirolepranav.sky`:
- `UserDefaults(suiteName: "group.com.shirolepranav.sky")` for state flags and counters
- Shared App Group file container for the verification result hand-off

---

## 5. Module / Folder Structure

```
Sky/
├── App/
│   ├── SkyApp.swift                  // @main entry point
│   ├── AppBranding.swift             // ALL swappable name/mascot/color constants
│   └── AppCoordinator.swift          // Top-level routing state
│
├── Features/
│   ├── Onboarding/                   // Welcome, value prop, permission intros
│   ├── AppSelection/                 // FamilyActivityPicker wrapper
│   ├── LimitConfiguration/           // Combined vs. per-app limit UI
│   ├── Verification/
│   │   ├── VideoRecording/           // AVCaptureSession + prompts UI
│   │   ├── SensorFusion/             // GPS + barometer + light + spoof checks
│   │   ├── VisionAnalysis/           // Frame-by-frame scene classification
│   │   └── DecisionEngine/           // Combines signals → pass/fail
│   ├── Mascot/
│   │   └── NimbusView.swift          // Single replaceable mascot component
│   ├── Streaks/                      // Streak + badge logic
│   ├── EmergencyUnlock/              // Typed-reason path
│   ├── Paywall/                      // StoreKit 2 + paywall UI
│   └── Settings/
│
├── Core/
│   ├── ScreenTime/
│   │   ├── FamilyControlsService.swift     // Authorization
│   │   ├── DeviceActivityService.swift     // Scheduling
│   │   └── ShieldService.swift             // ManagedSettingsStore actions
│   ├── Storage/
│   │   ├── SharedDefaults.swift            // App Group UserDefaults
│   │   ├── CloudKitSyncService.swift       // Private database sync
│   │   └── EmergencyLogStore.swift         // On-device only
│   ├── Subscription/
│   │   └── StoreKitService.swift           // Transaction listener + entitlement
│   ├── Notifications/
│   │   └── LocalNotificationScheduler.swift
│   └── DesignSystem/
│       ├── Buttons.swift
│       ├── Cards.swift
│       ├── Typography.swift
│       ├── ColorTokens.swift
│       └── PasteBlockedTextField.swift     // UIViewRepresentable
│
├── Extensions/
│   ├── DeviceActivityMonitor/        // Separate target
│   │   └── SkyDeviceActivityMonitor.swift
│   ├── ShieldConfiguration/          // Separate target
│   │   └── SkyShieldConfiguration.swift
│   └── ShieldAction/                 // Separate target
│       └── SkyShieldAction.swift
│
├── Tests/
│   ├── SkyTests/                     // XCTest unit tests
│   └── SkyUITests/                   // XCUITest UI tests
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings           // English only in v1.0
```

---

## 6. Data Model

### 6.1 SharedDefaults (UserDefaults in App Group)

Read by all four targets. Written primarily by the main app and DeviceActivityMonitor.

```swift
struct SharedDefaults {
    // Configuration (written by main app, read by extensions)
    @AppGroupStorage("selection") var familyActivitySelection: Data?  // Codable-archived FamilyActivitySelection
    @AppGroupStorage("limitMode") var limitMode: String = "combined"  // "combined" | "perApp"
    @AppGroupStorage("combinedLimitSeconds") var combinedLimitSeconds: Int = 7200  // default 2hr
    @AppGroupStorage("perAppLimits") var perAppLimitsData: Data?      // Codable [Token: Int]
    @AppGroupStorage("limitsEnabled") var limitsEnabled: Bool = true

    // Today state (written by extensions, read by main app)
    @AppGroupStorage("today_blocked") var isCurrentlyBlocked: Bool = false
    @AppGroupStorage("today_verified") var didVerifyToday: Bool = false
    @AppGroupStorage("today_emergency_used") var didEmergencyUnlockToday: Bool = false
    @AppGroupStorage("today_reset_token") var todayResetToken: String = ""  // YYYY-MM-DD local

    // Hand-off (written by main app post-verification, consumed by extension via re-evaluation)
    @AppGroupStorage("verification_completed_at") var verificationCompletedAt: Date?
}
```

### 6.2 CloudKit Private Database Schema

One record type: `UserProgress` (one record per user, ID = "current").

| Field | Type | Description |
|---|---|---|
| `currentStreak` | Int64 | Days in a row with a verification and no emergency unlock |
| `longestStreak` | Int64 | All-time max |
| `totalVerifications` | Int64 | Lifetime success count |
| `totalEmergencyUnlocks` | Int64 | Lifetime emergency count |
| `lastVerificationDate` | Date | Most recent successful verification |
| `unlockedBadges` | [String] | List of badge IDs |
| `mascotState` | String | "idle", "happy", "sad", "celebrating" |
| `verificationLocations` | [String] | List of "lat_lng" rounded to 0.01° (for "Wanderer" badge) |
| `firstInstallDate` | Date | Used for "Founder's Lifetime" eligibility check |

### 6.3 Emergency Unlock Log (on-device only, never synced)

Stored in a local SQLite file or simple Codable JSON in App Group container.

```swift
struct EmergencyUnlockEntry: Codable {
    let id: UUID
    let date: Date
    let typedReason: String  // Up to 200 chars
    let dayOfWeek: Int
    let hourOfDay: Int
}
```

Used to compute the weekly "Top reasons you unlocked" insight. Never leaves the device.

---

## 7. Screen Time Integration

### 7.1 Authorization Flow

```swift
import FamilyControls

let authCenter = AuthorizationCenter.shared
try await authCenter.requestAuthorization(for: .individual)
// .individual = user-controls-own-device (not parental)
```

Status is persisted by the OS — call once during onboarding, then check `authCenter.authorizationStatus` on every app launch.

### 7.2 App Selection

```swift
import FamilyControls
import SwiftUI

@State private var selection = FamilyActivitySelection()
@State private var isPickerPresented = false

FamilyActivityPicker(selection: $selection)
```

Apple's picker handles all UI — Sky never sees app names or bundle IDs, only opaque `ApplicationToken` values. Persist `selection` by encoding to `Data` (`FamilyActivitySelection` conforms to `Codable`) and writing to App Group `UserDefaults`.

### 7.3 Monitoring Setup

```swift
import DeviceActivity

let center = DeviceActivityCenter()

// Daily schedule resetting at midnight local time
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)

// Combined-mode example: single event for total budget
let event = DeviceActivityEvent(
    applications: selection.applicationTokens,
    categories: selection.categoryTokens,
    threshold: DateComponents(second: combinedLimitSeconds)
)

try center.startMonitoring(
    .daily,
    during: schedule,
    events: [.dailyLimitReached: event]
)
```

When the threshold is reached, iOS calls `SkyDeviceActivityMonitor.eventDidReachThreshold(_:activity:)` in the extension target.

### 7.4 Applying the Shield

In `SkyDeviceActivityMonitor`:

```swift
import ManagedSettings

override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    let selection = decodeSelectionFromSharedDefaults()
    let store = ManagedSettingsStore()
    store.shield.applications = selection.applicationTokens
    store.shield.applicationCategories = .specific(selection.categoryTokens)
    SharedDefaults().isCurrentlyBlocked = true
}

override func intervalDidStart(for activity: DeviceActivityName) {
    // Called at midnight local time — clear shields and reset day
    let store = ManagedSettingsStore()
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    SharedDefaults().isCurrentlyBlocked = false
    SharedDefaults().didVerifyToday = false
    SharedDefaults().didEmergencyUnlockToday = false
}
```

### 7.5 Custom Shield UI

`SkyShieldConfiguration` extension target overrides `configuration(shielding:)` and `configuration(shielding:in:)` to return a `ShieldConfiguration` with:
- Mascot image (Nimbus)
- Title: `"\(AppBranding.appName) — Time's up"`
- Subtitle: `"\(AppBranding.mascotName) is waiting outside for you ☁️"`
- Primary button: `"Go outside to unlock"` (action: deep link back to main app's verification flow)
- Secondary button: `"I can't go outside right now"` (action: deep link to emergency unlock)

`SkyShieldAction` extension target handles button taps via `handle(action:for:completionHandler:)` and opens the main app via universal link `sky://verify` or `sky://emergency`.

### 7.6 Unlocking Apps

After a successful verification (in the main app):

```swift
let store = ManagedSettingsStore()
store.shield.applications = nil
store.shield.applicationCategories = nil
SharedDefaults().isCurrentlyBlocked = false
SharedDefaults().didVerifyToday = true
```

---

## 8. Outdoor Verification Pipeline

### 8.1 Video Capture

`AVCaptureSession` with the back camera, 1080p at 30fps. Recording duration is exactly 30 seconds with on-screen prompts at:
- 0s — "Hold steady, point your camera up"
- 6s — "Now slowly look around"
- 14s — "Point at the sky for 5 seconds"
- 22s — "Last bit — show where you are"
- 30s — Recording ends, processing begins

While recording, Sky concurrently samples:
- GPS location every 2 seconds
- Barometric altitude every 1 second
- Camera exposure/ISO every 0.5 second

### 8.2 Frame Sampling

Every 5th frame of the recorded video (≈6 frames per second) is extracted via `AVAssetImageGenerator` and passed to:

```swift
let request = VNClassifyImageRequest()
let handler = VNImageRequestHandler(cgImage: frame)
try handler.perform([request])
let classifications = request.results ?? []
let outdoorScore = classifications
    .filter { ["outdoor", "sky", "tree", "grass", "park", "street", "field", "mountain", "cloud"].contains($0.identifier) }
    .map { $0.confidence }
    .max() ?? 0
```

Each frame gets an "outdoor confidence" score 0.0–1.0.

### 8.3 Sky Pixel Detection

For each sampled frame, count pixels matching sky color profile:

```swift
// Pseudocode — convert to HSV, count pixels where:
// - Hue in [200°, 230°] (blue-sky)
// - Saturation > 0.15
// - Brightness > 0.4
// OR overcast: low saturation, brightness > 0.7, hue near 220°
let skyPercent = countSkyPixels(in: frame) / totalPixels
```

Require at least one frame in the video to have `skyPercent ≥ 0.15`.

### 8.4 Sensor Aggregation

```swift
struct SensorReading {
    let gpsAccuracyAtBest: CLLocationAccuracy   // smallest accuracy value during recording
    let maxHorizontalSpeed: Double               // m/s
    let altitudeChangeMeters: Double             // |max - min| over recording window
    let medianExposureBias: Float                // proxy for ambient brightness
    let timeOfDay: Date                          // local time when recording started
    let gpsSpoofed: Bool                         // isProducedByAccessory at any sample
    let sunriseSunsetCheckPassed: Bool           // user is in daylight window unless night mode opted-in
}
```

### 8.5 Decision Engine

The verification passes if ALL of the following are true:

```swift
func verify(sensors: SensorReading, frameScores: [Double], maxSkyPercent: Double) -> Result<Verified, FailureReason> {
    if sensors.gpsSpoofed { return .failure(.gpsSpoofingDetected) }
    if !sensors.sunriseSunsetCheckPassed { return .failure(.outsideDaylightWindow) }
    if sensors.gpsAccuracyAtBest > 25 { return .failure(.poorGPSSignal) }    // probably indoors
    if sensors.maxHorizontalSpeed < 0.3 && sensors.altitudeChangeMeters < 0.5 {
        return .failure(.notEnoughMovement)
    }
    if sensors.medianExposureBias < -1.0 { return .failure(.notBrightEnough) }
    let outdoorFrameRatio = frameScores.filter { $0 > 0.5 }.count / Double(frameScores.count)
    if outdoorFrameRatio < 0.8 { return .failure(.sceneNotOutdoor) }
    if maxSkyPercent < 0.15 { return .failure(.noSkyVisible) }
    return .success(Verified())
}
```

Thresholds are tunable from a single `VerificationThresholds.swift` file. They should be re-measured in 5+ real-world environments before launch (see Roadmap Phase 10).

### 8.6 Cleanup

After verification completes (pass or fail):
- Video file is deleted from temporary directory
- All sensor data is discarded from memory
- No data is retained beyond the boolean outcome

---

## 9. Emergency Unlock — Paste-Blocked TextField

SwiftUI's native `TextField` does not support disabling paste cleanly. Implementation uses a UIViewRepresentable wrapper:

```swift
import SwiftUI
import UIKit

struct PasteBlockedTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let tf = NoPasteTextField()
        tf.placeholder = placeholder
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            // Reject any single insertion of > 5 characters (likely a paste even if menu was bypassed)
            if string.count > 5 { return false }
            // Reject any newline
            if string.contains("\n") { return false }
            return true
        }
    }

    private final class NoPasteTextField: UITextField {
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            // Block paste, copy, cut, select all, share, dictation, lookup, smart paste
            if action == #selector(UIResponderStandardEditActions.paste(_:)) { return false }
            if action == #selector(UIResponderStandardEditActions.copy(_:)) { return false }
            if action == #selector(UIResponderStandardEditActions.cut(_:)) { return false }
            if String(describing: action).contains("paste") { return false }
            return super.canPerformAction(action, withSender: sender)
        }
    }
}
```

Combined with a 5-second timer enforced by a `@State` countdown disabling the "Unlock" button, this gives meaningful friction without being unusable.

---

## 10. StoreKit 2 Integration

```swift
import StoreKit

@MainActor
final class StoreKitService: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPro: Bool = false

    private let productIDs = [
        AppBranding.monthlyProductID,
        AppBranding.annualProductID,
        AppBranding.lifetimeProductID,
        AppBranding.founderLifetimeProductID
    ]

    func loadProducts() async throws {
        products = try await Product.products(for: productIDs)
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            await refreshEntitlement()
        }
    }

    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result,
               productIDs.contains(txn.productID) {
                isPro = true
                return
            }
        }
        isPro = false
    }

    func listenForTransactions() {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let txn) = result {
                    await txn.finish()
                    await self.refreshEntitlement()
                }
            }
        }
    }
}
```

Founder's lifetime cap is enforced server-side via App Store Connect's limited availability — set the SKU to be available only until cap is hit. Sky's UI displays an *approximate* remaining-seats counter pulled from a static plist updated via App Store Connect's review-free metadata updates.

---

## 11. CloudKit Sync

`CKContainer.default()` with private database. One record per user (record ID = "current"). Sync is best-effort and non-blocking — UI reads from local cache first, syncs in background.

```swift
let db = CKContainer.default().privateCloudDatabase
let recordID = CKRecord.ID(recordName: "current")

// Save
let record = CKRecord(recordType: "UserProgress", recordID: recordID)
record["currentStreak"] = userProgress.currentStreak
// ... etc
try await db.save(record)

// Fetch
let fetched = try await db.record(for: recordID)
```

Conflict resolution: last-writer-wins for counters; union for `unlockedBadges`. CloudKit subscriptions push remote changes back to the device.

---

## 12. Local Notifications

```swift
import UserNotifications

let center = UNUserNotificationCenter.current()
try await center.requestAuthorization(options: [.alert, .sound])

// Morning reminder at 8:30 AM local
var morning = DateComponents()
morning.hour = 8
morning.minute = 30
let trigger = UNCalendarNotificationTrigger(dateMatching: morning, repeats: true)
let content = UNMutableNotificationContent()
content.title = "Good morning"
content.body = "\(AppBranding.mascotName) is ready for today's outdoor break ☁️"
let request = UNNotificationRequest(identifier: "morning", content: content, trigger: trigger)
try await center.add(request)
```

All notifications are local-only. No remote push, no APNs token registration.

---

## 13. Performance Targets

- App cold start: < 1.5s on iPhone 12 and newer
- Family Activity Picker present: < 500ms after tap
- Video recording start: < 1s after tap
- Verification processing (post-recording): < 5s on iPhone 12 and newer
- Shield UI appearance: instant (handled by iOS, but our ShieldConfiguration must render < 100ms)
- CloudKit sync: background; never blocks UI

---

## 14. Privacy Implementation Details

| Concern | Implementation |
|---|---|
| Video upload | Videos are written to `FileManager.default.temporaryDirectory`, processed locally, then `try FileManager.default.removeItem(at:)` immediately after verification result |
| GPS coordinates | Used only for accuracy check; rounded to 0.01° (≈1km) before storage; the rounded value is the only thing persisted, for the "Wanderer" badge |
| Screen Time data | Cannot leave the device per Apple's API — Sky never tries to read raw usage data; only relies on threshold callbacks |
| Emergency-unlock reasons | Stored in App Group container only; never synced to CloudKit, never sent to any server |
| Analytics | App Store Connect's first-party analytics only; no SDKs |
| Crash reporting | Xcode Organizer's crash reports only; no Crashlytics/Sentry |

App Store Privacy Nutrition Label declaration:
- Data Not Collected: Location, Photos, Contacts, Usage Data, Identifiers
- Data Linked to You: Apple ID (for Sign in with Apple and StoreKit only)

---

## 15. Build Configuration

- **Bundle ID:** `com.shirolepranav.sky` (or whatever final name) — main app
- **Bundle IDs:** `com.shirolepranav.sky.deviceactivity`, `com.shirolepranav.sky.shieldconfig`, `com.shirolepranav.sky.shieldaction` for the three extensions
- **App Group:** `group.com.shirolepranav.sky` enabled on all four targets
- **iCloud container:** `iCloud.com.shirolepranav.sky`
- **URL scheme:** `sky://` (for deep links from shield extensions)
- **Universal link domain:** Optional in v1.0; defer until launch

Build settings:
- Swift Strict Concurrency Checking: Complete
- Treat warnings as errors: Yes
- Optimization: -Onone (Debug), -O (Release)
