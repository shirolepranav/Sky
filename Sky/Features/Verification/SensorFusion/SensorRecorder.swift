// SensorRecorder.swift
// GPS sampler plus a retroactive step-count query for an outdoor verification.
// Tech Spec §8.1/§8.4; DAILY_LOCK_PLAN.md Phase E.
//
// The clip is only five seconds — often shorter than a GPS fix — so:
//   • a cached fix up to `cachedFixMaxAge` old is accepted (the phone usually has
//     one from the walk that just happened), and
//   • `stop()` keeps listening for up to `gpsGraceSeconds` more if no usable fix
//     has arrived yet.
//
// Steps come from CMPedometer's history, so the walk happens *before* recording
// and Sky doesn't need to be open during it.
//
// Threading: @MainActor throughout. CLLocationManager delegate callbacks hop back
// via Task { @MainActor in }.

import CoreLocation
import CoreMotion
import Foundation

@MainActor
final class SensorRecorder: NSObject {

    /// Oldest cached location accepted at the start of a recording.
    private static let cachedFixMaxAge: TimeInterval = 60

    private var locationManager: CLLocationManager?
    private var startTime: Date = Date()
    private var locationSamples: [CLLocation] = []
    private var anyGPSSpoofDetected = false

    // MARK: - Public interface

    /// Begin collecting GPS. Call immediately before recording starts.
    func start() {
        startTime = Date()
        locationSamples.removeAll()
        anyGPSSpoofDetected = false

        let mgr = CLLocationManager()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
        mgr.distanceFilter = kCLDistanceFilterNone
        locationManager = mgr
        mgr.startUpdatingLocation()
    }

    /// Stop and return an aggregated reading. Waits briefly for a usable GPS fix
    /// if none has arrived, and queries the pedometer.
    func stop() async -> SensorReading {
        let deadline = Date().addingTimeInterval(VerificationThresholds.gpsGraceSeconds)
        while bestGPSAccuracy() > VerificationThresholds.maxAcceptableGPSError, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(250))
        }
        let lastLocation = locationSamples.last
        stopAndDiscard()

        let steps = await Self.recentSteps()
        return SensorReading(
            gpsAccuracyAtBest: bestGPSAccuracy(),
            timeOfDay: startTime,
            gpsSpoofed: anyGPSSpoofDetected,
            isDaylight: isDaylight(at: lastLocation),
            recentSteps: steps,
            motionDenied: CMPedometer.authorizationStatus() == .denied,
            bestLocationTag: bestRoundedLocationTag()
        )
    }

    /// Stop GPS without building a reading. Call on cancel or interruption.
    func stopAndDiscard() {
        locationManager?.stopUpdatingLocation()
        locationManager?.delegate = nil
        locationManager = nil
    }

    // MARK: - Steps

    /// Steps in the last `stepWindowSeconds`, or nil when the device can't count
    /// steps. Denied access reads as 0 (the reading's `motionDenied` explains it).
    static func recentSteps(now: Date = Date()) async -> Int? {
        guard CMPedometer.isStepCountingAvailable() else { return nil }
        let from = now.addingTimeInterval(-VerificationThresholds.stepWindowSeconds)
        return await withCheckedContinuation { continuation in
            CMPedometer().queryPedometerData(from: from, to: now) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }

    // MARK: - Aggregation

    private func isDaylight(at location: CLLocation?) -> Bool {
        // No fix → false. Harmless: the GPS check fails first in that case.
        guard let loc = location else { return false }
        // Civil twilight, not true sunrise/sunset — see SolarCalculator.civilTwilightZenith.
        return SolarCalculator(coordinate: loc.coordinate, date: startTime, timeZone: .current)
            .isWithinVerificationWindow()
    }

    /// The most accurate sample rounded to 0.01° as "lat_lng" (privacy invariant),
    /// or nil if none was within 100 m.
    private func bestRoundedLocationTag() -> String? {
        let best = locationSamples
            .filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 100 }
            .min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy })
        guard let loc = best else { return nil }
        let lat = (loc.coordinate.latitude  * 100).rounded() / 100
        let lng = (loc.coordinate.longitude * 100).rounded() / 100
        return "\(lat)_\(lng)"
    }

    private func bestGPSAccuracy() -> CLLocationAccuracy {
        locationSamples.map(\.horizontalAccuracy).filter { $0 >= 0 }.min() ?? .infinity
    }

    // MARK: - Testability seam

    /// True if any location carries an accessory/software-simulated GPS flag.
    /// `internal static` because CLLocationSourceInformation has no public init.
    static func containsSpoofedLocation(_ locations: [CLLocation]) -> Bool {
        locations.contains {
            $0.sourceInformation?.isProducedByAccessory == true
            || $0.sourceInformation?.isSimulatedBySoftware == true
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SensorRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let oldest = self.startTime.addingTimeInterval(-Self.cachedFixMaxAge)
            for loc in locations where loc.timestamp >= oldest {
                if Self.containsSpoofedLocation([loc]) { self.anyGPSSpoofDetected = true }
                self.locationSamples.append(loc)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}
