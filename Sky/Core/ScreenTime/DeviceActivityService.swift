// DeviceActivityService.swift
// Registers the two daily DeviceActivity schedules behind the morning lock
// (DAILY_LOCK_PLAN.md Phase B; Technical Spec §7.3; Sky_App_Workflow.md J-02/J-06).
//
//   • `.daily` — 00:00–23:59. Its `intervalDidStart` is the midnight rollover
//     (streak hand-off, per-day flags). It never touches the shield.
//   • `.lock`  — lock time–23:59. Its `intervalDidStart` shields the selection
//     unless the user already went outside today.
//
// ⚠️ No usage events. Sky used to count usage with `DeviceActivityEvent`
// thresholds (`includesPastActivity`, a ladder of rungs per day), and those fired
// at arbitrary times — "30 minutes left" on days the apps were never opened.
// Scheduled interval starts are the reliable part of the API; keep it that way.
//
// DeviceActivityScheduling wraps DeviceActivityCenter so unit tests can inject a
// mock without the Family Controls entitlement.

import CryptoKit
import DeviceActivity
import FamilyControls
import Foundation

// MARK: - Testability protocol

// Signatures mirror DeviceActivityCenter exactly so the real type conforms with
// an empty extension. `stopMonitoring` takes the activities array (the concrete
// API's defaulted parameter does not witness a zero-arg requirement); pass `[]`
// to stop everything.
protocol DeviceActivityScheduling {
    /// Activities currently registered with the system. Survives app launches, so
    /// this — not an in-memory flag — is what the re-arm guard consults.
    var activities: [DeviceActivityName] { get }

    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

extension DeviceActivityCenter: DeviceActivityScheduling {}

// MARK: - Stable name constants

extension DeviceActivityName {
    /// Midnight-to-midnight: the daily rollover. ⚠️ Mirrored in SkyDeviceActivityMonitor.
    static let daily = DeviceActivityName("daily")
    /// Lock time-to-midnight: applies the shield. ⚠️ Mirrored in SkyDeviceActivityMonitor.
    static let lock = DeviceActivityName("lock")
}

// MARK: - Service

@MainActor
final class DeviceActivityService: ObservableObject {

    /// `true` while both schedules are registered.
    @Published private(set) var isMonitoring = false

    private let center: DeviceActivityScheduling
    private let store: SharedDefaults

    init(
        center: DeviceActivityScheduling = DeviceActivityCenter(),
        store: SharedDefaults = SharedDefaults()
    ) {
        self.center = center
        self.store = store
    }

    // MARK: Public API

    /// Registers `.daily` and `.lock` from the current SharedDefaults configuration.
    ///
    /// Idempotent: when both are registered with an identical configuration this
    /// returns without touching DeviceActivityCenter. Pass `force: true` to
    /// re-register unconditionally (debug menu).
    ///
    /// Throws if `DeviceActivityCenter.startMonitoring` fails (e.g. entitlement
    /// not yet approved). Call-sites use `try?`.
    func startMonitoring(force: Bool = false, now: Date = Date()) throws {
        guard store.selection != nil else {
            stopMonitoring()
            return
        }

        let fingerprint = Self.configFingerprint(
            selectionData: store.familyActivitySelection,
            lockTimeMinutes: store.lockTimeMinutes
        )

        if !force,
           center.activities.contains(.daily),
           center.activities.contains(.lock),
           store.monitoringConfigFingerprint == fingerprint {
            isMonitoring = true
            return
        }

        center.stopMonitoring([])
        isMonitoring = false
        // Cleared before the attempt so a throw can't leave a fingerprint claiming
        // this configuration is armed when it isn't.
        store.monitoringConfigFingerprint = nil
        // First arming after setup past today's lock time: waive today's lock.
        // Later re-arms (a lock-time change) get no such pass, or moving the lock
        // to an hour already gone would be a free way to dodge the day.
        if store.lockArmedAt == nil,
           now >= LockPolicy.lockInstant(on: now, lockTimeMinutes: store.lockTimeMinutes) {
            store.lockSkipDay = MidnightResetRecovery.dayStamp(for: now)
        }
        // Stamped *before* registering: iOS may call intervalDidStart re-entrantly
        // during startMonitoring, and the extension must already see the stamp.
        store.lockArmedAt = now

        try center.startMonitoring(.daily, during: Self.makeDailySchedule(), events: [:])
        try center.startMonitoring(
            .lock,
            during: Self.makeLockSchedule(lockTimeMinutes: store.lockTimeMinutes),
            events: [:]
        )
        isMonitoring = true
        store.monitoringConfigFingerprint = fingerprint
    }

    func stopMonitoring() {
        center.stopMonitoring([])
        isMonitoring = false
        store.monitoringConfigFingerprint = nil
    }

    // MARK: Pure helpers (internal for unit tests)

    /// Midnight-to-midnight repeating schedule — the daily rollover.
    static func makeDailySchedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }

    /// Lock time-to-midnight repeating schedule.
    ///
    /// DeviceActivity rejects intervals under 15 minutes, which is why
    /// `latestLockTimeMinutes` caps the picker well before 23:44.
    static func makeLockSchedule(lockTimeMinutes: Int) -> DeviceActivitySchedule {
        let minutes = min(max(lockTimeMinutes, 0), latestLockTimeMinutes)
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: minutes / 60, minute: minutes % 60),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }

    /// Latest lock time the picker offers (11 PM).
    static let latestLockTimeMinutes = 23 * 60

    /// A stable digest of everything that affects the registered schedules.
    ///
    /// SHA-256 rather than `hashValue`, which is seeded per process and would
    /// change every launch, defeating the guard.
    ///
    /// `osMajorVersion` is mixed in so an OS upgrade always forces one fresh
    /// registration — see `SharedDefaults.selectionNeedsRedo`.
    static func configFingerprint(
        selectionData: Data?,
        lockTimeMinutes: Int,
        osMajorVersion: Int = SharedDefaults.currentOSMajorVersion
    ) -> String {
        // "v3" = the daily lock. Bumped whenever the *shape* of the registration
        // changes, so every installed device re-registers once after the update.
        var hasher = SHA256()
        hasher.update(data: Data("v3|os\(osMajorVersion)|lock\(lockTimeMinutes)|".utf8))
        hasher.update(data: selectionData ?? Data())
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
