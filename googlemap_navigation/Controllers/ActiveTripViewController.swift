import UIKit
import GoogleMaps
import CoreLocation
import AVFoundation

class ActiveTripViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {
    
    private let locationManager = CLLocationManager()
    private var mapView: GMSMapView!
    private var routePolyline: GMSPolyline?
    private var currentLocationMarker: GMSMarker?
    private var destinationMarker: GMSMarker?
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .systemBlue
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private let distanceLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let nextInstructionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupUI()
        setupSpeechSynthesizer()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Active Trip"
        
        // Setup map view
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 15)
        let options = GMSMapViewOptions()
        options.camera = camera
        mapView = GMSMapView(options: options)

        mapView.camera = camera
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        // Add other UI elements
        view.addSubview(progressView)
        view.addSubview(distanceLabel)
        view.addSubview(timeLabel)
        view.addSubview(nextInstructionLabel)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7),
            
            progressView.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            distanceLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 10),
            distanceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            distanceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            timeLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 10),
            timeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            timeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            nextInstructionLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 20),
            nextInstructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nextInstructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupSpeechSynthesizer() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func speakInstruction(_ instruction: String) {
        let utterance = AVSpeechUtterance(string: instruction)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        // Update current location marker
        if currentLocationMarker == nil {
            currentLocationMarker = GMSMarker()
            currentLocationMarker?.icon = GMSMarker.markerImage(with: .blue)
        }
        currentLocationMarker?.position = location.coordinate
        currentLocationMarker?.map = mapView
        
        // Update camera position
        let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude,
                                            longitude: location.coordinate.longitude,
                                            zoom: 15)
        mapView.animate(to: camera)
        
        // Update progress and instructions
        updateNavigationInfo()
    }
    
    private func updateNavigationInfo() {
        // Update progress bar, distance, time, and next instruction
        // This would be implemented based on the actual route and current position
        progressView.progress = 0.5 // Example value
        distanceLabel.text = "Distance remaining: 2.5 km"
        timeLabel.text = "Estimated time: 15 minutes"
        nextInstructionLabel.text = "In 200 meters, turn right onto Main Street"
        
        // Speak the next instruction
        speakInstruction("In 200 meters, turn right onto Main Street")
    }
    
    // MARK: - GMSMapViewDelegate
    
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        // Handle marker taps if needed
        return true
    }
} 
