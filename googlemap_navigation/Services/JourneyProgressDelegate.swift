import Foundation
import UIKit
import CoreLocation

protocol JourneyProgressDelegate: AnyObject {
    /// Called whenever journey progress updates. Used to drive the UI animation and status.
    func journeyProgressDidUpdate(
        overallProgress: Double,
        phaseProgress: Double,
        canCatch: Bool,
        delta: TimeInterval,
        uncertainty: TimeInterval,
        phase: ProgressPhase
    )

    /// Optional: called when the journey phase changes (for animations, color, etc)
    func journeyPhaseDidChange(_ phase: ProgressPhase)
}

enum ProgressPhase: Equatable {
    case walkToStation
    case stationToPlatform
    case transferWalk(index: Int)
    case finished
}

class JourneyProgressService {
    weak var delegate: JourneyProgressDelegate?

    // --- Config/Data ---
    var walkToStationSec: Double
    var stationToPlatformSec: Double
    var transferTimesSec: [Double]
    var trainArrival: Date

    var originLocation: CLLocation?      // where user started
    var stationLocation: CLLocation?     // entrance of station

    // --- State ---
    private(set) var phase: ProgressPhase = .walkToStation
    private(set) var progress: Double = 0.0
    private(set) var phaseProgress: Double = 0.0
    private var timer: CADisplayLink?
    private var startTime: Date = Date()
    private var uncertainty: Double = 20

    // --- Phase switching ---
    private var lastPhase: ProgressPhase = .walkToStation

    init(walkToStationSec: Double, stationToPlatformSec: Double, transferTimesSec: [Double], trainArrival: Date, originLocation: CLLocation?, stationLocation: CLLocation?) {
        self.walkToStationSec = walkToStationSec
        self.stationToPlatformSec = stationToPlatformSec
        self.transferTimesSec = transferTimesSec
        self.trainArrival = trainArrival
        self.originLocation = originLocation
        self.stationLocation = stationLocation
    }

    func start() {
        startTime = Date()
        phase = .walkToStation
        timer = CADisplayLink(target: self, selector: #selector(update))
        timer?.preferredFramesPerSecond = 60
        timer?.add(to: .main, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        phase = .finished
        notifyDelegate()
    }

    /// Main animation update (for non-GPS phases)
    @objc private func update() {
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        let totalTime = walkToStationSec + stationToPlatformSec + transferTimesSec.reduce(0, +)
        let delta = trainArrival.timeIntervalSince(now)
        let canCatch = (delta - totalTime) > 20

        // ---- PHASE LOGIC ----
        if phase == .walkToStation {
            // Wait for location-driven updates (see below)
            // Just keep showing current progress (or 0)
        } else if phase == .stationToPlatform {
            let phaseStart = walkToStationSec
            let phaseEnd = phaseStart + stationToPlatformSec
            let progressInPhase = min(1.0, max(0, (elapsed - phaseStart) / stationToPlatformSec))
            phaseProgress = progressInPhase
            progress = min(1.0, max(0, (elapsed / totalTime)))
            notifyDelegate(phase: .stationToPlatform, phaseProgress: progressInPhase, canCatch: canCatch, delta: delta)
            if progressInPhase >= 1.0 && !transferTimesSec.isEmpty {
                switchToPhase(.transferWalk(index: 0))
            } else if progressInPhase >= 1.0 {
                switchToPhase(.finished)
            }
        } else if case .transferWalk(let idx) = phase, idx < transferTimesSec.count {
            let prevTime = walkToStationSec + stationToPlatformSec + transferTimesSec.prefix(idx).reduce(0, +)
            let phaseTime = transferTimesSec[idx]
            let progressInPhase = min(1.0, max(0, (elapsed - prevTime) / phaseTime))
            phaseProgress = progressInPhase
            progress = min(1.0, max(0, (elapsed / totalTime)))
            notifyDelegate(phase: .transferWalk(index: idx), phaseProgress: progressInPhase, canCatch: canCatch, delta: delta)
            if progressInPhase >= 1.0 {
                if idx + 1 < transferTimesSec.count {
                    switchToPhase(.transferWalk(index: idx + 1))
                } else {
                    switchToPhase(.finished)
                }
            }
        } else if phase == .finished {
            phaseProgress = 1
            progress = 1
            notifyDelegate(phase: .finished, phaseProgress: 1, canCatch: canCatch, delta: delta)
            stop()
        }
    }

    // ---- For GPS updates (walkToStation phase only) ----
    func updateProgressWithLocation(currentLocation: CLLocation) {
        guard phase == .walkToStation, let origin = originLocation, let station = stationLocation else { return }
        let totalDistance = origin.distance(from: station)
        let distanceLeft = currentLocation.distance(from: station)
        let walkProgress = max(0, min(1, 1 - (distanceLeft / totalDistance)))
        self.phaseProgress = walkProgress
        self.progress = walkProgress * (walkToStationSec / (walkToStationSec + stationToPlatformSec + transferTimesSec.reduce(0, +)))
        let delta = trainArrival.timeIntervalSince(Date())
        notifyDelegate(phase: .walkToStation, phaseProgress: walkProgress, canCatch: true, delta: delta)
        if distanceLeft < 10 { // User arrived at station entrance
            switchToPhase(.stationToPlatform)
        }
    }

    // ---- Helper: Notify delegate with all values
    private func notifyDelegate(phase: ProgressPhase? = nil, phaseProgress: Double? = nil, canCatch: Bool = true, delta: TimeInterval = 0) {
        let ph = phase ?? self.phase
        let pp = phaseProgress ?? self.phaseProgress
        delegate?.journeyProgressDidUpdate(
            overallProgress: self.progress,
            phaseProgress: pp,
            canCatch: canCatch,
            delta: delta,
            uncertainty: self.uncertainty,
            phase: ph
        )
        // Only call this if phase changed
        if ph != lastPhase {
            delegate?.journeyPhaseDidChange(ph)
            lastPhase = ph
        }
    }

    // ---- Phase switching
    private func switchToPhase(_ newPhase: ProgressPhase) {
        self.phase = newPhase
        if newPhase == .stationToPlatform || newPhase == .transferWalk(index: 0) {
            // Restart timer for next phase
            startTime = Date()
        }
        notifyDelegate()
    }
}
