// ShieldAuditTests.swift
// Pins the wire format of the shield audit trail.
//
// The DeviceActivityMonitor extension cannot import the Sky module, so it writes
// these lines by hand (`auditShield` in SkyDeviceActivityMonitor). If the shape
// here drifts, the app-side reader silently drops every entry the extension
// wrote — and the extension is the one process whose behaviour we most need the
// log to explain. These tests are the contract between the two copies.

import XCTest
@testable import Sky

final class ShieldAuditTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "sky.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// The extension writes "<epoch>|<action>|<source>|<count>" strings directly.
    /// Anything else must be readable back identically.
    func testRecordRoundTrips() {
        let now = Date(timeIntervalSince1970: 1_786_104_000)
        ShieldAudit.record(.applied, source: .monitorThreshold, appCount: 3,
                           now: now, defaults: defaults)

        let entries = ShieldAudit.entries(defaults: defaults)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].action, "applied")
        XCTAssertEqual(entries[0].source, "monitor.threshold")
        XCTAssertEqual(entries[0].appCount, 3)
        XCTAssertEqual(entries[0].date.timeIntervalSince1970, 1_786_104_000, accuracy: 1)
    }

    /// A hand-written line in the extension's exact format must parse. This is
    /// the mirrored-code check — if it fails, the two sides have drifted.
    func testExtensionFormatIsReadable() {
        defaults.set(["1786104000|cleared|monitor.intervalStart|0"], forKey: ShieldAudit.key)

        let entries = ShieldAudit.entries(defaults: defaults)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].action, "cleared")
        XCTAssertEqual(entries[0].source, "monitor.intervalStart")
    }

    /// No enum case may contain the separator, or its line splits into the wrong
    /// number of fields and is dropped on read.
    func testNoSourceContainsTheSeparator() {
        let sources: [ShieldAudit.Source] = [
            .monitorThreshold, .monitorIntervalStart, .verificationSuccess,
            .emergency, .pause, .midnightRecovery, .reconcile, .debug,
        ]
        for source in sources {
            XCTAssertFalse(
                source.rawValue.contains(ShieldAudit.separator),
                "\(source.rawValue) would corrupt its own log line"
            )
        }
    }

    /// Oldest entries drop out rather than growing without bound — this lives in
    /// the App Group container the extensions also use.
    func testLogIsCappedAtCapacity() {
        for i in 0..<(ShieldAudit.capacity + 10) {
            ShieldAudit.record(.applied, source: .reconcile, appCount: i,
                               now: Date(), defaults: defaults)
        }

        let entries = ShieldAudit.entries(defaults: defaults)
        XCTAssertEqual(entries.count, ShieldAudit.capacity)
        XCTAssertEqual(entries.last?.appCount, ShieldAudit.capacity + 9,
                       "the newest entry must survive the trim")
    }

    /// Garbage in the array must not take the whole log down with it.
    func testMalformedLinesAreSkipped() {
        defaults.set(["nonsense", "1786104000|applied|reconcile|1"], forKey: ShieldAudit.key)

        XCTAssertEqual(ShieldAudit.entries(defaults: defaults).count, 1)
    }

    /// The debug menu reads newest-first.
    func testFormattedLinesAreNewestFirst() {
        let early = Date(timeIntervalSince1970: 1_786_104_000)
        ShieldAudit.record(.applied, source: .monitorThreshold, appCount: 1,
                           now: early, defaults: defaults)
        ShieldAudit.record(.cleared, source: .verificationSuccess, appCount: 0,
                           now: early.addingTimeInterval(60), defaults: defaults)

        let lines = ShieldAudit.formattedLines(defaults: defaults)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("verification.success"))
        XCTAssertTrue(lines[1].contains("monitor.threshold"))
    }
}
