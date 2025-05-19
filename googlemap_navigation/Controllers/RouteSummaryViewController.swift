import UIKit
import CoreLocation

class RouteSummaryViewController: UIViewController, CLLocationManagerDelegate {

    // MARK: - Data for Progress Animation
      var walkToStationTimeSec: Double = 0
      var stationToPlatformTimeSec: Double = 120 // Default, will be updated when real data is available
      var transferTimesSec: [Double] = []
      var nextTrainArrivalDate: Date = Date()
      var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
  
    // MARK: - Progress Bar Properties
      private var progressService: JourneyProgressService?
      private let processBarView = UIView()
      private let deltaTimeLabel = UILabel()
      private let progressBarContainer = UIView()
      private let progressBarBackground = UIView()
      private let subwayIcon = UILabel()
      private let personDot = UILabel()
      private var personDotLeadingConstraint: NSLayoutConstraint?
    
    
    // Location & Progress Vars
      private var locationManager = CLLocationManager()
    private var isUsingLocationProgress = true // Track if using GPS progress
    private var userOriginLocation: CLLocation? // Where the user started
    private var userStationLocation: CLLocation? // Tube station entrance
    private var totalWalkDistance: Double = 1 // Will be set when data is loaded
      
      // MARK: - Other Existing Properties
      var totalEstimatedTime: String?
      var walkToStationTime: String?
      var walkToDestinationTime: String?
      var transitInfos: [TransitInfo] = []
      var routeDepartureTime: String?
      var routeArrivalTime: String?
      private let scrollView = UIScrollView()
      private let stackView = UIStackView()
      private var movingDot = UIView()
      private var dotCenterYConstraint: NSLayoutConstraint?
      private var timelineMap: [String: TimelineView] = [:]
      private var stopLabelMap: [String: UILabel] = [:]

    
    // MARK: - Lifecycle
      override func viewDidLoad() {
          super.viewDidLoad()
          view.backgroundColor = .systemBackground
          setupUI()
          setupProgressBar()
          setupProgressService()
          locationManager.delegate = self
          locationManager.requestWhenInUseAuthorization()
          locationManager.startUpdatingLocation()
      }

    private func setupUI() {
        title = "Route Summary"
        setupLayout()
        populateSummary()
    }
    


    private func setupProgressBar() {
            progressBarContainer.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(progressBarContainer)
            NSLayoutConstraint.activate([
                progressBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
                progressBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
                progressBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
                progressBarContainer.heightAnchor.constraint(equalToConstant: 54)
            ])

            // Subway icon (right)
            subwayIcon.text = "🚇"
            subwayIcon.font = .systemFont(ofSize: 32)
            subwayIcon.translatesAutoresizingMaskIntoConstraints = false
            progressBarContainer.addSubview(subwayIcon)
            NSLayoutConstraint.activate([
                subwayIcon.centerYAnchor.constraint(equalTo: progressBarContainer.centerYAnchor),
                subwayIcon.trailingAnchor.constraint(equalTo: progressBarContainer.trailingAnchor)
            ])

        // Progress bar background (between person and subway)
           progressBarBackground.backgroundColor = UIColor.systemGray5
           progressBarBackground.layer.cornerRadius = 18
           progressBarBackground.translatesAutoresizingMaskIntoConstraints = false
           progressBarContainer.addSubview(progressBarBackground)
           NSLayoutConstraint.activate([
               progressBarBackground.leadingAnchor.constraint(equalTo: progressBarContainer.leadingAnchor),
               progressBarBackground.trailingAnchor.constraint(equalTo: subwayIcon.leadingAnchor, constant: -18),
               progressBarBackground.heightAnchor.constraint(equalToConstant: 36),
               progressBarBackground.centerYAnchor.constraint(equalTo: progressBarContainer.centerYAnchor)
           ])
        
            // Dot (person emoji )
            personDot.text = "🧑"
            personDot.font = .systemFont(ofSize: 34, weight: .bold)
            personDot.translatesAutoresizingMaskIntoConstraints = false
            progressBarBackground.addSubview(personDot)
            personDotLeadingConstraint = personDot.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor, constant: 0)
            personDotLeadingConstraint?.isActive = true
            NSLayoutConstraint.activate([
                personDot.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
                personDot.widthAnchor.constraint(equalToConstant: 34),
                personDot.heightAnchor.constraint(equalToConstant: 34)
            ])
        }
    
//    // MARK: - CLLocationManagerDelegate
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard
//            let userLoc = locations.last,
//            let station = stationCoord
//        else { return }
//        userCurrentLocation = userLoc
//
//        // Calculate remaining distance (in meters)
//        let destination = CLLocation(latitude: station.latitude, longitude: station.longitude)
//        let distanceLeft = userLoc.distance(from: destination)
//        // Clamp to avoid weird values
//        let progress = max(0, min(1, 1 - (distanceLeft / max(totalWalkDistance, 1))))
//
//        animatePersonDot(progress: progress)
//    }

    private func animatePersonDot(progress: Double) {
        let clamped = max(0, min(progress, 1))
        self.progressBarBackground.layoutIfNeeded()
        let barWidth = self.progressBarBackground.bounds.width - 34
        let newLeading = CGFloat(clamped) * barWidth
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            self.personDotLeadingConstraint?.constant = newLeading
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

    private func setupLayout() {
        // Progress Bar Container
        progressBarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBarContainer)
        NSLayoutConstraint.activate([
            progressBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            progressBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            progressBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            progressBarContainer.heightAnchor.constraint(equalToConstant: 54)
        ])
        
        // ScrollView below Progress Bar
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: progressBarContainer.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

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

    
    
    
    
    // MARK: - Logic part
    private func startTrackingLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }


    private func populateSummary() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        

        // 🚶 1. Walk to Station time
        if let walkStart = walkToStationTime {
            stackView.addArrangedSubview(makeCard(title: "🚶 Walk to Station", subtitle: walkStart))
        }

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
    
