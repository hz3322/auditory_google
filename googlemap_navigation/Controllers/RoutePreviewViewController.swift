// RoutePreviewViewController.swift
// Cleaned version with line colors and live preview, with floating station name labels next to markers.

import UIKit
import GoogleMaps
import CoreLocation

class RoutePreviewViewController: UIViewController, GMSMapViewDelegate {
    // MARK: - Inputs
    var startLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var parsedWalkSteps: [WalkStep] = []
    var transitInfos: [TransitInfo] = []

    // MARK: - Internal state
    private var mapView: GMSMapView!
    private var stationCoordinates: [String: CLLocationCoordinate2D] = [:]

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

    private let bottomEstimatedLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.numberOfLines = 1
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
        view.backgroundColor = UIColor.systemBackground
        title = "Route Preview"

        setupMap()
        setupUI()
        setupActions()
        showRouteIfPossible()
        loadStationCoordinates()
    }

    // MARK: - Map Setup
    private func setupMap() {
        let camera = GMSCameraPosition.camera(withLatitude: 51.5074, longitude: -0.1278, zoom: 12)
        mapView = GMSMapView.map(withFrame: view.bounds, camera: camera)
        mapView.delegate = self
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(bottomCardView)
        bottomCardView.addSubview(bottomEstimatedLabel)
        bottomCardView.addSubview(bottomConfirmButton)

        NSLayoutConstraint.activate([
            bottomCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomCardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomCardView.heightAnchor.constraint(equalToConstant: 140),

            bottomEstimatedLabel.topAnchor.constraint(equalTo: bottomCardView.topAnchor, constant: 20),
            bottomEstimatedLabel.leadingAnchor.constraint(equalTo: bottomCardView.leadingAnchor, constant: 20),
            bottomEstimatedLabel.trailingAnchor.constraint(equalTo: bottomCardView.trailingAnchor, constant: -20),
            bottomEstimatedLabel.heightAnchor.constraint(equalToConstant: 24),

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
        ) { [weak self] walkSteps, transitSegments, totalTime, routeSteps in
            guard let self = self else { return }
            self.parsedWalkSteps = walkSteps
            self.transitInfos = transitSegments

            let formattedTime = String(format: "%.0f", totalTime)
            self.bottomEstimatedLabel.text = "Estimated time: \(formattedTime) min"

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
                    polyline.strokeColor = UIColor(hex: colorHex) ?? .systemBlue
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
                  let startCoord = stationCoordinates[startName],
                  let endCoord = stationCoordinates[endName] else { continue }

            let startMarker = GMSMarker(position: startCoord)
            startMarker.icon = GMSMarker.markerImage(with: .systemBlue)
            startMarker.title = startName
            startMarker.map = mapView

            let endMarker = GMSMarker(position: endCoord)
            endMarker.icon = GMSMarker.markerImage(with: .systemRed)
            endMarker.title = endName
            endMarker.map = mapView
        }

        if let first = transitInfos.first,
           let start = first.departureStation.flatMap({ stationCoordinates[$0] }),
           let last = transitInfos.last?.arrivalStation.flatMap({ stationCoordinates[$0] }) {
            let bounds = GMSCoordinateBounds(coordinate: start, coordinate: last)
            mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
        }
    }

    // MARK: - Confirm & Navigation
    @objc private func confirmRouteTapped() {
        guard !transitInfos.isEmpty else {
            let alert = UIAlertController(title: "Route not ready", message: "Still loading route info, try again in a moment.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        RouteLogic.shared.navigateToSummary(
            from: self,
            transitInfos: self.transitInfos,
            walkSteps: self.parsedWalkSteps,
            estimated: self.bottomEstimatedLabel.text
        )
    }
}

