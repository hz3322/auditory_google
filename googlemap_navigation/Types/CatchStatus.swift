import UIKit

enum CatchStatus {
    case easy       // Plenty of time
    case hurry      // Need to speed up, but likely
    case tough      // Possible with effort or slight train delay
    case missed     // Very unlikely or missed

    var displayText: String {
        switch self {
        case .easy: return "EASY"
        case .hurry: return "HURRY"
        case .tough: return "TOUGH!"
        case .missed: return "MISSED"
        }
    }

    var displayColor: UIColor {
        switch self {
        case .easy: return UIColor.systemGreen.withAlphaComponent(0.85)
        case .hurry: return UIColor.systemOrange.withAlphaComponent(0.85)
        case .tough: return UIColor.systemRed.withAlphaComponent(0.85)
        case .missed: return UIColor.systemGray 
        }
    }
    
    var systemIconName: String? {
        switch self {
        case .easy: return "figure.walk"
        case .hurry: return "figure.run"
        case .tough: return "bolt.fill"   
        case .missed: return "xmark.circle.fill"
        }
    }
    
}
