import AVFoundation
import Foundation
import CoreLocation
import GoogleMaps

class AuditoryFeedbackManager {
    static let shared = AuditoryFeedbackManager()
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastFeedbackTime: Date = Date()
    private let minimumFeedbackInterval: TimeInterval = 20.0 // 20 seconds between feedbacks
    private var currentSegment: (catchStatus: String, requiredPace: Double)?
    private var trainStatus: (arrivalTime: TimeInterval, isDelayed: Bool, delayMinutes: Int)?
    private var isInPlatformZone: Bool = false

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

    private func checkAndProvideFeedback() {
        let now = Date()
        guard now.timeIntervalSince(lastFeedbackTime) >= minimumFeedbackInterval else {
            return
        }

        // Check for train delay first
        if let trainStatus = trainStatus, trainStatus.isDelayed {
            playFeedback(.trainDelayed(minutes: trainStatus.delayMinutes))
            lastFeedbackTime = now
            return
        }

        // Check for train arrival
        if let trainStatus = trainStatus, trainStatus.arrivalTime < 60 && isInPlatformZone {
            playFeedback(.trainArrivingNow)
            lastFeedbackTime = now
            return
        }

        // Check pacing status
        if let segment = currentSegment {
            switch segment.catchStatus {
            case "Hurry":
                let currentPace = MotionManager.shared.currentSpeed
                if currentPace < segment.requiredPace {
                    playFeedback(.speedUp)
                    lastFeedbackTime = now
                }
            case "Tough":
                if let trainStatus = trainStatus, trainStatus.arrivalTime < 60 {
                    playFeedback(.likelyMissed)
                    lastFeedbackTime = now
                }
            case "Easy":
                playFeedback(.onTime)
                lastFeedbackTime = now
            default:
                break
            }
        }
    }

    private func playFeedback(_ type: FeedbackType) {
        // Play sound effect
        if let fileName = type.soundFileName,
           let url = Bundle.main.url(forResource: fileName, withExtension: nil) {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        }

        // Provide speech feedback
        if let speech = type.speechText {
            let utterance = AVSpeechUtterance(string: speech)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            utterance.rate = 0.5
            speechSynthesizer.speak(utterance)
        }
    }

    func stopFeedback() {
        audioPlayer?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}
