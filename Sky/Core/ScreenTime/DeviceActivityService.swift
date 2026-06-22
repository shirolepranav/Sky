// DeviceActivityService.swift
// Schedules daily app-usage monitoring and wires DeviceActivityCenter threshold
// events to the configured limits (Roadmap Phase 5; Technical Spec §7.3;
// Sky_App_Workflow.md J-02/J-06).
//
// DeviceActivityScheduling protocol wraps DeviceActivityCenter so unit tests can
// inject a mock without the Family Controls entitlement — mirrors the
// AuthorizationProviding pattern in FamilyControlsService.

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

    /// Per-app mode: deterministic name derived from the token's JSON encoding.
    /// Collisions are cryptographically implausible; no CryptoKit dependency needed.
    static func perAppLimit(for token: ApplicationToken) -> DeviceActivityEvent.Name {
        let data = (try? JSONEncoder().encode(token)) ?? Data()
        return DeviceActivityEvent.Name("perApp_\(data.base64EncodedString())")
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
    /// SharedDefaults configuration. Always stops any existing schedule first so
    /// re-arming after a limit edit is safe.
    ///
    /// Throws if `DeviceActivityCenter.startMonitoring` fails (e.g. entitlement
    /// not yet approved). Call-sites use `try?` to swallow the error gracefully
    /// while still reflecting `isMonitoring = false` in the UI.
    func startMonitoring() throws {
        center.stopMonitoring([])
        isMonitoring = false

        guard let selection = store.selection else { return }

        let schedule = Self.makeSchedule()
        let events = Self.makeEvents(
            limitMode: store.limitMode,
            combinedLimitSeconds: store.combinedLimitSeconds,
            selection: selection,
            perAppLimitsData: store.perAppLimitsData
        )

        try center.startMonitoring(.daily, during: schedule, events: events)
        isMonitoring = true
    }

    func stopMonitoring() {
        center.stopMonitoring([])
        isMonitoring = false
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
        // Default: combined
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(second: combinedLimitSeconds)
        )
        return [.dailyLimitReached: event]
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
            let event = DeviceActivityEvent(
                applications: [entry.token],
                threshold: DateComponents(second: entry.minutes * 60)
            )
            events[.perAppLimit(for: entry.token)] = event
        }
        return events
    }
}
