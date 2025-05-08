import UIKit
import GoogleMaps
import CoreLocation

class RoutePreviewViewController: UIViewController {
    var startLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    private var mapView: GMSMapView!
    
    private let travelModeSegmentedControl: UISegmentedControl = {
        let items = ["Walking", "Cycling", "Driving"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let speedSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.5
        slider.maximumValue = 2.0
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
        view.addSubview(travelModeSegmentedControl)
        view.addSubview(speedSlider)
        view.addSubview(speedLabel)
        view.addSubview(estimatedTimeLabel)
        
        NSLayoutConstraint.activate([
            travelModeSegmentedControl.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 20),
            travelModeSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            travelModeSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            speedSlider.topAnchor.constraint(equalTo: travelModeSegmentedControl.bottomAnchor, constant: 20),
            speedSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            speedSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            speedLabel.topAnchor.constraint(equalTo: speedSlider.bottomAnchor, constant: 10),
            speedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            estimatedTimeLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 20),
            estimatedTimeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupActions() {
        travelModeSegmentedControl.addTarget(self, action: #selector(routeOptionsChanged), for: .valueChanged)
        speedSlider.addTarget(self, action: #selector(routeOptionsChanged), for: .valueChanged)
    }
    
    @objc private func routeOptionsChanged() {
        let speed = speedSlider.value
        let speedText: String
        if speed < 0.75 {
            speedText = "Slow"
        } else if speed > 1.25 {
            speedText = "Fast"
        } else {
            speedText = "Normal"
        }
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
        let apiKey = "AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE"
        let mode: String
        switch travelModeSegmentedControl.selectedSegmentIndex {
        case 0: mode = "walking"
        case 1: mode = "bicycling"
        case 2: mode = "driving"
        default: mode = "driving"
        }
        let urlStr = "https://maps.googleapis.com/maps/api/directions/json?origin=\(from.latitude),\(from.longitude)&destination=\(to.latitude),\(to.longitude)&mode=\(mode)&key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let route = routes.first,
                  let overviewPolyline = route["overview_polyline"] as? [String: Any],
                  let points = overviewPolyline["points"] as? String,
                  let legs = route["legs"] as? [[String: Any]],
                  let leg = legs.first,
                  let duration = leg["duration"] as? [String: Any],
                  let durationText = duration["text"] as? String else {
                DispatchQueue.main.async {
                    self?.estimatedTimeLabel.text = "Estimated Time: --"
                }
                return
            }
            DispatchQueue.main.async {
                self?.drawPath(from: points)
                self?.updateEstimatedTime(durationText: durationText)
            }
        }.resume()
    }
    
    private func drawPath(from polyStr: String) {
        let path = GMSPath(fromEncodedPath: polyStr)
        let polyline = GMSPolyline(path: path)
        polyline.strokeWidth = 5
        polyline.strokeColor = .systemBlue
        polyline.map = mapView
        
        // Adjust camera to fit route
        if let path = path {
            var bounds = GMSCoordinateBounds()
            for i in 0..<path.count() {
                bounds = bounds.includingCoordinate(path.coordinate(at: i))
            }
            let update = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40))
            mapView.animate(with: update)
        }
    }
    
    private func updateEstimatedTime(durationText: String) {
        let speedMultiplier = Double(speedSlider.value)
        var totalMinutes: Double = 0
        print("Duration from API: \(durationText)")

        let components = durationText.lowercased().components(separatedBy: " ")
        print("Parsed components: \(components)")

        if durationText.contains("分钟") {
                   if let minutes = Double(durationText.replacingOccurrences(of: "分钟", with: "").trimmingCharacters(in: .whitespaces)) {
                       totalMinutes = minutes
                   }
        } else {
            // Handle English format
            let components = durationText.lowercased().components(separatedBy: " ")
            print("Parsed components: \(components)")
            
            var i = 0
            while i < components.count {
                if let value = Double(components[i]) {
                    let unit = components[safe: i + 1] ?? ""
                    if unit.contains("hour") {
                        totalMinutes += value * 60
                    } else if unit.contains("min") {
                        totalMinutes += value
                    }
                    i += 2
                } else {
                    i += 1
                }
            }
        }

        guard totalMinutes > 0 else {
            estimatedTimeLabel.text = "Estimated Time: --"
            return
        }

        let adjustedMinutes = totalMinutes / speedMultiplier
        let displayText = String(format: "Estimated Time: %.0f min", adjustedMinutes)
        estimatedTimeLabel.text = displayText
    }

}
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
