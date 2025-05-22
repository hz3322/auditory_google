import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class HomeViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate, GMSAutocompleteViewControllerDelegate {

    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var mapView: GMSMapView!
    private var currentLocation: CLLocationCoordinate2D?
    private var imageCache = NSCache<NSString, UIImage>()
    private var displayedPlaceNames = Set<String>()
    private var startTextField: UITextField!
    private var destinationTextField: UITextField!
    private let frequentStack = UIStackView()
    

    // MARK: - UI Components
   
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    
    // -- Custom sections
    private lazy var greetingHeader = GreetingHeaderView(name: "Hanxue", time: "Good Morning")
    private lazy var locationCard = LocationCardView(locationText: "Current Location: London")
    
    
    func makeRoundedTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.backgroundColor = .white
        tf.layer.cornerRadius = 18
        tf.layer.shadowColor = UIColor.black.cgColor
        tf.layer.shadowOpacity = 0.04
        tf.layer.shadowRadius = 6
        tf.layer.shadowOffset = CGSize(width: 0, height: 2)
        tf.font = UIFont.systemFont(ofSize: 17)
        tf.borderStyle = .none
        tf.setLeftPaddingPoints(16)
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return tf
    }

       private let startTripButton: UIButton = {
           let button = UIButton(type: .system)
           button.setTitle("Start the Trip", for: .normal)
           button.backgroundColor = .systemBlue
           button.setTitleColor(.white, for: .normal)
           button.layer.cornerRadius = 10
           button.translatesAutoresizingMaskIntoConstraints = false
           return button
       }()


  
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1)

        setupScrollView()
        setupContent()
        setupLocationManager()
        setupKeyboardNotifications()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.displayAttractions() }
    }
    
    // MARK: - Setup Layout
    
    private func setupScrollView() {
           scrollView.translatesAutoresizingMaskIntoConstraints = false
           contentStack.axis = .vertical
           contentStack.spacing = 24
           contentStack.translatesAutoresizingMaskIntoConstraints = false

           view.addSubview(scrollView)
           scrollView.addSubview(contentStack)

           NSLayoutConstraint.activate([
               scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
               scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
               scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
               scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
               contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
               contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 18),
               contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -18),
               contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
               contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -36)
           ])
       }

       private func setupContent() {
           // 1. Greeting
           contentStack.addArrangedSubview(greetingHeader)
           // 2. Location Card
           contentStack.addArrangedSubview(locationCard)
           // 3. Search Bars
           startTextField = makeRoundedTextField(placeholder: "From (Current Location)")
           destinationTextField = makeRoundedTextField(placeholder: "To (Enter Destination)")
           let searchStack = UIStackView(arrangedSubviews: [startTextField, destinationTextField])
           searchStack.axis = .vertical
           searchStack.spacing = 10
           contentStack.addArrangedSubview(searchStack)
           // 4. MapView
           mapView = GMSMapView()
           mapView.layer.cornerRadius = 18
           mapView.translatesAutoresizingMaskIntoConstraints = false
           mapView.heightAnchor.constraint(equalToConstant: 220).isActive = true
           contentStack.addArrangedSubview(mapView)
           // 5. Frequent Places (Fake data example)
           let frequentLabel = UILabel()
           frequentLabel.text = "Frequent Places"
           frequentLabel.font = .boldSystemFont(ofSize: 19)
           frequentLabel.textColor = .systemBlue
           contentStack.addArrangedSubview(frequentLabel)
           // 6. Frequent places cards
           let frequentStack = makeHorizontalCardStack(cardTitles: ["Imperial College", "Oxford Circus", "Baker Street"])
           contentStack.addArrangedSubview(frequentStack)
           // 7. Near of You
           let nearLabel = UILabel()
           nearLabel.text = "Near Of You"
           nearLabel.font = .boldSystemFont(ofSize: 19)
           nearLabel.textColor = .systemBlue
           contentStack.addArrangedSubview(nearLabel)
           // 8. Station cards
           let nearStack = makeHorizontalCardStack(cardTitles: ["Hyde Park", "Piccadilly Circus", "London Eye"])
           contentStack.addArrangedSubview(nearStack)
       }
       
       private func makeHorizontalCardStack(cardTitles: [String]) -> UIStackView {
           let stack = UIStackView()
           stack.axis = .horizontal
           stack.spacing = 16
           for title in cardTitles {
               let card = UIView()
               card.backgroundColor = .white
               card.layer.cornerRadius = 12
               card.layer.shadowColor = UIColor.black.cgColor
               card.layer.shadowOpacity = 0.04
               card.layer.shadowRadius = 6
               card.layer.shadowOffset = CGSize(width: 0, height: 2)
               let label = UILabel()
               label.text = title
               label.font = .systemFont(ofSize: 16, weight: .medium)
               label.textColor = .black
               label.translatesAutoresizingMaskIntoConstraints = false
               card.addSubview(label)
               label.centerXAnchor.constraint(equalTo: card.centerXAnchor).isActive = true
               label.centerYAnchor.constraint(equalTo: card.centerYAnchor).isActive = true
               card.translatesAutoresizingMaskIntoConstraints = false
               card.widthAnchor.constraint(equalToConstant: 120).isActive = true
               card.heightAnchor.constraint(equalToConstant: 60).isActive = true
               stack.addArrangedSubview(card)
           }
           return stack
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
        mapView.animate(toLocation: location.coordinate)
        mapView.clear()
        GMSMarker(position: location.coordinate).map = mapView
        displayAttractions()
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Attractions Loading
    private func displayAttractions() {
        guard let coord = currentLocation else { return }
        frequentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        displayedPlaceNames.removeAll()

        let desiredCount = Int.random(in: 3...5)
        var fetchedCount = 0
        var candidatesProcessed = 0
        let maxTries = 20

        func fetchOne() {
            fetchNearbyAttractionImage(coord: coord) { [weak self] image, name, placeCoord in
                guard let self = self,
                      let image = image,
                      let name = name,
                      let placeCoord = placeCoord else {
                    if candidatesProcessed < maxTries { candidatesProcessed += 1; fetchOne() }
                    return
                }

                DispatchQueue.main.async {
                    if !self.displayedPlaceNames.contains(name) {
                        self.displayedPlaceNames.insert(name)
                        let card = self.makeStationCard(name: name, image: image, coord: placeCoord)
                        self.frequentStack.addArrangedSubview(card)
                        fetchedCount += 1
                    }
                    if fetchedCount < desiredCount && candidatesProcessed < maxTries {
                        candidatesProcessed += 1
                        fetchOne()
                    }
                }
            }
        }
        fetchOne()
    }
    

    private func fetchNearbyAttractionImage(
        coord: CLLocationCoordinate2D,
        completion: @escaping (UIImage?, String?, CLLocationCoordinate2D?) -> Void
    ) {
        let urlStr = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(coord.latitude),\(coord.longitude)&radius=3000&type=tourist_attraction&key=AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE"
        guard let url = URL(string: urlStr) else {
            completion(nil, nil,nil); return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                completion(nil, nil,nil); return
            }

            let candidates = results.filter { $0["photos"] != nil }.prefix(10)
            guard let place = candidates.randomElement(),
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

            let photoURL = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(reference)&key=AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE"
            guard let url = URL(string: photoURL) else {
                completion(nil, name,attractionCoord); return
            }

            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let image = UIImage(data: data) else {
                    completion(nil, name, attractionCoord); return
                }
                self.imageCache.setObject(image, forKey: cacheKey)
                completion(image, name, attractionCoord)
            }.resume()
        }.resume()
    }

    // MARK: - Build Card

    private func makeStationCard(name: String, image: UIImage, coord: CLLocationCoordinate2D) -> UIView {
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 10
        container.clipsToBounds = true
        container.backgroundColor = .white
        container.widthAnchor.constraint(equalToConstant: 160).isActive = true
        container.heightAnchor.constraint(equalToConstant: 160).isActive = true
        container.accessibilityLabel = name
        container.accessibilityValue = "\(coord.latitude),\(coord.longitude)"

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        let label = UILabel()
        label.text = name
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .black
        label.textAlignment = .center
        label.backgroundColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.8),

            label.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
        container.accessibilityLabel = name
        return container
    }

    @objc private func cardTapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view,
              let coordStr = view.accessibilityValue,
              let endCoord = parseCoord(from: coordStr),
              let name = view.accessibilityLabel else { return } // 景点名

        if let text = startTextField.text, !text.isEmpty, text != "Current Location" {
            // 用户输入了起点
            geocodeAddress(text) { [weak self] startCoord in
                guard let self = self, let startCoord = startCoord else { return }
                DispatchQueue.main.async {
                    self.pushRoute(
                        start: startCoord,
                        end: endCoord,
                        startLabel: text,
                        destLabel: name
                    )
                }
            }
        } else if let current = currentLocation {
            // 默认当前位置
            self.pushRoute(
                start: current,
                end: endCoord,
                startLabel: "Current Location",    // 起点名字（默认）
                destLabel: name                    // 终点名字
            )
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
    // MARK: - Trip Button

    @objc private func startTripButtonTapped() {
        guard let destinationAddress = destinationTextField.text, !destinationAddress.isEmpty else { return }

        let routePreviewVC = RoutePreviewViewController()

        if let startAddress = startTextField.text, !startAddress.isEmpty, startAddress != "Current Location" {
            // 用户手动填了起点
            geocodeAddress(startAddress) { [weak self] startCoord in
                guard let startCoord = startCoord else { return }
                self?.geocodeAddress(destinationAddress) { endCoord in
                    guard let endCoord = endCoord else { return }
                    routePreviewVC.startLocation = startCoord
                    routePreviewVC.destinationLocation = endCoord
                    DispatchQueue.main.async {
                        self?.navigationController?.pushViewController(routePreviewVC, animated: true)
                    }
                }
            }
        } else {
            // 没填起点，用当前位置
            guard let current = currentLocation else { return }
            geocodeAddress(destinationAddress) { [weak self] endCoord in
                guard let endCoord = endCoord else { return }
                routePreviewVC.startLocation = current
                routePreviewVC.destinationLocation = endCoord
                DispatchQueue.main.async {
                    self?.navigationController?.pushViewController(routePreviewVC, animated: true)
                }
            }
        }
    }

    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        CLGeocoder().geocodeAddressString(address) { placemarks, _ in
            completion(placemarks?.first?.location?.coordinate)
        }
    }
    
    private func updateStartTripButtonState() {
        let hasStart = !(startTextField.text?.isEmpty ?? true)
        let hasDestination = !(destinationTextField.text?.isEmpty ?? true)
        startTripButton.isEnabled = hasStart && hasDestination
        startTripButton.alpha = startTripButton.isEnabled ? 1.0 : 0.5
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self

        let filter = GMSAutocompleteFilter()
        filter.countries = ["GB"] // 🇬🇧 限定 UK
        autocompleteController.autocompleteFilter = filter

        if textField == startTextField {
            autocompleteController.view.tag = 1
        } else if textField == destinationTextField {
            autocompleteController.view.tag = 2
        }

        present(autocompleteController, animated: true)
        return false
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        if viewController.view.tag == 1 {
            startTextField.text = place.formattedAddress
            currentLocation = place.coordinate // ✅ 如果起点填了就用
        } else if viewController.view.tag == 2 {
            destinationTextField.text = place.formattedAddress
        }
        updateStartTripButtonState()
        dismiss(animated: true)
    }

    // 自动补全失败
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        print("❌ Autocomplete error: \(error.localizedDescription)")
        dismiss(animated: true, completion: nil)
    }

    // 用户取消了自动补全
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }


    // MARK: - Keyboard

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
   

    @objc private func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           self.view.frame.origin.y == 0 {
            self.view.frame.origin.y -= keyboardFrame.height / 2
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        self.view.frame.origin.y = 0
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
}
