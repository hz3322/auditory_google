import Foundation
import UIKit

struct CatchInfo {
    let lineName: String             // District / Circle / etc.
    let lineColorHex: String
    let fromStation: String
    let toStation: String
    let stops: [String]
    let expectedArrival: String      
    let expectedArrivalDate: Date
    let timeToStation: Double
    
    var timeLeftToCatch: TimeInterval
    var catchStatus: CatchStatus
    
    
    // Thresholds for determining catch status (in seconds)
    // timeLeftToCatch = (Train Arrival Time) - (Time NOW) - (Time needed from station entrance to platform)
    static let easyThreshold: TimeInterval = 90     // > 1.5 minutes buffer
    static let hurryThreshold: TimeInterval = 20      // 20s to 1.5m buffer
    static let toughThreshold: TimeInterval = -40   // Up to 30s late for platform (might "冲一冲")

    static func determineInitialCatchStatus(timeLeftToCatch: TimeInterval) -> CatchStatus {
        if timeLeftToCatch > easyThreshold {
            return .easy
        } else if timeLeftToCatch > hurryThreshold {
            return .hurry
        } else if timeLeftToCatch > toughThreshold {
            return .tough
        } else {
            return .missed
        }
    }
}
