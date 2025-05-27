import Foundation
import UIKit

struct CatchInfo {
    let timeToStation: TimeInterval // This is the fixed entryToPlatformSec
    let expectedArrival: String     // Formatted time string e.g., "23:30"
    let expectedArrivalDate: Date   // Actual date object for sorting
    let timeLeftToCatch: TimeInterval // Time buffer (positive means spare time, negative means late to platform)
    let catchStatus: CatchStatus      // Calculated status for this specific train prediction

    // Thresholds for determining catch status (in seconds)
    // timeLeftToCatch = (Train Arrival Time) - (Time NOW) - (Time needed from station entrance to platform)
    static let easyThreshold: TimeInterval = 90     // > 1.5 minutes buffer
    static let hurryThreshold: TimeInterval = 20      // 20s to 1.5m buffer
    static let toughThreshold: TimeInterval = -30   // Up to 30s late for platform (might "冲一冲")

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
