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

public struct TransitInfo {
    public let lineName: String
    public let departureStation: String
    public let arrivalStation: String
    public let durationText: String
    public let platform: String?
    public let crowdLevel: String?
    public let numStops: Int?
    public let lineColorHex: String?
    public var stopNames: [String]
    
    public init(lineName: String, departureStation: String, arrivalStation: String, durationText: String, platform: String?, crowdLevel: String?, numStops: Int?, lineColorHex: String?, stopNames: [String] = []) {
        self.lineName = lineName
        self.departureStation = departureStation
        self.arrivalStation = arrivalStation
        self.durationText = durationText
        self.platform = platform
        self.crowdLevel = crowdLevel
        self.numStops = numStops
        self.lineColorHex = lineColorHex
        self.stopNames = stopNames
    }
} 