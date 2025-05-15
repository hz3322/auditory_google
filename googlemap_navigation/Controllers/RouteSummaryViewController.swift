import UIKit
import CoreLocation

class RouteSummaryViewController: UIViewController, CLLocationManagerDelegate {

    var totalEstimatedTime: String?
    
    var walkToStationTime: String?
    var walkToDestinationTime: String?
    
    var transitInfos: [TransitInfo] = []
    var routeDepartureTime: String?
    var routeArrivalTime: String?
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var locationManager = CLLocationManager()
    private var movingDot = UIView()
    private var dotCenterYConstraint: NSLayoutConstraint?
    private var timelineMap: [String: TimelineView] = [:]
    private var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
    private var stopLabelMap: [String: UILabel] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        title = "Route Summary"
        setupLayout()
        populateSummary()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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

        movingDot = UIView()
        movingDot.backgroundColor = .systemYellow
        movingDot.layer.cornerRadius = 6
        movingDot.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(movingDot)

        let offset = label.convert(label.bounds, to: timeline).midY
        dotCenterYConstraint = movingDot.centerYAnchor.constraint(equalTo: timeline.topAnchor, constant: offset)

        NSLayoutConstraint.activate([
            movingDot.centerXAnchor.constraint(equalTo: timeline.centerXAnchor),
            movingDot.widthAnchor.constraint(equalToConstant: 12),
            movingDot.heightAnchor.constraint(equalToConstant: 12),
            dotCenterYConstraint!
        ])
    }

    private func startTrackingLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func populateSummary() {
 
        // 🚶 Walk to Station
        if let walkStart = walkToStationTime {
            stackView.addArrangedSubview(makeCard(title: "🚶 Walk to Station", subtitle: walkStart))
        }

        // 🚇 Transit Segments
        for (index, info) in transitInfos.enumerated() {
            let card = makeTransitCard(info: info, isTransfer: index > 0)
            stackView.addArrangedSubview(card)

            // 🟡 Attach moving dot to first segment's timeline
            if index == 0,
               let timeline = timelineMap[info.lineName + ":" + (info.departureStation ?? "-")] {
                setupMovingDot(attachedTo: timeline, in: card)
            }

            // 📍 Fetch stop coordinates for GPS matching
            RouteLogic.shared.fetchStopCoordinates(for: RouteLogic.shared.tflLineId(from: info.lineName) ?? "", direction: "inbound") { coords in
                self.stationCoordinates.merge(coords) { current, _ in current }
                self.startTrackingLocation()
            }

            // 🔁 Transfer Walk Time
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if let nearest = RouteLogic.shared.nearestStation(to: location, from: stationCoordinates),
           let label = stopLabelMap[nearest] {

            let key = transitInfos.first(where: { $0.stopNames.contains(nearest) })
                .map { $0.lineName + ":" + ($0.departureStation ?? "-") }

            guard let timeline = key.flatMap({ timelineMap[$0] }) else { return }

            let offset = label.convert(label.bounds, to: timeline).midY

            dotCenterYConstraint?.isActive = false
            dotCenterYConstraint = movingDot.centerYAnchor.constraint(equalTo: timeline.topAnchor, constant: offset)
            dotCenterYConstraint?.isActive = true

            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                self.movingDot.alpha = 0.2
                UIView.animate(withDuration: 0.3) {
                    self.movingDot.alpha = 1.0
                }
            }
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
        stopLabelMap[startLabel.text ?? ""] = startLabel

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
