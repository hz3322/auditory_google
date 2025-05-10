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
        guard !transitInfos.isEmpty else {
            let alert = UIAlertController(title: "Route not ready", message: "Still loading route info, try again in a moment.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        navigateToSummary(with: transitInfos[0]) // Use first segment for now
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
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let legs = routes.first?["legs"] as? [[String: Any]],
                  let steps = legs.first?["steps"] as? [[String: Any]] else {
                print("Failed to parse route steps")
                DispatchQueue.main.async {
                    self?.estimatedTimeLabel.text = "Estimated Time: --"
                }
                return
            }

            print("Route steps extracted successfully")
            let (walkMin, transitMin, walkSteps, transitSegments) = self.calculateRouteTimes(from: steps)

            self.parsedWalkSteps = walkSteps
            let speedMultiplier = Double(self.speedSlider.value)
            let totalAdjusted = (walkMin / speedMultiplier) + transitMin

            if !transitSegments.isEmpty {
                print("Found \(transitSegments.count) transit segments")
                // Fetch stop names for each transit segment
                let group = DispatchGroup()
                var updatedSegments = transitSegments
                
                for (index, segment) in transitSegments.enumerated() {
                    group.enter()
                    self.fetchStopNames(for: segment) { updated in
                        updatedSegments[index] = updated
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.transitInfos = updatedSegments
                    self.drawPolyline(from: steps)
                    self.estimatedTimeLabel.text = String(format: "Estimated Time: %.0f min", totalAdjusted)
                }
            } else {
                print("No transit segments found")
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

    private func calculateRouteTimes(from steps: [[String: Any]]) -> (Double, Double, [WalkStep], [TransitInfo]) {
        var walkMin = 0.0, transitMin = 0.0
        var walkSteps: [WalkStep] = []
        var transitInfos: [TransitInfo] = []

        for step in steps {
            guard let mode = step["travel_mode"] as? String else { continue }

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
                            walkSteps.append(WalkStep(instruction: cleaned, distanceText: distText, durationText: dt))
                            walkMin += dv / 60.0
                        }
                    }
                }
            } else if mode == "TRANSIT" {
                if let d = step["duration"] as? [String: Any],
                   let value = d["value"] as? Double {
                    transitMin += value / 60.0
                }

                if let td = step["transit_details"] as? [String: Any],
                   let line = td["line"] as? [String: Any],
                   let shortName = line["short_name"] as? String ?? line["name"] as? String,
                   let dep = td["departure_stop"] as? [String: Any],
                   let arr = td["arrival_stop"] as? [String: Any],
                   let depTime = td["departure_time"] as? [String: Any],
                   let arrTime = td["arrival_time"] as? [String: Any] {

                    let durationText = "\(depTime["text"] ?? "") - \(arrTime["text"] ?? "")"
                    let info = TransitInfo(
                        lineName: shortName,
                        departureStation: dep["name"] as? String ?? "-",
                        arrivalStation: arr["name"] as? String ?? "-",
                        durationText: durationText,
                        platform: td["departure_platform"] as? String,
                        crowdLevel: td["crowd_level"] as? String,
                        numStops: td["num_stops"] as? Int,
                        lineColorHex: line["color"] as? String
                    )
                    transitInfos.append(info)
                }
            }
        }

        return (walkMin, transitMin, walkSteps, transitInfos)
    }
   
    private func fetchStopNames(for transit: TransitInfo, completion: @escaping (TransitInfo) -> Void) {
        // Check if it's a National Rail line
        let nationalRailOperators = [
            "Southern", "Thameslink", "Southeastern", "South Western Railway",
            "Chiltern Railways", "Avanti West Coast", "CrossCountry",
            "East Midlands Railway", "Greater Anglia", "Great Western Railway",
            "London Northwestern Railway", "LNER", "TransPennine Express",
            "West Midlands Railway"
        ]
        
        // Only use National Rail endpoint for actual National Rail operators
        let isNationalRail = nationalRailOperators.contains { operatorName in
            transit.lineName == operatorName
        }
        
        if isNationalRail {
            print("🚂 Using National Rail endpoint for operator: \(transit.lineName)")
            fetchNationalRailStops(for: transit, completion: completion)
            return
        }
        
        // For TfL lines, use the original method
        guard let lineId = tflLineId(from: transit.lineName),
              let url = URL(string: "https://api.tfl.gov.uk/Line/\(lineId)/Route/Sequence/inbound") else {
            print("⚠️ Invalid or unsupported line name: \(transit.lineName)")
            return
        }

        print("🚇 Using TfL endpoint for line: \(transit.lineName)")
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
    
    private func fetchNationalRailStops(for transit: TransitInfo, completion: @escaping (TransitInfo) -> Void) {
        // Map National Rail operators to their TfL API IDs
        let nationalRailMapping: [String: String] = [
            "Southern": "southern",
            "Thameslink": "thameslink",
            "Southeastern": "southeastern",
            "South Western Railway": "south-western-railway",
            "Chiltern Railways": "chiltern",
            "Avanti West Coast": "avanti-west-coast",
            "CrossCountry": "crosscountry",
            "East Midlands Railway": "east-midlands-railway",
            "Greater Anglia": "greater-anglia",
            "Great Western Railway": "great-western-railway",
            "London Northwestern Railway": "london-northwestern-railway",
            "LNER": "lner",
            "TransPennine Express": "transpennine-express",
            "West Midlands Railway": "west-midlands-railway",
            "Great Northern": "great-northern"
        ]
        
        // Find the TfL API ID for this operator
        guard let lineId = nationalRailMapping[transit.lineName] else {
            print("⚠️ Unknown National Rail operator: \(transit.lineName)")
            // Return just the departure and arrival stations
            var updated = transit
            updated.stopNames = [transit.departureStation, transit.arrivalStation]
            DispatchQueue.main.async { completion(updated) }
            return
        }
        
        // Use the Line API to get route information
        let urlString = "https://api.tfl.gov.uk/Line/\(lineId)/Route/Sequence/inbound"
        guard let url = URL(string: urlString) else {
            print("⚠️ Failed to create URL for \(transit.lineName)")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("0bc9522b0b77427eb20e858550d6a072", forHTTPHeaderField: "app_key")
        
        print("🔍 Fetching \(transit.lineName) line information")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("⚠️ No data received")
                return
            }
            
            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Raw response: \(jsonString)")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sequences = json["stopPointSequences"] as? [[String: Any]],
                  let firstSequence = sequences.first,
                  let stops = firstSequence["stopPoint"] as? [[String: Any]] else {
                print("⚠️ Failed to parse \(transit.lineName) line data")
                return
            }
            
            let stationNames = stops.compactMap { stop -> String? in
                if let name = stop["name"] as? String {
                    return name
                } else if let commonName = stop["commonName"] as? String {
                    return commonName
                }
                return nil
            }
            
            print("📍 Available stations: \(stationNames.joined(separator: ", "))")
            
            // Find the stations between departure and arrival
            if let departureIndex = stationNames.firstIndex(where: { $0.contains(transit.departureStation) }),
               let arrivalIndex = stationNames.firstIndex(where: { $0.contains(transit.arrivalStation) }) {
                let startIndex = min(departureIndex, arrivalIndex)
                let endIndex = max(departureIndex, arrivalIndex)
                let relevantStops = Array(stationNames[startIndex...endIndex])
                
                print("✅ Found \(relevantStops.count) stops between stations")
                var updated = transit
                updated.stopNames = relevantStops
                DispatchQueue.main.async { completion(updated) }
            } else {
                print("⚠️ Could not find departure or arrival station in route")
                // If we can't find the exact stations, return at least the departure and arrival
                var updated = transit
                updated.stopNames = [transit.departureStation, transit.arrivalStation]
                DispatchQueue.main.async { completion(updated) }
            }
        }.resume()
    }
    
    private func fetchRoutesForStation(stationId: String, transit: TransitInfo, completion: @escaping (TransitInfo) -> Void) {
        let urlString = "https://api.tfl.gov.uk/StopPoint/\(stationId)/Route"
        guard let url = URL(string: urlString) else {
            print("⚠️ Failed to create URL for routes")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("0bc9522b0b77427eb20e858550d6a072", forHTTPHeaderField: "app_key")
        
        print("🔍 Fetching routes for station ID: \(stationId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error)")
                return
            }
            
            guard let data = data,
                  let routes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("⚠️ Failed to parse routes")
                return
            }
            
            print("📦 Found \(routes.count) routes")
            
            // Find the route that matches our line name
            let matchingRoute = routes.first { route in
                guard let name = route["name"] as? String else { return false }
                return name.contains(transit.lineName)
            }
            
            if let route = matchingRoute,
               let stations = route["stations"] as? [[String: Any]] {
                let stationNames = stations.compactMap { $0["name"] as? String }
                print("📍 Available stations: \(stationNames.joined(separator: ", "))")
                
                // Find the stations between departure and arrival
                if let departureIndex = stationNames.firstIndex(where: { $0.contains(transit.departureStation) }),
                   let arrivalIndex = stationNames.firstIndex(where: { $0.contains(transit.arrivalStation) }) {
                    let startIndex = min(departureIndex, arrivalIndex)
                    let endIndex = max(departureIndex, arrivalIndex)
                    let relevantStops = Array(stationNames[startIndex...endIndex])
                    
                    print("✅ Found \(relevantStops.count) stops between stations")
                    var updated = transit
                    updated.stopNames = relevantStops
                    DispatchQueue.main.async { completion(updated) }
                } else {
                    print("⚠️ Could not find departure or arrival station in route")
                }
            } else {
                print("⚠️ No matching route found")
            }
        }.resume()
    }

    private func navigateToSummary(with info: TransitInfo) {
        let summaryVC = RouteSummaryViewController()
        summaryVC.totalEstimatedTime = estimatedTimeLabel.text
        summaryVC.walkToStationTime = parsedWalkSteps.first?.durationText
        summaryVC.walkToDestinationTime = parsedWalkSteps.last?.durationText
        summaryVC.transitInfos = transitInfos  // Pass all transit segments
        navigationController?.pushViewController(summaryVC, animated: true)
    }
    
    func tflLineId(from lineName: String) -> String? {
        let mapping: [String: String] = [
            // London Underground
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
            "Waterloo & City": "waterloo-city",
            
            // Other TfL services
            "London Overground": "london-overground",
            "Elizabeth": "elizabeth",
            "Elizabeth line": "elizabeth",
            "TfL Rail": "elizabeth",
            "DLR": "dlr",
            "Tram": "tram"
        ]
        
        // Try exact match first
        if let id = mapping[lineName] {
            return id
        }
        
        // Try case-insensitive match
        let lowercasedName = lineName.lowercased()
        for (key, value) in mapping {
            if key.lowercased() == lowercasedName {
                return value
            }
        }
        
        return nil
    }
}

