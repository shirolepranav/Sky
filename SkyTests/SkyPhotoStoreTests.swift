// SkyPhotoStoreTests.swift
// Phase F "today's sky" store: one photo per day, pruned to capacity, deletable.

import XCTest
@testable import Sky

final class SkyPhotoStoreTests: XCTestCase {

    private var dir: URL!
    private var store: SkyPhotoStore!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("skies-\(UUID().uuidString)")
        store = SkyPhotoStore(directory: dir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func jpeg() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).jpegData(withCompressionQuality: 0.5) { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    func testSaveAndReadBack() {
        store.save(jpeg: jpeg())
        XCTAssertNotNil(store.image(on: Date()))
        XCTAssertNotNil(store.latestImage())
    }

    func testOnePhotoPerDay() {
        store.save(jpeg: jpeg())
        store.save(jpeg: jpeg())
        XCTAssertEqual(store.days().count, 1)
    }

    func testNewestFirstAndPrunedToCapacity() {
        for offset in 0..<(SkyPhotoStore.capacity + 3) {
            store.save(jpeg: jpeg(), on: day(-offset))
        }
        let days = store.days()
        XCTAssertEqual(days.count, SkyPhotoStore.capacity)
        XCTAssertEqual(days.first, MidnightResetRecovery.dayStamp(for: Date()), "newest kept")
        XCTAssertFalse(days.contains(MidnightResetRecovery.dayStamp(for: day(-(SkyPhotoStore.capacity + 2)))),
                       "oldest pruned")
    }

    func testDeleteAllRemovesEverything() {
        store.save(jpeg: jpeg())
        store.deleteAll()
        XCTAssertTrue(store.days().isEmpty)
        XCTAssertNil(store.latestImage())
    }

    func testSavedFilesAreExcludedFromBackup() throws {
        store.save(jpeg: jpeg())
        let values = try dir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
