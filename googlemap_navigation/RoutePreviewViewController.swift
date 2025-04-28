import UIKit
import GoogleMaps
import CoreLocation
import AudioToolbox


class RoutePreviewViewController: UIViewController, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private var mapView: GMSMapView!
    private var startLocation: CLLocationCoordinate2D?
    private var destinationLocation: CLLocationCoordinate2D?
    
    private let destinationTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter destination"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
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
    
    private let soundCheckButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Sound", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupUI()
        setupActions()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Route Preview"
        
        // Setup map view
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 15)
        mapView = GMSMapView.map(withFrame: view.bounds, camera: camera)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        // Add other UI elements
        view.addSubview(destinationTextField)
        view.addSubview(travelModeSegmentedControl)
        view.addSubview(speedSlider)
        view.addSubview(speedLabel)
        view.addSubview(estimatedTimeLabel)
        view.addSubview(soundCheckButton)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            
            destinationTextField.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 20),
            destinationTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            destinationTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            travelModeSegmentedControl.topAnchor.constraint(equalTo: destinationTextField.bottomAnchor, constant: 20),
            travelModeSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            travelModeSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            speedSlider.topAnchor.constraint(equalTo: travelModeSegmentedControl.bottomAnchor, constant: 20),
            speedSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            speedSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            speedLabel.topAnchor.constraint(equalTo: speedSlider.bottomAnchor, constant: 10),
            speedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            estimatedTimeLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 20),
            estimatedTimeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            soundCheckButton.topAnchor.constraint(equalTo: estimatedTimeLabel.bottomAnchor, constant: 20),
            soundCheckButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            soundCheckButton.widthAnchor.constraint(equalToConstant: 200),
            soundCheckButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupActions() {
        speedSlider.addTarget(self, action: #selector(speedSliderValueChanged), for: .valueChanged)
        soundCheckButton.addTarget(self, action: #selector(soundCheckTapped), for: .touchUpInside)
    }
    
    @objc private func speedSliderValueChanged() {
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
        updateEstimatedTime()
    }
    
    @objc private func soundCheckTapped() {
        // Play test sound
        AudioServicesPlaySystemSound(1007)
    }
    
    private func updateEstimatedTime() {
        // Calculate estimated time based on distance and speed
        guard let start = startLocation, let destination = destinationLocation else { return }
        
        let distance = GMSGeometryDistance(start, destination)
        let speed = Double(speedSlider.value)
        let travelMode = travelModeSegmentedControl.selectedSegmentIndex
        
        var baseSpeed: Double
        switch travelMode {
        case 0: // Walking
            baseSpeed = 5.0 // km/h
        case 1: // Cycling
            baseSpeed = 15.0 // km/h
        case 2: // Driving
            baseSpeed = 50.0 // km/h
        default:
            baseSpeed = 5.0
        }
        
        let adjustedSpeed = baseSpeed * speed
        let timeInHours = distance / (adjustedSpeed * 1000)
        let timeInMinutes = Int(timeInHours * 60)
        
        estimatedTimeLabel.text = "Estimated Time: \(timeInMinutes) minutes"
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        startLocation = location.coordinate
        
        let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude,
                                            longitude: location.coordinate.longitude,
                                            zoom: 15)
        mapView.animate(to: camera)
        
        // Add marker for current location
        let marker = GMSMarker()
        marker.position = location.coordinate
        marker.title = "Current Location"
        marker.map = mapView
    }
} 
