import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

// Define some modern colors (you can customize these further)
struct AppColors {
    static let background = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1)
    static let cardBackground = UIColor.systemBackground
    static let primaryText = UIColor.label
    static let secondaryText = UIColor.secondaryLabel
    static let accentBlue = UIColor.systemBlue
    static let subtleGray = UIColor.systemGray4
    static let shadowColor = UIColor.black
    static let greetingText = UIColor(red: 41/255, green: 56/255, blue: 80/255, alpha: 1)
    static let areaBlockBackground = UIColor(red: 230/255, green: 239/255, blue: 250/255, alpha: 1)
    static let areaBlockText = UIColor(red: 42/255, green: 95/255, blue: 176/255, alpha: 1)
}

class HomeViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate, GMSAutocompleteViewControllerDelegate {

    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    private var imageCache = NSCache<NSString, UIImage>()
    private var displayedPlaceNames = Set<String>() // For nearby attractions
    private var startTextField: UITextField!
    private var destinationTextField: UITextField!
    private var profile: UserProfile!
    private var areaLabel: UILabel!

    // --- Frequent Places Properties ---
    private var frequentPlaces: [SavedPlace] = []
    private var frequentPlacesScrollView: UIScrollView!
    private var frequentPlacesStack: UIStackView!
    private var addFrequentPlaceButton: UIButton!
    private var currentlySettingPlaceName: String? // Stores "Home", "Work", or nil for new custom place

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var mapView: GMSMapView!
    private var nearAttractionsScrollView: UIScrollView!
    private var nearAttractionsStack: UIStackView!
    
    private lazy var startTripButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start the Trip", for: .normal)
        button.backgroundColor = AppColors.accentBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = AppColors.shadowColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: #selector(startTripButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Autocomplete Tags Enum
    private enum GMSAutocompleteTag: Int {
        case startField = 1
        case destinationField = 2
        case setHome = 100
        case setWork = 101
        case addFrequent = 102 // For adding a new custom frequent place
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        profile = UserProfile(name: "Hanxue") // Make sure UserProfile is correctly initialized

        loadFrequentPlacesData()
        
        setupScrollView()
        setupContentStack()
        setupGreetingAndLogo()
        setupSearchCard()
        setupStartTripButton()
        setupMapViewCard()
        setupFrequentPlacesSection()
        setupNearAttractionsSection()
        
        setupLocationManager()
        setupKeyboardNotifications()
        
        navigationController?.isNavigationBarHidden = true
        
        refreshFrequentPlacesUI() // Initial population

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.currentLocation != nil { // Only display attractions if location is known
                self.displayAttractions()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        refreshFrequentPlacesUI()
    }

    // MARK: - Data Handling
    private func loadFrequentPlacesData() {
        frequentPlaces = SavedPlacesManager.shared.loadPlaces()
    }
    
    private func refreshFrequentPlacesUI() {
        loadFrequentPlacesData() // Load the latest data
        populateFrequentPlacesCards() // Re-draw the cards
    }

