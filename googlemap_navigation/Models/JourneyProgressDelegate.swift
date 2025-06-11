import Foundation
import UIKit
import CoreLocation

protocol JourneyProgressDelegate: AnyObject {
    func journeyProgressDidUpdate(
        overallProgress: Double,
        phaseProgress: Double,
        currentCatchStatus: CatchStatus, // MODIFIED: Replaces canCatch
        delta: TimeInterval,             // Time until train_arrival_at_platform
        uncertainty: TimeInterval,
        phase: ProgressPhase
    )
    func journeyPhaseDidChange(_ phase: ProgressPhase)
}

enum ProgressPhase: Equatable {
    case walkToStation
    case stationToPlatform
    case onTrain(legIndex: Int)
    case transferWalk(index: Int)
    case walkToDestination
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
    
    // bufferTime = (Train Arrival Time) - (Time NOW) - (Predicted Time To Reach Platform From Current Location)
    private let easyThresholdDynamic: TimeInterval = 90
    private let hurryThresholdDynamic: TimeInterval = 20
    private let toughThresholdDynamic: TimeInterval = -30 // User can be up to 30s "late" to platform for a TOUGH status
    

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
    

    private func determineDynamicCatchStatus(bufferTime: TimeInterval) -> CatchStatus {
        if bufferTime > easyThresholdDynamic {
            return .easy
        } else if bufferTime > hurryThresholdDynamic {
            return .hurry
        } else if bufferTime > toughThresholdDynamic {
            return .tough
        } else {
            return .missed
        }
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
        // Only include stationToPlatformSec once in total time calculation
        let totalTime = walkToStationSec + stationToPlatformSec + transferTimesSec.reduce(0, +)
        let delta = trainArrival.timeIntervalSince(now)

        // ---- PHASE LOGIC ----
        if phase == .walkToStation {
            // Just keep showing current progress (or 0)
        } else if phase == .stationToPlatform {
            let phaseStart = walkToStationSec
            let progressInPhase = min(1.0, max(0, (elapsed - phaseStart) / stationToPlatformSec))
            phaseProgress = progressInPhase
            progress = min(1.0, max(0, (elapsed / totalTime)))
            notifyDelegate(phaseOverride: .stationToPlatform, phaseProgressOverride: progressInPhase)
            // After station to platform, go directly to first train if no transfers
            if progressInPhase >= 1.0 {
                if !transferTimesSec.isEmpty {
                    switchToPhase(.transferWalk(index: 0))
                } else {
                    switchToPhase(.onTrain(legIndex: 0))
                }
            }
        } else if case .transferWalk(let idx) = phase, idx < transferTimesSec.count {
            let prevTime = walkToStationSec + stationToPlatformSec + transferTimesSec.prefix(idx).reduce(0, +)
            let phaseTime = transferTimesSec[idx]
            let progressInPhase = min(1.0, max(0, (elapsed - prevTime) / phaseTime))
            phaseProgress = progressInPhase
            progress = min(1.0, max(0, (elapsed / totalTime)))
            notifyDelegate(phaseOverride: .transferWalk(index: idx), phaseProgressOverride: progressInPhase)
            if progressInPhase >= 1.0 {
                if idx + 1 < transferTimesSec.count {
                    switchToPhase(.transferWalk(index: idx + 1))
                } else {
                    switchToPhase(.onTrain(legIndex: idx + 1))
                }
            }
        } else if phase == .finished {
            phaseProgress = 1
            progress = 1
            notifyDelegate(phaseOverride: .finished, phaseProgressOverride: 1, explicitCatchStatus: .missed)
            stop()
        }
    }

