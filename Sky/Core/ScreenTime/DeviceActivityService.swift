// DeviceActivityService.swift
// Schedules daily app-usage monitoring and wires DeviceActivityCenter threshold
// events to the configured limits (Roadmap Phase 5; Technical Spec §7.3;
// Sky_App_Workflow.md J-02/J-06).
//
// ⚠️ Session ladder. A verification grants one more *session* of usage, not the
// rest of the day, so the apps have to be able to lock more than once between
// midnights. iOS will not do that from a single event: a DeviceActivityEvent
// threshold fires at most once per schedule interval, and Sky registers one
// interval per day. The way through is to pre-register a ladder — rungs at 1×,
// 2×, 3×… the session length — so the next block's event is already armed and
// counting while the user is unlocked. `ladderDepth` sizes it; the monitor
// extension tracks which rungs it has acted on.
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
    /// Combined-mode: rung `n` of the session ladder, at `n × sessionLimitSeconds`
    /// of cumulative usage. Rung 1 is the first block of the day.
    static func sessionLimit(rung: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("sessionLimit_\(rung)")
    }

    /// Combined-mode: fires 30 minutes before the matching `sessionLimit` rung.
    static func sessionWarning(rung: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("sessionWarn_\(rung)")
    }

    /// Per-app mode: rung `n` for one app. The token's JSON encoding is base64'd
    /// into the name — collisions are cryptographically implausible.
    ///
    /// The rung suffix is separated by `_`, which is safe to split on because it is
    /// not in the base64 alphabet (`A–Z a–z 0–9 + / =`).
    static func perAppLimit(for token: ApplicationToken, rung: Int) -> DeviceActivityEvent.Name {
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return DeviceActivityEvent.Name("perApp_\(data.base64EncodedString())_\(rung)")
    }

    /// Per-app mode: the 30-minutes-before warning counterpart for a rung.
    static func perAppWarning(for token: ApplicationToken, rung: Int) -> DeviceActivityEvent.Name {
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return DeviceActivityEvent.Name("perAppWarn_\(data.base64EncodedString())_\(rung)")
    }

    /// Inverse of `perAppLimit(for:rung:)` — recovers which app exhausted its budget
    /// so only that app is shielded. Returns nil for every other event, including
    /// `perAppWarning` names (a warning must never shield) and the combined-mode
    /// names, which is what the caller uses to pick the combined branch.
    ///
    /// ⚠️ `SkyDeviceActivityMonitor` mirrors this parsing — it cannot import the
    /// Sky module. Update both if the name format changes.
    static func applicationToken(fromPerAppLimit name: DeviceActivityEvent.Name) -> ApplicationToken? {
        // "perAppWarn_" does not carry the "perApp_" prefix (index 6 is 'W', not
        // '_'), so warnings can't be mistaken for limits here — but the tests pin
        // that, because the consequence would be shielding 30 minutes early.
        guard name.rawValue.hasPrefix("perApp_") else { return nil }
        let body = name.rawValue.dropFirst("perApp_".count)
        // Split off the rung suffix at the *last* underscore; base64 has none. A
        // body with no underscore is a pre-ladder name that is already just the
        // token — still parse it, so a stale registration resolves to the right app
        // instead of falling through to the combined branch and shielding everything.
        let encoded = body.lastIndex(of: "_").map { String(body[body.startIndex..<$0]) }
            ?? String(body)
        guard let data = Data(base64Encoded: encoded),
              let token = try? JSONDecoder().decode(ApplicationToken.self, from: data)
        else { return nil }
        return token
    }

    /// The ladder rung an event belongs to, or nil when the name carries none.
    ///
    /// This is what makes a replayed threshold harmless: the monitor records the
    /// highest rung it has acted on and ignores anything at or below it.
    static func rung(from name: DeviceActivityEvent.Name) -> Int? {
        guard let separator = name.rawValue.lastIndex(of: "_") else { return nil }
        return Int(name.rawValue[name.rawValue.index(after: separator)...])
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
    /// - Combined mode: a ladder of rungs at 1×, 2×, 3×… the session length, each
    ///   with a paired 30-minute warning.
    /// - Per-app mode: the same ladder per app, at a shallower depth.
    ///   Empty `perAppLimitsData` produces an empty dictionary (no events).
    static func makeEvents(
        limitMode: String,
        combinedLimitSeconds: Int,
        selection: FamilyActivitySelection,
        perAppLimitsData: Data?
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        if limitMode == "perApp" {
            return makePerAppEvents(from: perAppLimitsData, selection: selection)
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for rung in 1...ladderDepth(sessionSeconds: combinedLimitSeconds) {
            let limitSeconds = combinedLimitSeconds * rung
            events[.sessionLimit(rung: rung)] = makeEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(second: limitSeconds)
            )
            if let warnSeconds = ladderWarningSeconds(sessionSeconds: combinedLimitSeconds, rung: rung) {
                events[.sessionWarning(rung: rung)] = makeEvent(
                    applications: selection.applicationTokens,
                    categories: selection.categoryTokens,
                    threshold: DateComponents(second: warnSeconds)
                )
            }
        }
        return events
    }

    // MARK: The session ladder

    /// How much cumulative usage the ladder should reach before it runs out.
    /// Past this the user simply stays unlocked for the rest of the day — a
    /// deliberate ceiling, not an oversight.
    static let ladderHorizonSeconds = 12 * 60 * 60

    /// Hard ceiling on rungs per app. DeviceActivity has no documented cap on
    /// events per activity, but it is not unbounded in practice, and every rung
    /// costs two events (limit + warning).
    static let maxLadderDepth = 8

    /// Number of rungs for a given session length.
    ///
    /// A `DeviceActivityEvent` threshold fires **at most once per schedule
    /// interval**, and Sky registers one interval per day. A single
    /// "limit reached" event therefore cannot re-fire after the user verifies and
    /// unlocks — which is why a verification used to buy the whole rest of the day.
    /// Pre-registering a ladder at 1×, 2×, 3×… the session length gives each
    /// subsequent block its own event, so the next one is already armed and waiting
    /// when the user unlocks.
    ///
    /// Deeper ladders for shorter sessions, so the horizon stays roughly constant:
    /// a 1h session gets 8 rungs (8h, depth-capped), 2h gets 6, 3h gets 4.
    static func ladderDepth(sessionSeconds: Int) -> Int {
        guard sessionSeconds > 0 else { return 1 }
        let needed = Int((Double(ladderHorizonSeconds) / Double(sessionSeconds)).rounded(.up))
        return min(max(needed, 1), maxLadderDepth)
    }

    /// Ladder depth in per-app mode, where every app carries its own ladder.
    ///
    /// The event count is `2 × apps × depth`, so depth has to give way as the app
    /// count grows. At many apps this degrades to one rung each — the pre-ladder
    /// behaviour of a single block per app per day — which is the right thing to
    /// lose first: per-app mode is already the more forgiving of the two.
    static func perAppLadderDepth(sessionSeconds: Int, appCount: Int) -> Int {
        guard appCount > 0 else { return 0 }
        let budgeted = maxEventsPerActivity / (2 * appCount)
        return min(max(budgeted, 1), ladderDepth(sessionSeconds: sessionSeconds))
    }

    /// Event budget the ladder sizes itself against.
    static let maxEventsPerActivity = 20

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
        perAppLimitsData: Data?,
        osMajorVersion: Int = SharedDefaults.currentOSMajorVersion
    ) -> String {
        // The version prefix is bumped whenever the *shape* of the registered
        // events changes, not just their values. "v2" = the session ladder; it
        // forces every installed device to re-register once on the first
        // foreground after the update, replacing the old single-event schedule.
        //
        // `osMajorVersion` is mixed in so an OS upgrade always forces one fresh
        // registration. Every other input here is data *we* wrote, so none of them
        // move when iOS silently reissues ApplicationTokens — without this the
        // no-op guard below would pin a dead configuration forever, and monitoring
        // would never re-arm. See `SharedDefaults.selectionNeedsRedo`.
        var hasher = SHA256()
        hasher.update(data: Data("v2|os\(osMajorVersion)|\(selectionData?.count ?? -1)|".utf8))
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

    /// The warning threshold for rung `n` of a ladder, or nil when there is no
    /// sensible place to put one.
    ///
    /// A warning belongs *inside* its own rung, after the previous rung's limit:
    /// `n·S − 30m > (n−1)·S`, which reduces to `S > 30m` regardless of `n`. With a
    /// 15-minute session (the per-app floor) rung 3's naive warning would land at
    /// 45 minutes — exactly rung 1's limit — and fire "30 minutes left" at the
    /// moment the apps actually shut. Sessions of 30 minutes or less simply get no
    /// warnings.
    static func ladderWarningSeconds(sessionSeconds: Int, rung: Int) -> Int? {
        guard sessionSeconds > 30 * 60 else { return nil }
        return warningThresholdSeconds(for: sessionSeconds * rung)
    }

    // MARK: Private helpers

    /// Per-app events, restricted to apps that are *still selected*.
    ///
    /// `perAppLimitsData` is not pruned when the user edits their app selection, so
    /// it accumulates entries for apps Sky no longer manages. Registering events
    /// from those entries means an app the user removed still burns a budget, still
    /// posts "Time's up", and — because `eventDidReachThreshold` shields whichever
    /// token the event name carries — still gets shielded. Intersecting here is the
    /// single place that can be fixed without a migration.
    private static func makePerAppEvents(
        from data: Data?,
        selection: FamilyActivitySelection
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        guard let data,
              let entries = try? JSONDecoder().decode(
                  [LimitConfigurationViewModel.TokenLimitEntry].self, from: data)
        else { return [:] }

        let live = entries.filter { selection.applicationTokens.contains($0.token) }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for entry in live {
            let sessionSeconds = entry.minutes * 60
            let depth = perAppLadderDepth(sessionSeconds: sessionSeconds, appCount: live.count)
            guard depth > 0 else { continue }

            for rung in 1...depth {
                let limitSeconds = sessionSeconds * rung
                events[.perAppLimit(for: entry.token, rung: rung)] = makeEvent(
                    applications: [entry.token],
                    threshold: DateComponents(second: limitSeconds)
                )
                if let warnSeconds = ladderWarningSeconds(sessionSeconds: sessionSeconds, rung: rung) {
                    events[.perAppWarning(for: entry.token, rung: rung)] = makeEvent(
                        applications: [entry.token],
                        threshold: DateComponents(second: warnSeconds)
                    )
                }
            }
        }
        return events
    }
}
