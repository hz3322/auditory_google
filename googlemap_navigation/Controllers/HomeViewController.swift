
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
       var startLocation: CLLocationCoordinate2D!
       var destinationLocation: CLLocationCoordinate2D!

    // MARK: - UI Components
    
    
       private let mainScrollView: UIScrollView = {
           let scrollView = UIScrollView()
           scrollView.translatesAutoresizingMaskIntoConstraints = false
           scrollView.alwaysBounceVertical = true
           return scrollView
       }()

       private let contentView: UIView = {
           let view = UIView()
           view.translatesAutoresizingMaskIntoConstraints = false
           return view
       }()

       private lazy var cardContainer: UIView = {
           let view = UIView()
           view.translatesAutoresizingMaskIntoConstraints = false
           return view
       }()

       private lazy var stationScrollView: UIScrollView = {
           let scrollView = UIScrollView()
           scrollView.translatesAutoresizingMaskIntoConstraints = false
           return scrollView
       }()

       private lazy var stationStackView: UIStackView = {
           let stackView = UIStackView()
           stackView.axis = .horizontal
           stackView.spacing = 12
           stackView.translatesAutoresizingMaskIntoConstraints = false
           return stackView
       }()

       private let startTextField: UITextField = {
           let tf = UITextField()
           tf.placeholder = "Current Location"
           tf.borderStyle = .roundedRect
           tf.returnKeyType = .done
           tf.translatesAutoresizingMaskIntoConstraints = false
           return tf
       }()

       private let destinationTextField: UITextField = {
           let tf = UITextField()
           tf.placeholder = "Enter Destination"
           tf.borderStyle = .roundedRect
           tf.returnKeyType = .done
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


  
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Home"

        setupMap()
        setupScrollViewLayout()
        setupCardUI()
        setupLocationManager()
        setupKeyboardNotifications()

        startTextField.delegate = self
        destinationTextField.delegate = self

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.displayAttractions()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Setup Layout
       private func setupScrollViewLayout() {
           view.addSubview(mainScrollView)
           mainScrollView.addSubview(contentView)

           NSLayoutConstraint.activate([
               mainScrollView.topAnchor.constraint(equalTo: view.topAnchor),
               mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
               mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
               mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

               contentView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
               contentView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
               contentView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
               contentView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
               contentView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor)
           ])
       }


    private func setupMap() {
            let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 12)
            mapView = GMSMapView()
            mapView.frame = view.bounds
            mapView.camera = camera
            mapView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(mapView)

            NSLayoutConstraint.activate([
                mapView.topAnchor.constraint(equalTo: contentView.topAnchor),
                mapView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                mapView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                mapView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.35)
            ])
        }

        private func setupCardUI() {
            contentView.addSubview(cardContainer)
            cardContainer.addSubview(startTextField)
            cardContainer.addSubview(destinationTextField)
            cardContainer.addSubview(stationScrollView)
            stationScrollView.addSubview(stationStackView)
            contentView.addSubview(startTripButton)


            NSLayoutConstraint.activate([
                cardContainer.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 12),
                cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

                startTextField.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 16),
                startTextField.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
                startTextField.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
                startTextField.heightAnchor.constraint(equalToConstant: 44),

                destinationTextField.topAnchor.constraint(equalTo: startTextField.bottomAnchor, constant: 12),
                destinationTextField.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
                destinationTextField.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
                destinationTextField.heightAnchor.constraint(equalToConstant: 44),

                stationScrollView.topAnchor.constraint(equalTo: destinationTextField.bottomAnchor, constant: 12),
                stationScrollView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
                stationScrollView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
                stationScrollView.heightAnchor.constraint(equalToConstant: 200),
                stationScrollView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -16),

                stationStackView.topAnchor.constraint(equalTo: stationScrollView.topAnchor),
                stationStackView.leadingAnchor.constraint(equalTo: stationScrollView.leadingAnchor, constant: 16),
                stationStackView.trailingAnchor.constraint(equalTo: stationScrollView.trailingAnchor),
                stationStackView.bottomAnchor.constraint(equalTo: stationScrollView.bottomAnchor),
                stationStackView.heightAnchor.constraint(equalTo: stationScrollView.heightAnchor),

                startTripButton.topAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: 24),
                startTripButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                startTripButton.widthAnchor.constraint(equalToConstant: 200),
                startTripButton.heightAnchor.constraint(equalToConstant: 50),
                startTripButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
            ])

            startTripButton.addTarget(self, action: #selector(startTripButtonTapped), for: .touchUpInside)
            updateStartTripButtonState()
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
        stationStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
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
                        self.stationStackView.addArrangedSubview(card)
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
