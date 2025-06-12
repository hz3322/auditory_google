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
    private var recentSearches: [SearchHistory] = []
    weak var delegate: CustomAutocompleteViewControllerDelegate?
    
    // Add property to track which text field is active
    var isForStartLocation: Bool = true
    private var isShowingHistory = true

    
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
        loadRecentSearches()
    }
    
    // MARK: - Setup UI
        private func setupUI() {
            view.backgroundColor = .systemBackground
            // Navigation
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
            title = isForStartLocation ? "Starting Location" : "Destination"

            // SearchBar
            searchBar.delegate = self
            searchBar.placeholder = isForStartLocation ? "Search for starting location" : "Search for destination"
            searchBar.searchBarStyle = .minimal
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(searchBar)
            
            // TableView
            tableView.delegate = self
            tableView.dataSource = self
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
            tableView.tableFooterView = UIView()
            tableView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(tableView)
            
            // Layout
            NSLayoutConstraint.activate([
                searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                
                tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 0),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        private func setupLocationManager() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            } else if locationManager.authorizationStatus == .authorizedWhenInUse ||
                      locationManager.authorizationStatus == .authorizedAlways {
                locationManager.requestLocation()
            }
        }

        // MARK: - Data
        private func loadRecentSearches() {
            // ⚡️根据你自己的实现替换
            SearchHistoryService.shared.fetchRecentSearches { [weak self] searches in
                self?.recentSearches = searches
                self?.isShowingHistory = true
                DispatchQueue.main.async { self?.tableView.reloadData() }
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
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Show history when search bar is empty
                isShowingHistory = true
                tableView.reloadData()
            } else {
                isShowingHistory = false
                autocompleteFetcher.sourceTextHasChanged(searchText)
            }
        }
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate
    extension CustomAutocompleteViewController: UITableViewDataSource, UITableViewDelegate {
        func numberOfSections(in tableView: UITableView) -> Int {
            return 1
        }
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            if isShowingHistory {
                // 1 for Current Location, rest for history
                return 1 + recentSearches.count
            } else {
                return predictions.count
            }
        }
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.font = .systemFont(ofSize: 16)
            cell.imageView?.tintColor = .systemBlue
            
            if isShowingHistory {
                if indexPath.row == 0 {
                    cell.textLabel?.text = "📍 Current Location"
                    cell.imageView?.image = UIImage(systemName: "location.fill")
                } else {
                    let history = recentSearches[indexPath.row - 1]
                    cell.textLabel?.text = history.query
                    cell.imageView?.image = UIImage(systemName: "clock")
                }
            } else {
                let prediction = predictions[indexPath.row]
                cell.textLabel?.text = prediction.attributedFullText.string
                cell.imageView?.image = UIImage(systemName: "mappin.circle.fill")
                cell.imageView?.tintColor = .systemGray
            }
            return cell
        }
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            if isShowingHistory {
                if indexPath.row == 0 {
                    // 当前定位
                    if let location = currentLocation {
                        delegate?.customAutocompleteViewController(self, didSelectCurrentLocation: location)
                    } else {
                        locationManager.requestLocation()
                    }
                } else {
                    let history = recentSearches[indexPath.row - 1]
                    let query = history.query
                    let client = GMSPlacesClient.shared()
                    let token = GMSAutocompleteSessionToken()
                    client.findAutocompletePredictions(fromQuery: query, filter: nil, sessionToken: token) { [weak self] preds, error in
                        if let pred = preds?.first {
                            client.fetchPlace(fromPlaceID: pred.placeID, placeFields: [.name, .formattedAddress, .coordinate], sessionToken: token) { place, error in
                                if let place = place {
                                    self?.delegate?.customAutocompleteViewController(self!, didSelectPlace: place)
                                }
                            }
                        }
                    }
                }
            } else {
                let prediction = predictions[indexPath.row]
                let client = GMSPlacesClient.shared()
                let token = GMSAutocompleteSessionToken()
                client.fetchPlace(fromPlaceID: prediction.placeID, placeFields: [.name, .formattedAddress, .coordinate], sessionToken: token) { [weak self] place, error in
                    if let place = place {
                        self?.delegate?.customAutocompleteViewController(self!, didSelectPlace: place)
                    }
                }
            }
        }
    }

    // MARK: - GMSAutocompleteFetcherDelegate
    extension CustomAutocompleteViewController: GMSAutocompleteFetcherDelegate {
        func didAutocomplete(with predictions: [GMSAutocompletePrediction]) {
            self.predictions = predictions
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
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
                // 只更新位置，不自动回调
                // 让用户手动选择是否使用当前位置
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Location error: \(error.localizedDescription)")
            // 如果获取位置失败，可以显示一个错误提示
            let alert = UIAlertController(title: "Location Error", 
                                        message: "Could not get your current location. Please try again or select a different location.",
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else if manager.authorizationStatus == .denied {
                // 如果用户拒绝了位置权限，显示提示
                let alert = UIAlertController(title: "Location Access Required", 
                                            message: "Please enable location access in Settings to use this feature.",
                                            preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
