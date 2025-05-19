import Foundation
import UIKit
import CoreLocation

protocol JourneyProgressDelegate: AnyObject {
    func journeyProgressDidUpdate(progress: Double, canCatch: Bool, delta: TimeInterval, uncertainty: TimeInterval, phase: ProgressPhase)
}

enum ProgressPhase {
    case walkToStation
    case stationToPlatform
    case transferWalk
    case finished
}

class JourneyProgressService {
    weak var delegate: JourneyProgressDelegate?

    // MARK: - Time and Location Data
    var walkToStationSec: Double
    var stationToPlatformSec: Double
    var transferTimesSec: [Double]
    var originLocation: CLLocation?
    var stationLocation: CLLocation?
    var phase: ProgressPhase = .walkToStation
    var totalTime: Double = 0.0
    private var timer: CADisplayLink?
    private var startTime: Date!
    private var arrivalTime: Date
    private var uncertainty: Double = 20
    private(set) var progress: Double = 0.0
    private(set) var running = false

    // MARK: - Initialization
    init(
        walkToStationSec: Double,
        stationToPlatformSec: Double,
        transferTimesSec: [Double],
        trainArrival: Date,
        originLocation: CLLocation? = nil,
        stationLocation: CLLocation? = nil
    ) {
        self.walkToStationSec = walkToStationSec
        self.stationToPlatformSec = stationToPlatformSec
        self.transferTimesSec = transferTimesSec
        self.arrivalTime = trainArrival
        self.totalTime = walkToStationSec + stationToPlatformSec + transferTimesSec.reduce(0, +)
        self.originLocation = originLocation
        self.stationLocation = stationLocation
    }
    
    // MARK: - Timer-based Animation
    func start() {
        running = true
        startTime = Date()
        timer = CADisplayLink(target: self, selector: #selector(update))
        timer?.preferredFramesPerSecond = 60
        timer?.add(to: .main, forMode: .common)
        update()
    }
    
    func stop() {
        running = false
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func update() {
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        let delta = arrivalTime.timeIntervalSince(now)
        let canCatch = (delta - totalTime) > 20 // 20 seconds buffer

        // Phase progress calculation (default: time-based)
        var phaseProgress: Double = 0
        var phaseType: ProgressPhase = .walkToStation
        
        if elapsed < walkToStationSec {
            phaseType = .walkToStation
            phaseProgress = elapsed / walkToStationSec
        } else if elapsed < walkToStationSec + stationToPlatformSec {
            phaseType = .stationToPlatform
            phaseProgress = (elapsed - walkToStationSec) / stationToPlatformSec
        } else {
            var cumulative: Double = 0
            for (i, transferSec) in transferTimesSec.enumerated() {
                let begin = walkToStationSec + stationToPlatformSec + transferTimesSec[..<i].reduce(0, +)
                let end = begin + transferSec
                if elapsed < end {
                    phaseType = .transferWalk
                    phaseProgress = (elapsed - begin) / transferSec
                    break
                }
                cumulative = end
            }
            if elapsed > totalTime {
                phaseType = .finished
                phaseProgress = 1
                stop()
            }
        }
        let overallProgress = min(elapsed / totalTime, 1)
        self.progress = overallProgress
        
        // Notify delegate for UI update
        delegate?.journeyProgressDidUpdate(
            progress: overallProgress,
            canCatch: canCatch,
            delta: delta,
            uncertainty: uncertainty,
            phase: phaseType
        )
    }

    // MARK: - Location-based Progress Update
    func updateProgressWithLocation(currentLocation: CLLocation) {
        guard let origin = originLocation, let station = stationLocation else { return }
        let totalDistance = origin.distance(from: station)
        let distanceLeft = currentLocation.distance(from: station)
        let locProgress = max(0, min(1, 1 - (distanceLeft / totalDistance)))
        self.progress = locProgress
        if distanceLeft < 10 { // If within 10m of the station, switch phase
            self.phase = .stationToPlatform
        }
        delegate?.journeyProgressDidUpdate(
            progress: locProgress,
            canCatch: true,
            delta: arrivalTime.timeIntervalSince(Date()),
            uncertainty: uncertainty,
            phase: .walkToStation
        )
    }
    
    // MARK: - Future: Database for Station to Platform Time
    static func fetchStationToPlatformTime(for station: String, completion: @escaping (Double) -> Void) {
        // Placeholder for database query, returns default 120 seconds
        completion(120)
    }

    static func recordStationToPlatformTime(for station: String, seconds: Double) {
        // Placeholder for uploading record to a database
    }
}
