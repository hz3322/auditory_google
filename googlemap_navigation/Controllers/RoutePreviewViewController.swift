// Final cleaned-up version of RoutePreviewViewController.swift with manual user confirmation

import UIKit
import GoogleMaps
import CoreLocation

class RoutePreviewViewController: UIViewController {
    var startLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var parsedWalkSteps: [WalkStep] = []
    var transitInfo: TransitInfo? = nil
    private var mapView: GMSMapView!
    private let travelModeSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Transit"])
        control.selectedSegmentIndex = 0
        control.isEnabled = false
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
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
        print("✅ RoutePreviewViewController loaded")
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
        view.addSubview(confirmButton)

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
            estimatedTimeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            confirmButton.topAnchor.constraint(equalTo: estimatedTimeLabel.bottomAnchor, constant: 30),
            confirmButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 180),
            confirmButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupActions() {
        travelModeSegmentedControl.addTarget(self, action: #selector(routeOptionsChanged), for: .valueChanged)
        speedSlider.addTarget(self, action: #selector(routeOptionsChanged), for: .valueChanged)
        confirmButton.addTarget(self, action: #selector(confirmRouteTapped), for: .touchUpInside)
    }

    @objc private func confirmRouteTapped() {
        guard let transit = transitInfo else {
            let alert = UIAlertController(title: "Route not ready", message: "Still loading route info, try again in a moment.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        navigateToSummary(with: transit)
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
        let apiKey = "AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE"
        let urlStr = "https://maps.googleapis.com/maps/api/directions/json?origin=\(from.latitude),\(from.longitude)&destination=\(to.latitude),\(to.longitude)&mode=transit&transit_mode=subway|train&region=uk&key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }

        print("Fetching route from API...")
        print("API URL: \(urlStr)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("API Error: \(error)")
                return
            }
            
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Failed to parse API response")
                return
            }
            
            print("API Response received")
            
            // Print the complete route information
            if let routes = json["routes"] as? [[String: Any]] {
                print("Found \(routes.count) routes")
                for (index, route) in routes.enumerated() {
                    print("\nRoute \(index + 1):")
                    if let legs = route["legs"] as? [[String: Any]] {
                        for (legIndex, leg) in legs.enumerated() {
                            print("  Leg \(legIndex + 1):")
                            if let steps = leg["steps"] as? [[String: Any]] {
                                print("    Steps:")
                                for (stepIndex, step) in steps.enumerated() {
                                    if let mode = step["travel_mode"] as? String {
                                        print("      Step \(stepIndex + 1) - Mode: \(mode)")
                                        if mode == "TRANSIT" {
                                            if let td = step["transit_details"] as? [String: Any] {
                                                print("        Transit Details:")
                                                if let line = td["line"] as? [String: Any] {
                                                    print("          Line: \(line)")
                                                }
                                                if let dep = td["departure_stop"] as? [String: Any] {
                                                    print("          Departure: \(dep)")
                                                }
                                                if let arr = td["arrival_stop"] as? [String: Any] {
                                                    print("          Arrival: \(arr)")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            guard let routes = json["routes"] as? [[String: Any]],
                  let leg = routes.first?["legs"] as? [[String: Any]],
                  let steps = leg.first?["steps"] as? [[String: Any]] else {
                print("Failed to extract route steps from API response")
                DispatchQueue.main.async { 
                                          self.estimatedTimeLabel.text = "Estimated Time: --" }
                return
            }

            print("Route steps extracted successfully")
            let (walkMin, transitMin, walkSteps, baseTransit) = self.calculateRouteTimes(from: steps)
            print("Transit info created: \(baseTransit != nil ? "Yes" : "No")")
            
            self.parsedWalkSteps = walkSteps
            let speedMultiplier = Double(self.speedSlider.value)
            let totalAdjusted = (walkMin / speedMultiplier) + transitMin

            if let info = baseTransit {
                print("Fetching stop names for transit line: \(info.lineName)")
                self.fetchStopNames(for: info) { full in
                    print("Stop names fetched successfully")
                    self.transitInfo = full
                    DispatchQueue.main.async {
                        self.drawPolyline(from: steps)
                        self.estimatedTimeLabel.text = String(format: "Estimated Time: %.0f min", totalAdjusted)
                    }
                }
            } else {
                print("No transit info available")
                DispatchQueue.main.async {
                    self.drawPolyline(from: steps)
                    self.estimatedTimeLabel.text = String(format: "Estimated Time: %.0f min", totalAdjusted)
                }
            }
        }.resume()
    }

    private func drawPolyline(from steps: [[String: Any]]) {
        DispatchQueue.main.async {
            self.mapView.clear()
            var bounds = GMSCoordinateBounds()
            for step in steps {
                guard let mode = step["travel_mode"] as? String,
                      let polylineDict = step["polyline"] as? [String: Any],
                      let points = polylineDict["points"] as? String,
                      let path = GMSPath(fromEncodedPath: points) else { continue }

                let polyline = GMSPolyline(path: path)
                polyline.strokeWidth = 5
                polyline.map = self.mapView
                polyline.strokeColor = (mode == "WALKING") ? .systemTeal : .systemBlue

                for i in 0..<path.count() {
                    bounds = bounds.includingCoordinate(path.coordinate(at: i))
                }
            }
            let update = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40))
            self.mapView.animate(with: update)
        }
    }

    private func calculateRouteTimes(from steps: [[String: Any]]) -> (Double, Double, [WalkStep], TransitInfo?) {
        var walkMin = 0.0, transitMin = 0.0, stepsList: [WalkStep] = []
        var transitInfo: TransitInfo?

        print("Starting to process \(steps.count) steps")
        
        for (index, step) in steps.enumerated() {
            guard let mode = step["travel_mode"] as? String else {
                print("Step \(index): No travel mode found")
                continue
            }
            
            print("Step \(index): Processing \(mode) mode")

            if mode == "WALKING" {
                if let sub = step["steps"] as? [[String: Any]] {
                    for s in sub {
                        if let d = s["duration"] as? [String: Any],
                           let dv = d["value"] as? Double,
                           let dt = d["text"] as? String,
                           let dist = s["distance"] as? [String: Any],
                           let distText = dist["text"] as? String,
                           let html = s["html_instructions"] as? String {
                            let cleaned = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                            stepsList.append(WalkStep(instruction: cleaned, distanceText: distText, durationText: dt))
                            walkMin += dv / 60.0
                        }
                    }
                }
            } else if mode == "TRANSIT" {
                print("Found TRANSIT step, checking details...")
                
                if let d = step["duration"] as? [String: Any],
                   let value = d["value"] as? Double {
                    transitMin += value / 60.0
                    print("Transit duration: \(value/60.0) minutes")
                }

                if let td = step["transit_details"] as? [String: Any] {
                    print("Transit details found")
                    
                    if let line = td["line"] as? [String: Any] {
                        print("Line info found")
                        
                        // Get line name from either short_name or name
                        let lineName: String
                        if let shortName = line["short_name"] as? String {
                            lineName = shortName
                            print("Using line short name: \(lineName)")
                        } else if let name = line["name"] as? String {
                            lineName = name
                            print("Using line name: \(lineName)")
                        } else {
                            print("No line name found")
                            continue
                        }
                            
                        if let dep = td["departure_stop"] as? [String: Any],
                           let arr = td["arrival_stop"] as? [String: Any],
                           let depTime = td["departure_time"] as? [String: Any],
                           let arrTime = td["arrival_time"] as? [String: Any] {
                            
                            let platform = td["departure_platform"] as? String
                            let crowd = td["crowd_level"] as? String
                            let stops = td["num_stops"] as? Int
                            let hex = line["color"] as? String
                            
                            // Create duration text from departure and arrival times
                            let durationText = "\(depTime["text"] ?? "") - \(arrTime["text"] ?? "")"

                            transitInfo = TransitInfo(
                                lineName: lineName,
                                departureStation: dep["name"] as? String ?? "-",
                                arrivalStation: arr["name"] as? String ?? "-",
                                durationText: durationText,
                                platform: platform,
                                crowdLevel: crowd,
                                numStops: stops,
                                lineColorHex: hex
                            )
                            
                            print("num of stops", stops)
                            print("Successfully created transit info")
                        } else {
                            print("Missing required transit details: departure/arrival stops or times")
                        }
                    } else {
                        print("No line information found")
                    }
                } else {
                    print("No transit details found in step")
                }
            }
        }

        return (walkMin, transitMin, stepsList, transitInfo)
    }

    private func fetchStopNames(for transit: TransitInfo, completion: @escaping (TransitInfo) -> Void) {
        guard let lineId = tflLineId(from: transit.lineName),
              let url = URL(string: "https://api.tfl.gov.uk/Line/\(lineId)/Route/Sequence/inbound") else {
            print("⚠️ Invalid or unsupported line name: \(transit.lineName)")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("0bc9522b0b77427eb20e858550d6a072", forHTTPHeaderField: "app_key")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sequences = json["stopPointSequences"] as? [[String: Any]],
                  let stops = sequences.first?["stopPoint"] as? [[String: Any]] else { return }

            let names = stops.compactMap { $0["name"] as? String }
            var updated = transit
            updated.stopNames = names
            DispatchQueue.main.async { completion(updated) }
        }.resume()
    }

    private func navigateToSummary(with info: TransitInfo) {
        let summaryVC = RouteSummaryViewController()
        summaryVC.totalEstimatedTime = estimatedTimeLabel.text
        summaryVC.walkToStationTime = parsedWalkSteps.first?.durationText
        summaryVC.walkToDestinationTime = parsedWalkSteps.last?.durationText
        summaryVC.transitInfo = info
        navigationController?.pushViewController(summaryVC, animated: true)
    }
    
    func tflLineId(from lineName: String) -> String? {
        let mapping: [String: String] = [
            "Bakerloo": "bakerloo",
            "Central": "central",
            "Circle": "circle",
            "District": "district",
            "Hammersmith & City": "hammersmith-city",
            "Jubilee": "jubilee",
            "Metropolitan": "metropolitan",
            "Northern": "northern",
            "Piccadilly": "piccadilly",
            "Victoria": "victoria",
            "Waterloo & City": "waterloo-city"
        ]
        return mapping[lineName]
    }
}

