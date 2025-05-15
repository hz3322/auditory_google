// NavigationManager.swift
// Handles real-time step-by-step navigation with voice guidance and map updates

import Foundation
import AVFoundation
import GoogleMaps
import CoreLocation

class NavigationManager {
    static let shared = NavigationManager()

    private var currentStepIndex = 0
    private var steps: [TransitStep] = []
    private var timer: Timer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var mapView: GMSMapView?
    private var onStatusUpdate: ((String) -> Void)?

    private init() {}

    /// Starts the navigation sequence
    func startNavigation(steps: [TransitStep], on mapView: GMSMapView, statusUpdate: ((String) -> Void)? = nil) {
        self.steps = steps
        self.mapView = mapView
        self.onStatusUpdate = statusUpdate
        currentStepIndex = 0
        startStepLoop()
    }

    /// Begins a loop that walks through the steps with intervals
    private func startStepLoop() {
        guard !steps.isEmpty else { return }
        announceCurrentStep()
        timer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.advanceToNextStep()
        }
    }

    /// Provides speech and map focus for current step
    private func announceCurrentStep() {
        guard currentStepIndex < steps.count else { return }
        let step = steps[currentStepIndex]

        // Voice guidance
        let utterance = AVSpeechUtterance(string: step.instruction)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)

        // Map marker
        if let mapView = mapView {
            let marker = GMSMarker(position: step.coordinate)
            marker.icon = GMSMarker.markerImage(with: .systemIndigo)
            marker.title = step.title
            marker.map = mapView

            // Move camera
            let update = GMSCameraUpdate.setTarget(step.coordinate, zoom: 15)
            mapView.animate(with: update)
        }

        onStatusUpdate?(step.instruction)
    }

    /// Advances to the next navigation step
    private func advanceToNextStep() {
        currentStepIndex += 1
        if currentStepIndex < steps.count {
            announceCurrentStep()
        } else {
            finishNavigation()
        }
    }

    /// Handles location updates from CLLocationManager
    func updateUserLocation(_ location: CLLocation) {
        guard currentStepIndex < steps.count else { return }
        let step = steps[currentStepIndex]
        let stepLocation = CLLocation(latitude: step.coordinate.latitude, longitude: step.coordinate.longitude)

        // Trigger next step when within 30m
        let distance = location.distance(from: stepLocation)
        if distance < 30 {
            advanceToNextStep()
        }
    }

    /// Stops the navigation process
    func stop() {
        timer?.invalidate()
        timer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        mapView = nil
        currentStepIndex = 0
        steps = []
        onStatusUpdate = nil
    }

    /// Finalization when all steps completed
    private func finishNavigation() {
        stop()
        onStatusUpdate?("Navigation completed.")
    }
}
