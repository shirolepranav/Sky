// EmergencyUnlockEntry.swift
// Codable record for a single emergency-unlock event, persisted on-device only.
// Sky_Technical_Spec.md §6.3; Sky_App_Workflow.md S-EMG-02; Roadmap Phase 13.
//
// Privacy invariant: typedReason NEVER leaves the device — it is never included
// in CloudKit sync and never logged to any server.

import Foundation

struct EmergencyUnlockEntry: Codable, Identifiable {

    /// Which friction-gated action produced this entry. Phase 15 reuses the same
    /// on-device log for Pause-Sky confirmations (`.pause`) alongside the original
    /// emergency unlocks (`.emergency`).
    enum Kind: String, Codable {
        case emergency
        case pause
    }

    let id: UUID
    let date: Date
    let typedReason: String   // ≤ 200 chars, typed manually by the user
    let dayOfWeek: Int        // Calendar.Component.weekday (1 = Sunday)
    let hourOfDay: Int        // Calendar.Component.hour (0–23)
    var kind: Kind = .emergency
}

// Custom decode so records written before Phase 15 (no `kind` field) still load,
// defaulting to `.emergency`. Encoding stays synthesized.
extension EmergencyUnlockEntry {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        date        = try c.decode(Date.self,   forKey: .date)
        typedReason = try c.decode(String.self, forKey: .typedReason)
        dayOfWeek   = try c.decode(Int.self,    forKey: .dayOfWeek)
        hourOfDay   = try c.decode(Int.self,    forKey: .hourOfDay)
        kind        = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .emergency
    }
}
