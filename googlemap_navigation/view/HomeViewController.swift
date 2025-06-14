import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation
import FirebaseFirestore
import FirebaseAuth


class HomeViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate, GMSAutocompleteViewControllerDelegate, CustomAutocompleteViewControllerDelegate {

    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    private var imageCache = NSCache<NSString, UIImage>() // Cache for nearby attraction images
    private var displayedPlaceNames = Set<String>()     // To avoid duplicate nearby attractions

    private var startTextField: UITextField!
    private var destinationTextField: UITextField!
    private var areaLabel: UILabel!   // Displays current geographical area
    private var weatherBannerView: WeatherBannerView!

    // --- Frequent Places Properties ---
    private var frequentPlaces: [SavedPlace] = []
    private var frequentPlacesScrollView: UIScrollView!
    private var frequentPlacesStack: UIStackView! // Horizontal stack for frequent place cards
    private var addFrequentPlaceButton: UIButton!   // The "+" button itself
    
    private var isUILayoutComplete: Bool = false
    
    // ------ Profile name ------------ //
    var userProfile: UserProfile?
    private var welcomeMessageLabel: UILabel!
 
    // To keep track of which frequent place (especially "Home" or "Work" placeholders)
    // is being set or edited via the GMSAutocompleteViewController.
    // This stores the name of the placeholder ("Home" or "Work") if one of those is tapped.
    // It's nil if the user taps the general "+" button to add a new custom place.
    private var currentlySettingPlaceName: String? // Stores "Home", "Work" if a placeholder is tapped, or nil for new custom place.
    private var currentlyEditingFrequentPlace: SavedPlace?

    private var isLoadingFrequentPlaces = false

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView() // Main vertical stack for all content
    private var mapView: GMSMapView!
    private var nearAttractionsScrollView: UIScrollView!
    private var nearAttractionsStack: UIStackView! // Horizontal stack for nearby attraction cards
    
