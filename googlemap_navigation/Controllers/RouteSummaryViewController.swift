import UIKit
import CoreLocation

class RouteSummaryViewController: UIViewController, CLLocationManagerDelegate {
    
    // MARK: - Properties
    var totalEstimatedTime: String?
    var walkToStationTime: String?
    var walkToDestinationTime: String?
    var transitInfos: [TransitInfo] = []
    var routeDepartureTime: String?
    var routeArrivalTime: String?
    
    // UI
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let progressBarCard = UIView()
    private let progressBarBackground = UIView()
    private let stationEmoji = UILabel()
    private let platformEmoji = UILabel()
    private let personDot = UILabel()
    private var personDotLeadingConstraint: NSLayoutConstraint?
    
    private var movingDot = UIView()
    private var dotCenterYConstraint: NSLayoutConstraint?
    private var timelineMap: [String: TimelineView] = [:]
    private var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
    private var stopLabelMap: [String: UILabel] = [:]
    
    private var locationManager = CLLocationManager()
    var walkToStationTimeSec: Double = 0
    var stationToPlatformTimeSec: Double = 120
    var transferTimesSec: [Double] = []
    var nextTrainArrivalDate: Date = Date()
    private var progressService: JourneyProgressService?
    private let deltaTimeLabel = UILabel()
    private var startCoord: CLLocationCoordinate2D?
    private var endCoord: CLLocationCoordinate2D?
    
    
    private var isUsingLocationProgress = true // Track if using GPS progress
    private var userOriginLocation: CLLocation? // Where the user started
    private var userStationLocation: CLLocation? // Tube station entrance
    private var totalWalkDistance: Double = 1 // Will be set when data is loaded
    
