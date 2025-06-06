
import UIKit
import GooglePlaces
import CoreLocation

protocol CustomAutocompleteViewControllerDelegate: AnyObject {
    func customAutocompleteViewController(_ controller: CustomAutocompleteViewController, didSelectPlace place: GMSPlace)
    func customAutocompleteViewController(_ controller: CustomAutocompleteViewController, didSelectCurrentLocation location: CLLocationCoordinate2D)
    func customAutocompleteViewControllerDidCancel(_ controller: CustomAutocompleteViewController)
}

class CustomAutocompleteViewController: UIViewController {
    
    // MARK: - Properties
    private let searchBar: UISearchBar
    private let tableView: UITableView
    private let autocompleteFetcher: GMSAutocompleteFetcher
    private var predictions: [GMSAutocompletePrediction] = []
    private let locationManager: CLLocationManager
    private var currentLocation: CLLocationCoordinate2D?
    
    // Add property to track which text field is active
    var isForStartLocation: Bool = true
    
    weak var delegate: CustomAutocompleteViewControllerDelegate?
    
    // MARK: - Initialization
    init(isForStartLocation: Bool = true) {
        self.isForStartLocation = isForStartLocation
        searchBar = UISearchBar()
        tableView = UITableView()
        
        // Initialize location manager
        locationManager = CLLocationManager()
        
        // Initialize autocomplete fetcher
        let filter = GMSAutocompleteFilter()
        filter.countries = ["GB"]
        autocompleteFetcher = GMSAutocompleteFetcher(filter: filter)
        
        super.init(nibName: nil, bundle: nil)
        
        // Setup autocomplete fetcher
        autocompleteFetcher.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocationManager()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup search bar
        searchBar.delegate = self
        searchBar.placeholder = isForStartLocation ? "Search for starting location" : "Search for destination"
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add cancel button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Set title based on which field we're editing
        title = isForStartLocation ? "Starting Location" : "Destination"
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Request location authorization if needed
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse ||
                  locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    // MARK: - Actions
    @objc private func cancelTapped() {
        delegate?.customAutocompleteViewControllerDidCancel(self)
    }
}

// MARK: - UISearchBarDelegate
extension CustomAutocompleteViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        autocompleteFetcher.sourceTextHasChanged(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension CustomAutocompleteViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions.count + 1 // +1 for current location
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        if indexPath.row == 0 {
            // Current Location cell
            cell.textLabel?.text = "📍 Current Location"
            cell.imageView?.image = UIImage(systemName: "location.fill")
            cell.imageView?.tintColor = .systemBlue
        } else {
            // Google Places prediction cell
            let prediction = predictions[indexPath.row - 1]
            cell.textLabel?.text = prediction.attributedFullText.string
            cell.imageView?.image = UIImage(systemName: "mappin.circle.fill")
            cell.imageView?.tintColor = .systemGray
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row == 0 {
            // Current Location selected
            if let location = currentLocation {
                delegate?.customAutocompleteViewController(self, didSelectCurrentLocation: location)
            } else {
                // Request location if not available
                locationManager.requestLocation()
            }
        } else {
            // Google Places prediction selected
            let prediction = predictions[indexPath.row - 1]
            let placeClient = GMSPlacesClient.shared()
            
            // Create a session token for this request
            let sessionToken = GMSAutocompleteSessionToken()
            
            // Define the fields we want to fetch
            let placeFields: GMSPlaceField = [.name, .formattedAddress, .coordinate]
            
            placeClient.fetchPlace(fromPlaceID: prediction.placeID,
                                 placeFields: placeFields,
                                 sessionToken: sessionToken) { [weak self] place, error in
                guard let self = self, let place = place else {
                    print("Error fetching place: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                DispatchQueue.main.async {
                    self.delegate?.customAutocompleteViewController(self, didSelectPlace: place)
                }
            }
        }
    }
}

// MARK: - GMSAutocompleteFetcherDelegate
extension CustomAutocompleteViewController: GMSAutocompleteFetcherDelegate {
    func didAutocomplete(with predictions: [GMSAutocompletePrediction]) {
        self.predictions = predictions
        tableView.reloadData()
    }
    
    func didFailAutocompleteWithError(_ error: Error) {
        print("Autocomplete error: \(error.localizedDescription)")
    }
}

// MARK: - CLLocationManagerDelegate
extension CustomAutocompleteViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            currentLocation = location.coordinate
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
} 
