// CloudKitSyncService.swift
// Syncs UserProgress to the user's CloudKit private database.
// Local cache (UserDefaults) is always the authoritative source for UI;
// CloudKit is best-effort and never blocks any user interaction.
//
// Record type: "UserProgress", record ID: "current" (one record per user).
// Conflict strategy: last-writer-wins for all counters; union for unlockedBadges.
//
// Technical Spec §11; Sky_App_Workflow.md S-SET-06; Roadmap Phase 12.

import CloudKit
import Foundation

// MARK: - Sync status

enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
}

// MARK: - Service

@MainActor
final class CloudKitSyncService: ObservableObject {

    @Published private(set) var syncStatus: SyncStatus = .idle

    private let db: CKDatabase
    private let recordID = CKRecord.ID(recordName: "current")

    /// Coalescing timer: schedule a save rather than writing on every keystroke.
    private var pendingSaveTask: Task<Void, Never>?

    init(container: CKContainer = .default()) {
        db = container.privateCloudDatabase
    }

    // MARK: - Public API

    /// Fetch the remote record on launch and merge it with the local copy.
    /// Non-blocking: UI continues from local cache regardless of outcome.
    func fetchOnLaunch() {
        Task {
            await fetch()
        }
    }

    /// Coalesce rapid successive saves (e.g. badge + streak updated in one
    /// verification) and write once after a short delay.
    func scheduleSave(_ progress: UserProgress) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await save(progress)
        }
    }

    // MARK: - Private: fetch

    private func fetch() async {
        syncStatus = .syncing
        do {
            let record = try await db.record(for: recordID)
            var local = UserProgress.load()
            merge(remote: record, into: &local)
            local.save()
            syncStatus = .idle
        } catch let ckError as CKError {
            if ckError.code == .unknownItem {
                // First launch: no remote record yet — nothing to merge.
                syncStatus = .idle
            } else {
                syncStatus = .error(ckError.localizedDescription)
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Private: save

    private func save(_ progress: UserProgress) async {
        syncStatus = .syncing
        do {
            // Fetch existing record to update it (avoids overwriting concurrent changes).
            let record: CKRecord
            do {
                record = try await db.record(for: recordID)
            } catch {
                // No remote record yet — create one.
                record = CKRecord(recordType: "UserProgress", recordID: recordID)
            }
            encode(progress, into: record)
            try await db.save(record)
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Encoding / decoding

    private func encode(_ progress: UserProgress, into record: CKRecord) {
        record[UserProgress.CKField.currentStreak]             = progress.currentStreak as CKRecordValue
        record[UserProgress.CKField.longestStreak]             = progress.longestStreak as CKRecordValue
        record[UserProgress.CKField.totalVerifications]        = progress.totalVerifications as CKRecordValue
        record[UserProgress.CKField.totalEmergencyUnlocks]     = progress.totalEmergencyUnlocks as CKRecordValue
        record[UserProgress.CKField.lastVerificationDate]      = progress.lastVerificationDate as CKRecordValue?
        record[UserProgress.CKField.firstInstallDate]          = progress.firstInstallDate as CKRecordValue
        record[UserProgress.CKField.unlockedBadges]            = Array(progress.unlockedBadges.map(\.rawValue)) as CKRecordValue
        record[UserProgress.CKField.verificationLocations]     = progress.verificationLocations as CKRecordValue
        record[UserProgress.CKField.mascotState]               = progress.mascotState as CKRecordValue
        record[UserProgress.CKField.hadEmergencyUnlock]        = progress.hadEmergencyUnlock as CKRecordValue
        record[UserProgress.CKField.streakAfterFirstEmergency] = progress.streakAfterFirstEmergency as CKRecordValue
    }

    /// Merge remote CloudKit record into local progress.
    /// Strategy: last-writer-wins for numeric counters; union for badge list.
    private func merge(remote: CKRecord, into local: inout UserProgress) {
        // Counters — take whichever is larger (protects against rollback).
        if let v = remote[UserProgress.CKField.currentStreak] as? Int {
            local.currentStreak = max(local.currentStreak, v)
        }
        if let v = remote[UserProgress.CKField.longestStreak] as? Int {
            local.longestStreak = max(local.longestStreak, v)
        }
        if let v = remote[UserProgress.CKField.totalVerifications] as? Int {
            local.totalVerifications = max(local.totalVerifications, v)
        }
        if let v = remote[UserProgress.CKField.totalEmergencyUnlocks] as? Int {
            local.totalEmergencyUnlocks = max(local.totalEmergencyUnlocks, v)
        }

        // Dates — take the most recent
        if let v = remote[UserProgress.CKField.lastVerificationDate] as? Date {
            if let existing = local.lastVerificationDate {
                local.lastVerificationDate = max(existing, v)
            } else {
                local.lastVerificationDate = v
            }
        }

        // Badges — union
        if let rawBadges = remote[UserProgress.CKField.unlockedBadges] as? [String] {
            let remoteBadges = Set(rawBadges.compactMap(BadgeID.init(rawValue:)))
            local.unlockedBadges.formUnion(remoteBadges)
        }

        // Locations — union (deduplicated)
        if let remoteLocs = remote[UserProgress.CKField.verificationLocations] as? [String] {
            for loc in remoteLocs {
                if !local.verificationLocations.contains(loc) {
                    local.verificationLocations.append(loc)
                }
            }
        }

        // Boolean flags — OR (once true, stays true)
        if let v = remote[UserProgress.CKField.hadEmergencyUnlock] as? Int {
            local.hadEmergencyUnlock = local.hadEmergencyUnlock || (v != 0)
        }

        // streakAfterFirstEmergency — take max
        if let v = remote[UserProgress.CKField.streakAfterFirstEmergency] as? Int {
            local.streakAfterFirstEmergency = max(local.streakAfterFirstEmergency, v)
        }

        // mascotState — prefer remote (other device may be more current)
        if let v = remote[UserProgress.CKField.mascotState] as? String {
            local.mascotState = v
        }
    }
}