//    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard let location = locations.last else { return }
//        if let nearest = RouteLogic.shared.nearestStation(to: location, from: stationCoordinates),
//           let label = stopLabelMap[nearest] {
//
//            let key = transitInfos.first(where: { $0.stopNames.contains(nearest) })
//                .map { $0.lineName + ":" + ($0.departureStation ?? "-") }
//
//            guard let timeline = key.flatMap({ timelineMap[$0] }) else { return }
//
//            let offset = label.convert(label.bounds, to: timeline).midY
//
//            dotCenterYConstraint?.isActive = false
//            dotCenterYConstraint = movingDot.centerYAnchor.constraint(equalTo: timeline.topAnchor, constant: offset)
//            dotCenterYConstraint?.isActive = true
//
//            UIView.animate(withDuration: 0.3) {
//                self.view.layoutIfNeeded()
//                self.movingDot.alpha = 0.2
//                UIView.animate(withDuration: 0.3) {
//                    self.movingDot.alpha = 1.0
//                }
//            }
//        }
//    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let current = locations.last else { return }
        if userOriginLocation == nil {
            userOriginLocation = current
            if let station = userStationLocation {
                totalWalkDistance = current.distance(from: station)
            }
        }
        guard let origin = userOriginLocation, let station = userStationLocation else { return }
        let left = current.distance(from: station)
        let progress = 1 - min(max(left / max(totalWalkDistance, 1), 0), 1)
        animatePersonDot(progress: progress)
        if left < 5 { // 到站
            isUsingLocationProgress = false
            // 你可以发送一个事件到 progressService, phase 切换
        }
    }

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

    private func makeTransitCard(info: TransitInfo, isTransfer: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(hex: info.lineColorHex ?? "#DADADA")
        card.layer.cornerRadius = 10

        let timeline = TimelineView()
        timeline.lineColor = UIColor(hex: info.lineColorHex ?? "#FFFFFF")
        timeline.translatesAutoresizingMaskIntoConstraints = false
        timeline.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let lineKey = info.lineName + ":" + (info.departureStation ?? "-")
        timelineMap[lineKey] = timeline

        timeline.setContentHuggingPriority(.required, for: .horizontal)
        timeline.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let lineBadgeLabel = PaddingLabel()
        lineBadgeLabel.text = info.lineName
        lineBadgeLabel.font = .boldSystemFont(ofSize: 13)
        lineBadgeLabel.textColor = .black
        lineBadgeLabel.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        lineBadgeLabel.layer.cornerRadius = 6
        lineBadgeLabel.clipsToBounds = true
        lineBadgeLabel.textAlignment = .center
        
        let startLabel = UILabel()
        startLabel.text = info.departureStation
        startLabel.font = .boldSystemFont(ofSize: 16)
        startLabel.textColor = .white
        startLabel.tag = 999
        stopLabelMap[startLabel.text ?? ""] = startLabel

        // cannot get specific data from Google maps api or tfl unified api
        let crowdLabel = UILabel()
        crowdLabel.text = info.delayStatus
        crowdLabel.font = .systemFont(ofSize: 14)
        crowdLabel.textColor = .white

        let intermediateLabel = UILabel()
        intermediateLabel.font = .systemFont(ofSize: 13)
        intermediateLabel.textColor = .white
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
        rideSummaryLabel.textColor = .white

        let toggleButton = UIButton(type: .system)
        let arrowImage = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
        toggleButton.setImage(arrowImage, for: .normal)
        toggleButton.tintColor = .white
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
        endLabel.textColor = .white
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

extension UIColor {
    convenience init(hex: String) {
        var hexFormatted = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexFormatted.hasPrefix("#") { hexFormatted.removeFirst() }

        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

class TimelineView: UIView {
    var lineColor: UIColor = .white {
        didSet {
            setNeedsDisplay()
        }
    }

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
    func journeyProgressDidUpdate(progress: Double, canCatch: Bool, delta: TimeInterval, uncertainty: TimeInterval, phase: ProgressPhase) {
        if phase == .walkToStation, isUsingLocationProgress {
            // 用 GPS 驱动动画
            // 上面 locationManager 已经处理，无需重复 animate
        } else {
            // 非walk阶段全部用timeline-based
            animatePersonDot(progress: progress)
        }
        // deltaLabel 更新
        self.deltaTimeLabel.text = String(
            format: "🚇 %.0f sec left (±%.0f sec) · %@",
            delta, uncertainty, canCatch ? "On Time" : "Tight!"
        )
    }
}
