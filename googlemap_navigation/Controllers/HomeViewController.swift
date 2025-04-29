import UIKit
import GoogleMaps
import CoreLocation

class HomeViewController: UIViewController, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var mapView: GMSMapView!
    private var currentLocation: CLLocationCoordinate2D?

    private let startTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Start Point"
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let destinationTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter Destination"
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let startTripButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start the Trip", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Home"
        setupMap()
        setupFields()
        setupLocationManager()
        setupButton()
    }

    private func setupMap() {
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 12)
        let options = GMSMapViewOptions()
        options.camera = camera
        mapView = GMSMapView(options: options)

        mapView.camera = camera

        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
    }

    private func setupFields() {
        view.addSubview(startTextField)
        view.addSubview(destinationTextField)

        NSLayoutConstraint.activate([
            startTextField.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 24),
            startTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            startTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            startTextField.heightAnchor.constraint(equalToConstant: 44),

            destinationTextField.topAnchor.constraint(equalTo: startTextField.bottomAnchor, constant: 16),
            destinationTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            destinationTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            destinationTextField.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupButton() {
        view.addSubview(startTripButton)

        NSLayoutConstraint.activate([
            startTripButton.topAnchor.constraint(equalTo: destinationTextField.bottomAnchor, constant: 24),
            startTripButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startTripButton.widthAnchor.constraint(equalToConstant: 200),
            startTripButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        startTripButton.addTarget(self, action: #selector(startTripButtonTapped), for: .touchUpInside)
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        currentLocation = location.coordinate
        startTextField.text = "Current Location"
        let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude, longitude: location.coordinate.longitude, zoom: 12)
        mapView.animate(to: camera)

        // Add marker for current location
        mapView.clear()
        let marker = GMSMarker(position: location.coordinate)
        marker.title = "Current Location"
        marker.map = mapView
    }

    @objc private func startTripButtonTapped() {
        guard let destinationAddress = destinationTextField.text, !destinationAddress.isEmpty else {
            print("Destination is required.")
            return
        }
        
        let routePreviewVC = RoutePreviewViewController()
        
        if let startAddress = startTextField.text, !startAddress.isEmpty, startAddress != "Current Location" {
            // User entered a custom start address
            geocodeAddress(startAddress) { [weak self] startCoordinate in
                guard let startCoord = startCoordinate else {
                    print("Failed to find start address.")
                    return
                }
                self?.geocodeAddress(destinationAddress) { destinationCoordinate in
                    guard let destCoord = destinationCoordinate else {
                        print("Failed to find destination address.")
                        return
                    }
                    routePreviewVC.startLocation = startCoord
                    routePreviewVC.destinationLocation = destCoord
                    self?.navigationController?.pushViewController(routePreviewVC, animated: true)
                }
            }
        } else {
            // Use current GPS location as start
            guard let currentCoord = currentLocation else {
                print("Current location not available.")
                return
            }
            geocodeAddress(destinationAddress) { [weak self] destinationCoordinate in
                guard let destCoord = destinationCoordinate else {
                    print("Failed to find destination address.")
                    return
                }
                routePreviewVC.startLocation = currentCoord
                routePreviewVC.destinationLocation = destCoord
                self?.navigationController?.pushViewController(routePreviewVC, animated: true)
            }
        }
    }

    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let coordinate = placemarks?.first?.location?.coordinate {
                completion(coordinate)
            } else {
                completion(nil)
            }
        }
    }

}
