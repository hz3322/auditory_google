import UIKit
import GoogleMaps
import CoreLocation

class RoutePreviewViewController: UIViewController, GMSMapViewDelegate {
    // MARK: - Inputs
    var startLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var startLabelName: String?
    var destinationLabelName: String?
    var parsedWalkSteps: [WalkStep] = []
    var transitInfos: [TransitInfo] = []
    var walkToStationTime: String?
    var walkToDestinationTime: String?

    // MARK: - Internal state
    private var mapView: GMSMapView!
    private var stationCoordinates: [String: StationMeta] = [:]

    private var entryWalkMin: Double = 0.0
    private var exitWalkMin: Double = 0.0

    // MARK: - UI Elements
    private let estimatedTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "Estimated Time: --"
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Confirm Route", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(UIColor.label, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let bottomCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let topRouteLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bottomEstimatedLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.numberOfLines = 3
        label.backgroundColor = .white
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bottomConfirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Confirm Route", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
//        let _ = addLogoTitleHeader(title: "Route preview")
        view.backgroundColor = UIColor.systemBackground
        

        setupMap()
        setupUI()
        setupActions()
        showRouteIfPossible()
        loadStationCoordinates()
    }

    // MARK: - Map Setup
    private func setupMap() {
        let camera = GMSCameraPosition.camera(withLatitude: 51.5074, longitude: -0.1278, zoom: 12)
        mapView = GMSMapView()
        mapView.frame = view.bounds
        mapView.camera = camera
        mapView.delegate = self
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(bottomCardView)
        view.addSubview(topRouteLabel)
        bottomCardView.addSubview(bottomEstimatedLabel)
        bottomCardView.addSubview(bottomConfirmButton)

        NSLayoutConstraint.activate([
            topRouteLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topRouteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topRouteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topRouteLabel.heightAnchor.constraint(equalToConstant: 40),

            bottomCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomCardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomCardView.heightAnchor.constraint(equalToConstant: 140),

            bottomEstimatedLabel.topAnchor.constraint(equalTo: bottomCardView.topAnchor, constant: 20),
            bottomEstimatedLabel.leadingAnchor.constraint(equalTo: bottomCardView.leadingAnchor, constant: 20),
            bottomEstimatedLabel.trailingAnchor.constraint(equalTo: bottomCardView.trailingAnchor, constant: -20),
            bottomEstimatedLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            bottomConfirmButton.topAnchor.constraint(equalTo: bottomEstimatedLabel.bottomAnchor, constant: 12),
            bottomConfirmButton.leadingAnchor.constraint(equalTo: bottomCardView.leadingAnchor, constant: 20),
            bottomConfirmButton.trailingAnchor.constraint(equalTo: bottomCardView.trailingAnchor, constant: -20),
            bottomConfirmButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupActions() {
        bottomConfirmButton.addTarget(self, action: #selector(confirmRouteTapped), for: .touchUpInside)
    }

    // MARK: - Load and Render
    private func showRouteIfPossible() {
        guard let start = startLocation, let end = destinationLocation else { return }
        mapView.clear()
        fetchRoute(from: start, to: end)
    }

    private func fetchRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let userLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)

        RouteLogic.shared.fetchRoute(
            from: userLocation,
            to: to,
            speedMultiplier: 1.0
        ) {[weak self] walkSteps, transitSegments, totalTime, routeSteps, walkToStationMin, walkToDestinationMin in
            guard let self = self else { return }
            self.parsedWalkSteps = walkSteps
            self.transitInfos = transitSegments
            
            // set toplabel content
            if let firstTransit = transitSegments.first,
                  let lastTransit = transitSegments.last,
                  let departure = firstTransit.departureStation,
                  let arrival = lastTransit.arrivalStation {
                   self.topRouteLabel.text = "\(departure) → \(arrival)"
               } else {
                   self.topRouteLabel.text = "Route Preview"
               }
            

            
            
            // set bottomEstimatedLabel content
            let formattedTime = String(format: "%.0f", totalTime)
            self.bottomEstimatedLabel.text = "Estimated time: \(formattedTime) min"
            
            self.walkToStationTime = String(format: "%.0f min", walkToStationMin)
            self.walkToDestinationTime = String(format: "%.0f min", walkToDestinationMin)
            
            // Save the walk times
            self.entryWalkMin = walkToStationMin
            self.exitWalkMin = walkToDestinationMin

            self.drawPolyline(from: routeSteps)
            self.addMarkersAndPolylines()
        }
    }

    private func drawPolyline(from steps: [[String: Any]]) {
        var bounds = GMSCoordinateBounds()

        for step in steps {
            guard let mode = step["travel_mode"] as? String,
                  let polylineDict = step["polyline"] as? [String: Any],
                  let points = polylineDict["points"] as? String,
                  let path = GMSPath(fromEncodedPath: points) else { continue }

            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = 5

            if mode == "WALKING" {
                polyline.strokeColor = .systemTeal
            } else if mode == "TRANSIT" {
                if let td = step["transit_details"] as? [String: Any],
                   let line = td["line"] as? [String: Any],
                   let colorHex = line["color"] as? String {
                    polyline.strokeColor = UIColor(hex: colorHex)
                } else {
                    polyline.strokeColor = .systemBlue
                }
            }

            polyline.map = self.mapView

            for i in 0..<path.count() {
                bounds = bounds.includingCoordinate(path.coordinate(at: i))
            }
        }

        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
    }

    private func loadStationCoordinates() {
        RouteLogic.shared.loadAllTubeStations { [weak self] stationsDict in
            self?.stationCoordinates = stationsDict
            self?.addMarkersAndPolylines()
        }
    }

    private func addMarkersAndPolylines() {
        guard !transitInfos.isEmpty else { return }

        for info in transitInfos {
            guard let startName = info.departureStation,
                  let endName = info.arrivalStation,
                  let startMeta = stationCoordinates[startName],
                  let endMeta = stationCoordinates[endName] else { continue }

            // MARK: Marker + Station Label for Start
            let startMarker = GMSMarker(position: startMeta.coord)
            startMarker.icon = GMSMarker.markerImage(with: .systemBlue)
            startMarker.map = mapView
            addFloatingStationLabel(name: startName, coordinate: startMeta.coord)

            // MARK: Marker + Station Label for End
            let endMarker = GMSMarker(position: endMeta.coord)
            endMarker.icon = GMSMarker.markerImage(with: .systemRed)
            endMarker.map = mapView
            addFloatingStationLabel(name: endName, coordinate: endMeta.coord)

            // MARK: Polyline between stations
            let path = GMSMutablePath()
            path.add(startMeta.coord)
            path.add(endMeta.coord)

            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = 3.5
            polyline.strokeColor = UIColor(hex: info.lineColorHex ?? "#000000")
            polyline.map = mapView
        }

        // Adjust map camera
        if let first = transitInfos.first,
           let startMeta = first.departureStation.flatMap({ stationCoordinates[$0] }),
           let lastMeta = transitInfos.last?.arrivalStation.flatMap({ stationCoordinates[$0] }) {
            let bounds = GMSCoordinateBounds(coordinate: startMeta.coord, coordinate: lastMeta.coord)
            mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
        }
    }

    private func addLabeledMarker(title: String, coordinate: CLLocationCoordinate2D, color: UIColor) {
        let marker = GMSMarker(position: coordinate)
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.backgroundColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.layer.borderColor = UIColor.lightGray.cgColor
        label.layer.borderWidth = 0.5
        label.sizeToFit()
        label.frame = CGRect(x: 0, y: 0, width: label.frame.width + 12, height: 28)

        marker.iconView = label
        marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
        marker.map = mapView
    }

    // MARK: - Confirm & Navigation
    @objc private func confirmRouteTapped() {
        guard !transitInfos.isEmpty || !parsedWalkSteps.isEmpty else { // Check also for walk-only routes
            let alert = UIAlertController(title: "Route Not Ready",
                                          message: "Still loading route information or no route found. Please try again.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let summaryVC = RouteSummaryViewController()
        summaryVC.totalEstimatedTime = self.bottomEstimatedLabel.attributedText?.string ?? self.bottomEstimatedLabel.text
        summaryVC.walkToStationTime = String(format: "%.0f min", self.entryWalkMin)
        summaryVC.walkToDestinationTime = String(format: "%.0f min", self.exitWalkMin)
        
        // Process departure and arrival times from the first transit segment
        if let durationText = transitInfos.first?.durationText {
            let parts = durationText.components(separatedBy: " -")
            if parts.count == 2 {
                summaryVC.routeDepartureTime = parts[0]
                summaryVC.routeArrivalTime = parts[1]
            }
        }
        
        summaryVC.transitInfos = transitInfos
        
        // Convert [String: StationMeta] to [String: CLLocationCoordinate2D] before passing
        let coordinatesDict: [String: CLLocationCoordinate2D] = self.stationCoordinates.mapValues { $0.coord }
        summaryVC.stationCoordinates = coordinatesDict
        
        navigationController?.pushViewController(summaryVC, animated: true)
    }
    
    private func addFloatingStationLabel(name: String, coordinate: CLLocationCoordinate2D) {
        let point = mapView.projection.point(for: coordinate)

        let label = UILabel()
        label.text = name
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.backgroundColor = .clear
        label.sizeToFit()
        label.center = CGPoint(x: point.x, y: point.y - 30)
        label.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(label)
    }
}

