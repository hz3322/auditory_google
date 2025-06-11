import AVFoundation
import Foundation
import CoreLocation
import GoogleMaps

class AuditoryFeedbackManager {
    static let shared = AuditoryFeedbackManager()
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()

    private init() {}

    func playFeedback(_ type: FeedbackType, on mapView: GMSMapView?, at coordinate: CLLocationCoordinate2D? = nil) {
        if UserSettings.enableSound, let fileName = type.soundFileName,
           let url = Bundle.main.url(forResource: fileName, withExtension: nil) {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        }

        if UserSettings.enableSpeech, let speech = type.speechText {
            let utterance = AVSpeechUtterance(string: speech)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            utterance.rate = 0.5
            speechSynthesizer.speak(utterance)
        }

        if UserSettings.enableVisualCue, let message = type.visualText,
           let mapView = mapView, let coord = coordinate {
            showBubbleLabel(message, at: coord, on: mapView)
        }
    }
    
    private func showBubbleLabel(_ text: String, at coordinate: CLLocationCoordinate2D, on mapView: GMSMapView) {
        let point = mapView.projection.point(for: coordinate)

        let label = UILabel()
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.numberOfLines = 0
        label.alpha = 0
        label.frame = CGRect(x: point.x - 80, y: point.y - 60, width: 160, height: 40)

        mapView.addSubview(label)

        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 3.0, options: [], animations: {
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        }
    }
    
    
    func stopFeedback() {
        audioPlayer?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}
