
import Foundation


enum FeedbackType {
    case trainApproaching(platform: String)
    case trainArrived(platform: String)
    case transferSoon(nextLine: String)
    case delay(minutes: Int)

    var soundFileName: String? {
        switch self {
        case .trainApproaching: return "train_approaching.wav"
        case .trainArrived: return "train_arrived.wav"
        case .delay: return "delay_alert.wav"
        default: return nil
        }
    }

    var speechText: String? {
        switch self {
        case .trainApproaching(let line): return "\(line) train arriving"
        case .trainArrived(let line): return "train arrived."
        case .transferSoon: return "Transfer is coming up soon."
        case .delay(let min): return "Train delayed by \(min) minutes."
        }
    }

    var visualText: String? {
        switch self {
        case .trainApproaching(let platform):
            return "Approaching · Platform \(platform)"
        case .trainArrived(let platform):
            return "Arrived · Platform \(platform)"
        case .transferSoon(let nextLine):
            return "Transfer to \(nextLine)"
        case .delay(let min):
            return "Delay: \(min) min"
        }
    }
}