    // ---- For GPS updates (walkToStation phase only) ----
    // In updateProgressWithLocation(currentLocation: CLLocation)
    func updateProgressWithLocation(currentLocation: CLLocation) {
        guard phase == .walkToStation, let origin = originLocation, let station = stationLocation else { return }

        let totalDistanceToStation = origin.distance(from: station)
        guard totalDistanceToStation > 0 else { // Avoid division by zero
            // User is likely at the station or origin is same as station
            if phase == .walkToStation { switchToPhase(.stationToPlatform) }
            return
        }
        let distanceUserToStation = currentLocation.distance(from: station)

        // Calculate current predicted walk time based on remaining distance and a speed estimate
        // This is a simplified speed estimate. You might want a rolling average from GPS.
        let assumedWalkingSpeed: Double = 1.2 // m/s (average, adjust as needed)
        let remainingPredictedWalkTime = distanceUserToStation / assumedWalkingSpeed

        // Overall progress for this phase (walkToStation)
        let walkProgress = max(0, min(1, 1 - (distanceUserToStation / totalDistanceToStation)))
        self.phaseProgress = walkProgress

        // Update overall journey progress (simplified, assumes walkToStation is first part)
        let totalJourneyTimeEstimate = self.walkToStationSec + self.stationToPlatformSec + self.transferTimesSec.reduce(0, +)
        if totalJourneyTimeEstimate > 0 {
             self.progress = (self.walkToStationSec * walkProgress) / totalJourneyTimeEstimate
        } else {
             self.progress = 0
        }

        // Calculate dynamic catch status
        let predictedTimeToReachPlatformFromCurrent = remainingPredictedWalkTime + self.stationToPlatformSec
        let timeUntilTrainArrival = trainArrival.timeIntervalSince(Date())
        let bufferTime = timeUntilTrainArrival - predictedTimeToReachPlatformFromCurrent
        let dynamicStatus = determineDynamicCatchStatus(bufferTime: bufferTime)

        notifyDelegate(phaseOverride: .walkToStation, phaseProgressOverride: walkProgress, explicitCatchStatus: dynamicStatus)

        // Threshold for arriving at station (e.g., within 10-20 meters)
        if distanceUserToStation < 20 {
            switchToPhase(.stationToPlatform)
        }
    }
    

    private func notifyDelegate(
        phaseOverride: ProgressPhase? = nil,
        phaseProgressOverride: Double? = nil,
        explicitCatchStatus: CatchStatus? = nil
    ) {
        let currentPhase = phaseOverride ?? self.phase
        let currentPhaseProgress = phaseProgressOverride ?? self.phaseProgress
        let timeUntilTrainArrival = trainArrival.timeIntervalSince(Date()) // Live delta

        var currentCatchStatus: CatchStatus
        if let explicitStatus = explicitCatchStatus {
            currentCatchStatus = explicitStatus
        } else {
            // --- DYNAMIC STATUS CALCULATION ---
            // This is where you need your service's best guess of time to reach platform
            var predictedTimeToReachPlatform: Double
            if currentPhase == .walkToStation {
                // This needs dynamic calculation based on current location and speed
                // For now, a simplified version: assume remaining portion of initial walk time + fixed platform time
                let remainingWalkProportion = 1.0 - self.phaseProgress // phaseProgress for walkToStation is 0-1
                predictedTimeToReachPlatform = (remainingWalkProportion * self.walkToStationSec) + self.stationToPlatformSec
            } else if currentPhase == .stationToPlatform {
                let remainingPlatformProportion = 1.0 - self.phaseProgress
                predictedTimeToReachPlatform = remainingPlatformProportion * self.stationToPlatformSec
            } else { // For transfer walks or other phases, adapt logic
                // Fallback to a static pessimistic estimate or handle based on phase
                predictedTimeToReachPlatform = self.walkToStationSec + self.stationToPlatformSec // Placeholder for other phases
            }
             // Ensure predictedTimeToReachPlatform doesn't go negative if phaseProgress > 1 due to timing
            predictedTimeToReachPlatform = max(0, predictedTimeToReachPlatform)

            let bufferTime = timeUntilTrainArrival - predictedTimeToReachPlatform
            currentCatchStatus = determineDynamicCatchStatus(bufferTime: bufferTime)
        }

        delegate?.journeyProgressDidUpdate(
            overallProgress: self.progress, // Ensure self.progress is correctly updated for overall journey
            phaseProgress: currentPhaseProgress,
            currentCatchStatus: currentCatchStatus, // PASS THE CALCULATED STATUS
            delta: timeUntilTrainArrival,         // Pass the live delta
            uncertainty: self.uncertainty,
            phase: currentPhase
        )

        if currentPhase != lastPhase {
            delegate?.journeyPhaseDidChange(currentPhase)
            lastPhase = currentPhase
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
