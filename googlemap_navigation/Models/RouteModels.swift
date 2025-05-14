import Foundation

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

public struct TransitInfo {
    var lineName: String
    var departureStation: String?
    var arrivalStation: String?
    var durationText: String?
    var platform: String?
    var crowdLevel: CrowdLevel?
    var numStops: Int?
    var lineColorHex: String?
    var delayStatus: String?
    var stopNames: [String] = []
    var durationTime: String?
    
    
    public init(
        lineName: String,
        departureStation: String?,
        arrivalStation: String?,
        durationText: String?,
        platform: String?,
        crowdLevel: CrowdLevel,
        numStops: Int?,
        lineColorHex: String?,
        delayStatus: String?,
        stopNames: [String] = [],
        durationTime: String? = nil
    ) {
        self.lineName = lineName
        self.departureStation = departureStation
        self.arrivalStation = arrivalStation
        self.durationText = durationText
        self.platform = platform
        self.crowdLevel = crowdLevel
        self.numStops = numStops
        self.lineColorHex = lineColorHex
        self.delayStatus = delayStatus
        self.stopNames = stopNames
        self.durationTime = durationTime
    }
}
