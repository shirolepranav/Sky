// SkyPhotoStore.swift
// On-device store for "today's sky" — one still frame per verified day
// (DAILY_LOCK_PLAN.md Phase F).
//
// Privacy (CLAUDE.md invariants, PRIVACY_POLICY.md): the verification *video* is
// still deleted right after processing. This keeps a single JPEG per day,
// downscaled, with no metadata (no GPS, no EXIF — it is encoded from a bare
// CGImage). Files live in Application Support, are excluded from device backup,
// are never read by CloudKitSyncService, and leave the phone only when the user
// shares one themselves. The newest `capacity` days are kept; Settings deletes all.

import UIKit

final class SkyPhotoStore {

    static let shared = SkyPhotoStore(
        directory: (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Skies", isDirectory: true)
    )

    /// Days kept. Older photos are deleted on each save.
    static let capacity = 30

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    // MARK: Write

    /// Saves (or replaces) the photo for the day containing `date`, then prunes.
    func save(jpeg: Data, on date: Date = Date()) {
        var dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)

        try? jpeg.write(to: fileURL(for: date), options: [.atomic, .completeFileProtection])
        prune()
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Read

    /// Day stamps (`yyyy-MM-dd`) with a photo, newest first.
    func days() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { $0.hasSuffix(".jpg") }
            .map { String($0.dropLast(4)) }
            .sorted(by: >)
    }

    func image(forDay day: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent("\(day).jpg").path)
    }

    func image(on date: Date) -> UIImage? {
        image(forDay: MidnightResetRecovery.dayStamp(for: date))
    }

    func latestImage() -> UIImage? {
        days().first.flatMap(image(forDay:))
    }

    // MARK: Private

    private func fileURL(for date: Date) -> URL {
        directory.appendingPathComponent("\(MidnightResetRecovery.dayStamp(for: date)).jpg")
    }

    private func prune() {
        for day in days().dropFirst(Self.capacity) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(day).jpg"))
        }
    }
}

extension SkyPhotoStore {
    /// JPEG for a frame — the encoding drops all metadata.
    static func jpeg(from image: CGImage) -> Data? {
        UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
    }
}
