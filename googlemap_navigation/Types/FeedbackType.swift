import Foundation


enum FeedbackType {
    case speedUp
    case onTime
    case likelyMissed
    case trainArrivingNow
    case trainDelayed(minutes: Int)
    case transferSoon(nextLine: String)

    var soundFileName: String? {
        switch self {
        case .speedUp: return "speed_up.wav"
        case .likelyMissed: return "missed_alert.wav"
        case .trainArrivingNow: return "train_approaching.wav"
        case .trainDelayed: return "delay_alert.wav"
        default: return nil
        }
    }

    var speechText: String? {
        switch self {
        case .speedUp: return "Speed up to catch the train"
        case .onTime: return "You're on time"
        case .likelyMissed: return "Likely to miss the train"
        case .trainArrivingNow: return "Train arriving now"
        case .trainDelayed(let min): return "Train delayed by \(min) minutes"
        case .transferSoon(let nextLine): return "Transfer to \(nextLine) coming up soon"
        }
    }

    var visualText: String? {
        switch self {
        case .speedUp: return "Speed Up"
        case .onTime: return "On Time"
        case .likelyMissed: return "Likely Missed"
        case .trainArrivingNow: return "Train Arriving Now"
        case .trainDelayed(let min): return "Delay: \(min) min"
        case .transferSoon(let nextLine): return "Transfer to \(nextLine)"
        }
    }
}


