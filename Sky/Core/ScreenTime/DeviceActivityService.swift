// DeviceActivityService.swift
// Schedules daily app-usage monitoring and wires DeviceActivityCenter threshold
// events to the configured limits (Roadmap Phase 5; Technical Spec §7.3;
// Sky_App_Workflow.md J-02/J-06).
//
// DeviceActivityScheduling protocol wraps DeviceActivityCenter so unit tests can
// inject a mock without the Family Controls entitlement — mirrors the
// AuthorizationProviding pattern in FamilyControlsService.
//
// ⚠️ Budget-reset invariant (see TIME_REMAINING_PLAN.md §2). A DeviceActivityEvent
// counts usage from the moment monitoring starts, *not* from the interval start,
// unless `includesPastActivity: true` is set. Sky re-arms on every foreground
// (SkyApp.swift), so without both defences below a user who opens Sky regularly
// would keep receiving a fresh full budget and would never be blocked:
//   1. `makeEvent` sets `includesPastActivity: true` (iOS 17.4+), so a re-arm
//      resumes counting from midnight instead of from zero.
//   2. `startMonitoring` no-ops when the configuration fingerprint is unchanged
//      and `.daily` is already registered, so the common foreground path never
//      touches the center at all. This is the only mitigation on iOS 17.0–17.3.

import CryptoKit
import DeviceActivity
import FamilyControls
import ManagedSettings
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
    /// The single daily activity Sky registers each launch.
    static let daily = DeviceActivityName("daily")
}

extension DeviceActivityEvent.Name {
    /// Combined-mode: one event that covers all selected apps.
    static let dailyLimitReached = DeviceActivityEvent.Name("dailyLimitReached")

    /// Combined-mode: fires 30 minutes before the limit (Phase 15 warning).
    static let dailyWarning = DeviceActivityEvent.Name("dailyWarning")

    /// Per-app mode: deterministic name derived from the token's JSON encoding.
    /// Collisions are cryptographically implausible; no CryptoKit dependency needed.
    static func perAppLimit(for token: ApplicationToken) -> DeviceActivityEvent.Name {
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return DeviceActivityEvent.Name("perApp_\(data.base64EncodedString())")
    }

    /// Per-app mode: the 30-minutes-before warning counterpart (Phase 15).
    static func perAppWarning(for token: ApplicationToken) -> DeviceActivityEvent.Name {
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return DeviceActivityEvent.Name("perAppWarn_\(data.base64EncodedString())")
    }
}

// MARK: - Service

@MainActor
final class DeviceActivityService: ObservableObject {

    /// `true` while a DeviceActivityCenter schedule is active.
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

    /// Build and register the daily monitoring schedule from the current
    /// SharedDefaults configuration.
    ///
    /// Idempotent: when `.daily` is already registered with an identical
    /// configuration this returns without touching DeviceActivityCenter, which is
    /// what keeps the every-foreground call in SkyApp from resetting the day's
    /// accumulated usage (see the header note). Pass `force: true` to re-register
    /// unconditionally — used by the debug menu and after a configuration repair.
    ///
    /// Throws if `DeviceActivityCenter.startMonitoring` fails (e.g. entitlement
    /// not yet approved). Call-sites use `try?` to swallow the error gracefully
    /// while still reflecting `isMonitoring = false` in the UI.
    func startMonitoring(force: Bool = false) throws {
        guard let selection = store.selection else {
            center.stopMonitoring([])
            isMonitoring = false
            store.monitoringConfigFingerprint = nil
            return
        }

        let fingerprint = Self.configFingerprint(
            selectionData: store.familyActivitySelection,
            limitMode: store.limitMode,
            combinedLimitSeconds: store.combinedLimitSeconds,
            perAppLimitsData: store.perAppLimitsData
        )

        // Nothing changed and the system still has our activity — leave it alone.
        if !force,
           center.activities.contains(.daily),
           store.monitoringConfigFingerprint == fingerprint {
            isMonitoring = true
            return
        }

        center.stopMonitoring([])
        isMonitoring = false
        // Cleared before the attempt so a throw can't leave a fingerprint claiming
        // this configuration is armed when it isn't.
        store.monitoringConfigFingerprint = nil

        let schedule = Self.makeSchedule()
        let events = Self.makeEvents(
            limitMode: store.limitMode,
            combinedLimitSeconds: store.combinedLimitSeconds,
            selection: selection,
            perAppLimitsData: store.perAppLimitsData
        )

        try center.startMonitoring(.daily, during: schedule, events: events)
        isMonitoring = true
        store.monitoringConfigFingerprint = fingerprint
    }

