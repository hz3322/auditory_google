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
    private var displayedPlaceNames = Set<String>()
    private var startTextField: UITextField!
    private var destinationTextField: UITextField!
    private var profile: UserProfile!
    private var areaLabel: UILabel!
    // Removed greetingAreaStack as a class property, it's now constructed and returned by makeGreetingWithLogoAndAreaBlock
    // private var greetingAreaStack: UIStackView?


    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var mapView: GMSMapView!
    private var nearAttractionsScrollView: UIScrollView!
    private var nearAttractionsStack: UIStackView!
    
    private let startTripButton: UIButton = {
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
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background

        profile = UserProfile(name: "Hanxue")

        setupScrollView()
        setupContent()
        setupLocationManager()
        setupKeyboardNotifications()
        
        navigationController?.isNavigationBarHidden = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.displayAttractions() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }

    // MARK: - Setup Layout
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        
        contentStack.axis = .vertical
        contentStack.spacing = 28
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func setupContent() {
        // 1. Greeting, Logo and Area block
        let username = profile.name ?? "User"
        let greeting = getGreetingText()
        // *** UPDATED FUNCTION CALL ***
        let greetingLogoAndAreaStack = makeGreetingWithLogoAndAreaBlock(greeting: greeting, username: username, area: "Locating...")
        contentStack.addArrangedSubview(greetingLogoAndAreaStack)
        // self.greetingAreaStack = greetingLogoAndAreaStack // Not needed if it's not a class property for external modification
        contentStack.setCustomSpacing(30, after: greetingLogoAndAreaStack)

        // 2. Search Card
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

        // 3. Start Trip Button
        contentStack.addArrangedSubview(startTripButton)
        startTripButton.addTarget(self, action: #selector(startTripButtonTapped), for: .touchUpInside)
        contentStack.setCustomSpacing(30, after: startTripButton)

        // 4. MapView Card
        let mapCardView = createCardView()
        contentStack.addArrangedSubview(mapCardView)
        
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 12)
        mapView = GMSMapView()
        mapView.camera = camera
        mapView.layer.cornerRadius = 12
        mapView.clipsToBounds = true
        mapView.translatesAutoresizingMaskIntoConstraints = false
        
        mapCardView.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapCardView.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapCardView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapCardView.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapCardView.bottomAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 220)
        ])
        contentStack.setCustomSpacing(30, after: mapCardView)
        
        // 5. Frequent Places
        let frequentLabel = makeSectionHeaderLabel(text: "Frequent Places")
        contentStack.addArrangedSubview(frequentLabel)
        contentStack.setCustomSpacing(12, after: frequentLabel)

        let frequentPlaces = ["Imperial College", "Oxford Circus", "Baker Street"]
        let frequentCardsStack = makeHorizontalCardsScrollView(cardData: frequentPlaces.map { ($0, nil) })
        contentStack.addArrangedSubview(frequentCardsStack)
        frequentCardsStack.heightAnchor.constraint(equalToConstant: 70).isActive = true
        contentStack.setCustomSpacing(30, after: frequentCardsStack)

        // 6. Near Of You
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
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOpacity = 0.08
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
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = AppColors.primaryText
        return label
    }
    
    // *** MODIFIED FUNCTION to include Logo next to Greeting Text ***
    private func makeGreetingWithLogoAndAreaBlock(greeting: String, username: String, area: String) -> UIStackView {
        // Greeting label
        let greetingLabel = UILabel()
        greetingLabel.numberOfLines = 0 // Allow text to wrap if needed
        let greetingAttributedText = NSMutableAttributedString(
            string: "Hi, \(username)! 👋\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: AppColors.greetingText
            ]
        )
        greetingAttributedText.append(NSAttributedString(
            string: greeting,
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                .foregroundColor: AppColors.secondaryText
            ]
        ))
        greetingLabel.attributedText = greetingAttributedText
        greetingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        greetingLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)


        // Logo ImageView
        let logoImageView = UIImageView(image: UIImage(named: "ontimego_logo"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100)
        ])
        logoImageView.setContentHuggingPriority(.required, for: .horizontal)
        logoImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Spacer View
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        spacerView.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)

        

        // Horizontal Stack for Greeting and Logo
        let greetingLogoStack = UIStackView(arrangedSubviews: [greetingLabel, logoImageView])
        greetingLogoStack.axis = .horizontal
        greetingLogoStack.alignment = .fill // Aligns items vertically center
        greetingLogoStack.spacing = 12 // Space between greeting text and logo

        // Area Block (as a small chip/tag)
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

        // Main Vertical Stack for the entire header section
        let mainHeaderStack = UIStackView(arrangedSubviews: [greetingLogoStack, areaBlock])
        mainHeaderStack.axis = .vertical
        mainHeaderStack.alignment = .fill // Align areaBlock to the leading edge of the greeting/logo
        mainHeaderStack.spacing = 8 // Space between greeting/logo row and area block
        
        return mainHeaderStack
    }


    private func makeHorizontalCardsScrollView(cardData: [(title: String, imageName: String?)]) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        for data in cardData {
            let card = createSimpleTextCard(title: data.title)
            stackView.addArrangedSubview(card)
        }
        return scrollView
    }

    private func createSimpleTextCard(title: String) -> UIView {
        let card = createCardView()
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = AppColors.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -8)
        ])
        
        card.widthAnchor.constraint(equalToConstant: 130).isActive = true
        card.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        card.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(frequentPlaceTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        card.accessibilityLabel = title

        return card
    }
    
    @objc private func frequentPlaceTapped(_ sender: UITapGestureRecognizer) {
        guard let cardView = sender.view, let placeName = cardView.accessibilityLabel else { return }
        
        destinationTextField.text = placeName
        updateStartTripButtonState()
        print("\(placeName) tapped")
    }


    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Location Update
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if startTextField.text?.isEmpty ?? true {
            startTextField.text = "Current Location"
        }
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        
        if let coord = currentLocation {
            fetchCurrentAreaName(from: coord) { [weak self] area in
                DispatchQueue.main.async {
                    self?.updateAreaBlock(area)
                }
            }
        }
        
        mapView.animate(toLocation: location.coordinate)
        mapView.camera = GMSCameraPosition.camera(withTarget: location.coordinate, zoom: 14)
        mapView.clear()
        GMSMarker(position: location.coordinate).map = mapView
        
        displayAttractions()
        locationManager.stopUpdatingLocation()
    }
    
    func updateAreaBlock(_ areaName: String) {
        areaLabel?.text = areaName
    }
    
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
            let placemark = placemarks?.first
            let area = placemark?.subLocality ?? placemark?.locality ?? placemark?.name ?? "Unknown area"
            completion(area)
        }
    }

    // MARK: - Attractions Loading
    private func displayAttractions() {
        guard let coord = currentLocation else { return }
        nearAttractionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        displayedPlaceNames.removeAll()

        let desiredCount = Int.random(in: 4...6)
        var fetchedCount = 0
        var candidatesProcessed = 0
        let maxTries = 20

        func fetchOneAttraction() {
            guard fetchedCount < desiredCount, candidatesProcessed < maxTries else { return }
            
            let currentCandidatesProcessedBeforeFetch = candidatesProcessed // Capture current value
            candidatesProcessed += 1
            
            fetchNearbyAttractionImage(coord: coord) { [weak self] image, name, placeCoord in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let img = image, let placeName = name, let placeCoordinate = placeCoord, !self.displayedPlaceNames.contains(placeName) {
                        self.displayedPlaceNames.insert(placeName)
                        let card = self.makeAttractionCard(name: placeName, image: img, coord: placeCoordinate)
                        self.nearAttractionsStack.addArrangedSubview(card)
                        fetchedCount += 1
                    }
                    if fetchedCount < desiredCount && currentCandidatesProcessedBeforeFetch < maxTries - 1 { // check against value before this recursive call + allowance for this attempt
                        fetchOneAttraction()
                    }
                }
            }
        }
        fetchOneAttraction()
    }
    

    private func fetchNearbyAttractionImage(
        coord: CLLocationCoordinate2D,
        completion: @escaping (UIImage?, String?, CLLocationCoordinate2D?) -> Void
    ) {
        let urlStr = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(coord.latitude),\(coord.longitude)&radius=3000&type=tourist_attraction&key=AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE"
        guard let url = URL(string: urlStr) else {
            completion(nil, nil,nil); return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if error != nil {
                completion(nil, nil, nil); return
            }
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                completion(nil, nil,nil); return
            }

            let freshCandidates = results.filter { place -> Bool in
                guard let name = place["name"] as? String else { return false }
                return place["photos"] != nil && !self.displayedPlaceNames.contains(name)
            }

            guard let place = freshCandidates.randomElement(),
                  let name = place["name"] as? String,
                  let geometry = place["geometry"] as? [String: Any],
                  let location = geometry["location"] as? [String: Any],
                  let lat = location["lat"] as? Double,
                  let lng = location["lng"] as? Double,
                  let photos = place["photos"] as? [[String: Any]],
                  let reference = photos.first?["photo_reference"] as? String else {
                completion(nil, nil, nil); return
            }
            let attractionCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)

            let cacheKey = NSString(string: reference)
            if let cached = self.imageCache.object(forKey: cacheKey) {
                completion(cached, name, attractionCoord); return
            }

            let photoURLStr = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(reference)&key=AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSEY"
            guard let photoURL = URL(string: photoURLStr) else {
                completion(nil, name,attractionCoord); return
            }

            URLSession.shared.dataTask(with: photoURL) { data, _, photoError in
                if photoError != nil {
                     completion(nil, name, attractionCoord); return
                }
                guard let data = data, let image = UIImage(data: data) else {
                    completion(nil, name, attractionCoord); return
                }
                self.imageCache.setObject(image, forKey: cacheKey)
                completion(image, name, attractionCoord)
            }.resume()
        }.resume()
    }

    // MARK: - Build Attraction Card (styled)
    private func makeAttractionCard(name: String, image: UIImage, coord: CLLocationCoordinate2D) -> UIView {
        let card = createCardView()
        card.widthAnchor.constraint(equalToConstant: 160).isActive = true
        card.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]


        let textContentView = UIView()
        textContentView.translatesAutoresizingMaskIntoConstraints = false
        textContentView.backgroundColor = .clear

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 14, weight: .semibold)
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
            imageView.heightAnchor.constraint(equalTo: card.heightAnchor, multiplier: 0.65),

            textContentView.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            textContentView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            textContentView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            textContentView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            label.topAnchor.constraint(equalTo: textContentView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: textContentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: textContentView.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(lessThanOrEqualTo: textContentView.bottomAnchor, constant: -8)
        ])

        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
        card.accessibilityLabel = name
        card.accessibilityValue = "\(coord.latitude),\(coord.longitude)"
        return card
    }

    @objc private func cardTapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view,
              let coordStr = view.accessibilityValue,
              let endCoord = parseCoord(from: coordStr),
              let name = view.accessibilityLabel else { return }

        if let text = startTextField.text, !text.isEmpty, text != "Current Location" {
            geocodeAddress(text) { [weak self] startCoord in
                guard let self = self, let startCoord = startCoord else { return }
                DispatchQueue.main.async {
                    self.pushRoute(start: startCoord, end: endCoord, startLabel: text, destLabel: name)
                }
            }
        } else if let current = currentLocation {
            self.pushRoute(start: current, end: endCoord, startLabel: "Current Location", destLabel: name)
        }
    }
    
    private func parseCoord(from string: String) -> CLLocationCoordinate2D? {
        let parts = string.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lng = Double(parts[1]) else { return nil }
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
            return
        }

        let routePreviewVC = RoutePreviewViewController()

        let startAddress = startTextField.text
        if let startAddr = startAddress, !startAddr.isEmpty, startAddr != "Current Location" {
            geocodeAddress(startAddr) { [weak self] startCoord in
                guard let startCoord = startCoord else {
                    print("Could not geocode start address: \(startAddr)")
                    return
                }
                self?.geocodeAddress(destinationAddress) { endCoord in
                    guard let endCoord = endCoord else {
                        print("Could not geocode destination address: \(destinationAddress)")
                        return
                    }
                    routePreviewVC.startLocation = startCoord
                    routePreviewVC.destinationLocation = endCoord
                    routePreviewVC.startLabelName = startAddr
                    routePreviewVC.destinationLabelName = destinationAddress
                    DispatchQueue.main.async {
                        self?.navigationController?.pushViewController(routePreviewVC, animated: true)
                    }
                }
            }
        } else {
            guard let current = currentLocation else {
                print("Current location not available.")
                return
            }
            geocodeAddress(destinationAddress) { [weak self] endCoord in
                guard let endCoord = endCoord else {
                     print("Could not geocode destination address: \(destinationAddress)")
                    return
                }
                routePreviewVC.startLocation = current
                routePreviewVC.destinationLocation = endCoord
                routePreviewVC.startLabelName = "Current Location"
                routePreviewVC.destinationLabelName = destinationAddress
                DispatchQueue.main.async {
                    self?.navigationController?.pushViewController(routePreviewVC, animated: true)
                }
            }
        }
    }

    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        CLGeocoder().geocodeAddressString(address) { placemarks, error in
            if error != nil {
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

        let acAppearance = GMSAutocompleteViewController().view
        acAppearance?.backgroundColor = AppColors.background
        
        let filter = GMSAutocompleteFilter()
        filter.countries = ["GB"]
        autocompleteController.autocompleteFilter = filter

        autocompleteController.view.tag = (textField == startTextField) ? 1 : 2
        present(autocompleteController, animated: true)
        return false
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        if viewController.view.tag == 1 {
            startTextField.text = place.formattedAddress ?? place.name
            currentLocation = place.coordinate
        } else {
            destinationTextField.text = place.formattedAddress ?? place.name
        }
        updateStartTripButtonState()
        dismiss(animated: true)
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
        view.addGestureRecognizer(tapGesture)
    }
   
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = keyboardFrame.height
        
        var contentInset = scrollView.contentInset
        contentInset.bottom = keyboardHeight
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
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
