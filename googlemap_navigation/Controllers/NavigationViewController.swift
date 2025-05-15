//
//  NavigationViewController.swift
//  googlemap_navigation
//
//  Created by 赵韩雪 on 15/05/2025.
//


// NavigationViewController.swift
// Connects NavigationManager with UI and updates auditory + visual feedback

import UIKit
import CoreLocation
import GoogleMaps

class NavigationViewController: UIViewController, CLLocationManagerDelegate {
    var steps: [TransitStep] = []
    
    private let mapView = GMSMapView()
    private let locationManager = CLLocationManager()
    private let navigationManager = NavigationManager.shared

    // UI element to show current navigation status (optional)
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var transitInfos: [TransitInfo] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Live Navigation"

        setupMap()
        setupUI()
        setupLocationTracking()
        startNavigation()
    }

    private func setupMap() {
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
    }

    private func setupUI() {
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupLocationTracking() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        mapView.isMyLocationEnabled = true
    }

    private func startNavigation() {
        NavigationManager.shared.startNavigation(steps: steps, on: mapView)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        NavigationManager.shared.updateUserLocation(location)
        mapView.animate(toLocation: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// Usage: In RouteSummaryViewController, when user taps "Start Navigation"
// let vc = NavigationViewController()
// vc.transitInfos = self.transitInfos
// self.navigationController?.pushViewController(vc, animated: true)