    // MARK: - UI Setup
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupContentStack() {
        contentStack.axis = .vertical
        contentStack.spacing = 28
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func setupGreetingAndLogo() {
        let username = profile.name ?? "User"
        let greeting = getGreetingText()
        let greetingLogoAndAreaStack = makeGreetingWithLogoAndAreaBlock(greeting: greeting, username: username, area: "Locating...")
        contentStack.addArrangedSubview(greetingLogoAndAreaStack)
        contentStack.setCustomSpacing(30, after: greetingLogoAndAreaStack)
    }

    private func setupSearchCard() {
        let searchCardView = createCardView()
        contentStack.addArrangedSubview(searchCardView)
        
        startTextField = makeStyledTextField(placeholder: "From (Current Location)")
        destinationTextField = makeStyledTextField(placeholder: "To (Enter Destination)")
        startTextField.delegate = self
        destinationTextField.delegate = self

        let searchFieldsStack = UIStackView(arrangedSubviews: [startTextField, destinationTextField])
        searchFieldsStack.axis = .vertical
        searchFieldsStack.spacing = 12
        searchFieldsStack.translatesAutoresizingMaskIntoConstraints = false
        
        searchCardView.addSubview(searchFieldsStack)
        NSLayoutConstraint.activate([
            searchFieldsStack.topAnchor.constraint(equalTo: searchCardView.topAnchor, constant: 16),
            searchFieldsStack.leadingAnchor.constraint(equalTo: searchCardView.leadingAnchor, constant: 16),
            searchFieldsStack.trailingAnchor.constraint(equalTo: searchCardView.trailingAnchor, constant: -16),
            searchFieldsStack.bottomAnchor.constraint(equalTo: searchCardView.bottomAnchor, constant: -16)
        ])
        contentStack.setCustomSpacing(16, after: searchCardView)
    }

    private func setupStartTripButton() {
        contentStack.addArrangedSubview(startTripButton)
        contentStack.setCustomSpacing(30, after: startTripButton)
    }

    private func setupMapViewCard() {
        let mapCardView = createCardView()
        contentStack.addArrangedSubview(mapCardView)
        
        let initialCamera: GMSCameraPosition
        if let currentLoc = currentLocation {
            initialCamera = GMSCameraPosition.camera(withTarget: currentLoc, zoom: 14)
        } else {
            initialCamera = GMSCameraPosition.camera(withLatitude: 51.5074, longitude: -0.1278, zoom: 12) // London default
        }
        mapView = GMSMapView.map(withFrame: .zero, camera: initialCamera)
        mapView.layer.cornerRadius = 12
        mapView.clipsToBounds = true
        mapView.translatesAutoresizingMaskIntoConstraints = false
        
        mapCardView.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapCardView.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapCardView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapCardView.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapCardView.bottomAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 200) // Adjusted height
        ])
        contentStack.setCustomSpacing(30, after: mapCardView)
    }

    private func setupFrequentPlacesSection() {
        let frequentLabel = makeSectionHeaderLabel(text: "Frequent Places")
        contentStack.addArrangedSubview(frequentLabel)
        contentStack.setCustomSpacing(12, after: frequentLabel)

        frequentPlacesScrollView = UIScrollView()
        frequentPlacesScrollView.showsHorizontalScrollIndicator = false
        frequentPlacesScrollView.clipsToBounds = false
        frequentPlacesScrollView.translatesAutoresizingMaskIntoConstraints = false

        frequentPlacesStack = UIStackView()
        frequentPlacesStack.axis = .horizontal
        frequentPlacesStack.spacing = 12
        frequentPlacesStack.translatesAutoresizingMaskIntoConstraints = false
        frequentPlacesScrollView.addSubview(frequentPlacesStack)

        NSLayoutConstraint.activate([
            frequentPlacesStack.topAnchor.constraint(equalTo: frequentPlacesScrollView.topAnchor),
            frequentPlacesStack.bottomAnchor.constraint(equalTo: frequentPlacesScrollView.bottomAnchor),
            frequentPlacesStack.leadingAnchor.constraint(equalTo: frequentPlacesScrollView.leadingAnchor),
            frequentPlacesStack.trailingAnchor.constraint(equalTo: frequentPlacesScrollView.trailingAnchor),
            frequentPlacesStack.heightAnchor.constraint(equalTo: frequentPlacesScrollView.heightAnchor)
        ])
        
        contentStack.addArrangedSubview(frequentPlacesScrollView)
        frequentPlacesScrollView.heightAnchor.constraint(equalToConstant: 70).isActive = true
        contentStack.setCustomSpacing(30, after: frequentPlacesScrollView)
    }

    private func setupNearAttractionsSection() {
        let nearLabel = makeSectionHeaderLabel(text: "Near You")
        contentStack.addArrangedSubview(nearLabel)
        contentStack.setCustomSpacing(12, after: nearLabel)

        nearAttractionsScrollView = UIScrollView()
        nearAttractionsScrollView.showsHorizontalScrollIndicator = false
        nearAttractionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        nearAttractionsScrollView.clipsToBounds = false

        nearAttractionsStack = UIStackView()
        nearAttractionsStack.axis = .horizontal
        nearAttractionsStack.spacing = 16
        nearAttractionsStack.alignment = .center
        nearAttractionsStack.translatesAutoresizingMaskIntoConstraints = false

        nearAttractionsScrollView.addSubview(nearAttractionsStack)
        contentStack.addArrangedSubview(nearAttractionsScrollView)

        NSLayoutConstraint.activate([
            nearAttractionsStack.topAnchor.constraint(equalTo: nearAttractionsScrollView.topAnchor),
            nearAttractionsStack.bottomAnchor.constraint(equalTo: nearAttractionsScrollView.bottomAnchor),
            nearAttractionsStack.leadingAnchor.constraint(equalTo: nearAttractionsScrollView.leadingAnchor),
            nearAttractionsStack.trailingAnchor.constraint(equalTo: nearAttractionsScrollView.trailingAnchor),
            nearAttractionsStack.heightAnchor.constraint(equalTo: nearAttractionsScrollView.heightAnchor)
        ])
        nearAttractionsScrollView.heightAnchor.constraint(equalToConstant: 170).isActive = true
    }
    
    // MARK: - UI Helper methods
    private func createCardView() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = AppColors.cardBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = AppColors.shadowColor.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOpacity = 0.07
        cardView.translatesAutoresizingMaskIntoConstraints = false
        return cardView
    }

    private func makeStyledTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = .systemFont(ofSize: 16)
        tf.textColor = AppColors.primaryText
        tf.backgroundColor = UIColor.systemGray6
        tf.layer.cornerRadius = 10
        tf.layer.borderColor = AppColors.subtleGray.cgColor
        tf.layer.borderWidth = 0.5
        tf.setLeftPaddingPoints(16)
        tf.setRightPaddingPoints(16)
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return tf
    }
    
    private func makeSectionHeaderLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .bold) // Slightly smaller section header
        label.textColor = AppColors.primaryText
        return label
    }
    
    private func makeGreetingWithLogoAndAreaBlock(greeting: String, username: String, area: String) -> UIStackView {
        let greetingLabel = UILabel()
        greetingLabel.numberOfLines = 0
        let greetingAttributedText = NSMutableAttributedString(
            string: "Hi, \(username)! 👋\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold), // Slightly adjusted size
                .foregroundColor: AppColors.greetingText
            ]
        )
        greetingAttributedText.append(NSAttributedString(
            string: greeting,
            attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold), // Adjusted size
                .foregroundColor: AppColors.secondaryText
            ]
        ))
        greetingLabel.attributedText = greetingAttributedText
        greetingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        greetingLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let logoImageView = UIImageView(image: UIImage(named: "ontimego_logo"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 50),
            logoImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 50) // Ensure it doesn't get too tall
        ])
        logoImageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        logoImageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        spacerView.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
        
        let greetingLogoStack = UIStackView(arrangedSubviews: [greetingLabel, spacerView, logoImageView])
        greetingLogoStack.axis = .horizontal
        greetingLogoStack.alignment = .top // Align logo to top of greeting text
        greetingLogoStack.spacing = 8

        let areaBlock = UIView()
        areaBlock.backgroundColor = AppColors.areaBlockBackground
        areaBlock.layer.cornerRadius = 12
        areaBlock.layer.masksToBounds = true
        areaBlock.translatesAutoresizingMaskIntoConstraints = false

        areaLabel = UILabel()
        areaLabel.text = area
        areaLabel.font = .systemFont(ofSize: 12, weight: .medium)
        areaLabel.textColor = AppColors.areaBlockText
        areaLabel.textAlignment = .center
        areaLabel.translatesAutoresizingMaskIntoConstraints = false

        areaBlock.addSubview(areaLabel)
        NSLayoutConstraint.activate([
            areaLabel.leadingAnchor.constraint(equalTo: areaBlock.leadingAnchor, constant: 10),
            areaLabel.trailingAnchor.constraint(equalTo: areaBlock.trailingAnchor, constant: -10),
            areaLabel.topAnchor.constraint(equalTo: areaBlock.topAnchor, constant: 6),
            areaLabel.bottomAnchor.constraint(equalTo: areaBlock.bottomAnchor, constant: -6)
        ])
        areaBlock.setContentHuggingPriority(.required, for: .horizontal)
        areaBlock.setContentCompressionResistancePriority(.required, for: .horizontal)

        let mainHeaderStack = UIStackView(arrangedSubviews: [greetingLogoStack, areaBlock])
        mainHeaderStack.axis = .vertical
        mainHeaderStack.alignment = .leading
        mainHeaderStack.spacing = 8
        
        return mainHeaderStack
    }

    // MARK: - Frequent Places UI & Logic
    private func populateFrequentPlacesCards() {
        frequentPlacesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for place in frequentPlaces {
            let card = createFrequentPlaceCard(savedPlace: place)
            frequentPlacesStack.addArrangedSubview(card)
        }

        addFrequentPlaceButton = UIButton(type: .custom)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium) // Slightly smaller
            let plusImage = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
            addFrequentPlaceButton.setImage(plusImage, for: .normal)
        } else {
            addFrequentPlaceButton.setTitle("+", for: .normal)
            addFrequentPlaceButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        }
        addFrequentPlaceButton.tintColor = AppColors.accentBlue
        addFrequentPlaceButton.addTarget(self, action: #selector(addNewFrequentPlaceTapped), for: .touchUpInside)
        
        let addButtonCard = UIView() // Not using createCardView to avoid shadow on a simple button
        addButtonCard.backgroundColor = .clear // Transparent background for the button container
        addButtonCard.addSubview(addFrequentPlaceButton)
        addFrequentPlaceButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            addFrequentPlaceButton.centerXAnchor.constraint(equalTo: addButtonCard.centerXAnchor),
            addFrequentPlaceButton.centerYAnchor.constraint(equalTo: addButtonCard.centerYAnchor),
            addButtonCard.widthAnchor.constraint(equalToConstant: 50), // Smaller touch area for add button
            addButtonCard.heightAnchor.constraint(equalToConstant: 60)
        ])
        frequentPlacesStack.addArrangedSubview(addButtonCard)
    }

    private func createFrequentPlaceCard(savedPlace: SavedPlace) -> UIView {
        let card = createCardView()

        let nameLabel = UILabel()
        nameLabel.text = savedPlace.name
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold) // Main name
        nameLabel.textColor = AppColors.primaryText
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        
        let addressLabel = UILabel()
        if savedPlace.isSystemDefault && (savedPlace.latitude == 0 && savedPlace.longitude == 0) {
            addressLabel.text = "Tap to set"
            addressLabel.textColor = AppColors.accentBlue
            addressLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        } else {
            addressLabel.text = savedPlace.address
            addressLabel.textColor = AppColors.secondaryText
            addressLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular) // Smaller address text
        }
        addressLabel.textAlignment = .center
        addressLabel.numberOfLines = 1
        addressLabel.lineBreakMode = .byTruncatingTail

        let textStack = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        textStack.axis = .vertical
        textStack.spacing = 1
        textStack.alignment = .center
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6)
        ])
        
        let cardWidth: CGFloat = (savedPlace.name.count > 9 || savedPlace.address.count > 18) ? 130 : 110 // Adjusted widths
        card.widthAnchor.constraint(equalToConstant: cardWidth).isActive = true
        card.heightAnchor.constraint(equalToConstant: 60).isActive = true

        card.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(frequentPlaceCardTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        card.accessibilityIdentifier = savedPlace.id.uuidString
        card.accessibilityLabel = savedPlace.name
        if savedPlace.isSystemDefault && (savedPlace.latitude == 0 && savedPlace.longitude == 0) {
             card.accessibilityHint = "PLACEHOLDER"
        }

        if !savedPlace.isSystemDefault {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnFrequentPlace(_:)))
            card.addGestureRecognizer(longPressGesture)
        }
        return card
    }
    
    @objc private func frequentPlaceCardTapped(_ sender: UITapGestureRecognizer) {
        guard let cardView = sender.view,
              let placeIDString = cardView.accessibilityIdentifier,
              let placeID = UUID(uuidString: placeIDString),
              let tappedPlace = frequentPlaces.first(where: { $0.id == placeID }) else {
            print("🛑 Could not identify frequent place from tap.")
            return
        }

        if tappedPlace.isSystemDefault && (tappedPlace.latitude == 0 && tappedPlace.longitude == 0) {
            currentlySettingPlaceName = tappedPlace.name // "Home" or "Work"
            let autocompleteController = GMSAutocompleteViewController()
            autocompleteController.delegate = self
            autocompleteController.view.tag = (tappedPlace.name == "Home") ? GMSAutocompleteTag.setHome.rawValue : GMSAutocompleteTag.setWork.rawValue
            
            let filter = GMSAutocompleteFilter()
            filter.countries = ["GB"]
            autocompleteController.autocompleteFilter = filter
            present(autocompleteController, animated: true, completion: nil)
        } else {
            destinationTextField.text = tappedPlace.address
            print("ℹ️ \(tappedPlace.name) tapped, Address: \(tappedPlace.address)")
            updateStartTripButtonState()
        }
    }

    @objc private func addNewFrequentPlaceTapped() {
        currentlySettingPlaceName = nil // Indicates a new custom place
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        autocompleteController.view.tag = GMSAutocompleteTag.addFrequent.rawValue
        
        let filter = GMSAutocompleteFilter()
        filter.countries = ["GB"]
        autocompleteController.autocompleteFilter = filter
        present(autocompleteController, animated: true, completion: nil)
    }

    @objc private func handleLongPressOnFrequentPlace(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            guard let cardView = gestureRecognizer.view,
                  let placeIDString = cardView.accessibilityIdentifier,
                  let placeID = UUID(uuidString: placeIDString),
                  let placeToRemove = frequentPlaces.first(where: { $0.id == placeID }),
                  !placeToRemove.isSystemDefault else {
                return
            }

            let alert = UIAlertController(title: "Delete \"\(placeToRemove.name)\"",
                                          message: "Are you sure you want to delete this frequent place?",
                                          preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
                SavedPlacesManager.shared.removePlace(withId: placeID)
                self?.refreshFrequentPlacesUI()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = cardView
                popoverController.sourceRect = cardView.bounds
            }
            present(alert, animated: true)
        }
    }
    
    // MARK: - Location and API Methods
    func getGreetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<18: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    func fetchCurrentAreaName(from location: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let geo = CLGeocoder()
        let loc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        geo.reverseGeocodeLocation(loc) { placemarks, error in
            if let error = error {
                print("🛑 Reverse geocoding error: \(error.localizedDescription)")
                completion("Unknown area")
                return
            }
            let placemark = placemarks?.first
            let area = placemark?.subLocality ?? placemark?.locality ?? placemark?.name ?? "Unknown area"
            completion(area)
        }
    }
    
    func updateAreaBlock(_ areaName: String) {
        areaLabel?.text = areaName
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        // Check authorization status before starting
        if CLLocationManager.locationServicesEnabled() {
            switch locationManager.authorizationStatus { // Use instance property
            case .notDetermined, .restricted, .denied:
                print("⚠️ Location services not authorized or restricted.")
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.startUpdatingLocation()
            @unknown default:
                print("⚠️ Unknown location authorization status.")
            }
        } else {
            print("⚠️ Location services are not enabled on this device.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        if startTextField.text?.isEmpty ?? true || startTextField.text?.lowercased() == "current location" {
            startTextField.text = "Current Location"
        }

        if currentLocation == nil { // First location update
            currentLocation = location.coordinate
            mapView.camera = GMSCameraPosition.camera(withTarget: location.coordinate, zoom: 14)
            // Add a subtle marker for current location, or rely on Google's blue dot if myLocationEnabled is true
            // let currentMarker = GMSMarker(position: location.coordinate)
            // currentMarker.icon = GMSMarker.markerImage(with: AppColors.accentBlue) // Or a custom dot
            // currentMarker.map = mapView
            mapView.isMyLocationEnabled = true // Show Google's blue dot

            displayAttractions()
        }
        currentLocation = location.coordinate // Continuously update for other uses if needed
        
        fetchCurrentAreaName(from: location.coordinate) { [weak self] area in
            DispatchQueue.main.async { self?.updateAreaBlock(area) }
        }
        // Consider stopping updates if only needed once or for a short period to save battery
        // locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🛑 Location manager failed with error: \(error.localizedDescription)")
        // Handle error, e.g., show an alert to the user or default to a generic location
        areaLabel?.text = "Area unknown"
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle changes in authorization status, e.g., start updating if now authorized
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            print("ℹ️ Location authorization granted.")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ Location authorization denied or restricted.")
            // Optionally guide user to settings
            areaLabel?.text = "Location access denied"
        case .notDetermined:
            print("ℹ️ Location authorization not determined.")
        @unknown default:
            print("⚠️ Unknown location authorization status after change.")
        }
    }

    
    // MARK: - Attractions Loading
     private func displayAttractions() {
        guard let coord = currentLocation else { return }
        nearAttractionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        displayedPlaceNames.removeAll()

        let desiredCount = Int.random(in: 3...5)
        var fetchedCount = 0
        var candidatesProcessed = 0
        let maxTries = 20

        func fetchOneAttractionRecursive() {
            guard fetchedCount < desiredCount, candidatesProcessed < maxTries else {
                if fetchedCount == 0 && candidatesProcessed >= maxTries {
                    print("ℹ️ Max tries (\(maxTries)) reached for attractions. No new attractions with photos found.")
                    // Update UI to indicate no attractions found, if desired
                    DispatchQueue.main.async {
                        let noAttractionsLabel = UILabel()
                        noAttractionsLabel.text = "No attractions found nearby."
                        noAttractionsLabel.textColor = AppColors.secondaryText
                        noAttractionsLabel.textAlignment = .center
                        self.nearAttractionsStack.addArrangedSubview(noAttractionsLabel)
                    }
                }
                return
            }
            candidatesProcessed += 1

            fetchNearbyAttractionImage(coord: coord) { [weak self] image, name, placeCoord in
                guard let self = self else { return }
                
                if let img = image, let placeName = name, let placeCoordinate = placeCoord, !self.displayedPlaceNames.contains(placeName) {
                    self.displayedPlaceNames.insert(placeName)
                    DispatchQueue.main.async {
                        let card = self.makeAttractionCard(name: placeName, image: img, coord: placeCoordinate)
                        self.nearAttractionsStack.addArrangedSubview(card)
                    }
                    fetchedCount += 1
                }
                fetchOneAttractionRecursive() // Continue fetching
            }
        }
        fetchOneAttractionRecursive()
    }

    // In HomeViewController.swift

    private func fetchNearbyAttractionImage(
        coord: CLLocationCoordinate2D,
        completion: @escaping (UIImage?, String?, CLLocationCoordinate2D?) -> Void
    ) {
        let apiKey = APIKeys.googleMaps // Use global key

        let urlStr = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(coord.latitude),\(coord.longitude)&radius=3000&type=tourist_attraction&key=\(apiKey)"
        guard let url = URL(string: urlStr) else {
            print("🛑 NS Error: Invalid URL for Nearby Search."); completion(nil, nil, nil); return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error { print("🛑 NS Error: \(error.localizedDescription)"); completion(nil, nil, nil); return }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("🛑 NS Error: HTTP Status \( (response as? HTTPURLResponse)?.statusCode ?? 0 ) for URL: \(urlStr)")
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("🔗 NS Response body: \(responseBody)")
                }
                completion(nil, nil, nil); return
            }
            guard let self = self, let data = data else { completion(nil, nil, nil); return }

            var jsonResponse: [String: Any]? // Declare jsonResponse here to be accessible in the error print
            do {
                jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let json = jsonResponse, // Use the declared jsonResponse
                      let results = json["results"] as? [[String: Any]] else {
                    // Now jsonResponse can be safely accessed here for its status
                    print("🛑 NS Error: JSON Parsing failed or 'results' key missing. API Status: \(jsonResponse?["status"] as? String ?? "N/A")")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🔗 Raw JSON Response (Nearby Search): \(responseString)")
                    }
                    completion(nil, nil, nil); return
                }
                
                let freshCandidates = results.filter { p in (p["name"] as? String).map { !self.displayedPlaceNames.contains($0) && p["photos"] != nil } ?? false }
                guard let place = freshCandidates.randomElement(),
                      let name = place["name"] as? String,
                      let geo = place["geometry"] as? [String: Any], let loc = geo["location"] as? [String: Any],
                      let lat = loc["lat"] as? Double, let lng = loc["lng"] as? Double,
                      let photos = place["photos"] as? [[String: Any]], let ref = photos.first?["photo_reference"] as? String else {
                    // This is not necessarily an error, just means no suitable candidate in this batch
                    completion(nil, nil, nil); return
                }
                let attractionCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                if let cached = self.imageCache.object(forKey: ref as NSString) { completion(cached, name, attractionCoord); return }

                let photoURLStr = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(ref)&key=\(apiKey)"
                guard let photoURL = URL(string: photoURLStr) else { print("🛑 PF Error: Invalid Photo URL"); completion(nil, name, attractionCoord); return }

                URLSession.shared.dataTask(with: photoURL) { pData, pResponse, pError in
                    if let pError = pError { print("🛑 PF Error: \(pError.localizedDescription)"); completion(nil, name, attractionCoord); return }
                    guard let pHTTP = pResponse as? HTTPURLResponse, (200...299).contains(pHTTP.statusCode) else {
                         print("🛑 PF Error: HTTP Status \( (pResponse as? HTTPURLResponse)?.statusCode ?? 0 ) for URL: \(photoURLStr)")
                         if let photoData = pData, let responseBody = String(data: photoData, encoding: .utf8) {
                             print("🔗 PF Response body: \(responseBody)")
                         }
                         completion(nil, name, attractionCoord); return
                    }
                    guard let data = pData, let image = UIImage(data: data) else { print("🛑 PF Error: No image data from photo ref \(ref)"); completion(nil, name, attractionCoord); return }
                    self.imageCache.setObject(image, forKey: ref as NSString)
                    completion(image, name, attractionCoord)
                }.resume()
            } catch {
                // This catch block handles errors from 'try JSONSerialization.jsonObject'
                print("🛑 NS Error: JSON Serialization Catch Block: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) { // 'data' is captured and available here
                    print("🔗 Raw JSON Response causing serialization error (Nearby Search): \(responseString)")
                }
                completion(nil, nil, nil)
            }
        }.resume()
    }
    private func makeAttractionCard(name: String, image: UIImage, coord: CLLocationCoordinate2D) -> UIView {
        let card = createCardView()
        card.widthAnchor.constraint(equalToConstant: 150).isActive = true // Slightly narrower cards
        card.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let textContentView = UIView() // Container for text for better padding control
        textContentView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 13, weight: .semibold) // Slightly smaller
        label.textColor = AppColors.primaryText
        label.textAlignment = .left
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        textContentView.addSubview(label)
        
        card.addSubview(imageView)
        card.addSubview(textContentView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: card.heightAnchor, multiplier: 0.7), // Image takes more space

            textContentView.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            textContentView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            textContentView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            textContentView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            label.topAnchor.constraint(equalTo: textContentView.topAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: textContentView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: textContentView.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(lessThanOrEqualTo: textContentView.bottomAnchor, constant: -6)
        ])
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
        card.accessibilityLabel = name // For identifying which card was tapped
        card.accessibilityValue = "\(coord.latitude),\(coord.longitude)" // Store coordinates
        return card
    }

    @objc private func cardTapped(_ sender: UITapGestureRecognizer) { // This is for ATTRACTION cards
        guard let view = sender.view,
              let coordStr = view.accessibilityValue,
              let endCoord = parseCoord(from: coordStr),
              let name = view.accessibilityLabel else { return }

        // Set as destination
        destinationTextField.text = name // Or a more formatted address if available
        // Optionally, trigger route calculation or preview immediately
        // For now, user needs to tap "Start the Trip"
        print("Attraction \(name) selected as destination.")
        updateStartTripButtonState()
    }
    
    private func parseCoord(from string: String) -> CLLocationCoordinate2D? {
        let parts = string.split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    private func pushRoute(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, startLabel: String?, destLabel: String?) {
        let vc = RoutePreviewViewController()
        vc.startLocation = start
        vc.destinationLocation = end
        vc.startLabelName = startLabel
        vc.destinationLabelName = destLabel
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Trip Button Action
    @objc private func startTripButtonTapped() {
        guard let destinationAddress = destinationTextField.text, !destinationAddress.isEmpty else {
            // Optionally show an alert if destination is empty
            return
        }
        let routePreviewVC = RoutePreviewViewController()
        let startAddressText = startTextField.text
        
        if let startAddr = startAddressText, !startAddr.isEmpty, startAddr.lowercased() != "current location" {
            geocodeAddress(startAddr) { [weak self] startCoord in
                guard let self = self, let sc = startCoord else {
                    print("🛑 Geocode start address failed: \(startAddr)"); return
                }
                self.geocodeAddress(destinationAddress) { endCoord in
                    guard let ec = endCoord else {
                        print("🛑 Geocode destination address failed: \(destinationAddress)"); return
                    }
                    self.navigateToPreview(vc: routePreviewVC, start: sc, end: ec, startLabel: startAddr, destLabel: destinationAddress)
                }
            }
        } else {
            guard let current = currentLocation else {
                print("🛑 Current location is not available to use as start."); return
            }
            geocodeAddress(destinationAddress) { [weak self] endCoord in
                guard let self = self, let ec = endCoord else {
                    print("🛑 Geocode destination address failed: \(destinationAddress)"); return
                }
                self.navigateToPreview(vc: routePreviewVC, start: current, end: ec, startLabel: "Current Location", destLabel: destinationAddress)
            }
        }
    }
    
    private func navigateToPreview(vc: RoutePreviewViewController, start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, startLabel: String?, destLabel: String?) {
        vc.startLocation = start
        vc.destinationLocation = end
        vc.startLabelName = startLabel
        vc.destinationLabelName = destLabel
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        CLGeocoder().geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("🛑 Geocoding error for '\(address)': \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(placemarks?.first?.location?.coordinate)
        }
    }
    
    private func updateStartTripButtonState() {
        let hasStart = !(startTextField.text?.isEmpty ?? true)
        let hasDestination = !(destinationTextField.text?.isEmpty ?? true)
        startTripButton.isEnabled = hasStart && hasDestination
        startTripButton.alpha = startTripButton.isEnabled ? 1.0 : 0.6
    }
    
    // MARK: - UITextFieldDelegate & GMSAutocompleteViewControllerDelegate
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        autocompleteController.modalPresentationStyle = .fullScreen
        
        // Apply some basic styling to GMSAutocompleteViewController if possible
        // Note: Deep customization of GMSAutocompleteViewController is limited.
        // These might not all take effect or might require different approaches.
        let appearance = GMSAutocompleteViewController() // For accessing styling properties if available
        appearance.primaryTextColor = AppColors.primaryText
        appearance.secondaryTextColor = AppColors.secondaryText
        appearance.tableCellBackgroundColor = AppColors.cardBackground
        appearance.tableCellSeparatorColor = AppColors.subtleGray
        // For actual controller presented:
        autocompleteController.primaryTextColor = AppColors.primaryText
        autocompleteController.secondaryTextColor = AppColors.secondaryText
        autocompleteController.tableCellBackgroundColor = AppColors.cardBackground
        autocompleteController.tableCellSeparatorColor = AppColors.subtleGray
        autocompleteController.tintColor = AppColors.accentBlue


        let filter = GMSAutocompleteFilter()
        filter.countries = ["GB"]
        autocompleteController.autocompleteFilter = filter

        if textField == startTextField {
            autocompleteController.view.tag = GMSAutocompleteTag.startField.rawValue
        } else if textField == destinationTextField {
            autocompleteController.view.tag = GMSAutocompleteTag.destinationField.rawValue
        }
        present(autocompleteController, animated: true)
        return false
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        guard let tagValue = GMSAutocompleteTag(rawValue: viewController.view.tag) else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            let placeAddress = place.formattedAddress ?? place.name ?? "Selected Location"
            let placeCoordinate = place.coordinate

            switch tagValue {
            case .startField:
                self.startTextField.text = placeAddress
                self.currentLocation = placeCoordinate // User explicitly selected a start
            case .destinationField:
                self.destinationTextField.text = placeAddress
            case .setHome:
                let homePlace = SavedPlace(name: "Home", address: placeAddress, coordinate: placeCoordinate, isSystemDefault: true)
                SavedPlacesManager.shared.addOrUpdatePlace(homePlace)
                self.refreshFrequentPlacesUI()
                self.currentlySettingPlaceName = nil
            case .setWork:
                let workPlace = SavedPlace(name: "Work", address: placeAddress, coordinate: placeCoordinate, isSystemDefault: true)
                SavedPlacesManager.shared.addOrUpdatePlace(workPlace)
                self.refreshFrequentPlacesUI()
                self.currentlySettingPlaceName = nil
            case .addFrequent:
                // If currentlySettingPlaceName was set (e.g. "Gym"), use it, else prompt.
                // For the "+" button, currentlySettingPlaceName should be nil.
                self.promptForFrequentPlaceCustomName(for: place, selectedAddress: placeAddress, selectedCoordinate: placeCoordinate)
            }
            self.updateStartTripButtonState()
        }
    }
    
    private func promptForFrequentPlaceCustomName(for googlePlace: GMSPlace?, selectedAddress: String, selectedCoordinate: CLLocationCoordinate2D) {
        let alertController = UIAlertController(title: "Save Frequent Place", message: "Enter a name for this location:", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "e.g., Gym, Cafe"
            textField.text = googlePlace?.name // Pre-fill with Google Place name if available
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self, weak alertController] _ in
            guard let self = self,
                  let nameField = alertController?.textFields?.first,
                  let customName = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !customName.isEmpty else {
                // Optionally show an alert for empty name
                return
            }
            
            if ["home", "work"].contains(customName.lowercased()) {
                 let errorAlert = UIAlertController(title: "Name Reserved", message: "\"Home\" and \"Work\" are special. Please set them by tapping their cards or choose a different name.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(errorAlert, animated: true)
                return
            }
            
            if self.frequentPlaces.contains(where: { !$0.isSystemDefault && $0.name.lowercased() == customName.lowercased() }) {
                let errorAlert = UIAlertController(title: "Name Exists", message: "A frequent place with this name already exists.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(errorAlert, animated: true)
                return
            }

            let newFrequentPlace = SavedPlace(name: customName,
                                              address: selectedAddress,
                                              coordinate: selectedCoordinate,
                                              isSystemDefault: false)
            SavedPlacesManager.shared.addOrUpdatePlace(newFrequentPlace)
            self.refreshFrequentPlacesUI()
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(saveAction)
        present(alertController, animated: true)
    }


    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        print("❌ Autocomplete error: \(error.localizedDescription)")
        dismiss(animated: true, completion: nil)
    }

    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Keyboard Handling
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tapGesture) // Add to scrollView so it doesn't interfere with card taps
    }
   
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = keyboardFrame.height
        
        var contentInset = scrollView.contentInset
        contentInset.bottom = keyboardHeight + 20
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UITextField Padding Extension
extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
    func setRightPaddingPoints(_ amount:CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}
