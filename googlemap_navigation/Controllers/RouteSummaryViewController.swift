import UIKit
import CoreLocation

class RouteSummaryViewController: UIViewController, CLLocationManagerDelegate {

    // MARK: - Properties
    /// Total estimated time for the entire route
    var totalEstimatedTime: String?
    
    /// Time required to walk to the starting station
    var walkToStationTime: String?
    
    /// Time required to walk from the final station to destination
    var walkToDestinationTime: String?
    
    /// Array of transit information for each segment of the journey
    var transitInfos: [TransitInfo] = []
    
    /// Departure time of the route
    var routeDepartureTime: String?
    
    /// Arrival time of the route
    var routeArrivalTime: String?
    
    // MARK: - UI Components
    /// Main scrollable container for the route summary
    private let scrollView = UIScrollView()
    
    /// Vertical stack view containing all route cards
    private let stackView = UIStackView()
    
    /// Moving dot indicator showing current position
    private var movingDot = UIView()
    
    /// Constraint for the moving dot's vertical position
    private var dotCenterYConstraint: NSLayoutConstraint?
    
    /// Dictionary mapping line names to their timeline views
    private var timelineMap: [String: TimelineView] = [:]
    
    /// Dictionary of station coordinates
    private var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
    
    
    /// Dictionary mapping station names to their labels
    private var stopLabelMap: [String: UILabel] = [:]
    
    // MARK: - Location Services
    /// Manager for handling location updates
    private var locationManager = CLLocationManager()

    // MARK: - Data for Progress Animation
    var walkToStationTimeSec: Double = 0
    var stationToPlatformTimeSec: Double = 120 // Default, will be updated when real data is available
    var transferTimesSec: [Double] = []
    var nextTrainArrivalDate: Date = Date()

    // MARK: - Progress Bar Properties
    private var progressService: JourneyProgressService?
    private let processBarView = UIView()
    private let deltaTimeLabel = UILabel()
    
    private let progressBarBackground = UIView()
    private let stationEmoji = UILabel()
    private let platformEmoji = UILabel()
    private let personDot = UILabel()
    private var personDotLeadingConstraint: NSLayoutConstraint?
    private var startCoord: CLLocationCoordinate2D?
    private var endCoord: CLLocationCoordinate2D?

    
    private var isUsingLocationProgress = true // Track if using GPS progress
    private var userOriginLocation: CLLocation? // Where the user started
    private var userStationLocation: CLLocation? // Tube station entrance
    private var totalWalkDistance: Double = 1 // Will be set when data is loaded

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // 1. Set up UI structure first
        setupProgressBar()
        setupLayout()
        populateSummary()

        // 2. Set up logic/services
        setupProgressService()

