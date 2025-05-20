import Foundation
import CoreLocation


public enum CrowdLevel: String {
    case low, medium, high, unknown

    init(raw: String?) {
        switch raw?.lowercased() {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        default: self = .unknown
        }
    }

    var emoji: String {
        switch self {
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🔴"
        case .unknown: return "⚪️"
        }
    }
}


public struct WalkStep {
    public let instruction: String
    public let distanceText: String
    public let durationText: String
    
    public init(instruction: String, distanceText: String, durationText: String) {
        self.instruction = instruction
        self.distanceText = distanceText
        self.durationText = durationText
    }
}

public struct TransitInfo {
    var lineName: String
    var departureStation: String?
    var arrivalStation: String?
    var durationText: String?
    
    var departurePlatform: String?
    var arrivalPlatform: String?
    var departureCoordinate: CLLocationCoordinate2D?
    var arrivalCoordinate: CLLocationCoordinate2D?
    
    var crowdLevel: CrowdLevel?
    var numStops: Int?
    var lineColorHex: String?
    var delayStatus: String?
    var stopNames: [String] = []
    var durationTime: String?
    
//    var walkToStationSec: Double?   // 单位秒，可选（比如第一段有，Transfer段无）
//    var stationToPlatformSec: Double? //
    
    
    init(
        lineName: String,
        departureStation: String?,
        arrivalStation: String?,
        durationText: String?,
        
        departurePlatform: String?,
        arrivalPlatform: String?,
        departureCoordinate: CLLocationCoordinate2D?,
        arrivalCoordinate: CLLocationCoordinate2D?,
        
        crowdLevel: CrowdLevel?,
        numStops: Int?,
        lineColorHex: String?,
        delayStatus: String?,
        
//        walkToStationSec: Double?,
//        stationToPlatformSec: Double?
        
    ) {
        self.lineName = lineName
        self.departureStation = departureStation
        self.arrivalStation = arrivalStation
        self.durationText = durationText
        
        self.departurePlatform = departurePlatform
        self.arrivalPlatform = arrivalPlatform
        self.departureCoordinate = departureCoordinate
        self.arrivalCoordinate = arrivalCoordinate
        
        self.crowdLevel = crowdLevel
        self.numStops = numStops
        self.lineColorHex = lineColorHex
        self.delayStatus = delayStatus
//        
//        self.walkToStationSec = walkToStationSec
//        self.stationToPlatformSec = stationToPlatformSec
    }
}
    
    // Represents a step in the navigation sequence (e.g., "Board at Oxford Circus")
    public struct TransitStep {
        let title: String            // For display (e.g., station name)
        let instruction: String      // For speech feedback (e.g., "Get on the Victoria line at Oxford Circus")
        let coordinate: CLLocationCoordinate2D  // Location for map marker
    }
    
    public struct EntryToPlatformTracker{
        let stationName: String
        let entranceTime: Date
        let platformTime: Date
        var duration: TimeInterval {
            return platformTime.timeIntervalSince(entranceTime)
        }
    }

public struct StationMeta {
    let id: String                // TfL StopPointId (比如 940GZZLUOXC)
    let coord: CLLocationCoordinate2D
}

