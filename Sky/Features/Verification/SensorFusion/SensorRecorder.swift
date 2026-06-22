// SensorRecorder.swift
// Concurrent GPS, barometric-pressure, and camera-light sampler that runs
// during the 30-second outdoor video recording.
// Tech Spec §8.1/§8.4, Roadmap Phase 8.
//
// Threading model: @MainActor throughout.
//   • CLLocationManager must be created on the main thread (per Apple docs).
//     Delegate callbacks arrive on an arbitrary thread; they dispatch back to
//     @MainActor via Task { @MainActor in }.
//   • CMAltimeter handler is dispatched on OperationQueue.main — MainActor safe.
//   • The light-sampler loop runs as a Task { @MainActor } (no extra sync needed).
// All sample arrays are only written from @MainActor, so no locks are required.

import AVFoundation
import CoreLocation
import CoreMotion
import Foundation

@MainActor
final class SensorRecorder: NSObject {

    // MARK: - Configuration

    private weak var captureDevice: AVCaptureDevice?

    // MARK: - Running state

    private var locationManager: CLLocationManager?
    private var altimeter: CMAltimeter?
    private var lightSamplerTask: Task<Void, Never>?

    // MARK: - Collected samples

    private var startTime: Date = Date()
    private var locationSamples: [CLLocation] = []
    private var altitudeSamples: [Double] = []
    private var exposureSamples: [Float] = []
    private var anyGPSSpoofDetected = false

    // MARK: - Init

    init(captureDevice: AVCaptureDevice?) {
        self.captureDevice = captureDevice
    }

    // MARK: - Public interface

    /// Begin collecting sensor data. Call immediately before `startRecording`.
    func start() {
        startTime = Date()
        locationSamples.removeAll()
        altitudeSamples.removeAll()
        exposureSamples.removeAll()
        anyGPSSpoofDetected = false

        startLocationManager()
        startAltimeter()
        startLightSampler()
    }

    /// Stop all sensors and return an aggregated reading. Call in the
    /// AVCaptureFileOutputRecordingDelegate success callback.
    func stop() -> SensorReading {
        let lastLocation = locationSamples.last
        stopAll()
        let sunOK = sunriseSunsetCheck(lastLocation: lastLocation)
        return buildReading(sunriseSunsetCheckPassed: sunOK)
    }

    /// Stop all sensors without building a reading. Call on cancel or interruption.
    func stopAndDiscard() {
        stopAll()
    }

    // MARK: - Private: start helpers

    private func startLocationManager() {
        let mgr = CLLocationManager()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
        mgr.distanceFilter = kCLDistanceFilterNone
        locationManager = mgr
        mgr.startUpdatingLocation()
    }

    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        let alt = CMAltimeter()
        altimeter = alt
        alt.startRelativeAltitudeUpdates(to: OperationQueue.main) { [weak self] data, error in
            guard let data, error == nil else { return }
            self?.altitudeSamples.append(data.relativeAltitude.doubleValue)
        }
    }

    private func startLightSampler() {
        lightSamplerTask = Task { [weak self] in
            while !Task.isCancelled {
                if let device = self?.captureDevice {
                    self?.exposureSamples.append(device.exposureTargetOffset)
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    // MARK: - Private: stop

    private func stopAll() {
        locationManager?.stopUpdatingLocation()
        locationManager?.delegate = nil
        locationManager = nil

        altimeter?.stopRelativeAltitudeUpdates()
        altimeter = nil

        lightSamplerTask?.cancel()
        lightSamplerTask = nil
    }

    // MARK: - Private: aggregation

    private func sunriseSunsetCheck(lastLocation: CLLocation?) -> Bool {
        guard let loc = lastLocation else { return false }
        let calc = SolarCalculator(
            coordinate: loc.coordinate,
            date: startTime,
            timeZone: .current
        )
        return calc.isCurrentlyDaylight()
    }

    private func buildReading(sunriseSunsetCheckPassed: Bool) -> SensorReading {
        SensorReading(
            gpsAccuracyAtBest: bestGPSAccuracy(),
            maxHorizontalSpeed: maxSpeed(),
            altitudeChangeMeters: altitudeDelta(),
            medianExposureBias: medianExposure(),
            timeOfDay: startTime,
            gpsSpoofed: anyGPSSpoofDetected,
            sunriseSunsetCheckPassed: sunriseSunsetCheckPassed
        )
    }

    private func bestGPSAccuracy() -> CLLocationAccuracy {
        locationSamples.map(\.horizontalAccuracy).min() ?? .infinity
    }

    private func maxSpeed() -> Double {
        // Use CoreLocation's Kalman-filtered .speed when the device provides it (>= 0).
        let clSpeeds = locationSamples.compactMap { $0.speed >= 0 ? $0.speed : nil }
        // Also compute pairwise speed between consecutive samples as a fallback.
        let pairwise: [Double] = zip(locationSamples, locationSamples.dropFirst()).compactMap { prev, curr in
            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard dt > 0 else { return nil }
            return curr.distance(from: prev) / dt
        }
        return (clSpeeds + pairwise).max() ?? 0
    }

    private func altitudeDelta() -> Double {
        guard let lo = altitudeSamples.min(), let hi = altitudeSamples.max() else { return 0 }
        return abs(hi - lo)
    }

    private func medianExposure() -> Float {
        guard !exposureSamples.isEmpty else { return 0 }
        let sorted = exposureSamples.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
    }

    // MARK: - Testability seam

    /// Returns true if any location carries an accessory/software-simulated GPS flag.
    /// Exposed as `internal static` because CLLocationSourceInformation has no public init,
    /// making direct unit testing of real-device spoof scenarios impossible in tests.
    static func containsSpoofedLocation(_ locations: [CLLocation]) -> Bool {
        guard #available(iOS 15.0, *) else { return false }
        return locations.contains {
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
            for loc in locations {
                guard loc.timestamp >= self.startTime else { continue }
                if #available(iOS 15.0, *) {
                    if loc.sourceInformation?.isProducedByAccessory == true
                       || loc.sourceInformation?.isSimulatedBySoftware == true {
                        self.anyGPSSpoofDetected = true
                    }
                }
                self.locationSamples.append(loc)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}