    private var refreshTimer: Timer?
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1)
        setupProgressBar()
        setupLayout()
        populateSummary()
        setupProgressService()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - UI Setup
    private func setupProgressBar() {
        // Card style for the progress bar
        progressBarCard.backgroundColor = .white
        progressBarCard.layer.cornerRadius = 18
        progressBarCard.layer.shadowColor = UIColor.black.cgColor
        progressBarCard.layer.shadowOpacity = 0.05
        progressBarCard.layer.shadowRadius = 10
        progressBarCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        progressBarCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBarCard)
        NSLayoutConstraint.activate([
            progressBarCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            progressBarCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressBarCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressBarCard.heightAnchor.constraint(equalToConstant: 72)
        ])
        
        // The bar itself (light blue background)
        progressBarBackground.backgroundColor = UIColor(red: 230/255, green: 239/255, blue: 250/255, alpha: 1)
        progressBarBackground.layer.cornerRadius = 14
        progressBarBackground.translatesAutoresizingMaskIntoConstraints = false
        progressBarCard.addSubview(progressBarBackground)
        NSLayoutConstraint.activate([
            progressBarBackground.centerYAnchor.constraint(equalTo: progressBarCard.centerYAnchor),
            progressBarBackground.leadingAnchor.constraint(equalTo: progressBarCard.leadingAnchor, constant: 18),
            progressBarBackground.trailingAnchor.constraint(equalTo: progressBarCard.trailingAnchor, constant: -18),
            progressBarBackground.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // Emojis
        stationEmoji.text = "🚉"
        stationEmoji.font = .systemFont(ofSize: 22)
        stationEmoji.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(stationEmoji)
        NSLayoutConstraint.activate([
            stationEmoji.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            stationEmoji.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor, constant: 8)
        ])
        
        platformEmoji.text = "🚇"
        platformEmoji.font = .systemFont(ofSize: 22)
        platformEmoji.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(platformEmoji)
        NSLayoutConstraint.activate([
            platformEmoji.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            platformEmoji.trailingAnchor.constraint(equalTo: progressBarBackground.trailingAnchor, constant: -8)
        ])
        
        // Little person dot
        personDot.text = "🧑"
        personDot.font = .systemFont(ofSize: 25)
        personDot.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(personDot)
        personDotLeadingConstraint = personDot.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor)
        personDotLeadingConstraint?.isActive = true
        NSLayoutConstraint.activate([
            personDot.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            personDot.widthAnchor.constraint(equalToConstant: 28),
            personDot.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    
    // Setup the progress animation service and start animation
    private func setupProgressService() {
        let targetStationName = transitInfos.first?.departureStation ?? ""
        guard let stationCoord = stationCoordinates[targetStationName] else { return }
        let stationLocation = CLLocation(latitude: stationCoord.latitude, longitude: stationCoord.longitude)
        let service = JourneyProgressService(
            walkToStationSec: walkToStationTimeSec,
            stationToPlatformSec: stationToPlatformTimeSec,
            transferTimesSec: transferTimesSec,
            trainArrival: nextTrainArrivalDate,
            originLocation: userOriginLocation,
            stationLocation: stationLocation
        )
        service.delegate = self
        service.start()
        self.progressService = service
        self.userStationLocation = stationLocation
    }
    
    /// Sets up the layout constraints for all UI components
    private func setupLayout() {
        // Main ScrollView + Stack
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: progressBarCard.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    /// Sets up the moving dot indicator on the timeline
    private func setupMovingDot(attachedTo timeline: TimelineView, in card: UIView) {
        guard let label = card.viewWithTag(999) else { return }
        
        movingDot.removeFromSuperview()
        movingDot = UIView()
        movingDot.backgroundColor = .systemYellow
        movingDot.layer.cornerRadius = 6
        movingDot.translatesAutoresizingMaskIntoConstraints = false
        timeline.addSubview(movingDot)
        
        let offset = label.convert(label.bounds, to: timeline).midY
        dotCenterYConstraint?.isActive = false
        dotCenterYConstraint = movingDot.centerYAnchor.constraint(equalTo: timeline.topAnchor, constant: offset)
        
        NSLayoutConstraint.activate([
            movingDot.centerXAnchor.constraint(equalTo: timeline.centerXAnchor),
            movingDot.widthAnchor.constraint(equalToConstant: 12),
            movingDot.heightAnchor.constraint(equalToConstant: 12),
            dotCenterYConstraint!
        ])
    }
    
    

    
    func updateProgressBar(progress: CGFloat) {
        // Clamp progress to [0,1]
        let p = min(max(progress, 0), 1)
        let barWidth = progressBarBackground.bounds.width - 34 // 34 = dot width
        let leading = barWidth * p
        personDotLeadingConstraint?.constant = leading
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.progressBarBackground.layoutIfNeeded()
        }
    }
    

    // MARK: - Summary Content (all card style)
    private func populateSummary() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 1. Walk to Station
        if let walkStart = walkToStationTime {
            stackView.addArrangedSubview(makeCard(title: "🚶 Walk to Station", subtitle: walkStart))
        }
        
        // 2. Transit Segments
        for (index, info) in transitInfos.enumerated() {
            // Station to Platform
            stackView.addArrangedSubview(makeCard(title: "🚶 Station to Platform", subtitle: "Approx. 2 min"))
            
            // Catch train predictions
            let catchSectionView = UIStackView()
            catchSectionView.axis = .vertical
            catchSectionView.spacing = 8
            let catchTitle = UILabel()
            catchTitle.text = "🚦 Next 3 Trains Information"
            catchTitle.font = .systemFont(ofSize: 16, weight: .bold)
            catchTitle.textColor = .systemBlue
            catchSectionView.addArrangedSubview(catchTitle)
            stackView.addArrangedSubview(makeCard(customView: catchSectionView))
            
            let entryToPlatformSec: Double = 600
            CatchInfo.fetchCatchInfos(for: info, entryToPlatformSec: entryToPlatformSec) { [weak self] catchInfos in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if catchInfos.isEmpty {
                        let emptyLabel = UILabel()
                        emptyLabel.text = "No predictions available"
                        emptyLabel.textColor = .gray
                        catchSectionView.addArrangedSubview(emptyLabel)
                    } else {
                        for catchInfo in catchInfos {
                            let row = CatchInfoRowView(info: catchInfo)
                            catchSectionView.addArrangedSubview(row)
                        }
                    }
                }
            }
            
            // Transit Card
            let card = makeTransitCard(info: info, isTransfer: index > 0)
            stackView.addArrangedSubview(card)
            
            // Transfer (if any)
            if index < transitInfos.count - 1 {
                let transferTime = info.durationTime ?? "Walk to next station"
                stackView.addArrangedSubview(makeCard(title: "🚶 Transfer Walk", subtitle: "\(transferTime) transfer time"))
            }
        }
        
        // 3. Final Walk to Destination
        if let walkEnd = walkToDestinationTime {
            stackView.addArrangedSubview(makeCard(title: "🚶 Walk to Destination", subtitle: walkEnd))
        }
    
    }
    
    /// Initializes and starts location tracking
    private func startTrackingLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    

    
    /// Handles the start navigation button tap
    @objc private func startNavigationTapped() {
        // Navigation logic will be implemented here
        let vc = NavigationViewController()
        vc.transitInfos = self.transitInfos
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func makeLabel(text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = UIColor.label
        label.numberOfLines = 0
        return label
    }
    
    // MARK: - Card Makers
    private func makeCard(title: String, subtitle: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 7
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor(red: 41/255, green: 56/255, blue: 80/255, alpha: 1)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }
    
    private func makeCard(customView: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 7
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        customView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(customView)
        NSLayoutConstraint.activate([
            customView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            customView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            customView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            customView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }
    
    
    /// Creates a card for transit segments
    private func makeTransitCard(info: TransitInfo, isTransfer: Bool) -> UIView {
        let card = UIView()
        let backgroundColor = UIColor(hex: info.lineColorHex ?? "#E6EFFA")
        card.backgroundColor = backgroundColor
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 7
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        let timeline = TimelineView()
        timeline.lineColor = .white
        timeline.translatesAutoresizingMaskIntoConstraints = false
        timeline.widthAnchor.constraint(equalToConstant: 20).isActive = true
        
        let lineBadgeLabel = PaddingLabel()
        lineBadgeLabel.text = info.lineName
        lineBadgeLabel.font = .boldSystemFont(ofSize: 13)
        lineBadgeLabel.textColor = backgroundColor.isLight ? .black : .white
        lineBadgeLabel.backgroundColor = backgroundColor.isLight ? .white.withAlphaComponent(0.8) : .black.withAlphaComponent(0.8)
        lineBadgeLabel.layer.cornerRadius = 6
        lineBadgeLabel.clipsToBounds = true
        lineBadgeLabel.textAlignment = .center
        
        let startLabel = UILabel()
        startLabel.text = info.departureStation
        startLabel.font = .boldSystemFont(ofSize: 16)
        startLabel.textColor = backgroundColor.isLight ? .black : .white
        startLabel.tag = 999
        stopLabelMap[startLabel.text ?? ""] = startLabel
        
        let crowdLabel = UILabel()
        crowdLabel.text = info.delayStatus
        crowdLabel.font = .systemFont(ofSize: 14)
        crowdLabel.textColor = backgroundColor.isLight ? .black : .white
        
        let intermediateLabel = UILabel()
        intermediateLabel.font = .systemFont(ofSize: 13)
        intermediateLabel.textColor = backgroundColor.isLight ? .black : .white
        intermediateLabel.numberOfLines = 0
        intermediateLabel.isHidden = true
        let stops = info.stopNames
        if stops.count > 2 {
            let middle = stops[1..<(stops.count - 1)]
            let middleLines = middle.map { (station: String) in "• \(station)" }
            intermediateLabel.text = middleLines.joined(separator: "\n")
        }
        
        let rideSummaryLabel = UILabel()
        let stopCount = info.numStops ?? 0
        let durationTime = info.durationTime ?? "-"
        let durationText = info.durationText
        rideSummaryLabel.text = "Ride · \(stopCount) stops · \(durationTime) \(durationText ?? "")"
        rideSummaryLabel.font = .systemFont(ofSize: 13)
        rideSummaryLabel.textColor = backgroundColor.isLight ? .black : .white
        
        let toggleButton = UIButton(type: .system)
        let arrowImage = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
        toggleButton.setImage(arrowImage, for: .normal)
        toggleButton.tintColor = backgroundColor.isLight ? .black : .white
        toggleButton.transform = .identity
        toggleButton.addAction(UIAction { _ in
            intermediateLabel.isHidden.toggle()
            UIView.animate(withDuration: 0.25) {
                toggleButton.transform = intermediateLabel.isHidden ? .identity : CGAffineTransform(rotationAngle: .pi)
            }
        }, for: .touchUpInside)
        
        let toggleRow = UIStackView(arrangedSubviews: [toggleButton, rideSummaryLabel])
        toggleRow.axis = .horizontal
        toggleRow.spacing = 8
        toggleRow.alignment = .center
        
        let toggleRowWrapper = UIStackView(arrangedSubviews: [toggleRow])
        toggleRowWrapper.axis = .vertical
        toggleRowWrapper.alignment = .leading
        
        let endLabel = UILabel()
        endLabel.text = info.arrivalStation
        endLabel.font = .boldSystemFont(ofSize: 16)
        endLabel.textColor = backgroundColor.isLight ? .black : .white
        stopLabelMap[endLabel.text ?? ""] = endLabel
        
        let contentStack = UIStackView(arrangedSubviews: [lineBadgeLabel, startLabel, crowdLabel, toggleRowWrapper, intermediateLabel, endLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 6
        
        let horizontalStack = UIStackView(arrangedSubviews: [timeline, contentStack])
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 12
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(horizontalStack)
        NSLayoutConstraint.activate([
            horizontalStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            horizontalStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            horizontalStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            horizontalStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        
        return card
    }


// MARK: - Location Manager Delegate Methods
/// Handles location updates and updates the moving dot position
    // MARK: - Location Update for Live Progress (optional, can leave as is)
       func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
           guard let location = locations.last,
                 let start = startCoord,
                 let end = endCoord else { return }
           let userLoc = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
           let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
           let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
           let totalDistance = startLoc.distance(from: endLoc)
           let traveled = userLoc.distance(from: startLoc)
           let progress = min(max(traveled / totalDistance, 0), 1)
           updatePersonDot(progress: progress)
       }
       
       func updatePersonDot(progress: Double) {
           let barWidth = progressBarBackground.bounds.width
           let leftOffset = stationEmoji.frame.maxX
           let rightOffset = progressBarBackground.bounds.width - platformEmoji.frame.minX
           let usableWidth = barWidth - leftOffset - rightOffset - personDot.bounds.width
           let offset = usableWidth * CGFloat(progress)
           personDotLeadingConstraint?.constant = offset
           UIView.animate(withDuration: 0.18) {
               self.progressBarBackground.layoutIfNeeded()
           }
       }
       
}

// MARK: - Timeline View
/// A custom view that displays a vertical timeline
class TimelineView: UIView {
    // MARK: - Properties
    /// Color of the timeline line
    var lineColor: UIColor = .white {
        didSet {
            setNeedsDisplay()
        }
    }

    // MARK: - Drawing Methods
    /// Draws the vertical timeline
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setLineWidth(2)
        context.setStrokeColor(lineColor.cgColor)
        let centerX = rect.width / 2
        context.move(to: CGPoint(x: centerX, y: 0))
        context.addLine(to: CGPoint(x: centerX, y: rect.height))
        context.strokePath()
    }
}

// MARK: - Color Extension
/// Extension for UIColor to support hex color codes
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    /// Determines if the color is light or dark
    var isLight: Bool {
        guard let components = cgColor.components, components.count >= 3 else {
            return false
        }
        
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5
    }
}




//Utility class
class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}






extension RouteSummaryViewController: JourneyProgressDelegate {
    func journeyProgressDidUpdate(
        overallProgress: Double,
        phaseProgress: Double,
        canCatch: Bool,
        delta: TimeInterval,
        uncertainty: TimeInterval,
        phase: ProgressPhase
    ) {
        // Animate the dot on the bar (left = 0, right = 1)
        let totalWidth = progressBarBackground.bounds.width - personDot.bounds.width
        let newX = totalWidth * CGFloat(overallProgress)
        personDotLeadingConstraint?.constant = newX
        UIView.animate(withDuration: 0.2) {
            self.progressBarBackground.layoutIfNeeded()
        }
        // Show remaining time, uncertainty, canCatch
        deltaTimeLabel.text = String(format: "🚇 %.0f sec left (±%.0f sec) · %@", delta, uncertainty, canCatch ? "On Time" : "Hurry!")
    }
    func journeyPhaseDidChange(_ phase: ProgressPhase) {
        // Optional: Add fancy phase transitions, color animations, etc.
    }
}
