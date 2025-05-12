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
    public let lineName: String
    public let departureStation: String
    public let arrivalStation: String
    public let durationText: String
    public let platform: String?
    public let crowdLevel: CrowdLevel
    public let numStops: Int?
    public let lineColorHex: String?
    public let delayStatus: String?
    public var stopNames: [String]

    public init(
        lineName: String,
        departureStation: String,
        arrivalStation: String,
        durationText: String,
        platform: String?,
        crowdLevel: CrowdLevel,
        numStops: Int?,
        lineColorHex: String?,
        delayStatus: String?,
        stopNames: [String] = []
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
    }
}
