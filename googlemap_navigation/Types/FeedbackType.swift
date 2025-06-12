import Foundation

enum FeedbackType {
    case speedUp
    case onTime
    case likelyMissed
    case trainArrivingNow
    case transferSoon(nextLine: String)

    var speechText: String? {
        switch self {
        case .speedUp: return "Speed up to catch the train"
        case .onTime: return "You're on time"
        case .likelyMissed: return "Likely to miss the train"
        case .trainArrivingNow: return "Train arriving now"
        }
    }

    var visualText: String? {
        switch self {
        case .speedUp: return "Speed Up"
        case .onTime: return "On Time"
        case .likelyMissed: return "Likely Missed"
        case .trainArrivingNow: return "Train Arriving Now"
        }
    }
}


