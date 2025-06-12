import AVFoundation
import Foundation
import CoreLocation
import GoogleMaps
import UIKit

class AuditoryFeedbackManager {
    static let shared = AuditoryFeedbackManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastFeedbackTime: Date = Date()
    private let minimumFeedbackInterval: TimeInterval = 20.0 // 20 seconds between feedbacks
    private var currentSegment: (catchStatus: String, requiredPace: Double)?
    private var trainStatus: (arrivalTime: TimeInterval, isDelayed: Bool, delayMinutes: Int)?
    private var isInPlatformZone: Bool = false
    private weak var currentViewController: UIViewController?

    private init() {}

    // Update current segment information
    func updateSegment(catchStatus: String, requiredPace: Double) {
        currentSegment = (catchStatus, requiredPace)
        checkAndProvideFeedback()
    }

    // Update train status
    func updateTrainStatus(arrivalTime: TimeInterval, isDelayed: Bool, delayMinutes: Int) {
        trainStatus = (arrivalTime, isDelayed, delayMinutes)
        checkAndProvideFeedback()
    }

    // Update platform zone status
    func updatePlatformZoneStatus(isInZone: Bool) {
        isInPlatformZone = isInZone
        checkAndProvideFeedback()
    }
    
    // Set current view controller for showing alerts
    func setCurrentViewController(_ viewController: UIViewController) {
        currentViewController = viewController
    }

    private func checkAndProvideFeedback() {
        let now = Date()
        guard now.timeIntervalSince(lastFeedbackTime) >= minimumFeedbackInterval else {
            return
        }

        // Check for train arrival
        if let trainStatus = trainStatus, trainStatus.arrivalTime < 60 && isInPlatformZone {
            provideFeedback(.trainArrivingNow)
            lastFeedbackTime = now
            return
        }

        // Check pacing status
        if let segment = currentSegment {
            switch segment.catchStatus {
            case "Hurry":
                let currentPace = MotionManager.shared.currentSpeed
                if currentPace < segment.requiredPace {
                    provideFeedback(.speedUp)
                    lastFeedbackTime = now
                }
            case "Tough":
                if let trainStatus = trainStatus, trainStatus.arrivalTime < 60 {
                    provideFeedback(.likelyMissed)
                    lastFeedbackTime = now
                }
            case "Easy":
                provideFeedback(.onTime)
                lastFeedbackTime = now
            default:
                break
            }
        }
    }

    private func provideFeedback(_ type: FeedbackType) {
        // Provide speech feedback
        if let speech = type.speechText {
            let utterance = AVSpeechUtterance(string: speech)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            utterance.rate = 0.5
            speechSynthesizer.speak(utterance)
        }

        // Show visual feedback
        if let visualText = type.visualText {
            DispatchQueue.main.async { [weak self] in
                self?.showAlert(with: visualText)
            }
        }
    }
    
    private func showAlert(with message: String) {
        guard let viewController = currentViewController else { return }
        
        // Create alert controller
        let alert = UIAlertController(
            title: "Journey Update",
            message: message,
            preferredStyle: .alert
        )
        
        // Add OK button
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Show alert
        viewController.present(alert, animated: true)
        
        // Auto dismiss after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak alert] in
            alert?.dismiss(animated: true)
        }
    }

    func stopFeedback() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}
