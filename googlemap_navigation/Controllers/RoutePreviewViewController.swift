import UIKit
import GoogleMaps
import CoreLocation

class RoutePreviewViewController: UIViewController, GMSMapViewDelegate {
    // MARK: - Inputs
    var startLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var startLabelName: String?
    var destinationLabelName: String?
    var parsedWalkSteps: [WalkStep] = []
    var transitInfos: [TransitInfo] = []
    var walkToStationTime: String?
    var walkToDestinationTime: String?

    // MARK: - Internal state
    private var mapView: GMSMapView!
    private var stationCoordinates: [String: StationMeta] = [:]

    private var entryWalkMin: Double = 0.0
    private var exitWalkMin: Double = 0.0

    // MARK: - UI Elements (Styled)
    private let topRouteLabelContainer: UIView = { // Container for padding
        let view = UIView()
        view.backgroundColor = AppColors.cardBackground.withAlphaComponent(0.95)
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.layer.borderColor = AppColors.subtleGray.withAlphaComponent(0.7).cgColor
        view.layer.borderWidth = 1.0
        view.layer.shadowColor = AppColors.shadowColor.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 3
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let topRouteActualLabel: UILabel = {
        let label = UILabel()
        label.textColor = AppColors.primaryText
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bottomCardView: UIView = {
        let view = UIView()
        view.backgroundColor = AppColors.cardBackground
        view.layer.cornerRadius = 20 // Softer corners
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] 
        view.layer.shadowColor = AppColors.shadowColor.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: -3)
        view.layer.shadowRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomEstimatedLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = AppColors.primaryText
        label.numberOfLines = 0 // Allow wrapping
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bottomConfirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Confirm Route", for: .normal)
        button.backgroundColor = AppColors.accentBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = AppColors.shadowColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground // Or AppColors.background

        setupNavigationBar()
        setupMap()
        setupUI()
        setupActions()
        showRouteIfPossible()
        loadStationCoordinates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupNavigationBar() {
        self.title = "Route Preview"
        navigationController?.navigationBar.tintColor = AppColors.accentBlue

        // Standard back button
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left.circle.fill"), // A slightly more modern icon
                                         style: .plain,
                                         target: self,
                                         action: #selector(backButtonTapped))
        navigationItem.leftBarButtonItem = backButton


         let appearance = UINavigationBarAppearance()
         appearance.configureWithTransparentBackground() // or .configureWithDefaultBackground()
         appearance.backgroundColor = .clear // or AppColors.background
         appearance.titleTextAttributes = [.foregroundColor: AppColors.primaryText]
         navigationItem.standardAppearance = appearance
         navigationItem.scrollEdgeAppearance = appearance
    }

    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Map Setup
    private func setupMap() {
        let camera = GMSCameraPosition.camera(withLatitude: 51.5074, longitude: -0.1278, zoom: 12) // Default London
        mapView = GMSMapView.map(withFrame: view.bounds, camera: camera) // Use convenience init
        mapView.delegate = self
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
        view.addSubview(mapView)
    }

    // MARK: - UI Setup
    private func setupUI() {

        view.addSubview(topRouteLabelContainer)
        topRouteLabelContainer.addSubview(topRouteActualLabel)
        view.addSubview(bottomCardView)
        
        bottomCardView.addSubview(bottomEstimatedLabel)
        bottomCardView.addSubview(bottomConfirmButton)

        NSLayoutConstraint.activate([
            // Top Route Label Container (acting as a floating chip)
            topRouteLabelContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topRouteLabelContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topRouteLabelContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30),
            topRouteLabelContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -30),

            // Actual Label within the container (for padding)
            topRouteActualLabel.topAnchor.constraint(equalTo: topRouteLabelContainer.topAnchor, constant: 8),
            topRouteActualLabel.bottomAnchor.constraint(equalTo: topRouteLabelContainer.bottomAnchor, constant: -8),
            topRouteActualLabel.leadingAnchor.constraint(equalTo: topRouteLabelContainer.leadingAnchor, constant: 16),
            topRouteActualLabel.trailingAnchor.constraint(equalTo: topRouteLabelContainer.trailingAnchor, constant: -16),

            // Bottom Card View
            bottomCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomCardView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // Stick to absolute bottom

            // Estimated Label within Bottom Card
            bottomEstimatedLabel.topAnchor.constraint(equalTo: bottomCardView.topAnchor, constant: 24),
            bottomEstimatedLabel.leadingAnchor.constraint(equalTo: bottomCardView.leadingAnchor, constant: 24),
            bottomEstimatedLabel.trailingAnchor.constraint(equalTo: bottomCardView.trailingAnchor, constant: -24),

            // Confirm Button within Bottom Card
            bottomConfirmButton.topAnchor.constraint(equalTo: bottomEstimatedLabel.bottomAnchor, constant: 20),
            bottomConfirmButton.leadingAnchor.constraint(equalTo: bottomCardView.leadingAnchor, constant: 24),
            bottomConfirmButton.trailingAnchor.constraint(equalTo: bottomCardView.trailingAnchor, constant: -24),
            bottomConfirmButton.heightAnchor.constraint(equalToConstant: 50),
            bottomConfirmButton.bottomAnchor.constraint(equalTo: bottomCardView.safeAreaLayoutGuide.bottomAnchor, constant: -20) // Space from bottom safe area
        ])
    }

    private func setupActions() {
        bottomConfirmButton.addTarget(self, action: #selector(confirmRouteTapped), for: .touchUpInside)
    }

    // MARK: - Load and Render
    private func showRouteIfPossible() {
        guard let start = startLocation, let end = destinationLocation else {
            // Handle case where locations are not set (e.g., show an error or default view)
            topRouteActualLabel.text = "Route information missing"
            bottomEstimatedLabel.text = "Please select start and destination."
            return
        }
        mapView.clear() // Clear previous markers/polylines
        fetchRoute(from: start, to: end)
    }

    private func fetchRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let userLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)

        RouteLogic.shared.fetchRoute(
            from: userLocation,
            to: to,
            speedMultiplier: 1.0 // This could be a user setting in the future
        ) { [weak self] walkSteps, transitSegments, totalTime, routeSteps, walkToStationMin, walkToDestinationMin in
            guard let self = self else { return }
            
            self.parsedWalkSteps = walkSteps
            self.transitInfos = transitSegments
            
            // Set top label content
            if let firstTransit = transitSegments.first,
               let lastTransit = transitSegments.last,
               let departure = firstTransit.departureStation,
               let arrival = lastTransit.arrivalStation {
                self.topRouteActualLabel.text = "\(departure) → \(arrival)"
            } else if let startName = self.startLabelName, !startName.isEmpty,
                      let destName = self.destinationLabelName, !destName.isEmpty {
                self.topRouteActualLabel.text = "\(startName) → \(destName)"
            } else {
                self.topRouteActualLabel.text = "Route Preview"
            }
            
            // Set bottomEstimatedLabel content with improved styling
            let formattedTimeValue = String(format: "%.0f min", totalTime)
            let prefixText = "Estimated time: "
            
            let fullAttributedString = NSMutableAttributedString(string: prefixText, attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: AppColors.secondaryText // Use a secondary color for the prefix
            ])
            fullAttributedString.append(NSAttributedString(string: formattedTimeValue, attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold), // Emphasize the time
                .foregroundColor: AppColors.primaryText
            ]))
            self.bottomEstimatedLabel.attributedText = fullAttributedString
            
            // Store walk times for passing to the summary
            self.walkToStationTime = String(format: "%.0f min", walkToStationMin)
            self.walkToDestinationTime = String(format: "%.0f min", walkToDestinationMin)
            self.entryWalkMin = walkToStationMin
            self.exitWalkMin = walkToDestinationMin

            self.drawPolyline(from: routeSteps)
            self.addMarkersAndPolylines()
        }
    }

    private func drawPolyline(from steps: [[String: Any]]) {
        var bounds = GMSCoordinateBounds()

        for step in steps {
            guard let polylineDict = step["polyline"] as? [String: Any],
                  let points = polylineDict["points"] as? String,
                  let path = GMSPath(fromEncodedPath: points) else { continue }

            let polyline = GMSPolyline(path: path)
            
            if let mode = step["travel_mode"] as? String, mode == "WALKING" {
                polyline.strokeColor = UIColor.systemCyan // Adjusted walking color
                polyline.strokeWidth = 4
                // Dashed line for walking
                polyline.spans = [GMSStyleSpan(style: .solidColor(.clear), segments: 5), GMSStyleSpan(style: .solidColor(.systemCyan), segments: 5)]
            } else if let mode = step["travel_mode"] as? String, mode == "TRANSIT" {
                polyline.strokeWidth = 5 // Slightly thicker for transit lines
                if let td = step["transit_details"] as? [String: Any],
                   let line = td["line"] as? [String: Any],
                   let colorHex = line["color"] as? String {
                    polyline.strokeColor = UIColor(hex: colorHex)
                } else {
                    polyline.strokeColor = AppColors.accentBlue // Default transit color
                }
            } else {
                polyline.strokeColor = AppColors.subtleGray // Fallback color
                polyline.strokeWidth = 3
            }

            polyline.map = self.mapView

            for i in 0..<path.count() {
                bounds = bounds.includingCoordinate(path.coordinate(at: i))
            }
        }
        if bounds.isValid { // Only animate if bounds are valid
             mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60.0))
        }
    }

    private func loadStationCoordinates() {
        RouteLogic.shared.loadAllTubeStations { [weak self] stationsDict in
            self?.stationCoordinates = stationsDict
            // Call addMarkersAndPolylines only if transitInfos is already populated.
            // It's also called in fetchRoute completion, which might be better
            // to ensure data consistency.
            if !(self?.transitInfos.isEmpty ?? true) {
                 self?.addMarkersAndPolylines()
            }
        }
    }

    // In RoutePreviewViewController.swift

    private func addMarkersAndPolylines() {
        guard !transitInfos.isEmpty || startLocation != nil || destinationLocation != nil else { return } // Ensure there's something to draw

        // Clear existing floating labels (this part is correct for UILabels added as subviews)
        for subview in mapView.subviews {
            if subview is UILabel && subview.tag == 1001 { // Tag for floating labels
                subview.removeFromSuperview()
            }
        }

        var allRelevantBounds: GMSCoordinateBounds?

        // Add markers for transit segments
        for info in transitInfos {
            guard let startName = info.departureStation,
                  let endName = info.arrivalStation,
                  let startMeta = stationCoordinates[startName],
                  let endMeta = stationCoordinates[endName] else { continue }

            // Start Marker for this transit segment
            let startMarker = GMSMarker(position: startMeta.coord)
            startMarker.icon = GMSMarker.markerImage(with: AppColors.accentBlue) // Assuming AppColors is defined
            startMarker.title = startName
            // If you need to identify these later for specific removal without mapView.clear(),
            // you could add them to a class property array: self.stationSpecificMarkers.append(startMarker)
            startMarker.map = mapView
            // addFloatingStationLabel(name: startName, coordinate: startMeta.coord) // Optional

            // End Marker for this transit segment
            let endMarker = GMSMarker(position: endMeta.coord)
            endMarker.icon = GMSMarker.markerImage(with: .systemOrange) // Different color for intermediate transit points
            endMarker.title = endName
            endMarker.map = mapView
            // addFloatingStationLabel(name: endName, coordinate: endMeta.coord) // Optional

            if allRelevantBounds == nil {
                allRelevantBounds = GMSCoordinateBounds(coordinate: startMeta.coord, coordinate: endMeta.coord)
            } else {
                allRelevantBounds = allRelevantBounds?.includingCoordinate(startMeta.coord)
                allRelevantBounds = allRelevantBounds?.includingCoordinate(endMeta.coord)
            }

            // MARK: Polyline between stations for this transit segment (This part was outside the loop in your original, moved it in)
            // This seems to be for individual polylines *between* transit stations, not the main route polyline from Google.
            // If you already draw the main route polyline via drawPolyline(from: routeSteps), this might be redundant or for a different purpose.
            // For now, assuming it's for highlighting direct connections between listed transit stops.
            let transitPath = GMSMutablePath()
            transitPath.add(startMeta.coord)
            transitPath.add(endMeta.coord)

            let transitPolyline = GMSPolyline(path: transitPath)
            transitPolyline.strokeWidth = 2.0 // Thinner for specific transit segment highlights
            transitPolyline.strokeColor = UIColor(hex: info.lineColorHex ?? "#007AFF").withAlphaComponent(0.7) // Use line color, ensure UIColor(hex:) is defined
            transitPolyline.map = mapView
        }
        
        // Add overall start and destination markers
        if let start = startLocation {
            let overallStartMarker = GMSMarker(position: start)
            overallStartMarker.title = startLabelName ?? "Start"
            overallStartMarker.icon = GMSMarker.markerImage(with: .systemGreen)
            overallStartMarker.map = mapView
            if allRelevantBounds == nil {
                allRelevantBounds = GMSCoordinateBounds(coordinate: start, coordinate: start)
            } else {
                allRelevantBounds = allRelevantBounds?.includingCoordinate(start)
            }
        }
        if let end = destinationLocation {
            let overallEndMarker = GMSMarker(position: end)
            overallEndMarker.title = destinationLabelName ?? "Destination"
            overallEndMarker.icon = GMSMarker.markerImage(with: .red) // System red for final destination
            overallEndMarker.map = mapView
            if allRelevantBounds == nil {
                // This case should ideally not happen if startLocation is also nil,
                // but as a fallback:
                allRelevantBounds = GMSCoordinateBounds(coordinate: end, coordinate: end)
            } else {
                allRelevantBounds = allRelevantBounds?.includingCoordinate(end)
            }
        }

        // Adjust map camera to fit all relevant markers
        if let bounds = allRelevantBounds, bounds.isValid {
                  // Check if the bounds represent a single point (or very close points)
                  let neCorner = CLLocation(latitude: bounds.northEast.latitude, longitude: bounds.northEast.longitude)
                  let swCorner = CLLocation(latitude: bounds.southWest.latitude, longitude: bounds.southWest.longitude)
                  
                  if neCorner.distance(from: swCorner) < 1 { // If bounds are very small 
                      let update = GMSCameraUpdate.setTarget(bounds.northEast, zoom: 15) // Use one of the corners
                      mapView.animate(with: update)
                  } else {
                      mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 70.0))
                  }
              }
          }
    
    // This function might be redundant if GMSMarker.title and snippet are used effectively.
    // If kept, ensure labels are removed correctly when view reloads or markers are cleared.
    private func addFloatingStationLabel(name: String, coordinate: CLLocationCoordinate2D) {
        let point = mapView.projection.point(for: coordinate)

        let label = UILabel()
        label.tag = 1001 // Tag to identify these labels for removal
        label.text = name
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium) // Smaller font
        label.textColor = AppColors.primaryText
        label.backgroundColor = AppColors.cardBackground.withAlphaComponent(0.8) // Semi-transparent background
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.padding = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4) // Requires UILabel extension for padding
        
        label.sizeToFit()
        // Manually add padding to frame if not subclassing:
        var frame = label.frame
        frame.size.width += 8 // 4pt padding on each side
        frame.size.height += 4 // 2pt padding on top/bottom
        label.frame = frame
        
        label.center = CGPoint(x: point.x, y: point.y - (frame.height / 2) - 15) // Position above marker
        label.translatesAutoresizingMaskIntoConstraints = true // For manual center positioning
        mapView.addSubview(label)
    }


    // MARK: - Confirm & Navigation
    @objc private func confirmRouteTapped() {
        guard !transitInfos.isEmpty || !parsedWalkSteps.isEmpty else { // Check also for walk-only routes
            let alert = UIAlertController(title: "Route Not Ready",
                                          message: "Still loading route information or no route found. Please try again.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        RouteLogic.shared.navigateToSummary(
            from: self,
            transitInfos: self.transitInfos,
            walkSteps: self.parsedWalkSteps,
            estimated: self.bottomEstimatedLabel.attributedText?.string ?? self.bottomEstimatedLabel.text, // Pass the full string
            walkToStationMin: self.entryWalkMin,
            walkToDestinationMin: self.exitWalkMin
        )
    }
}

// Helper extension for UILabel padding (optional, if you want precise padding for floating labels)
extension UILabel {
    private struct AssociatedKeys {
        static var padding = "UILabel_padding_key"
    }

    var padding: UIEdgeInsets? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.padding) as? UIEdgeInsets
        }
        set {
            if let newValue = newValue {
                objc_setAssociatedObject(self, &AssociatedKeys.padding, newValue as UIEdgeInsets?, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }

    override open func draw(_ rect: CGRect) {
        if let insets = padding {
            self.drawText(in: rect.inset(by: insets))
        } else {
            self.drawText(in: rect)
        }
    }

    override open var intrinsicContentSize: CGSize {
        guard let text = self.text else { return super.intrinsicContentSize }
        var contentSize = super.intrinsicContentSize
        if let insets = padding {
            contentSize.height += insets.top + insets.bottom
            contentSize.width += insets.left + insets.right
        }
        return contentSize
    }
}

