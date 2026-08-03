// EmergencyLogStore.swift
// On-device-only store for EmergencyUnlockEntry records.
// Sky_Technical_Spec.md §6.3; Sky_App_Workflow.md S-STREAK-04; Roadmap Phase 13.
//
// Storage: Codable JSON array in the App Group container so the file is not
// in the standard UserDefaults namespace (which extensions also read). The
// injectable fileURL init lets unit tests point at a temp directory.
//
// Privacy invariant: this store is NEVER read by CloudKitSyncService. No entry
// field maps to any CKRecord field in UserProgress. No network path touches it.

import Foundation

final class EmergencyLogStore {

    // MARK: Shared instance

    static let shared: EmergencyLogStore = {
        // App Group identifier mirrors SharedDefaults.suiteName — keep in sync.
        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.shirolepranav.sky")
            ?? FileManager.default.temporaryDirectory
        let fileURL = containerURL.appendingPathComponent("emergency_log.json")
        return EmergencyLogStore(fileURL: fileURL)
    }()

    // MARK: Storage

    private let fileURL: URL
    private var entries: [EmergencyUnlockEntry] = []

    init(fileURL: URL) {
        self.fileURL = fileURL
        entries = load()
    }

    // MARK: Write

    func add(_ entry: EmergencyUnlockEntry) {
        entries.append(entry)
        persist()
    }

    #if DEBUG
    /// Debug-menu (S-SET-09) seed hook — replace all entries with a demo set.
    func debugReplaceAll(_ newEntries: [EmergencyUnlockEntry]) {
        entries = newEntries
        persist()
    }

    /// Debug-menu (S-SET-09) reset hook — clear all entries.
    func debugClear() {
        entries = []
        persist()
    }
    #endif

    // MARK: Read

    func entriesThisWeek() -> [EmergencyUnlockEntry] {
        let cal = Calendar.current
        let now = Date()
        return entries.filter { cal.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
    }

    /// Returns up to `limit` most-frequent reasons this week, sorted by count descending.
    /// Reasons are normalized (trimmed, lowercased) before grouping so near-duplicates merge.
    func topReasonsThisWeek(limit: Int = 3) -> [(reason: String, count: Int)] {
        let week = entriesThisWeek()
        guard !week.isEmpty else { return [] }

        var counts: [String: (display: String, count: Int)] = [:]
        for entry in week {
            let key = entry.typedReason
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if counts[key] == nil {
                counts[key] = (display: entry.typedReason.trimmingCharacters(in: .whitespacesAndNewlines), count: 0)
            }
            counts[key]!.count += 1
        }

        return counts.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { (reason: $0.display, count: $0.count) }
    }

    // MARK: Persistence

    private func load() -> [EmergencyUnlockEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([EmergencyUnlockEntry].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
