// Final cleaned-up version of RoutePreviewViewController.swift with manual user confirmation

import UIKit
import GoogleMaps
import CoreLocation

class RoutePreviewViewController: UIViewController {
    var startLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var parsedWalkSteps: [WalkStep] = []
    var transitInfos: [TransitInfo] = []     // Changed back to array to support transfers
    private var mapView: GMSMapView!
    
    
    // --------------------------------------- UI element ----------------------------------------- //
    private let speedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.6
        slider.maximumValue = 1.4
        slider.value = 1.0
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private let speedLabel: UILabel = {
        let label = UILabel()
        label.text = "Speed: Normal"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let estimatedTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "Estimated Time: --"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Confirm Route", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Route Preview"
        setupMap()
        setupUI()
        setupActions()
        showRouteIfPossible()
    }
    
    private func setupMap() {
        let camera = GMSCameraPosition.camera(withLatitude: startLocation?.latitude ?? 0,
                                              longitude: startLocation?.longitude ?? 0,
                                              zoom: 12)
        let options = GMSMapViewOptions()
        options.camera = camera
        mapView = GMSMapView(options: options)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
    }
    
    private func setupUI() {
        view.addSubview(speedSlider)
        view.addSubview(speedLabel)
        view.addSubview(estimatedTimeLabel)
        view.addSubview(confirmButton)
        
        NSLayoutConstraint.activate([
            speedSlider.topAnchor.constraint(equalTo:mapView.bottomAnchor, constant: 20),
            speedSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            speedSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            speedLabel.topAnchor.constraint(equalTo: speedSlider.bottomAnchor, constant: 10),
            speedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            estimatedTimeLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 20),
            estimatedTimeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            confirmButton.topAnchor.constraint(equalTo: estimatedTimeLabel.bottomAnchor, constant: 30),
            confirmButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 180),
            confirmButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupActions() {
        speedSlider.addTarget(self, action: #selector(routeOptionsChanged), for: .valueChanged)
        confirmButton.addTarget(self, action: #selector(confirmRouteTapped), for: .touchUpInside)
    }
    
    @objc private func routeOptionsChanged() {
        let speed = speedSlider.value
        let speedText = speed < 0.75 ? "Slow" : (speed > 1.25 ? "Fast" : "Normal")
        speedLabel.text = "Speed: \(speedText)"
        showRouteIfPossible()
    }
    
    private func showRouteIfPossible() {
        guard let start = startLocation, let end = destinationLocation else { return }
        mapView.clear()
        drawMarkers(start: start, end: end)
        fetchRoute(from: start, to: end)
    }
    
    private func drawMarkers(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) {
        let startMarker = GMSMarker(position: start)
        startMarker.title = "Start"
        startMarker.map = mapView
        
        let endMarker = GMSMarker(position: end)
        endMarker.title = "Destination"
        endMarker.map = mapView
    }
    
    private func fetchRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        RouteLogic.shared.fetchRoute(
            from: from,
            to: to,
            speedMultiplier: Double(self.speedSlider.value)
        ) { [weak self] walkSteps, transitSegments, totalTime, routeSteps in
            guard let self = self else { return }
            self.parsedWalkSteps = walkSteps
            self.transitInfos = transitSegments
            self.estimatedTimeLabel.text = String(format: "Estimated Time: %.0f min", totalTime)
            
            // Draw the route on the map
            self.drawPolyline(from: routeSteps)
        }
    }
    
    private func drawPolyline(from steps: [[String: Any]]) {
        DispatchQueue.main.async {
            self.mapView.clear()
            var bounds = GMSCoordinateBounds()
            
            // Draw markers for start and end points
            if let start = self.startLocation, let end = self.destinationLocation {
                self.drawMarkers(start: start, end: end)
            }
            
            for step in steps {
                guard let mode = step["travel_mode"] as? String,
                      let polylineDict = step["polyline"] as? [String: Any],
                      let points = polylineDict["points"] as? String,
                      let path = GMSPath(fromEncodedPath: points) else { continue }

                let polyline = GMSPolyline(path: path)
                polyline.strokeWidth = 5
                
                // Set different colors for walking and transit
                if mode == "WALKING" {
                    polyline.strokeColor = .systemTeal
                } else if mode == "TRANSIT" {
                    // Try to get the line color from transit details
                    if let td = step["transit_details"] as? [String: Any],
                       let line = td["line"] as? [String: Any],
                       let colorHex = line["color"] as? String {
                        polyline.strokeColor = UIColor(hex: colorHex) ?? .systemBlue
                    } else {
                        polyline.strokeColor = .systemBlue
                    }
                }
                
                polyline.map = self.mapView

                // Update bounds to include all points
                for i in 0..<path.count() {
                    bounds = bounds.includingCoordinate(path.coordinate(at: i))
                }
            }
            
            // Animate camera to show the entire route
            let update = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40))
            self.mapView.animate(with: update)
        }
    }
    
    @objc private func confirmRouteTapped() {
        guard !transitInfos.isEmpty else {
            let alert = UIAlertController(title: "Route not ready", message: "Still loading route info, try again in a moment.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        RouteLogic.shared.navigateToSummary(from: self, transitInfos: self.transitInfos, walkSteps: self.parsedWalkSteps, estimated: self.estimatedTimeLabel.text)
    }
}
    
    



