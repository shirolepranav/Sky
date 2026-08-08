// ShieldAudit.swift
// A small on-device trail of every shield apply/clear, so "my apps unlocked and
// I don't know why" is answerable without a debugger attached.
//
// The shield is written from four processes (main app, DeviceActivityMonitor,
// and — indirectly — the two shield extensions) on callbacks that fire while the
// app is not running. When one of them lifts a shield unexpectedly there is no
// console to read, so this records who did it and when.
//
// PRIVACY (Technical Spec §14, CLAUDE.md invariants): entries carry a timestamp,
// an action, a source, and a *count* of shielded apps. Never app names, never
// bundle IDs, never tokens, never usage figures. Stored in the App Group
// container only — no CloudKit, no upload, no analytics.
//
// The extension target cannot import the Sky module, so it writes the same
// line format through raw UserDefaults keys — see SkyDeviceActivityMonitor.
// Both sides must keep `Self.key`, `separator`, and the field order in sync.
//
// Concurrency: read-modify-write from two processes can lose an entry if they
// race. That is acceptable for a diagnostic trail and is not worth a file lock —
// but it does mean a missing entry is weak evidence, while a present one is strong.

import Foundation

enum ShieldAudit {

    /// Mirrored in SkyDeviceActivityMonitor.Key.shieldAuditLog.
    static let key = "shield_audit_log"
    /// Mirrored in the extension. Must not appear in any field value.
    static let separator = "|"
    /// Oldest entries are dropped past this. Mirrored in the extension.
    static let capacity = 60

    enum Action: String {
        case applied
        case cleared
    }

    /// Who touched the shield. Add a case rather than reusing a near-miss —
    /// the whole value of the log is telling these apart.
    enum Source: String {
        /// DeviceActivityMonitor — a usage threshold was reached.
        case monitorThreshold = "monitor.threshold"
        /// DeviceActivityMonitor — the daily interval rolled over.
        case monitorIntervalStart = "monitor.intervalStart"
        /// A passed outdoor verification (S-VER-06).
        case verificationSuccess = "verification.success"
        /// The typed-reason emergency unlock (S-EMG-02).
        case emergency
        /// A 24-hour Pro pause (S-SET-06).
        case pause
        /// The app-side late midnight reset (MidnightResetRecovery).
        case midnightRecovery
        /// ShieldService.reconcile restoring a shield that had gone missing.
        case reconcile
        /// The debug menu. Should never appear in a release build.
        case debug
    }

    // MARK: - Writing

    /// Appends one entry. `appCount` is the number of apps shielded *after* the
    /// action — 0 for a clear.
    static func record(
        _ action: Action,
        source: Source,
        appCount: Int,
        now: Date = Date(),
        defaults: UserDefaults? = nil
    ) {
        let ud = defaults ?? UserDefaults(suiteName: SharedDefaults.suiteName) ?? .standard
        let line = [
            String(Int(now.timeIntervalSince1970)),
            action.rawValue,
            source.rawValue,
            String(appCount),
        ].joined(separator: separator)

        var lines = ud.stringArray(forKey: key) ?? []
        lines.append(line)
        if lines.count > capacity { lines.removeFirst(lines.count - capacity) }
        ud.set(lines, forKey: key)
    }

    // MARK: - Reading

    /// One parsed entry, newest last.
    struct Entry {
        let date: Date
        let action: String
        let source: String
        let appCount: Int
    }

    static func entries(defaults: UserDefaults? = nil) -> [Entry] {
        let ud = defaults ?? UserDefaults(suiteName: SharedDefaults.suiteName) ?? .standard
        return (ud.stringArray(forKey: key) ?? []).compactMap { line in
            let parts = line.components(separatedBy: separator)
            guard parts.count == 4, let epoch = TimeInterval(parts[0]) else { return nil }
            return Entry(
                date: Date(timeIntervalSince1970: epoch),
                action: parts[1],
                source: parts[2],
                appCount: Int(parts[3]) ?? 0
            )
        }
    }

    /// Newest first, one line per entry, for the debug menu.
    static func formattedLines(defaults: UserDefaults? = nil) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm:ss"
        return entries(defaults: defaults).reversed().map { entry in
            let suffix = entry.action == Action.applied.rawValue ? " (\(entry.appCount) apps)" : ""
            return "\(formatter.string(from: entry.date))  \(entry.action)  \(entry.source)\(suffix)"
        }
    }

    static func clear(defaults: UserDefaults? = nil) {
        let ud = defaults ?? UserDefaults(suiteName: SharedDefaults.suiteName) ?? .standard
        ud.removeObject(forKey: key)
    }
}