        // 3. Enable location updates (for live progress)
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - UI Setup Methods
    /// Initializes and configures the main UI components

    
    private func setupProgressBar() {
        // 1. progress bar background
        progressBarBackground.backgroundColor = UIColor.systemGray5
        progressBarBackground.layer.cornerRadius = 18
        progressBarBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBarBackground)
        NSLayoutConstraint.activate([
            progressBarBackground.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            progressBarBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            progressBarBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            progressBarBackground.heightAnchor.constraint(equalToConstant: 36)
        ])
        // 2. stationary station emoji
        stationEmoji.text = "🚉"
        stationEmoji.font = .systemFont(ofSize: 28)
        stationEmoji.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(stationEmoji)
        NSLayoutConstraint.activate([
            stationEmoji.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            stationEmoji.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor, constant: 10)
        ])
        // 3. stationary platform emoji（最右）
        platformEmoji.text = "🚇"
        platformEmoji.font = .systemFont(ofSize: 28)
        platformEmoji.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(platformEmoji)
        NSLayoutConstraint.activate([
            platformEmoji.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            platformEmoji.trailingAnchor.constraint(equalTo: progressBarBackground.trailingAnchor, constant: -10)
        ])
        // 4. 小人
        personDot.text = "🧑"
        personDot.font = .systemFont(ofSize: 30)
        personDot.translatesAutoresizingMaskIntoConstraints = false
     
        progressBarBackground.addSubview(personDot)
        // 先把小人放到"station"上
        personDotLeadingConstraint = personDot.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor)
        personDotLeadingConstraint?.isActive = true
        NSLayoutConstraint.activate([
            personDot.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            personDot.widthAnchor.constraint(equalToConstant: 30),
            personDot.heightAnchor.constraint(equalToConstant: 30)
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
   
        // ScrollView below Progress Bar
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: progressBarBackground.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
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
    

    // MARK: - Summary Population Methods
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

    // MARK: - Summary Population Methods
    /// Populates the summary view with route information
    private func populateSummary() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 1. Walk to Station time
        if let walkStart = walkToStationTime {
            stackView.addArrangedSubview(makeCard(title: "🚶 Walk to Station", subtitle: walkStart))
        }
        
        print("Transit count:", transitInfos.count)

        // 🚇 Transit Segments
        for (index, info) in transitInfos.enumerated() {
            // a. station to platform card
            stackView.addArrangedSubview(makeCard(title: "🚶 station to Platform", subtitle: "Approx. 2 min"))
            
            // b. catch info for next 3 tube
            let entryToPlatformSec: Double = 120
            let catchTitle = UILabel()
            catchTitle.text = "🚦 Next 3 Trains — Can You Catch?"
            catchTitle.font = .systemFont(ofSize: 17, weight: .bold)
            catchTitle.textColor = .systemBlue
            stackView.addArrangedSubview(catchTitle)

            CatchInfo.fetchCatchInfos(for: info, entryToPlatformSec: entryToPlatformSec) { [weak self] catchInfos in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if catchInfos.isEmpty {
                        let emptyLabel = UILabel()
                        emptyLabel.text = "No predictions available"
                        emptyLabel.textColor = .gray
                        self.stackView.addArrangedSubview(emptyLabel)
                    } else {
                        for catchInfo in catchInfos {
                            let row = CatchInfoRowView(info: catchInfo)
                            self.stackView.addArrangedSubview(row)
                        }
                    }
                }
            }
            
            // c. transit card with info and moving dot
            let card = makeTransitCard(info: info, isTransfer: index > 0)
            stackView.addArrangedSubview(card)
            
            // 🟡 Moving dot
            if index == 0,
               let timeline = timelineMap[info.lineName + ":" + (info.departureStation ?? "-")] {
                setupMovingDot(attachedTo: timeline, in: card)
            }

            // 📍 Stop coordinates for GPS tracking
            RouteLogic.shared.fetchStopCoordinates(
                for: RouteLogic.shared.tflLineId(from: info.lineName) ?? "",
                direction: "inbound"
            ) { coords in
                let newCoords: [String: CLLocationCoordinate2D] = coords.mapValues { $0.coord }
                self.stationCoordinates.merge(newCoords) { current, _ in current }
                self.startTrackingLocation()
            }

            // d. 🔁 Transfer Walk Time if needed
            if index < transitInfos.count - 1 {
                if let transferTime = info.durationTime {
                    stackView.addArrangedSubview(makeCard(title: "🚶 Transfer Walk", subtitle: "\(transferTime) transfer time"))
                } else {
                    stackView.addArrangedSubview(makeCard(title: "🚶 Transfer Walk", subtitle: "Walk to next station"))
                }
            }
        }

        // 🚶 Final Walk to Destination
        if let walkEnd = walkToDestinationTime {
            stackView.addArrangedSubview(makeCard(title: "🚶 Walk to Destination", subtitle: walkEnd))
        }

        // 🟢 Start Navigation Button
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.setTitleColor(UIColor.label, for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        startButton.backgroundColor = .systemGreen
        startButton.layer.cornerRadius = 8
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        startButton.addTarget(self, action: #selector(startNavigationTapped), for: .touchUpInside)
        stackView.addArrangedSubview(startButton)
    }

    /// Initializes and starts location tracking
    private func startTrackingLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Location Manager Delegate Methods
    /// Handles location updates and updates the moving dot position
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let start = startCoord,
              let end = endCoord else { return }

        let userLoc = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        
        let totalDistance = startLoc.distance(from: endLoc)
        let traveled = userLoc.distance(from: startLoc)
        let progress = min(max(traveled / totalDistance, 0), 1) // clamp between 0~1

        updatePersonDot(progress: progress)
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

    private func makeCard(title: String, subtitle: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 10

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor.label

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor.secondaryLabel

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        return card
    }

    /// Creates a card for transit segments
    private func makeTransitCard(info: TransitInfo, isTransfer: Bool) -> UIView {
        let card = UIView()
        // 设置默认颜色，以防 lineColorHex 为空
        let backgroundColor = UIColor(hex: info.lineColorHex ?? "#DADADA")
        card.backgroundColor = backgroundColor
        card.layer.cornerRadius = 10

        let timeline = TimelineView()
        // 使用白色作为时间线的颜色，确保可见性
        timeline.lineColor = .white
        timeline.translatesAutoresizingMaskIntoConstraints = false
        timeline.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let lineKey = info.lineName + ":" + (info.departureStation ?? "-")
        timelineMap[lineKey] = timeline

        timeline.setContentHuggingPriority(.required, for: .horizontal)
        timeline.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let lineBadgeLabel = PaddingLabel()
        lineBadgeLabel.text = info.lineName
        lineBadgeLabel.font = .boldSystemFont(ofSize: 13)
        // 确保文本颜色与背景形成对比
        lineBadgeLabel.textColor = backgroundColor.isLight ? .black : .white
        lineBadgeLabel.backgroundColor = backgroundColor.isLight ? .white.withAlphaComponent(0.8) : .black.withAlphaComponent(0.8)
        lineBadgeLabel.layer.cornerRadius = 6
        lineBadgeLabel.clipsToBounds = true
        lineBadgeLabel.textAlignment = .center
        
        let startLabel = UILabel()
        startLabel.text = info.departureStation
        startLabel.font = .boldSystemFont(ofSize: 16)
        // 确保文本颜色与背景形成对比
        startLabel.textColor = backgroundColor.isLight ? .black : .white
        startLabel.tag = 999
        stopLabelMap[startLabel.text ?? ""] = startLabel

        let crowdLabel = UILabel()
        crowdLabel.text = info.delayStatus
        crowdLabel.font = .systemFont(ofSize: 14)
        // 确保文本颜色与背景形成对比
        crowdLabel.textColor = backgroundColor.isLight ? .black : .white

        let intermediateLabel = UILabel()
        intermediateLabel.font = .systemFont(ofSize: 13)
        // 确保文本颜色与背景形成对比
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
        // 确保文本颜色与背景形成对比
        rideSummaryLabel.textColor = backgroundColor.isLight ? .black : .white

        let toggleButton = UIButton(type: .system)
        let arrowImage = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
        toggleButton.setImage(arrowImage, for: .normal)
        // 确保按钮颜色与背景形成对比
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
        // 确保文本颜色与背景形成对比
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

class CatchInfoRowView: UIView {
    init(info: CatchInfo) {
        super.init(frame: .zero)
        setupUI(info: info)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI(info: CatchInfo) {
        let platformLabel = UILabel()
        platformLabel.text = info.platformName
        platformLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        platformLabel.textAlignment = .left
        platformLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true
        
        let personLabel = UILabel()
        personLabel.text = "🧑"
        personLabel.font = .systemFont(ofSize: 22)
        
        let toPlatformTime = UILabel()
        let min = Int(round(info.timeToStation / 60))
        toPlatformTime.text = "\(min) min"
        toPlatformTime.font = .systemFont(ofSize: 14)
        toPlatformTime.textColor = .gray
        
        let arrow = UILabel()
        arrow.text = "→"
        arrow.font = .systemFont(ofSize: 16)
        
        let expectedArrival = UILabel()
        expectedArrival.text = "Train: \(info.expectedArrival)"
        expectedArrival.font = .systemFont(ofSize: 14)
        expectedArrival.textColor = .darkGray
        
        let resultIcon = UILabel()
        resultIcon.text = info.canCatch ? "✅" : "❌"
        resultIcon.font = .systemFont(ofSize: 18)
        resultIcon.textColor = info.canCatch ? .systemGreen : .systemRed
        resultIcon.textAlignment = .center
        resultIcon.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let hStack = UIStackView(arrangedSubviews: [
            platformLabel,
            personLabel,
            toPlatformTime,
            arrow,
            expectedArrival,
            resultIcon
        ])
        hStack.axis = .horizontal
        hStack.spacing = 14
        hStack.alignment = .center
        hStack.distribution = .equalSpacing
        addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: self.topAnchor, constant: 6),
            hStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -6),
            hStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12),
            hStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12)
        ])
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