    func stopMonitoring() {
        center.stopMonitoring([])
        isMonitoring = false
        store.monitoringConfigFingerprint = nil
    }

    // MARK: Pure helpers (internal for unit tests)

    /// Midnight-to-midnight repeating schedule (Technical Spec §7.3).
    static func makeSchedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }

    /// Build the events dictionary from current configuration.
    ///
    /// - Combined mode: one event covering all selected apps.
    /// - Per-app mode: one event per token with its individual limit.
    ///   Empty `perAppLimitsData` produces an empty dictionary (no events).
    static func makeEvents(
        limitMode: String,
        combinedLimitSeconds: Int,
        selection: FamilyActivitySelection,
        perAppLimitsData: Data?
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        if limitMode == "perApp" {
            return makePerAppEvents(from: perAppLimitsData)
        }
        // Default: combined — a limit event plus a paired 30-min warning event.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .dailyLimitReached: makeEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(second: combinedLimitSeconds)
            )
        ]
        if let warnSeconds = warningThresholdSeconds(for: combinedLimitSeconds) {
            events[.dailyWarning] = makeEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(second: warnSeconds)
            )
        }
        return events
    }

    /// Every event Sky registers goes through here so the `includesPastActivity`
    /// invariant can never be forgotten at a call site.
    ///
    /// `includesPastActivity: true` makes the threshold count usage accumulated
    /// since the schedule's interval began (midnight) rather than since this call,
    /// so re-arming mid-day resumes the day's budget instead of restarting it. The
    /// parameter is iOS 17.4+; on 17.0–17.3 the re-arm guard in `startMonitoring`
    /// is the only defence, which is why that guard is not merely an optimisation.
    static func makeEvent(
        applications: Set<ApplicationToken> = [],
        categories: Set<ActivityCategoryToken> = [],
        threshold: DateComponents
    ) -> DeviceActivityEvent {
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(
                applications: applications,
                categories: categories,
                threshold: threshold,
                includesPastActivity: true
            )
        }
        return DeviceActivityEvent(
            applications: applications,
            categories: categories,
            threshold: threshold
        )
    }

    /// A stable digest of everything that affects the registered schedule/events.
    ///
    /// Hashes the *stored* `Data` blobs rather than re-encoding, so identical
    /// configuration always yields an identical digest. Swift's `hashValue` is
    /// seeded per process and would change on every launch, defeating the guard —
    /// hence SHA-256. Byte counts are interleaved so two different field splits
    /// can't produce the same input stream.
    static func configFingerprint(
        selectionData: Data?,
        limitMode: String,
        combinedLimitSeconds: Int,
        perAppLimitsData: Data?
    ) -> String {
        var hasher = SHA256()
        hasher.update(data: Data("v1|\(selectionData?.count ?? -1)|".utf8))
        hasher.update(data: selectionData ?? Data())
        hasher.update(data: Data("|\(limitMode)|\(combinedLimitSeconds)|\(perAppLimitsData?.count ?? -1)|".utf8))
        hasher.update(data: perAppLimitsData ?? Data())
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// The 30-minutes-before threshold for a limit, or nil when the limit is
    /// 30 minutes or less (no room for a distinct earlier warning).
    static func warningThresholdSeconds(for limitSeconds: Int) -> Int? {
        let warn = limitSeconds - 30 * 60
        return warn > 0 ? warn : nil
    }

    // MARK: Private helpers

    private static func makePerAppEvents(
        from data: Data?
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        guard let data,
              let entries = try? JSONDecoder().decode(
                  [LimitConfigurationViewModel.TokenLimitEntry].self, from: data)
        else { return [:] }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for entry in entries {
            let limitSeconds = entry.minutes * 60
            events[.perAppLimit(for: entry.token)] = makeEvent(
                applications: [entry.token],
                threshold: DateComponents(second: limitSeconds)
            )
            if let warnSeconds = warningThresholdSeconds(for: limitSeconds) {
                events[.perAppWarning(for: entry.token)] = makeEvent(
                    applications: [entry.token],
                    threshold: DateComponents(second: warnSeconds)
                )
            }
        }
        return events
    }
}