    // Lazy var for the "Start the Trip" button to allow adding target to self
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
        button.isEnabled = false // Initially disabled until start/destination are set
        button.alpha = 0.5      // Visual cue for disabled state
        return button
    }()
    
    // MARK: - Autocomplete Tags Enum
    // Tags to differentiate the purpose of GMSAutocompleteViewController presentation
    private enum GMSAutocompleteTag: Int {
        case startField = 1         // For the "From" text field
        case destinationField = 2   // For the "To" text field
        case setHome = 100          // When tapping "Tap to set Home" card
        case setWork = 101          // When tapping "Tap to set Work" card
        case addFrequent = 102      // When tapping the "+" button to add a new custom frequent place
        case editFrequent = 103     // When editing an existing custom frequent place
    }

    // Add new properties for search history
    private var searchHistoryTableView: UITableView!
    private var recentSearches: [SearchHistory] = []
    private var isShowingSearchHistory = false
    private var activeTextField: UITextField?

    // Add new property for location cache
    private var lastKnownLocation: CLLocation?

    // 定义站点数据结构
    private struct Station {
        let name: String
        let coordinate: CLLocationCoordinate2D
        let distance: Double
        let lines: [String]
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        
        // Setup location manager first
        setupLocationManager()
        
        // Setup UI components
        setupScrollView()
        setupContentStack()
        setupGreetingAndLogo()
        setupWeatherBanner()
        setupMapViewCard()
        setupSearchCard()
        setupStartTripButton()
        setupFrequentPlacesSection()
        setupNearAttractionsSection()

        // Load initial data (frequent places) - this is now asynchronous
        loadFrequentPlacesDataAndSetupInitialUI()
        
        navigationController?.isNavigationBarHidden = true
        
        // Set isUILayoutComplete to true after all UI setup is done
        isUILayoutComplete = true
        
        // Ensure delegates are set after all UI setup is complete
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("[Debug] Re-setting delegates in viewDidLoad")
            self.startTextField.delegate = self
            self.destinationTextField.delegate = self
            print("[Debug] After re-setting - startTextField.delegate = \(String(describing: self.startTextField.delegate))")
        }
        
        // Start location updates if authorized
        if locationManager.authorizationStatus == .authorizedWhenInUse || 
           locationManager.authorizationStatus == .authorizedAlways {
            print("✅ UI setup complete. Starting location updates now.")
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        // Refresh frequent places UI in case it was modified elsewhere (e.g., a settings screen)
        // or if data loading in viewDidLoad hadn't completed before first willAppear.
        if frequentPlacesScrollView != nil { // Check if UI is already set up
             refreshFrequentPlacesUI()
        }
    }

    // MARK: - Data Handling for Frequent Places
    private func loadFrequentPlacesDataAndSetupInitialUI() {
        fetchAndDisplayFrequentPlaces { [weak self] in
            guard let self = self else { return }
            
            self.isUILayoutComplete = true
            
            if self.locationManager.authorizationStatus == .authorizedWhenInUse || 
               self.locationManager.authorizationStatus == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
            }
            
            if self.currentLocation != nil {
                self.displayStations()
            }
        }
    }

    private func fetchAndDisplayFrequentPlaces(completion: (() -> Void)? = nil) {
        guard !isLoadingFrequentPlaces else {
            completion?()
            return
        }

        isLoadingFrequentPlaces = true

        SavedPlacesManager.shared.loadPlaces { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let places):
                    if places.isEmpty {
                        // Initialize with empty Home and Work placeholders and save them to Firestore
                        let homePlace = SavedPlace(name: "Home", address: "Tap to set", coordinate: CLLocationCoordinate2D())
                        let workPlace = SavedPlace(name: "Work", address: "Tap to set", coordinate: CLLocationCoordinate2D())
                        
                        // Save both places to Firestore
                        SavedPlacesManager.shared.addOrUpdatePlace(homePlace) { error in
                            if let error = error {
                                print("Error saving Home placeholder: \(error.localizedDescription)")
                            }
                        }
                        
                        SavedPlacesManager.shared.addOrUpdatePlace(workPlace) { error in
                            if let error = error {
                                print("Error saving Work placeholder: \(error.localizedDescription)")
                            }
                        }
                        
                        self.frequentPlaces = [homePlace, workPlace]
                    } else {
                        self.frequentPlaces = places
                    }
                case .failure(let error):
                    print("Error loading frequent places: \(error.localizedDescription)")
                    // Initialize with empty Home and Work placeholders
                    self.frequentPlaces = [
                        SavedPlace(name: "Home", address: "Tap to set", coordinate: CLLocationCoordinate2D()),
                        SavedPlace(name: "Work", address: "Tap to set", coordinate: CLLocationCoordinate2D())
                    ]
                }
                
                self.populateFrequentPlacesCards()
                self.isLoadingFrequentPlaces = false
                completion?()
            }
        }
    }

    private func refreshFrequentPlacesUI() {
        // Asynchronously load places and then repopulate cards on the main thread
        fetchAndDisplayFrequentPlaces()
    }

    // MARK: - UI Setup Methods (Decomposed for clarity)
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
        
        // Add sign out button with improved styling
        let signOutButton = UIButton(type: .system)
        signOutButton.setImage(UIImage(systemName: "person.crop.circle.badge.minus"), for: .normal)
        signOutButton.tintColor = AppColors.accentBlue
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(signOutButton)
        NSLayoutConstraint.activate([
            signOutButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            signOutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            signOutButton.widthAnchor.constraint(equalToConstant: 44),
            signOutButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupContentStack() {
        contentStack.axis = .vertical
        contentStack.spacing = 28 // Overall spacing between major sections
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func setupGreetingAndLogo() {
        // Get username from Firebase Auth first, then fallback to userProfile
        let username: String
        if let firebaseUser = Auth.auth().currentUser,
           let displayName = firebaseUser.displayName,
           !displayName.isEmpty {
            username = displayName
        } else if let profileName = userProfile?.name,
                  !profileName.isEmpty {
            username = profileName
        } else {
            username = "Guest User"
        }
        
        let greeting = getGreetingText()
        let greetingLogoAndAreaStack = makeGreetingWithLogoAndAreaBlock(greeting: greeting, username: username, area: "Locating...")
        contentStack.addArrangedSubview(greetingLogoAndAreaStack)
        contentStack.setCustomSpacing(30, after: greetingLogoAndAreaStack)
    }

    private func setupSearchCard() {
        let searchCardView = createCardView()
        contentStack.addArrangedSubview(searchCardView)
        
        // 创建文本框
        startTextField = makeStyledTextField(placeholder: "From (Current Location)")
        destinationTextField = makeStyledTextField(placeholder: "To (Enter Destination)")
        
        // 创建切换按钮
        let switchButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            let switchImage = UIImage(systemName: "arrow.up.arrow.down.circle.fill", withConfiguration: config)
            switchButton.setImage(switchImage, for: .normal)
        } else {
            switchButton.setTitle("⇅", for: .normal)
            switchButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        }
        switchButton.tintColor = AppColors.accentBlue
        switchButton.addTarget(self, action: #selector(switchLocationsTapped), for: .touchUpInside)
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 先设置 delegate
        startTextField.delegate = self
        destinationTextField.delegate = self
        
        // 再添加其他设置
        startTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        destinationTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        // 创建并设置 stack view
        let searchFieldsStack = UIStackView(arrangedSubviews: [startTextField, destinationTextField])
        searchFieldsStack.axis = .vertical
        searchFieldsStack.spacing = 12
        searchFieldsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加到视图层级
        searchCardView.addSubview(searchFieldsStack)
        searchCardView.addSubview(switchButton)
        
        NSLayoutConstraint.activate([
            searchFieldsStack.topAnchor.constraint(equalTo: searchCardView.topAnchor, constant: 16),
            searchFieldsStack.leadingAnchor.constraint(equalTo: searchCardView.leadingAnchor, constant: 16),
            searchFieldsStack.trailingAnchor.constraint(equalTo: searchCardView.trailingAnchor, constant: -16),
            searchFieldsStack.bottomAnchor.constraint(equalTo: searchCardView.bottomAnchor, constant: -16),
            
            switchButton.centerXAnchor.constraint(equalTo: searchCardView.centerXAnchor),
            switchButton.centerYAnchor.constraint(equalTo: searchCardView.centerYAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 44),
            switchButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        contentStack.setCustomSpacing(16, after: searchCardView)
    }

    @objc private func switchLocationsTapped() {
        // 交换文本
        let tempText = startTextField.text
        startTextField.text = destinationTextField.text
        destinationTextField.text = tempText
        
        // 如果起始位置是"Current Location"，需要特殊处理
        if startTextField.text == "Current Location" {
            if let currentLocation = locationManager.location?.coordinate {
                self.currentLocation = currentLocation
            }
        } else if destinationTextField.text == "Current Location" {
            if let currentLocation = locationManager.location?.coordinate {
                self.currentLocation = currentLocation
            }
        }
        
        // 更新按钮状态
        updateStartTripButtonState()
        
        // 添加动画效果
        UIView.animate(withDuration: 0.3, animations: {
            self.startTextField.transform = CGAffineTransform(translationX: 0, y: 12)
            self.destinationTextField.transform = CGAffineTransform(translationX: 0, y: -12)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.startTextField.transform = .identity
                self.destinationTextField.transform = .identity
            }
        }
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        updateStartTripButtonState()
    }

    private func setupStartTripButton() {
        contentStack.addArrangedSubview(startTripButton)
        updateStartTripButtonState() // Set initial state
        contentStack.setCustomSpacing(30, after: startTripButton)
    }
    
    private func setupWeatherBanner() {
        weatherBannerView = WeatherBannerView()
        weatherBannerView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(weatherBannerView)
        contentStack.setCustomSpacing(16, after: weatherBannerView)

        // Set a minimum height (text will expand as needed)
        weatherBannerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
    }

    private func updateWeatherBanner(condition: String, suggestion: String, gradient: (start: UIColor, end: UIColor)) {
        weatherBannerView.configure(condition: condition,
                                  suggestion: suggestion,
                                  gradient: gradient)
    }

    private func fetchCurrentWeather(at coordinate: CLLocationCoordinate2D) {
        WeatherService.shared.fetchCurrentWeather(at: coordinate) { [weak self] condition, suggestion, gradient in
            DispatchQueue.main.async {
                self?.updateWeatherBanner(
                    condition: condition,
                    suggestion: suggestion,
                    gradient: gradient
                )
            }
        }
    }
    
    private func setupMapViewCard() {
        let camera = GMSCameraPosition(latitude: 0, longitude: 0, zoom: 14) // 初始值，占位用
        
        let options = GMSMapViewOptions()
        options.camera = camera
        options.frame = .zero
        
        let mapView = GMSMapView(options: options)
        mapView.layer.cornerRadius = 12
        mapView.clipsToBounds = true
        mapView.isMyLocationEnabled = true
        mapView.translatesAutoresizingMaskIntoConstraints = false
        
        self.mapView = mapView
        
        let mapCardView = createCardView()
        mapCardView.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapCardView.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapCardView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapCardView.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapCardView.bottomAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 200)
        ])
        contentStack.addArrangedSubview(mapCardView)
        contentStack.setCustomSpacing(30, after: mapCardView)
    }

    private func setupFrequentPlacesSection() {
        let frequentLabel = makeSectionHeaderLabel(text: "Frequent Places")
        contentStack.addArrangedSubview(frequentLabel)
        contentStack.setCustomSpacing(12, after: frequentLabel)

        frequentPlacesScrollView = UIScrollView()
        frequentPlacesScrollView.showsHorizontalScrollIndicator = false
        frequentPlacesScrollView.clipsToBounds = false // Allows card shadows to be visible
        frequentPlacesScrollView.translatesAutoresizingMaskIntoConstraints = false

        frequentPlacesStack = UIStackView()
        frequentPlacesStack.axis = .horizontal
        frequentPlacesStack.spacing = 12 // Spacing between cards
        frequentPlacesStack.translatesAutoresizingMaskIntoConstraints = false
        frequentPlacesScrollView.addSubview(frequentPlacesStack)

        NSLayoutConstraint.activate([
            frequentPlacesStack.topAnchor.constraint(equalTo: frequentPlacesScrollView.topAnchor),
            frequentPlacesStack.bottomAnchor.constraint(equalTo: frequentPlacesScrollView.bottomAnchor),
            frequentPlacesStack.leadingAnchor.constraint(equalTo: frequentPlacesScrollView.leadingAnchor),
            frequentPlacesStack.trailingAnchor.constraint(equalTo: frequentPlacesScrollView.trailingAnchor)
        ])
        
        contentStack.addArrangedSubview(frequentPlacesScrollView)
        frequentPlacesScrollView.heightAnchor.constraint(equalToConstant: 70).isActive = true // Height of the scrollable area
        contentStack.setCustomSpacing(30, after: frequentPlacesScrollView)
    }

    private func setupNearAttractionsSection() {
        let nearLabel = makeSectionHeaderLabel(text: "Station Near You")
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
        
        // Disable QuickType bar and other iOS input suggestions
        tf.textContentType = .none
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.smartInsertDeleteType = .no
        tf.autocapitalizationType = .none
        if #available(iOS 11.0, *) {
            tf.inputAssistantItem.leadingBarButtonGroups = []
            tf.inputAssistantItem.trailingBarButtonGroups = []
        }
        
        // Ensure text field is interactive
        tf.isUserInteractionEnabled = true
        tf.isEnabled = true
        
        return tf
    }
    
    private func makeSectionHeaderLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        return label
    }
    
    private func makeGreetingWithLogoAndAreaBlock(greeting: String, username: String, area: String) -> UIStackView {
        // Greeting label
        let greetingLabel = UILabel()
        greetingLabel.numberOfLines = 0
        let greetingAttributedText = NSMutableAttributedString(
            string: "Hi, \(username)! 👋\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: AppColors.greetingText
            ]
        )
        greetingAttributedText.append(NSAttributedString(
            string: greeting,
            attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                .foregroundColor: AppColors.secondaryText
            ]
        ))
        greetingLabel.attributedText = greetingAttributedText
        
        // Store reference to welcome message label
        welcomeMessageLabel = greetingLabel

        // Area Block
        let areaBlock = UIView()
        areaBlock.backgroundColor = AppColors.areaBlockBackground
        areaBlock.layer.cornerRadius = 12
        areaBlock.layer.masksToBounds = true
        areaBlock.translatesAutoresizingMaskIntoConstraints = false

        // Use the class property areaLabel and initialize it here
        areaLabel = UILabel() // Initialize the class property
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

        // Left side vertical stack: greeting + area
        let leftStack = UIStackView(arrangedSubviews: [greetingLabel, areaBlock])
        leftStack.axis = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 5

        // Logo (right)
        let logoImageView = UIImageView(image: UIImage(named: "ontimego_logo"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.setContentHuggingPriority(.required, for: .horizontal)
        logoImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 120).isActive = true
        logoImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 120).isActive = true

        // Horizontal stack: left (greeting+area) + right (logo)
        let mainStack = UIStackView(arrangedSubviews: [leftStack, logoImageView])
        mainStack.axis = .horizontal
        mainStack.alignment = .center // Center vertically

        return mainStack
    }
    // MARK: - Frequent Places UI & Logic
    private func populateFrequentPlacesCards() {
        // Ensure stack is available
        guard frequentPlacesStack != nil else {
            print("⚠️ frequentPlacesStack is nil in populateFrequentPlacesCards")
            return
        }
        frequentPlacesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for place in frequentPlaces {
            let card = createFrequentPlaceCard(savedPlace: place)
            frequentPlacesStack.addArrangedSubview(card)
        }

        // Add "Add More" Button
        addFrequentPlaceButton = UIButton(type: .custom) 
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            let plusImage = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
            addFrequentPlaceButton.setImage(plusImage, for: .normal)
        } else {
            addFrequentPlaceButton.setTitle("+", for: .normal)
            addFrequentPlaceButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        }
        addFrequentPlaceButton.tintColor = AppColors.accentBlue
        addFrequentPlaceButton.addTarget(self, action: #selector(addNewFrequentPlaceTapped), for: .touchUpInside)
        addFrequentPlaceButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a container view for the button
        let addButtonContainer = UIView()
        addButtonContainer.backgroundColor = AppColors.cardBackground
        addButtonContainer.layer.cornerRadius = 16
        addButtonContainer.layer.shadowColor = AppColors.shadowColor.cgColor
        addButtonContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        addButtonContainer.layer.shadowRadius = 8
        addButtonContainer.layer.shadowOpacity = 0.07
        addButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        
        addButtonContainer.addSubview(addFrequentPlaceButton)
        
        NSLayoutConstraint.activate([
            addButtonContainer.widthAnchor.constraint(equalToConstant: 110),
            addButtonContainer.heightAnchor.constraint(equalToConstant: 60),
            
            addFrequentPlaceButton.centerXAnchor.constraint(equalTo: addButtonContainer.centerXAnchor),
            addFrequentPlaceButton.centerYAnchor.constraint(equalTo: addButtonContainer.centerYAnchor),
            addFrequentPlaceButton.widthAnchor.constraint(equalToConstant: 44),
            addFrequentPlaceButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        frequentPlacesStack.addArrangedSubview(addButtonContainer)
    }

    private func createFrequentPlaceCard(savedPlace: SavedPlace) -> UIView {
        let card = createCardView()

        let nameLabel = UILabel()
        nameLabel.text = savedPlace.name
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = AppColors.primaryText
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        
        let addressLabel = UILabel()
        if savedPlace.address.starts(with: "Tap to set") {
            addressLabel.text = "Tap to set"
            addressLabel.textColor = AppColors.accentBlue // Highlight tappable placeholders
            addressLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        } else {
            addressLabel.text = savedPlace.address
            addressLabel.textColor = AppColors.secondaryText
            addressLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        }
        addressLabel.textAlignment = .center
        addressLabel.numberOfLines = 1
        addressLabel.lineBreakMode = .byTruncatingTail

        let textStack = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .center // Center text within the stack
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6)
        ])
        
        // Dynamic width based on content can be tricky in horizontal stack.
        // For simplicity, using a slightly adaptive fixed width.
        let cardWidth: CGFloat = (savedPlace.name.count > 9 || (savedPlace.address.count > 15 && !savedPlace.address.starts(with: "Tap to set"))) ? 130 : 110
        card.widthAnchor.constraint(equalToConstant: cardWidth).isActive = true
        card.heightAnchor.constraint(equalToConstant: 60).isActive = true // Fixed height for cards

        card.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(frequentPlaceCardTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        // Store ID for identifying which SavedPlace object this card represents
        card.accessibilityIdentifier = savedPlace.id.uuidString
        // Store name for easier access in tap handler if needed (though ID is primary identifier)
        card.accessibilityLabel = savedPlace.name
        
        // Add edit button
        let editButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let editImage = UIImage(systemName: "pencil.circle.fill", withConfiguration: config)
            editButton.setImage(editImage, for: .normal)
        } else {
            editButton.setTitle("✎", for: .normal)
        }
        editButton.tintColor = AppColors.accentBlue
        editButton.accessibilityIdentifier = savedPlace.id.uuidString
        editButton.addTarget(self, action: #selector(editFrequentPlaceTapped(_:)), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(editButton)
        NSLayoutConstraint.activate([
            editButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            editButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 24),
            editButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Adjust text stack trailing constraint to make room for edit button
        textStack.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -4).isActive = true
        
        // Add swipe gesture for deletion
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeGesture.direction = .left
        card.addGestureRecognizer(swipeGesture)
        
        return card
    }
    
    @objc private func frequentPlaceCardTapped(_ sender: UITapGestureRecognizer) {
        guard let cardView = sender.view,
              let placeIDString = cardView.accessibilityIdentifier,
              let placeID = UUID(uuidString: placeIDString),
              let tappedPlace = frequentPlaces.first(where: { $0.id == placeID }) else {
            print("🛑 Could not identify frequent place from tap via ID.")
            // Fallback or alternative identification if needed, e.g. by accessibilityLabel if ID fails temporarily
            if let cardLabel = sender.view?.accessibilityLabel,
               let fallbackPlace = frequentPlaces.first(where: { $0.name == cardLabel }) {
                handleFrequentPlaceTap(fallbackPlace)
            }
            return
        }
        handleFrequentPlaceTap(tappedPlace)
    }

    // Helper function to handle the tap logic
    private func handleFrequentPlaceTap(_ tappedPlace: SavedPlace) {
        if tappedPlace.address.starts(with: "Tap to set") {
            self.currentlySettingPlaceName = tappedPlace.name
            let customAutocompleteVC = CustomAutocompleteViewController(isForStartLocation: true)
            customAutocompleteVC.delegate = self
            let nav = UINavigationController(rootViewController: customAutocompleteVC)
            present(nav, animated: true)
        } else {
            destinationTextField.text = tappedPlace.address
            updateStartTripButtonState()
        }
    }
    
    @objc private func addNewFrequentPlaceTapped() {
        self.currentlySettingPlaceName = nil
        let customAutocompleteVC = CustomAutocompleteViewController(isForStartLocation: true)
        customAutocompleteVC.delegate = self
        let nav = UINavigationController(rootViewController: customAutocompleteVC)
        present(nav, animated: true)
    }

    @objc private func editFrequentPlaceTapped(_ sender: UIButton) {
        guard let placeIDString = sender.accessibilityIdentifier,
              let placeID = UUID(uuidString: placeIDString),
              let placeToEdit = frequentPlaces.first(where: { $0.id == placeID }) else {
            return
        }
        currentlyEditingFrequentPlace = placeToEdit
        let customAutocompleteVC = CustomAutocompleteViewController(isForStartLocation: true)
        customAutocompleteVC.delegate = self
        let nav = UINavigationController(rootViewController: customAutocompleteVC)
        present(nav, animated: true)
    }

    @objc private func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        guard let cardView = gesture.view,
              let placeIDString = cardView.accessibilityIdentifier,
              let placeID = UUID(uuidString: placeIDString),
              let placeToRemove = frequentPlaces.first(where: { $0.id == placeID }) else {
            return
        }
        
        // Create a delete action view
        let deleteActionView = UIView()
        deleteActionView.backgroundColor = .systemRed
        deleteActionView.translatesAutoresizingMaskIntoConstraints = false
        
        let deleteLabel = UILabel()
        deleteLabel.text = "Delete"
        deleteLabel.textColor = .white
        deleteLabel.font = .systemFont(ofSize: 14, weight: .medium)
        deleteLabel.translatesAutoresizingMaskIntoConstraints = false
        
        deleteActionView.addSubview(deleteLabel)
        NSLayoutConstraint.activate([
            deleteLabel.centerXAnchor.constraint(equalTo: deleteActionView.centerXAnchor),
            deleteLabel.centerYAnchor.constraint(equalTo: deleteActionView.centerYAnchor)
        ])
        
        // Add delete action view to the card
        cardView.addSubview(deleteActionView)
        NSLayoutConstraint.activate([
            deleteActionView.topAnchor.constraint(equalTo: cardView.topAnchor),
            deleteActionView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            deleteActionView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            deleteActionView.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        // Animate the swipe
        UIView.animate(withDuration: 0.3) {
            cardView.transform = CGAffineTransform(translationX: -80, y: 0)
        } completion: { _ in
            // Show confirmation alert
            let alert = UIAlertController(title: "Delete \"\(placeToRemove.name)\"",
                                        message: "Are you sure you want to delete this frequent place?",
                                        preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                SavedPlacesManager.shared.removePlace(withId: placeID,
                                                    defaultName: placeToRemove.name) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("🛑 Error deleting frequent place: \(error.localizedDescription)")
                            self?.showErrorAlert(message: "Could not delete \(placeToRemove.name). Please try again.")
                        } else {
                            print("✅ Frequent place '\(placeToRemove.name)' deleted.")
                            // If Home or Work was deleted, create a new placeholder
                            if placeToRemove.name == "Home" || placeToRemove.name == "Work" {
                                let newPlace = SavedPlace(name: placeToRemove.name,
                                                        address: "Tap to set",
                                                        coordinate: CLLocationCoordinate2D())
                                SavedPlacesManager.shared.addOrUpdatePlace(newPlace) { _ in
                                    self?.refreshFrequentPlacesUI()
                                }
                            } else {
                                self?.refreshFrequentPlacesUI()
                            }
                        }
                    }
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                // Animate back to original position
                UIView.animate(withDuration: 0.3) {
                    cardView.transform = .identity
                } completion: { _ in
                    deleteActionView.removeFromSuperview()
                }
            })
            
            self.present(alert, animated: true)
        }
    }

    // MARK: - Location Manager Delegate & Helpers
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
                completion("Area unknown") // Provide a default
                return
            }
            let placemark = placemarks?.first
            let area = placemark?.subLocality ?? placemark?.locality ?? placemark?.name ?? "Area unknown"
            completion(area)
        }
    }
    
    func updateAreaBlock(_ areaName: String) {
        areaLabel?.text = areaName
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Request location permission and start updates immediately
        locationManager.requestWhenInUseAuthorization()
        
        // Try to get last known location first
        if let lastLocation = locationManager.location {
            self.lastKnownLocation = lastLocation
            self.currentLocation = lastLocation.coordinate
            self.updateUIWithLocation(lastLocation.coordinate)
        }
        
        // Start significant location changes for faster initial fix
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
    }

    private func updateUIWithLocation(_ coordinate: CLLocationCoordinate2D) {
        // Update current location immediately
        currentLocation = coordinate
        
        // Update UI immediately
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.startTextField.text == "Getting current location..." {
                self.startTextField.text = "Current Location"
                self.startTextField.isEnabled = true
            }
            self.updateStartTripButtonState()
        }
        
        // Only proceed with map updates if UI is ready
        guard isUILayoutComplete else {
            print("⚠️ UI layout not yet complete. Buffering location.")
            return
        }
        
        // Update map view if needed
        if let mapView = self.mapView {
            if mapView.camera.target.latitude == 0 && mapView.camera.target.longitude == 0 {
                print("ℹ️ Setting initial map position to: \(coordinate)")
                mapView.camera = GMSCameraPosition.camera(withTarget: coordinate, zoom: 14)
                mapView.isMyLocationEnabled = true
                displayStations()
            }
        }

        // Update area name
        fetchCurrentAreaName(from: coordinate) { [weak self] area in
            DispatchQueue.main.async { self?.updateAreaBlock(area) }
        }
        
        // Fetch weather data with the new coordinates
        fetchCurrentWeather(at: coordinate)
    }

    // Add back the parseCoord function
    private func parseCoord(from string: String) -> CLLocationCoordinate2D? {
        let parts = string.split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastReceivedLocation = locations.last else {
            print("⚠️ locationManager didUpdateLocations: locations array was empty.")
            return
        }

        // Update last known location
        lastKnownLocation = lastReceivedLocation
        
        // Update UI with new location
        updateUIWithLocation(lastReceivedLocation.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🛑 Location manager failed with error: \(error.localizedDescription)")
        areaLabel?.text = "Area unknown (Error)"
        
        // If waiting for current location, show error state
        if startTextField.text == "Getting current location..." {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.startTextField.text = "Location Error"
                self.startTextField.isEnabled = true
                self.showErrorAlert(message: "Could not get your current location. Please try again or select a different location.")
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("ℹ️ Location authorization status changed to: \(manager.authorizationStatus.rawValue)")
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location access granted. Starting location updates.")
            locationManager.startUpdatingLocation() // Start if now authorized
        case .denied, .restricted:
            print("❌ Location access denied or restricted.")
            currentLocation = nil // Clear current location if permission is revoked
            areaLabel?.text = "Location Denied"
            // Update UI, maybe disable location-dependent features or show message
        case .notDetermined:
            print("🤷 Location authorization not determined yet.")
            // App will wait for user's decision from the prompt
        @unknown default:
            print("⚠️ Unknown location authorization status after change.")
        }
    }

    // MARK: - Station Loading & UI
    private func displayStations() {
        guard self.isUILayoutComplete else { 
            print("⚠️ displayStations: UI layout not complete. Aborting.")
                        return
                    }
                    
        guard let coord = currentLocation else {
            print("ℹ️ Cannot display stations, current location is nil.")
                    DispatchQueue.main.async {
                self.nearAttractionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                let noLocationLabel = UILabel()
                noLocationLabel.text = "Enable location to see nearby tube stations."
                noLocationLabel.font = .systemFont(ofSize: 14)
                noLocationLabel.textColor = AppColors.secondaryText
                noLocationLabel.textAlignment = .center
                self.nearAttractionsStack.addArrangedSubview(noLocationLabel)
            }
            return
        }
        
         guard self.nearAttractionsStack != nil else {
            print("🛑 displayStations: nearAttractionsStack is unexpectedly nil!")
                return
            }
            
        nearAttractionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        displayedPlaceNames.removeAll()

        // 显示加载指示器
        let loadingLabel = UILabel()
        loadingLabel.text = "Loading nearby stations..."
        loadingLabel.font = .systemFont(ofSize: 14)
        loadingLabel.textColor = AppColors.secondaryText
        loadingLabel.textAlignment = .center
        nearAttractionsStack.addArrangedSubview(loadingLabel)

        // 获取附近的站点
        fetchNearbyStations(coord: coord) { [weak self] stations in
            guard let self = self else { return }
            
                    DispatchQueue.main.async {
                // 移除加载指示器
                loadingLabel.removeFromSuperview()
                
                if stations.isEmpty {
                    let noStationsLabel = UILabel()
                    noStationsLabel.text = "No tube stations found nearby."
                    noStationsLabel.font = .systemFont(ofSize: 14)
                    noStationsLabel.textColor = AppColors.secondaryText
                    noStationsLabel.textAlignment = .center
                    self.nearAttractionsStack.addArrangedSubview(noStationsLabel)
                    return
                }
                
                // 显示找到的站点
                for station in stations {
                    let card = self.makeStationCard(name: station.name, coord: station.coordinate, lines: station.lines)
                    self.nearAttractionsStack.addArrangedSubview(card)
                }
            }
        }
    }

    private func fetchNearbyStations(coord: CLLocationCoordinate2D, completion: @escaping ([Station]) -> Void) {
        let baseURL = "https://api.tfl.gov.uk/StopPoint"
        let radius = 2000
        let stopTypes = "NaptanMetroStation"
        let urlString = "\(baseURL)?lat=\(coord.latitude)&lon=\(coord.longitude)&stoptypes=\(stopTypes)&radius=\(radius)"
        
        print("🔍 Fetching TfL stations with URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("🛑 Error: Invalid TfL API URL")
            completion([])
                    return
                }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { completion([]); return }
            
            if let error = error {
                print("🛑 TfL API Error: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🛑 TfL API Error: Invalid response")
                completion([])
                return
            }
            
            print("📡 TfL API Response Status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("🛑 TfL API Error: HTTP Status \(httpResponse.statusCode)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("🛑 TfL API Error: No data received")
                completion([])
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(TfLStopPointResponse.self, from: data)
                print("📊 Found \(response.stopPoints.count) stations")
                
                var stations: [Station] = []
                
                for stopPoint in response.stopPoints {
                    // 只处理地铁站
                    guard stopPoint.modes.contains("tube") else { continue }
                    
                    let stationCoord = CLLocationCoordinate2D(
                        latitude: stopPoint.lat,
                        longitude: stopPoint.lon
                    )
                    
                    let distance = self.calculateDistance(from: coord, to: stationCoord)
                    let lines = stopPoint.lines.map { $0.name }
                    
                    let station = Station(
                        name: stopPoint.commonName,
                        coordinate: stationCoord,
                        distance: distance,
                        lines: lines
                    )
                    stations.append(station)
                }
                
                // 按距离排序并返回最近的5个站点
                let sortedStations = stations.sorted { $0.distance < $1.distance }
                print("🎯 Returning \(sortedStations.count) sorted stations")
                completion(Array(sortedStations.prefix(5)))
                
            } catch {
                print("🛑 TfL API Error: JSON parsing failed - \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("Missing key: \(key.stringValue), context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: expected \(type), context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found: expected \(type), context: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                completion([])
            }
        }.resume()
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    // TfL API 响应模型
    private struct TfLStopPointResponse: Codable {
        let stopPoints: [TfLStopPoint]
    }

    private struct TfLStopPoint: Codable {
        let naptanId: String
        let commonName: String
        let lat: Double
        let lon: Double
        let lines: [Line]
        let modes: [String]
        let lineModeGroups: [LineModeGroup]
        
        enum CodingKeys: String, CodingKey {
            case naptanId
            case commonName
            case lat
            case lon
            case lines
            case modes
            case lineModeGroups
        }
    }
    
    private struct Line: Codable {
        let id: String
        let name: String
        let uri: String
        let type: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case uri
            case type
        }
    }
    
    private struct LineModeGroup: Codable {
        let modeName: String
        let lineIdentifier: [String]
        
        enum CodingKeys: String, CodingKey {
            case modeName
            case lineIdentifier
        }
    }

    private func makeStationCard(name: String, coord: CLLocationCoordinate2D, lines: [String] = []) -> UIView {
        let card = createCardView()
        card.widthAnchor.constraint(equalToConstant: 150).isActive = true
        card.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = AppColors.primaryText
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let lineColorsStack = UIStackView()
        lineColorsStack.axis = .horizontal
        lineColorsStack.spacing = 4
        lineColorsStack.alignment = .center
        lineColorsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 根据线路名称获取颜色并创建颜色条
        for lineId in lines {
            if let color = TfLLineColors.color(for: lineId.lowercased()) {
                let colorView = UIView()
                colorView.backgroundColor = color
                colorView.layer.cornerRadius = 4
                colorView.translatesAutoresizingMaskIntoConstraints = false
                colorView.widthAnchor.constraint(equalToConstant: 25).isActive = true
                colorView.heightAnchor.constraint(equalToConstant: 10).isActive = true
                lineColorsStack.addArrangedSubview(colorView)
            }
        }
        
        let stackView = UIStackView(arrangedSubviews: [nameLabel, lineColorsStack])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10)
        ])
        
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(stationCardTapped(_:))))
        card.accessibilityLabel = name
        card.accessibilityValue = "\(coord.latitude),\(coord.longitude)"
        return card
    }

    @objc private func stationCardTapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view,
              let coordStr = view.accessibilityValue,
              let coord = parseCoord(from: coordStr),
              let name = view.accessibilityLabel else { return }

        let routePreviewVC = RoutePreviewViewController()
        
        if let startAddr = startTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !startAddr.isEmpty,
           startAddr.lowercased() != "current location" {
            geocodeAddress(startAddr) { [weak self] startCoord in
                guard let self = self, let sc = startCoord else {
                    self?.showErrorAlert(message: "Could not find starting address: \"\(startAddr)\". Please try again or use current location.")
                    return
                }
                self.navigateToPreview(vc: routePreviewVC, start: sc, end: coord, startLabel: startAddr, destLabel: name)
            }
        } else if let current = currentLocation {
            navigateToPreview(vc: routePreviewVC, start: current, end: coord, startLabel: "Current Location", destLabel: name)
        } else {
            showErrorAlert(message: "Current location is not available. Please ensure location services are enabled or enter a starting address.")
        }
        
        destinationTextField.text = name
        updateStartTripButtonState()
    }

    // MARK: - Trip Button Action
    @objc private func startTripButtonTapped() {
        guard let destinationAddress = destinationTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !destinationAddress.isEmpty else {
            showErrorAlert(title: "Missing Destination", message: "Please enter a destination.")
                        return
                    }
                    
        let routePreviewVC = RoutePreviewViewController()
        let startAddressText = startTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let startAddr = startAddressText, !startAddr.isEmpty, startAddr.lowercased() != "current location" {
            geocodeAddress(startAddr) { [weak self] startCoord in
                guard let self = self, let sc = startCoord else {
                    self?.showErrorAlert(message: "Could not find starting address: \"\(startAddr)\". Please try again or use current location."); return
                }
                self.geocodeAddress(destinationAddress) { endCoord in
                    guard let ec = endCoord else {
                        self.showErrorAlert(message: "Could not find destination address: \"\(destinationAddress)\"."); return
                    }
                    print("[HomeVC] Passing destinationAddress to navigateToPreview: \(destinationAddress)")
                    self.navigateToPreview(vc: routePreviewVC, start: sc, end: ec, startLabel: startAddr, destLabel: destinationAddress)
                }
            }
        } else { // Use current location
            guard let current = currentLocation else {
                self.showErrorAlert(message: "Current location is not available. Please ensure location services are enabled or enter a starting address."); return
            }
            geocodeAddress(destinationAddress) { [weak self] endCoord in
                guard let self = self, let ec = endCoord else {
                    self?.showErrorAlert(message: "Could not find destination address: \"\(destinationAddress)\"."); return
                }
                print("[HomeVC] Passing destinationAddress to navigateToPreview: \(destinationAddress)")
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
        let isStartValid = !(startTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isDestinationValid = !(destinationTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        
        startTripButton.isEnabled = isStartValid && isDestinationValid
        startTripButton.alpha = startTripButton.isEnabled ? 1.0 : 0.5
    }
    
    private func showErrorAlert(title: String = "Error", message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - UITextFieldDelegate & GMSAutocompleteViewControllerDelegate
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        activeTextField = textField
        
        // If it's start location and no current location yet, show loading state
        if textField === startTextField && currentLocation == nil {
            startTextField.text = "Getting current location..."
            startTextField.isEnabled = false
            
            // If location manager hasn't started updating, start immediately
            if locationManager.authorizationStatus == .authorizedWhenInUse || 
               locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
            
            return false
        }
        
        let customAutocompleteVC = CustomAutocompleteViewController(isForStartLocation: textField === startTextField)
        customAutocompleteVC.delegate = self
        let nav = UINavigationController(rootViewController: customAutocompleteVC)
        present(nav, animated: true, completion: nil)
        
        return false
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) { }
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) { }
    func wasCancelled(_ viewController: GMSAutocompleteViewController) { }

    // MARK: - CustomAutocompleteViewControllerDelegate
    func customAutocompleteViewController(_ controller: CustomAutocompleteViewController, didSelectPlace place: GMSPlace) {
        let placeAddress = place.formattedAddress ?? place.name ?? "Selected Location"
        let placeCoordinate = place.coordinate
        
        SearchHistoryService.shared.saveSearch(query: placeAddress, coordinate: placeCoordinate)
        
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            if let settingPlaceName = self.currentlySettingPlaceName {
                // Handle setting Home/Work
                let placeID = self.frequentPlaces.first(where: { $0.name == settingPlaceName })?.id ?? UUID()
                let savedPlace = SavedPlace(id: placeID,
                                          name: settingPlaceName,
                                          address: placeAddress,
                                          coordinate: placeCoordinate)
                self.saveFrequentPlaceAndUpdateUI(savedPlace)
            } else if let editingPlace = self.currentlyEditingFrequentPlace {
                // Handle editing existing place
                let updatedPlace = SavedPlace(id: editingPlace.id,
                                            name: editingPlace.name,
                                            address: placeAddress,
                                            coordinate: placeCoordinate)
                self.saveFrequentPlaceAndUpdateUI(updatedPlace)
            } else if self.activeTextField === self.startTextField {
                // Handle start location
                self.startTextField.text = placeAddress
                self.currentLocation = placeCoordinate
                // 确保文本字段保持可交互状态
                self.startTextField.isEnabled = true
                self.startTextField.isUserInteractionEnabled = true
            } else if self.activeTextField === self.destinationTextField {
                // Handle destination
                self.destinationTextField.text = placeAddress
                // 确保文本字段保持可交互状态
                self.destinationTextField.isEnabled = true
                self.destinationTextField.isUserInteractionEnabled = true
            }
            
            self.updateStartTripButtonState()
        }
    }
    
    func customAutocompleteViewController(_ controller: CustomAutocompleteViewController, didSelectCurrentLocation location: CLLocationCoordinate2D) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            if self.activeTextField === self.startTextField {
                self.startTextField.text = "Current Location"
                self.currentLocation = location
                self.mapView.camera = GMSCameraPosition.camera(withTarget: location, zoom: 15)
                // 确保文本字段保持可交互状态
                self.startTextField.isEnabled = true
                self.startTextField.isUserInteractionEnabled = true
            }
            
            self.updateStartTripButtonState()
        }
    }
    
    func customAutocompleteViewControllerDidCancel(_ controller: CustomAutocompleteViewController) {
        controller.dismiss(animated: true)
        // 确保文本字段保持可交互状态
        if activeTextField === startTextField {
            startTextField.isEnabled = true
            startTextField.isUserInteractionEnabled = true
        } else if activeTextField === destinationTextField {
            destinationTextField.isEnabled = true
            destinationTextField.isUserInteractionEnabled = true
        }
    }
    
    private func saveFrequentPlaceAndUpdateUI(_ place: SavedPlace) {
        SavedPlacesManager.shared.addOrUpdatePlace(place) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    print("🛑 Error saving frequent place '\(place.name)' to Firestore: \(error.localizedDescription)")
                    self.showErrorAlert(message: "Could not save \"\(place.name)\". Please try again.")
                } else {
                    print("✅ Frequent place '\(place.name)' saved to Firestore.")
                    self.refreshFrequentPlacesUI()
                }
            }
        }
    }

    // MARK: - Sign Out
    @objc private func signOutTapped() {
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            self?.performSignOut()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func performSignOut() {
        do {
            try Auth.auth().signOut()
            print("✅ User signed out successfully")
            
            // Clear any cached data
            SavedPlacesManager.shared.clearCachedData()
            
            // Present login view controller
            let loginVC = LoginViewController()
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = UINavigationController(rootViewController: loginVC)
                window.makeKeyAndVisible()
                UIView.transition(with: window,
                                duration: 0.3,
                                options: .transitionCrossDissolve,
                                animations: nil,
                                completion: nil)
            }
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
            showErrorAlert(message: "Failed to sign out. Please try again.")
        }
    }

    // Add cleanup in deinit
    deinit {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
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

// TfL Line Colors
struct TfLLineColors {
    static func color(for lineId: String) -> UIColor? {
        switch lineId {
        case "bakerloo": return UIColor(red: 0.63, green: 0.35, blue: 0.13, alpha: 1.0) // #995521
        case "central": return UIColor(red: 0.81, green: 0.17, blue: 0.18, alpha: 1.0) // #CE232A
        case "circle": return UIColor(red: 0.99, green: 0.82, blue: 0.00, alpha: 1.0) // #FCBF00
        case "district": return UIColor(red: 0.00, green: 0.44, blue: 0.22, alpha: 1.0) // #00703C
        case "hammersmith-city": return UIColor(red: 0.96, green: 0.69, blue: 0.79, alpha: 1.0) // #F4AFCB
        case "jubilee": return UIColor(red: 0.52, green: 0.58, blue: 0.60, alpha: 1.0) // #858D91
        case "metropolitan": return UIColor(red: 0.54, green: 0.07, blue: 0.34, alpha: 1.0) // #891653
        case "northern": return UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.0) // #000000
        case "piccadilly": return UIColor(red: 0.00, green: 0.22, blue: 0.70, alpha: 1.0) // #0038B3
        case "victoria": return UIColor(red: 0.00, green: 0.65, blue: 0.87, alpha: 1.0) // #00A3DF
        case "waterloo-city": return UIColor(red: 0.49, green: 0.80, blue: 0.72, alpha: 1.0) // #7DC3B2
        case "elizabeth": return UIColor(red: 0.43, green: 0.24, blue: 0.64, alpha: 1.0) // #6F269F
        case "london-overground": return UIColor(red: 0.91, green: 0.37, blue: 0.00, alpha: 1.0) // #ED8B00
        case "tfl-rail": return UIColor(red: 0.00, green: 0.11, blue: 0.44, alpha: 1.0) // #001C78 (Elizabeth Line before full opening)
        case "tramlink": return UIColor(red: 0.53, green: 0.78, blue: 0.00, alpha: 1.0) // #84BD00
        case "dlr": return UIColor(red: 0.00, green: 0.69, blue: 0.69, alpha: 1.0) // #00B1B4
        case "emirates-air-line": return UIColor(red: 0.70, green: 0.11, blue: 0.17, alpha: 1.0) // #B20D25
        case "gondola": return UIColor(red: 0.70, green: 0.11, blue: 0.17, alpha: 1.0) // Same as Emirates Air Line
        default: return nil
        }
    }
}
