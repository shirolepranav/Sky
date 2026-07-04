// EmergencyLogStoreTests.swift
// Unit tests for EmergencyLogStore — persistence, week filtering, and reason grouping.
// All tests use a temp-directory fileURL so they don't touch the real App Group container.
// Roadmap Phase 13.

import XCTest
@testable import Sky

final class EmergencyLogStoreTests: XCTestCase {

    private var tempFileURL: URL!
    private var store: EmergencyLogStore!

    override func setUp() {
        super.setUp()
        tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_emergency_log_\(UUID().uuidString).json")
        store = EmergencyLogStore(fileURL: tempFileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    // MARK: - Persistence

    func testAdd_appendsEntry() {
        let before = store.entriesThisWeek().count
        store.add(makeEntry(reason: "testing add"))
        XCTAssertEqual(store.entriesThisWeek().count, before + 1)
    }

    func testAdd_persistsAcrossReinit() {
        store.add(makeEntry(reason: "persist me"))
        let reloaded = EmergencyLogStore(fileURL: tempFileURL)
        XCTAssertEqual(reloaded.entriesThisWeek().count, 1)
        XCTAssertEqual(reloaded.entriesThisWeek().first?.typedReason, "persist me")
    }

    // MARK: - Week filtering

    func testEntriesThisWeek_includesCurrentWeek() {
        store.add(makeEntry(reason: "this week", date: Date()))
        XCTAssertEqual(store.entriesThisWeek().count, 1)
    }

    func testEntriesThisWeek_excludesPriorWeek() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        store.add(makeEntry(reason: "last week", date: eightDaysAgo))
        XCTAssertEqual(store.entriesThisWeek().count, 0)
    }

    // MARK: - Top reasons

    func testTopReasons_emptyWhenNoEntries() {
        XCTAssertTrue(store.topReasonsThisWeek().isEmpty)
    }

    func testTopReasons_groupsNormalizedStrings() {
        store.add(makeEntry(reason: "  Test "))
        store.add(makeEntry(reason: "test"))
        let results = store.topReasonsThisWeek()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].count, 2)
    }

    func testTopReasons_sortsByCountDescending() {
        store.add(makeEntry(reason: "once"))
        store.add(makeEntry(reason: "twice"))
        store.add(makeEntry(reason: "twice"))
        let results = store.topReasonsThisWeek()
        XCTAssertEqual(results[0].reason.lowercased(), "twice")
        XCTAssertEqual(results[0].count, 2)
        XCTAssertEqual(results[1].count, 1)
    }

    func testTopReasons_limitsToN() {
        for i in 1...5 {
            store.add(makeEntry(reason: "reason \(i)"))
        }
        XCTAssertEqual(store.topReasonsThisWeek(limit: 3).count, 3)
    }

    // MARK: - Helpers

    private func makeEntry(reason: String, date: Date = Date()) -> EmergencyUnlockEntry {
        let cal = Calendar.current
        return EmergencyUnlockEntry(
            id: UUID(),
            date: date,
            typedReason: reason,
            dayOfWeek: cal.component(.weekday, from: date),
            hourOfDay:  cal.component(.hour, from: date)
        )
    }
}
