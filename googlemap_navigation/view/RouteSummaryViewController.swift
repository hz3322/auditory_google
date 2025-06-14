import UIKit
import CoreLocation


class RouteSummaryViewController: UIViewController, CLLocationManagerDelegate {
    
    // MARK: - Tag Constants
    private let transitCardBaseTag = 1000
    private let timelineViewTag = 2000
    private let timelineStartLabelTag = 2001
    private let timelineEndLabelTag = 2002
    private let walkToStationCardTag = 3000
    private let stationToPlatformCardTag = 3001
    private let walkToDestinationCardTag = 3002
    private let catchTrainCardBaseTag = 5000
    
    
    //Label
    private var walkToStationTimeLabel: UILabel?
    
    // MARK: - Properties
    private let movingDot = UIView()
    private var dotCenterYConstraint: NSLayoutConstraint?
    private var activeJourneySegmentCard: UIView?
    private var currentActiveTransitLegIndex: Int?
    private var pacingManager: PacingManager?
    private var currentLocation: CLLocation?
    private var journeyProgressService: JourneyProgressService?
    private var userOriginLocation: CLLocation? // Add this line to store the starting location
    
    var totalEstimatedTime: String?
    var walkToStationTime: String?
    var walkToStationTimeMin: Double = 0.0
    var walkToDestinationTime: String?
    var transitInfos: [TransitInfo] = []
    var routeDepartureTime: String?
    var routeArrivalTime: String?
    /// The final destination station name for the entire route, passed from the previous screen.
    var finalDestinationStationName: String? = nil
    /// The starting coordinate for the entire route, passed from the previous screen.
    var routeStartCoordinate: CLLocationCoordinate2D? = nil
    /// The destination coordinate for the entire route, passed from the previous screen.
    var routeDestinationCoordinate: CLLocationCoordinate2D? = nil
    var currentWeather: String?
    
    var walkToStationTimeSec: Double = 0
    var stationToPlatformTimeSec: Double = 120
    var transferTimesSec: [Double] = []
    var nextTrainArrivalDate: Date = Date()
    
    var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
    

    
    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    
    // UI
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private let progressBarCard = UIView()
    private let progressBarBackground = UIView()
    private let tflLogoImageView = UIImageView()
    private let platformEmoji = UILabel()
    private let personDot = UILabel()
    private var personDotLeadingConstraint: NSLayoutConstraint?
    private var stationPositionRatio: CGFloat = 0.5
    private var hasReachedStationVisualCue: Bool = false
    private var previousCatchStatus: CatchStatus? = nil // For haptic feedback
    

    private var locationManager = CLLocationManager()
    private var progressService: JourneyProgressService? // This service will provide the dynamic CatchStatus
    private let deltaTimeLabel = UILabel() // Displays dynamic catch status and time
    


    // Replace sloganLabel with summaryLabel
    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.text = "--" // Initial placeholder text
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
  
    
    // MARK: - Auto Refresh Properties
    private var arrivalsRefreshTimer: Timer?
    private let refreshInterval: TimeInterval = 3.0
    private let missedThreshold: TimeInterval = 100.0 // 100 seconds threshold for missed trains
    
    // for the pred catch info
    private var catchInfosDict: [Int: [CatchInfo]] = [:]
    private var catchInfoRowViewsDict: [Int: [CatchInfoRowView]] = [:]
    private var catchNaptanIdDict: [Int: String] = [:]
    private var stopListCache: [Int: [String]] = [:]
    private var depNormCache: [Int: String] = [:]
    private var targetNormCache: [Int: String] = [:]
    private var lastLineFetchTime: [String: Date] = [:]
    
    // MARK: - Rate Limiting Properties
    private let lineFetchCooldown: TimeInterval = 2.0 // 2 seconds cooldown between requests for the same station
    private var isRefreshing = false
    
    // MARK: - Location Manager Delegate
    private var lastLocationUpdateTime: Date?
    private var lastLocation: CLLocation?
    private let minimumLocationChangeDistance: CLLocationDistance = 10.0 // 最小位置变化距离为10米
    
    // Add a cache for estimated times
    private var estimatedTimeCache: [String: TimeInterval] = [:]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocationManager()
        setupStatusButton()
        
        // Set current view controller for auditory feedback
        AuditoryFeedbackManager.shared.setCurrentViewController(self)
        
        self.title = "Journey Summary"
        navigationController?.navigationBar.tintColor = AppColors.accentBlue
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
                   image: UIImage(systemName: "chevron.left"),
                   style: .plain,
                   target: self,
                   action: #selector(backButtonTapped)
               )
        print("🕵️ viewDidLoad: walkToStationTimeMin = \(walkToStationTimeMin), walkToStationTimeSec = \(walkToStationTimeSec)")

        self.walkToStationTimeSec = walkToStationTimeMin * 60.0 // for progrss bar Uses Only
        setupProgressBar()
        setupLayout()
        
        // Add the call to fetch and show route summary
        fetchAndShowRouteSummary()
        
        // —— 关键：先加载坐标，加载完再 populate ——
             loadStationCoordinates { [weak self] in
                 guard let self = self else { return }
                 self.populateSummary()
                 self.calculateStationPositionRatio()
                 
                 // 在 populateSummary 完成后添加初始高亮
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                     guard let self = self else { return }
                     if let walkToStationCard = self.stackView.arrangedSubviews.first(where: { $0.tag == self.walkToStationCardTag }) {
                         self.activeJourneySegmentCard = walkToStationCard
                         
                         UIView.animate(withDuration: 0.35, delay: 0.05, options: .curveEaseOut, animations: {
                             walkToStationCard.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                             walkToStationCard.backgroundColor = AppColors.highlightYellow
                             walkToStationCard.layer.shadowOpacity = 0.15
                             walkToStationCard.layer.shadowRadius = 12
                             
                             // Update text colors
                             walkToStationCard.subviews.forEach { view in
                                 if let stack = view as? UIStackView {
                                     stack.arrangedSubviews.forEach { subview in
                                         if let label = subview as? UILabel {
                                             label.textColor = AppColors.highlightText
                                         }
                                     }
                                 }
                             }
                             
                             // Scroll to make the active card visible
                             let cardFrameInScrollView = self.scrollView.convert(walkToStationCard.frame, from: self.stackView)
                             var visibleRect = cardFrameInScrollView
                             visibleRect.origin.y -= 20
                             visibleRect.size.height += 40
                             self.scrollView.scrollRectToVisible(visibleRect, animated: true)
                         })
                     }
                 }
             }
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter  = kCLDistanceFilterNone
        
        // Start periodic refresh of train arrivals
        startArrivalsAutoRefresh()
    }
    
    @objc private func backButtonTapped() {
        progressService?.stop()
        navigationController?.popViewController(animated: true)
    }


    deinit {
        arrivalsRefreshTimer?.invalidate()
        arrivalsRefreshTimer = nil
        progressService?.stop()
        print("RouteSummaryViewController deinitialized")
        pacingManager?.stopPacing()
        pacingManager = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
           // Ensure stationPositionRatio is calculated and progressBarBackground has its bounds.
           if tflLogoImageView.superview != nil &&
              tflLogoImageView.constraints.contains(where: { $0.firstAttribute == .centerX }) == false && // Check if centerX constraint is NOT YET set
              progressBarBackground.bounds.width > 0 &&
              stationPositionRatio > 0 && stationPositionRatio < 1 { 
               positionStationMarkerIcon()
           }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1)
        
        self.title = "Journey Summary"
        navigationController?.navigationBar.tintColor = AppColors.accentBlue
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        
        print("🕵️ viewDidLoad: walkToStationTimeMin = \(walkToStationTimeMin), walkToStationTimeSec = \(walkToStationTimeSec)")
        
        self.walkToStationTimeSec = walkToStationTimeMin * 60.0 // for progress bar Uses Only
        setupProgressBar()
        setupLayout()
        
        // Add the call to fetch and show route summary
        fetchAndShowRouteSummary()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
    }
    
    private func setupProgressBar() {
        // Use summaryLabel instead of sloganLabel
        view.addSubview(summaryLabel)
        
        progressBarCard.backgroundColor = .systemBackground
        progressBarCard.layer.cornerRadius = 18
        progressBarCard.layer.shadowColor = UIColor.black.cgColor
        progressBarCard.layer.shadowOpacity = 0.06
        progressBarCard.layer.shadowRadius = 10
        progressBarCard.layer.shadowOffset = CGSize(width: 0, height: 3)
        progressBarCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBarCard)

        NSLayoutConstraint.activate([
            // Update constraints to use summaryLabel
            summaryLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            summaryLabel.bottomAnchor.constraint(equalTo: progressBarCard.topAnchor, constant: -12),
            progressBarCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 45),
            progressBarCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressBarCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressBarCard.heightAnchor.constraint(equalToConstant: 72)
        ])
        
        let progressBarBackgroundHeight: CGFloat = 28
        progressBarBackground.backgroundColor = UIColor.secondarySystemBackground
        progressBarBackground.layer.cornerRadius = progressBarBackgroundHeight / 2
        progressBarBackground.translatesAutoresizingMaskIntoConstraints = false
        progressBarCard.addSubview(progressBarBackground)
        
        NSLayoutConstraint.activate([
            progressBarBackground.centerYAnchor.constraint(equalTo: progressBarCard.centerYAnchor),
            progressBarBackground.leadingAnchor.constraint(equalTo: progressBarCard.leadingAnchor, constant: 18),
            progressBarBackground.trailingAnchor.constraint(equalTo: progressBarCard.trailingAnchor, constant: -18),
            progressBarBackground.heightAnchor.constraint(equalToConstant: progressBarBackgroundHeight)
        ])

        // --- Person Dot (User's current position) ---
        personDot.text = "🧑"
        personDot.font = .systemFont(ofSize: 25)
        personDot.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(personDot)
        
        personDotLeadingConstraint = personDot.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor, constant: 4) // Initial padding
        personDotLeadingConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            personDot.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            // personDot.widthAnchor.constraint(equalToConstant: 28), // Optional: for explicit sizing
            // personDot.heightAnchor.constraint(equalToConstant: 28)  // Optional: for explicit sizing
        ])

        // --- TfL Logo (Station Marker - positioned dynamically) ---
        tflLogoImageView.image = UIImage(named: "london-underground") // Ensure asset exists
        tflLogoImageView.contentMode = .scaleAspectFit
        tflLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(tflLogoImageView)
        // Initial constraints for size, centerX will be set in positionStationMarkerIcon()
        NSLayoutConstraint.activate([
            tflLogoImageView.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            tflLogoImageView.widthAnchor.constraint(equalToConstant: 22), // Size of the station marker
            tflLogoImageView.heightAnchor.constraint(equalToConstant: 22)
        ])


        // --- Platform Emoji (End of the 'walk to platform' segment) ---
        platformEmoji.text = "🚇" // This is back!
        platformEmoji.font = .systemFont(ofSize: 22)
        platformEmoji.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(platformEmoji)
        
        NSLayoutConstraint.activate([
            platformEmoji.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            platformEmoji.trailingAnchor.constraint(equalTo: progressBarBackground.trailingAnchor, constant: -8) // Padding from right
        ])

        // deltaTimeLabel setup (remains the same)
        deltaTimeLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        deltaTimeLabel.textAlignment = .center
        deltaTimeLabel.numberOfLines = 0
        deltaTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(deltaTimeLabel)

        NSLayoutConstraint.activate([
            deltaTimeLabel.topAnchor.constraint(equalTo: progressBarCard.bottomAnchor, constant: 12),
            deltaTimeLabel.centerXAnchor.constraint(equalTo: progressBarCard.centerXAnchor),
            deltaTimeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            deltaTimeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // Rename this method and adjust its logic slightly if needed.
    private func positionStationMarkerIcon() {
        guard progressBarBackground.bounds.width > 0 else {
            print("Warning: progressBarBackground has no width yet for positionStationMarkerIcon.")
            tflLogoImageView.isHidden = true
            return
        }

        guard self.stationPositionRatio >= 0 && self.stationPositionRatio <= 1 else {
            print("Warning: stationPositionRatio (\(self.stationPositionRatio)) is out of bounds [0,1].")
            tflLogoImageView.isHidden = true
            return
        }

        // Define display widths for icons
        let personDotDisplayWidth: CGFloat = 28.0
        let platformEmojiDisplayWidth: CGFloat = 22.0
        let tflLogoDisplayWidth: CGFloat = 22.0

        // Define internal padding for the progress bar
        let barInternalLeadingPadding: CGFloat = 4
        let barInternalTrailingPadding: CGFloat = 8

        // Calculate track boundaries
        let trackStartX = barInternalLeadingPadding + (personDotDisplayWidth / 2)
        let trackEndX = progressBarBackground.bounds.width - barInternalTrailingPadding - (platformEmojiDisplayWidth / 2)
        let effectiveTrackLength = trackEndX - trackStartX

        guard effectiveTrackLength >= tflLogoDisplayWidth else {
            print("Warning: Track length too short for station marker.")
            tflLogoImageView.isHidden = true
            return
        }
        
        // Calculate logo position along the track
        let logoCenterOnTrack = effectiveTrackLength * self.stationPositionRatio
        let finalMarkerCenterXConstant = trackStartX + logoCenterOnTrack

        // Update constraints
        tflLogoImageView.constraints.forEach { constraint in
            if constraint.firstAttribute == .centerX {
                constraint.isActive = false
            }
        }
        
        NSLayoutConstraint.activate([
            tflLogoImageView.centerXAnchor.constraint(equalTo: progressBarBackground.leadingAnchor, constant: finalMarkerCenterXConstant)
        ])
        
        tflLogoImageView.isHidden = false
    }
    
    
    private func calculateStationPositionRatio() {
        let totalPreTrainTime = walkToStationTimeSec + stationToPlatformTimeSec
        
        if totalPreTrainTime > 0 {
            self.stationPositionRatio = CGFloat(walkToStationTimeSec / totalPreTrainTime)
            print("Calculated Station Position Ratio: \(self.stationPositionRatio)")
        } else {
            self.stationPositionRatio = 0.5
            print("Warning: totalPreTrainTime is zero for stationPositionRatio. Using default: 0.5")
        }
    }
    
    
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: deltaTimeLabel.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }
    
    // tracking user's real time progress through their planned journey - init journey progress Service
    private func setupProgressService() {
        guard let firstTransitInfo = transitInfos.first,
              let departureStationName = firstTransitInfo.departureStation else {
            print("Error: Cannot setup ProgressService - missing departure station")
            deltaTimeLabel.text = "Route data incomplete."
            deltaTimeLabel.textColor = .systemRed
            return
        }
        
        let normalizedKey = StationNameUtils.normalizeStationName(departureStationName)
        guard let stationData = stationCoordinates[normalizedKey] else {
            print("Error: Cannot setup ProgressService - missing station data for \(departureStationName) (normalized: \(normalizedKey))")
            print("Available stationCoordinate keys: \(stationCoordinates.keys)")
            deltaTimeLabel.text = "Route data incomplete."
            deltaTimeLabel.textColor = .systemRed
            return
        }
        
        let stationLocationForService = CLLocation(latitude: stationData.latitude, longitude: stationData.longitude)

        let service = JourneyProgressService(
            walkToStationSec: walkToStationTimeSec,
            stationToPlatformSec: stationToPlatformTimeSec,
            transferTimesSec: transferTimesSec,
            trainArrival: nextTrainArrivalDate,
            originLocation: userOriginLocation,
            stationLocation: stationLocationForService
        )
        service.delegate = self
        service.pacingManager = pacingManager  // 设置 pacingManager
        service.start()
        self.progressService = service
        
        // Setup PacingManager
        setupPacingManager(stationLocation: stationLocationForService)
    }
    
    private func setupPacingManager(stationLocation: CLLocation) {
        pacingManager = PacingManager()
        
        // Set initial values
        if let userOriginLocation = userOriginLocation {
            pacingManager?.distanceToStation = userOriginLocation.distance(from: stationLocation)
        }
        pacingManager?.timeToDeparture = nextTrainArrivalDate.timeIntervalSince(Date())
        
        // Handle speed updates
        pacingManager?.onSpeedUpdate = { [weak self] currentSpeed, targetSpeed in
            // Update UI with speed information if needed
            print("Current speed: \(currentSpeed) m/s, Target speed: \(targetSpeed) m/s")
        }
    }
    
    // MARK: - Summary Content & Animations
    private func populateSummary() {
        // Check if stationCoordinates are loaded before setting up progress service
        guard !stationCoordinates.isEmpty else {
            print("[RouteSummaryVC] stationCoordinates not loaded yet. Delaying populateSummary.")
            return
        }
        
        // Debugging: Print the final destination name
        print("[RouteSummaryVC] Final Destination Station Name: \(self.finalDestinationStationName ?? "N/A")")

        // clean the old views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var viewsToAdd: [UIView] = []

        if let departureStationName = transitInfos.first?.departureStation {
               // 用已知函数算一下目前距离车站的秒数
               let initialSec = estimatedSecondsToStation(for: departureStationName)
               let initialMinText = String(format: "%.0f min", initialSec / 60.0)

               // 直接传一个 UILabel 而不是纯字符串
               let subtitleLabel = UILabel()
               subtitleLabel.font = .systemFont(ofSize: 15)
               subtitleLabel.textColor = .secondaryLabel
               subtitleLabel.text = initialMinText
               subtitleLabel.numberOfLines = 1

               // 保存引用，以后不断去更新它
               self.walkToStationTimeLabel = subtitleLabel

               // 把这个 subtitleLabel 和标题一起放进卡片
               let walkToStationCard = makeCard(customView: {
                   let titleLabel = UILabel()
                   titleLabel.text = "🚶 Walk to Station"
                   titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
                   titleLabel.textColor = .label

                   let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
                   stack.axis = .vertical
                   stack.spacing = 6
                   stack.translatesAutoresizingMaskIntoConstraints = false
                   return stack
               }(), internalPadding: 18)

               walkToStationCard.tag = walkToStationCardTag
               viewsToAdd.append(walkToStationCard)
           }

        
        for (index, transitLegInfo) in transitInfos.enumerated() {
            // Only show station to platform card for the first transit leg
            if index == 0 {
                let stationToPlatformCard = StationToPlatformCardView()
                stationToPlatformCard.tag = stationToPlatformCardTag
                if let dep = transitLegInfo.departureStation {
                    stationToPlatformCard.configure(with: dep)
                }
                viewsToAdd.append(stationToPlatformCard)
            }

            let catchSectionView = UIStackView()
            catchSectionView.axis = .vertical
            catchSectionView.spacing = 10
            
            let catchTitleLabel = UILabel()
            catchTitleLabel.text = "🚦 Next Available Trains"
            catchTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
            catchTitleLabel.textColor = AppColors.accentBlue
            catchSectionView.addArrangedSubview(catchTitleLabel)
            
            let catchTrainCard = makeCard(customView: catchSectionView, internalPadding: 12)
            catchTrainCard.tag = catchTrainCardBaseTag + index
            viewsToAdd.append(catchTrainCard)
            
            // Call the new helper method to fetch, filter, and display arrivals
            fetchAndFilterArrivals(
                for: transitLegInfo,
                catchSectionView: catchSectionView,
                catchTrainCard: catchTrainCard,
                timeNeededAtStationToReachPlatformSec: self.stationToPlatformTimeSec,
                catchTitleLabel: catchTitleLabel,
                index: index
            )
            viewsToAdd.append(makeTransitCard(info: transitLegInfo, isTransfer: index > 0, legIndex: index))
            
            // Check for transfer leg and add transfer card if necessary
            if index < transitInfos.count - 1 {
               let  transferTimeSec = transitLegInfo.transferTimeSec
                    viewsToAdd.append(makeCard(title: "🚶‍♀️ Transfer", subtitle: "\(transferTimesSec)"))
            }
           
        }
        
        if let walkEndText = walkToDestinationTime, !walkEndText.isEmpty {
            let walkToDestinationCard = makeCard(title: "🏁 Walk to Destination", subtitle: walkEndText)
            walkToDestinationCard.tag = walkToDestinationCardTag
            viewsToAdd.append(walkToDestinationCard)
        }

        for (idx, cardView) in viewsToAdd.enumerated() {
            cardView.alpha = 0
            cardView.transform = CGAffineTransform(translationX: 0, y: 25)
            self.stackView.addArrangedSubview(cardView)
            UIView.animate(withDuration: 0.5,
                           delay: 0.15 + Double(idx) * 0.1,
                           usingSpringWithDamping: 0.75,
                           initialSpringVelocity: 0.15,
                           options: .curveEaseOut,
                           animations: {
                            cardView.alpha = 1
                            cardView.transform = .identity
            })
        }
    }

    private func addErrorLabel(_ message: String, to stackView: UIStackView?) {
        guard let stackView = stackView else { return }
        let errorLabel = UILabel()
        errorLabel.text = message
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textColor = .systemRed // Use a clear error color
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        stackView.addArrangedSubview(errorLabel)
    }
    
    func showNoTrainAlertAndPop() {
        let alert = UIAlertController(title: "No Trains Available 🚫", message: "We couldn't find any upcoming trains for a segment of your journey.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.navigationController?.popViewController(animated: true)
        }))
        if presentedViewController == nil { // Avoid presenting if already presenting something
            present(alert, animated: true)
        }
    }
    
    // MARK: - Card Makers
    private func makeCard(title: String, subtitle: String, internalPadding: CGFloat = 18) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.clipsToBounds = false // Important for shadow to be visible
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: internalPadding),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: internalPadding),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -internalPadding),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -internalPadding)
        ])
        return card
    }
    
    private func makeCard(customView: UIView, internalPadding: CGFloat = 18) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        customView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(customView)
        NSLayoutConstraint.activate([
            customView.topAnchor.constraint(equalTo: card.topAnchor, constant: internalPadding),
            customView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: internalPadding),
            customView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -internalPadding),
            customView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -internalPadding)
        ])
        return card
    }
    
    private func makeTransitCard(info: TransitInfo, isTransfer: Bool, legIndex: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.tag = transitCardBaseTag + legIndex // Tag the card with its leg index

        let accentColor = UIColor(hex: info.lineColorHex ?? "#007AFF")

        let accentBar = UIView()
        accentBar.backgroundColor = accentColor
        accentBar.layer.cornerRadius = 3
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accentBar)

        let timeline = TimelineView()
        timeline.lineColor = UIColor.systemGray3
        timeline.translatesAutoresizingMaskIntoConstraints = false
        timeline.tag = timelineViewTag // Tag the timeline view
        
        let lineBadgeLabel = PaddingLabel()
        lineBadgeLabel.text = info.lineName
        lineBadgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        lineBadgeLabel.textColor = accentColor.isLight ? .black.withAlphaComponent(0.8) : .white
        lineBadgeLabel.backgroundColor = accentColor
        lineBadgeLabel.layer.cornerRadius = 8
        lineBadgeLabel.clipsToBounds = true
        lineBadgeLabel.textAlignment = .center
        let badgeWidthConstraint = lineBadgeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100)
        badgeWidthConstraint.priority = .defaultHigh
        badgeWidthConstraint.isActive = true
        lineBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let startLabel = UILabel()
        startLabel.text = info.departureStation
        startLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        startLabel.textColor = .label
        startLabel.tag = timelineStartLabelTag // Tag the start label

        let crowdLabel = UILabel()
        crowdLabel.text = info.delayStatus
        crowdLabel.font = .systemFont(ofSize: 14)
        crowdLabel.textColor = .secondaryLabel
        
        let rideSummaryLabel = UILabel()
        let stopCount = info.numStops ?? 0
        let durationTime = info.durationTime ?? "-"
        let durationText = info.durationText ?? ""
        rideSummaryLabel.text = "Ride · \(stopCount) stops · \(durationTime) \(durationText)"
        rideSummaryLabel.font = .systemFont(ofSize: 14)
        rideSummaryLabel.textColor = .secondaryLabel
        rideSummaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let toggleButton = UIButton(type: .system)
        let arrowImage = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
        toggleButton.setImage(arrowImage, for: .normal)
        toggleButton.tintColor = .systemGray
        toggleButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let toggleRow = UIStackView(arrangedSubviews: [rideSummaryLabel, toggleButton])
        toggleRow.axis = .horizontal
        toggleRow.spacing = 8
        toggleRow.alignment = .center

        let intermediateLabel = UILabel()
        intermediateLabel.font = .systemFont(ofSize: 14)
        intermediateLabel.textColor = .label
        intermediateLabel.numberOfLines = 0
        intermediateLabel.isHidden = true
        let stops = info.stopNames
        if stops.count > 2 {
            let middleStops = stops[1..<(stops.count - 1)]
            intermediateLabel.text = middleStops.map { "•  \($0)" }.joined(separator: "\n")
        } else {
            intermediateLabel.text = ""
        }
        toggleButton.isHidden = intermediateLabel.text?.isEmpty ?? true

        toggleButton.addAction(UIAction { [weak intermediateLabel, weak card, weak toggleButton] _ in
            guard let intermediateLabel = intermediateLabel, let button = toggleButton else { return }
            intermediateLabel.isHidden.toggle()
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                button.transform = intermediateLabel.isHidden ? .identity : CGAffineTransform(rotationAngle: .pi)
                card?.layoutIfNeeded()
            })
        }, for: .touchUpInside)

        let endLabel = UILabel()
        endLabel.text = info.arrivalStation
        endLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        endLabel.textColor = .label
        endLabel.tag = timelineEndLabelTag // Tag the end label

        let contentStack = UIStackView(arrangedSubviews: [lineBadgeLabel, startLabel, crowdLabel, toggleRow, intermediateLabel, endLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .leading
        contentStack.setCustomSpacing(6, after: lineBadgeLabel)
        contentStack.setCustomSpacing(10, after: crowdLabel)
        contentStack.setCustomSpacing(intermediateLabel.text?.isEmpty ?? true ? 0 : 10, after: toggleRow)
        contentStack.setCustomSpacing(10, after: intermediateLabel)

        let horizontalStack = UIStackView(arrangedSubviews: [timeline, contentStack])
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 12
        horizontalStack.alignment = .top
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(horizontalStack)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            accentBar.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            accentBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            accentBar.widthAnchor.constraint(equalToConstant: 6),
            timeline.widthAnchor.constraint(equalToConstant: 20),
            horizontalStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            horizontalStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            horizontalStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            horizontalStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    // MARK: - Data Fetching and Processing

    private func fetchAndShowRouteSummary() {
        guard let from = routeStartCoordinate, let to = routeDestinationCoordinate else {
            summaryLabel.text = "--"
            return
        }
        
        // Call GoogleMapsService to fetch transit duration and arrival time
        GoogleMapsService.shared.fetchTransitDurationAndArrival(from: from, to: to) { [weak self] duration, arrivalTime, _, error in
            DispatchQueue.main.async {
                if let self = self {
                    if let duration = duration, let arrival = arrivalTime {
                        self.summaryLabel.text = "\(duration), arrive \(arrival)"
                    } else if let duration = duration {
                        self.summaryLabel.text = duration
                    } else if let arrival = arrivalTime {
                         self.summaryLabel.text = "Arrive \(arrival)"
                    } else {
                        self.summaryLabel.text = "No route info"
                    }
                }
            }
        }
    }

    private func fetchAndFilterArrivals(
        for transitLegInfo: TransitInfo,
        catchSectionView: UIStackView,
        catchTrainCard: UIView,
        timeNeededAtStationToReachPlatformSec: Double,
        catchTitleLabel: UILabel,
        index: Int
    ) {
        guard let departureStationName = transitLegInfo.departureStation else {
            DispatchQueue.main.async {
                self.addErrorLabel("Train station missing.", to: catchSectionView)
                catchTrainCard.layoutIfNeeded()
            }
            return
        }

        // 1. 先拿到 departureStation 的 naptanId
        TfLDataService.shared.resolveStationId(for: departureStationName) { [weak self] stationNaptanId in
            guard let self = self, let naptanId = stationNaptanId else {
                DispatchQueue.main.async {
                    self?.addErrorLabel("Station ID not found for \(departureStationName).", to: catchSectionView)
                    catchTrainCard.layoutIfNeeded()
                }
                return
            }

            // 缓存 naptanId
            self.catchNaptanIdDict[index] = naptanId

            let lineName = transitLegInfo.lineName
            let targetStationName = self.finalDestinationStationName ?? transitLegInfo.arrivalStation ?? ""
            let departureStationCoord = transitLegInfo.departureCoordinate
            let arrivalStationCoord = transitLegInfo.arrivalCoordinate

            // 2. 用 Journey Planner 拿到从 departure 到目标站的停靠站列表
            let fetchGroup = DispatchGroup()
            var stopSequence: [String]? = nil
            
            if let depCoord = departureStationCoord, let routeDestCoord = arrivalStationCoord {
                print("[RouteSummaryVC] Fetching stop sequence from current segment departure to route destination.")
                fetchGroup.enter()
                TfLDataService.shared.fetchJourneyPlannerStops(fromCoord: depCoord, toCoord: routeDestCoord) { sequence in
                    stopSequence = sequence
                    print("[RouteSummaryVC] Fetched stop sequence for filtering: \(sequence)")
                    fetchGroup.leave()
                }
            } else {
                print("[RouteSummaryVC] Skipping fetchJourneyPlannerStops due to missing coordinates.")
            }
            
            fetchGroup.notify(queue: .main) {
                catchSectionView.arrangedSubviews
                    .filter { !($0 is UILabel && ($0 as? UILabel)?.text == catchTitleLabel.text) }
                    .forEach { $0.removeFromSuperview() }

                guard let stopSequence = stopSequence, !stopSequence.isEmpty else {
                    self.addErrorLabel("No stop sequence available.", to: catchSectionView)
                    catchTrainCard.layoutIfNeeded()
                    return
                }
                
                // 归一化 stopList
                var stopList = stopSequence.map { StationNameUtils.normalizeStationName($0) }
                let depNorm = StationNameUtils.normalizeStationName(departureStationName)
                
                
            
                guard let targetTfLName = self.bestMatchingStationName(in: stopSequence, for: targetStationName) else {
                    self.addErrorLabel("Target station not found in this route segment.", to: catchSectionView)
                    catchTrainCard.layoutIfNeeded()
                    print("ERROR: Cannot match target \(targetStationName) in \(stopSequence)")
                    return
                }
                
                let targetNorm = StationNameUtils.normalizeStationName(targetTfLName)
                print("[RouteSummaryVC] Smart matched target station: \(targetTfLName) [norm: \(targetNorm)]")
                
                // 缓存 stopList, depNorm, targetNorm
                self.stopListCache[index] = stopList
                self.depNormCache[index] = depNorm
                self.targetNormCache[index] = targetNorm
                
                // 创建 stopSequence 的可变副本
                var mutableStopSequence = stopSequence
                
                // handle the problem of tfl journey planner with missing valid drepature station
                if stopList.first != depNorm {
                    stopList.insert(depNorm, at: 0)
                    mutableStopSequence.insert(departureStationName, at: 0)
                }
                
                guard let depIdx = stopList.firstIndex(of: depNorm),
                      let targetIdx = stopList.firstIndex(of: targetNorm) else {
                    print("[DEBUG] depNorm = \(depNorm), targetNorm = \(targetNorm), stopList = \(stopList)")
                    self.addErrorLabel("Could not find station indices in stop sequence.", to: catchSectionView)
                    catchTrainCard.layoutIfNeeded()
                    return
                }
                
                // 确保索引在有效范围内
                let minIdx = max(0, min(depIdx, targetIdx))
                let maxIdx = min(stopList.count - 1, max(depIdx, targetIdx))
                
                guard minIdx <= maxIdx else {
                    print("[DEBUG] Invalid indices: minIdx = \(minIdx), maxIdx = \(maxIdx), stopList count = \(stopList.count)")
                    self.addErrorLabel("Invalid station sequence.", to: catchSectionView)
                    catchTrainCard.layoutIfNeeded()
                    return
                }
                
                let journeySegmentStops = Array(mutableStopSequence[minIdx...maxIdx])
                print("[DEBUG] Journey segment stops: \(journeySegmentStops)")
                
                // 获取所有相关线路
                let lineGroup = DispatchGroup()
                var lineSets: [Set<String>] = []
                
                for stop in journeySegmentStops {
                    lineGroup.enter()
                    TfLDataService.shared.resolveStationId(for: stop) { naptanId in
                        guard let naptanId = naptanId else { 
                            print("[DEBUG] Could not resolve station ID for: \(stop)")
                            lineGroup.leave()
                            return 
                        }
                        TfLDataService.shared.fetchAvailableLines(for: naptanId) { lineIds in
                            print("[DEBUG] Fetched \(lineIds.count) lines for station: \(stop)")
                            lineSets.append(Set(lineIds))
                            lineGroup.leave()
                        }
                    }
                }
                
                lineGroup.notify(queue: .main) {
                    guard let firstSet = lineSets.first, !lineSets.isEmpty else {
                        self.addErrorLabel("Could not determine valid lines for journey segment.", to: catchSectionView)
                        catchTrainCard.layoutIfNeeded()
                        return
                    }
                    
                    let validLineIds = lineSets.reduce(firstSet) { $0.intersection($1) }
                    print("[RouteSummaryVC] Valid lineIds for segment: \(validLineIds)")
                    
                    // 获取到站预测
                    TfLDataService.shared.fetchAllArrivals(for: naptanId, relevantLineIds: Array(validLineIds)) { arrivals in
                        let now = Date()
                        let validArrivals = arrivals.filter { prediction in
                            let destNorm = StationNameUtils.normalizeStationName(prediction.destinationName ?? "")
                            guard let depIdx = stopList.firstIndex(of: depNorm),
                                  let targetIdx = stopList.firstIndex(of: targetNorm)
                            else { return false }

                            // First check if the train's route is valid
                            if let destIdx = stopList.firstIndex(of: destNorm) {
                                guard depIdx <= targetIdx && targetIdx <= destIdx else {
                                    return false
                                }
                            } else {
                                guard depIdx <= targetIdx else {
                                    return false
                                }
                            }

                            // Then check if user can still catch this train
                            let secondsUntilTrain = prediction.expectedArrival.timeIntervalSince(now)
                            let travelSec = self.estimatedSecondsToStation(for: departureStationName) + self.stationToPlatformTimeSec
                            let timeLeft = secondsUntilTrain - travelSec
                            return timeLeft >= -30
                        }
                        
                        print("[RouteSummaryVC] Filtered down to \(validArrivals.count) valid arrivals.")
                        
                        if validArrivals.isEmpty {
                            self.addErrorLabel("No upcoming train data available for your destination.", to: catchSectionView)
                            catchTrainCard.layoutIfNeeded()
                            return
                        }
                        
                        // 生成 CatchInfo
                        let allCatchInfos = validArrivals.map { prediction -> CatchInfo in
                            let secondsUntilTrainArrival = prediction.expectedArrival.timeIntervalSince(now)
                            let dynamicTravelSec = self.estimatedSecondsToStation(for: departureStationName) + self.stationToPlatformTimeSec
                            let timeLeftToCatch = secondsUntilTrainArrival - dynamicTravelSec
                            let status = CatchInfo.determineInitialCatchStatus(timeLeftToCatch: timeLeftToCatch)
                            return CatchInfo(
                                lineName:            prediction.lineName ?? (prediction.lineId ?? ""),
                                lineColorHex:        TfLColorUtils.hexString(forLineId: prediction.lineId ?? ""),
                                fromStation:         StationNameUtils.normalizeStationName(departureStationName),
                                toStation:           StationNameUtils.normalizeStationName(prediction.destinationName ?? ""),
                                stops:               [],
                                expectedArrival:     RouteSummaryViewController.shortTimeFormatter.string(from: prediction.expectedArrival),
                                expectedArrivalDate: prediction.expectedArrival,
                                timeToStation:       dynamicTravelSec,
                                timeLeftToCatch:     timeLeftToCatch,
                                catchStatus:         status
                            )
                        }.sorted { $0.expectedArrivalDate < $1.expectedArrivalDate }
                        
                        // 更新 ProgressService
                        if let firstTrain = allCatchInfos.first(where: { $0.catchStatus != .missed }) ?? allCatchInfos.first {
                            self.nextTrainArrivalDate = firstTrain.expectedArrivalDate
                            self.setupProgressService()
                        } else if transitLegInfo == self.transitInfos.first {
                            self.addErrorLabel("No catchable trains for the first leg.", to: catchSectionView)
                        }
                        
                        // 只取前5条做初次展示
                        let arrivalsToDisplay = Array(allCatchInfos.prefix(5))
                        
                        DispatchQueue.main.async {
                            // 缓存前5条 CatchInfo
                            self.catchInfosDict[index] = arrivalsToDisplay
                            
                            // 创建并缓存 CatchInfoRowView
                            var rowViews: [CatchInfoRowView] = []
                            for info in arrivalsToDisplay {
                                let row = CatchInfoRowView(info: info)
                                row.onMissed = { [weak self] in
                                    self?.refreshCatchTrainCards()
                                }
                                row.alpha = 0
                                catchSectionView.addArrangedSubview(row)
                                rowViews.append(row)
                                UIView.animate(withDuration: 0.35) {
                                    row.alpha = 1
                                }
                            }
                            
                            self.catchInfoRowViewsDict[index] = rowViews
                            catchTrainCard.layoutIfNeeded()
                            
                          
                            if self.catchInfosDict.count == self.transitInfos.count {
                                self.startArrivalsAutoRefresh()
                            }
                        }
                    }
                }
            }
        }
    }

    private func startArrivalsAutoRefresh() {
        // Invalidate existing timer if any
        arrivalsRefreshTimer?.invalidate()
        
        // Create a new timer that fires every refreshInterval seconds
        arrivalsRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshCatchTrainCards()
        }
    }

    private func refreshCatchTrainCards() {
        guard !isRefreshing else { return }
        isRefreshing = true

        let now = Date()
        let dispatchGroup = DispatchGroup()

        for (legIndex, oldRowViews) in catchInfoRowViewsDict {
            // 1. 取出存储在 catchInfosDict[legIndex] 的旧列表
            guard var oldInfos = catchInfosDict[legIndex],
                  let departureStationName = transitInfos[legIndex].departureStation else {
                continue
            }

            var oldViews = oldRowViews
            
            print("【刷新开始】legIndex=\(legIndex)，当前 oldInfos 的 expectedArrivalDates = \(oldInfos.map{ $0.expectedArrivalDate })")

            // Get the estimated time once for this station
            let travelSec = estimatedSecondsToStation(for: departureStationName) + self.stationToPlatformTimeSec
            
            // Update all infos with the same travel time
            for i in 0..<oldInfos.count {
                var info = oldInfos[i]
                let secondsUntilTrain = info.expectedArrivalDate.timeIntervalSince(now)
                let newTimeLeft = secondsUntilTrain - travelSec
                let newStatus = CatchInfo.determineInitialCatchStatus(timeLeftToCatch: newTimeLeft)

                info.timeLeftToCatch = newTimeLeft
                info.catchStatus = newStatus
                oldInfos[i] = info

                // Update the row view
                let rowView = oldViews[i]
                let updatedInfo = CatchInfo(
                    lineName:            info.lineName,
                    lineColorHex:        info.lineColorHex,
                    fromStation:         info.fromStation,
                    toStation:           info.toStation,
                    stops:               info.stops,
                    expectedArrival:     RouteSummaryViewController.shortTimeFormatter.string(from: info.expectedArrivalDate),
                    expectedArrivalDate: info.expectedArrivalDate,
                    timeToStation:       travelSec,
                    timeLeftToCatch:     newTimeLeft,
                    catchStatus:         newStatus
                )
                rowView.update(with: updatedInfo)
            }

            // 先把刚刚 update 完的旧列表写回缓存
            catchInfosDict[legIndex] = oldInfos

            // —— 2. 统计队头连续的 missed —— 
            var removeCount = 0
            for info in oldInfos {
                if info.catchStatus == .missed {
                    removeCount += 1
                } else {
                    break
                }
            }

            // —— 3. 如果 removeCount == 0，就什么都不做（既不删也不 fetch） —— 
            if removeCount == 0 {
                continue
            }

            // —— 4. 真正把连续的 removeCount 条删掉 —— 
            for _ in 0..<removeCount {
                let viewToRemove = oldViews.removeFirst()
                UIView.animate(withDuration: 0.25, animations: {
                    viewToRemove.alpha = 0
                }, completion: { _ in
                    viewToRemove.removeFromSuperview()
                })
                oldInfos.removeFirst()
            }

            print("【删行后】legIndex=\(legIndex)，剩下 oldInfos = \(oldInfos.map{ $0.expectedArrivalDate })")

            // 先把删掉之后的缓存马上写回
            catchInfosDict[legIndex] = oldInfos
            catchInfoRowViewsDict[legIndex] = oldViews

            // —— 5. 只有真正"删了行"才触发一个 fetch，去补 removeCount 条 —— 
            dispatchGroup.enter()
            TfLDataService.shared.fetchAllArrivals(for: catchNaptanIdDict[legIndex]!, relevantLineIds: nil) { [weak self] arrivals in
                guard let self = self else {
                    dispatchGroup.leave()
                    return
                }
                let nowInner = Date()

                // 5.1 过滤 + 排序（只剩能赶上的那几辆车，和原来第一次 fetch 用的逻辑保持一致）
                let stopList = self.stopListCache[legIndex]!
                let depNorm = self.depNormCache[legIndex]!
                let targetNorm = self.targetNormCache[legIndex]!

                let filteredPredictions = arrivals.filter { prediction in
                    let destNorm = StationNameUtils.normalizeStationName(prediction.destinationName ?? "")
                    guard let depIdx = stopList.firstIndex(of: depNorm),
                          let targetIdx = stopList.firstIndex(of: targetNorm) else {
                        return false
                    }
                    if let destIdx = stopList.firstIndex(of: destNorm) {
                        guard depIdx <= targetIdx && targetIdx <= destIdx else {
                            return false
                        }
                    } else {
                        guard depIdx <= targetIdx else {
                            return false
                        }
                    }
                    let secondsUntilTrain = prediction.expectedArrival.timeIntervalSince(nowInner)
                    let travelSec = self.estimatedSecondsToStation(for: departureStationName) + self.stationToPlatformTimeSec
                    let timeLeft = secondsUntilTrain - travelSec
                    return timeLeft >= -30
                }
                .sorted { $0.expectedArrival < $1.expectedArrival }

                // 5.2 把这些 prediction map 成 CatchInfo 数组
                let newCatchInfosAll: [CatchInfo] = filteredPredictions.map { prediction in
                    let secondsUntilTrain = prediction.expectedArrival.timeIntervalSince(nowInner)
                    let travelSec = self.estimatedSecondsToStation(for: departureStationName) + self.stationToPlatformTimeSec
                    let left = secondsUntilTrain - travelSec
                    let status = CatchInfo.determineInitialCatchStatus(timeLeftToCatch: left)
                    return CatchInfo(
                        lineName:            prediction.lineName ?? (prediction.lineId ?? ""),
                        lineColorHex:        TfLColorUtils.hexString(forLineId: prediction.lineId ?? ""),
                        fromStation:         StationNameUtils.normalizeStationName(departureStationName),
                        toStation:           StationNameUtils.normalizeStationName(prediction.destinationName ?? ""),
                        stops:               [],
                        expectedArrival:     RouteSummaryViewController.shortTimeFormatter.string(from: prediction.expectedArrival),
                        expectedArrivalDate: prediction.expectedArrival,
                        timeToStation:       travelSec,
                        timeLeftToCatch:     left,
                        catchStatus:         status
                    )
                }

                // 5.3 从 newCatchInfosAll 中挑出「真正全新」的 removeCount 条来补
                var existingDates = Set<Date>(oldInfos.map { $0.expectedArrivalDate })
                var trulyNew: [CatchInfo] = []
                for info in newCatchInfosAll {
                    if !existingDates.contains(info.expectedArrivalDate) {
                        trulyNew.append(info)
                        existingDates.insert(info.expectedArrivalDate)
                    }
                    if trulyNew.count == removeCount {
                        break
                    }
                }

                DispatchQueue.main.async {
                    // 5.4 把这 removeCount 条真正的"新车" append 到末尾，并加 rowView
                    for newInfo in trulyNew {
                        oldInfos.append(newInfo)
                        let newRow = CatchInfoRowView(info: newInfo)
                        newRow.onMissed = { [weak self] in
                            self?.refreshCatchTrainCards()
                        }
                        newRow.alpha = 0

                        if let catchTrainCard = self
                            .stackView
                            .arrangedSubviews
                            .first(where: { $0.tag == self.catchTrainCardBaseTag + legIndex }),
                           let catchSectionView = catchTrainCard.subviews.compactMap({ $0 as? UIStackView }).first {
                            catchSectionView.addArrangedSubview(newRow)
                            oldViews.append(newRow)
                            UIView.animate(withDuration: 0.25) {
                                newRow.alpha = 1
                            }
                        }
                    }

                    print("【补行后】legIndex=\(legIndex)，new oldInfos = \(oldInfos.map{ $0.expectedArrivalDate })")

                    // 5.5 写回缓存
                    self.catchInfosDict[legIndex] = oldInfos
                    self.catchInfoRowViewsDict[legIndex] = oldViews

                    // 5.6 如果新列表的第一条 expectedArrivalDate 变了，就更新 progressService
                    if let newFirst = oldInfos.first,
                       newFirst.expectedArrivalDate != self.nextTrainArrivalDate {
                        self.nextTrainArrivalDate = newFirst.expectedArrivalDate
                        self.setupProgressService()
                    }

                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.isRefreshing = false
        }
    }

    private func bestMatchingStationName(in stopList: [String], for rawTargetName: String) -> String? {
        let normTarget = StationNameUtils.normalizeStationName(rawTargetName)
        
        // First try exact match
        if let exact = stopList.first(where: { StationNameUtils.normalizeStationName($0) == normTarget }) {
            return exact
        }
        
        // If target is a postal code, try to find the nearest station
        if normTarget.contains("ec") || normTarget.contains("e1") || normTarget.contains("e2") {
            // For EC3N 4AB, try to match with Tower Hill or Monument
            if normTarget.contains("ec3") {
                if let towerHill = stopList.first(where: { StationNameUtils.normalizeStationName($0).contains("tower hill") }) {
                    return towerHill
                }
                if let monument = stopList.first(where: { StationNameUtils.normalizeStationName($0).contains("monument") }) {
                    return monument
                }
            }
        }
        
        // Try partial match
        if let partial = stopList.first(where: { StationNameUtils.normalizeStationName($0).contains(normTarget) || normTarget.contains(StationNameUtils.normalizeStationName($0)) }) {
            return partial
        }
        
        // If still no match, try to find the last station in the sequence
        // This is a fallback for when the target is beyond the last station
        return stopList.last
    }

    // MARK: - Location Manager Delegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update current location
        currentLocation = location
        
        // Set origin location if not set
        if userOriginLocation == nil {
            userOriginLocation = location
        }
        
        // Update journey progress
        journeyProgressService?.updateProgressWithLocation(currentLocation: location)
        
        // Update pacing manager with new location
        pacingManager?.updateWithNewLocation(location)
        
        // Update UI with new location
        updateUIWithNewLocation(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed: \(error.localizedDescription)")
        // You might want to inform the user or fallback to non-GPS based progress updates
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location access granted.")
            // If a journey is active and requires location, start updates.
            // if progressService?.isActive == true && progressService?.currentPhase == .walkToStation {
            //    locationManager.startUpdatingLocation()
            // }
        case .denied, .restricted:
            print("Location access denied.")
            // Inform user that location-based features will be limited.
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization() // Or request when feature is needed
        @unknown default:
            print("Unknown location authorization status.")
        }
    }
    
    // Removed setupMovingDot as its usage depends on more context (active card, etc.)
    // You can re-add it if you have a clear way to determine the active timeline and card.

    private func setupMovingDot(attachedTo timeline: TimelineView, in card: UIView) {
        // Remove this entire function
    }

    private func loadStationCoordinates(completion: @escaping () -> Void) {
         TfLDataService.shared.loadAllTubeStations { [weak self] stationsDict in
             guard let self = self else { return }
             var tmp: [String: CLLocationCoordinate2D] = [:]
             for (rawName, meta) in stationsDict {
                 let norm = StationNameUtils.normalizeStationName(rawName)
                 tmp[norm] = meta.coord
             }
             self.stationCoordinates = tmp
             DispatchQueue.main.async {
                 completion()
             }
         }
     }

    private func estimatedSecondsToStation(for stationName: String) -> TimeInterval {
        // 只用Google API返回的步行时间
        return walkToStationTimeSec
    }

    private func updateUIWithNewLocation(_ location: CLLocation) {
        // Update the progress bar position
        if let progressService = journeyProgressService {
            let progress = progressService.progress
            updateProgressBar(with: progress)
        }
        
        // Update the walk time label if needed
        if let walkToStationTimeLabel = walkToStationTimeLabel {
            let minutes = Int(ceil(walkToStationTimeSec / 60.0))
            walkToStationTimeLabel.text = "\(minutes) min"
        }
    }

    private func updateProgressBar(with progress: Double) {
        // Update the progress bar UI
        let clampedProgress = min(max(progress, 0), 1)
        if progressBarBackground.bounds.width > 0 {
            let startPadding: CGFloat = 4
            let personDotEffectiveWidth = personDot.intrinsicContentSize.width > 0 ? personDot.intrinsicContentSize.width : 28
            let platformEmojiEffectiveWidth = platformEmoji.intrinsicContentSize.width > 0 ? platformEmoji.intrinsicContentSize.width : 22
            let platformEmojiTrailingPadding: CGFloat = 8
            
            let endPointForDotLeadingEdge = progressBarBackground.bounds.width - platformEmojiTrailingPadding - platformEmojiEffectiveWidth - personDotEffectiveWidth
            let actualTravelableWidth = max(0, endPointForDotLeadingEdge - startPadding)
            
            let leadingConstant = startPadding + (actualTravelableWidth * CGFloat(clampedProgress))
            personDotLeadingConstraint?.constant = leadingConstant
            
            UIView.animate(withDuration: 0.25) {
                self.progressBarBackground.layoutIfNeeded()
            }
        }
    }

    // Add these properties at the top of the class
    private var statusButton: UIButton!
    private var lineStatuses: [String: TfLLineStatus] = [:]
    private var statusPopoverVC: UIViewController?

    // Add this method after setupUI()
    private func setupStatusButton() {
        statusButton = UIButton(type: .system)
        statusButton.setImage(UIImage(systemName: "exclamationmark.circle.fill"), for: .normal)
        statusButton.tintColor = .systemBlue
        statusButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusButton)
        
        NSLayoutConstraint.activate([
            statusButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            statusButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            statusButton.widthAnchor.constraint(equalToConstant: 44),
            statusButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        statusButton.addTarget(self, action: #selector(statusButtonTapped), for: .touchUpInside)
        
        // Add initial state check
        Task {
            do {
                lineStatuses = try await TfLDataService.shared.fetchAllLineStatuses()
                await MainActor.run {
                    updateStatusButtonAppearance()
                }
            } catch {
                print("Error fetching initial line statuses: \(error)")
            }
        }
    }
    
    private func updateStatusButtonAppearance() {
        // Check if any line has severe status
        let hasSevereStatus = lineStatuses.values.contains { status in
            status.lineStatuses.contains { $0.statusSeverity > 5 }
        }
        
        // Update button appearance
        statusButton.tintColor = hasSevereStatus ? .systemRed : .systemBlue
        statusButton.alpha = hasSevereStatus ? 1.0 : 0.6
    }

    @objc private func statusButtonTapped() {
        Task {
            do {
                // 获取所有线路状态
                lineStatuses = try await TfLDataService.shared.fetchAllLineStatuses()
                
                // 在主线程更新 UI
                await MainActor.run {
                    updateStatusButtonAppearance()
                    showStatusPopover()
                }
            } catch {
                print("Error fetching line statuses: \(error)")
                // 可以在这里添加错误提示
            }
        }
    }

    private func showStatusPopover() {
        // 移除现有的弹窗
        statusPopoverVC?.dismiss(animated: false)
        
        // 创建新的弹窗视图
        let popoverVC = UIViewController()
        popoverVC.modalPresentationStyle = .popover
        popoverVC.preferredContentSize = CGSize(width: 300, height: 400)
        popoverVC.view.backgroundColor = .systemBackground
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        popoverVC.view.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // 添加标题
        let titleLabel = UILabel()
        titleLabel.text = "Line Status"
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        stackView.addArrangedSubview(titleLabel)
        
        // 添加分隔线
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator)
        
        // 添加每个线路的状态
        for (lineId, status) in lineStatuses.sorted(by: { $0.key < $1.key }) {
            let lineView = createLineStatusView(lineId: lineId, status: status)
            stackView.addArrangedSubview(lineView)
        }
        
        // 设置约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: popoverVC.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: popoverVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: popoverVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: popoverVC.view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // 设置弹窗位置
        if let popover = popoverVC.popoverPresentationController {
            popover.sourceView = statusButton
            popover.sourceRect = statusButton.bounds
            popover.permittedArrowDirections = [.up]
        }
        
        statusPopoverVC = popoverVC
        present(popoverVC, animated: true)
    }

    private func createLineStatusView(lineId: String, status: TfLLineStatus) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        
        let lineNameLabel = UILabel()
        lineNameLabel.text = status.name
        lineNameLabel.font = .boldSystemFont(ofSize: 16)
        lineNameLabel.textColor = TfLColorUtils.color(forLineId: lineId)
        
        let statusLabel = UILabel()
        statusLabel.numberOfLines = 0
        
        // 获取最严重的状态
        if let mostSevereStatus = status.lineStatuses.max(by: { $0.statusSeverity < $1.statusSeverity }) {
            let statusText = mostSevereStatus.statusSeverityDescription
            let reasonText = mostSevereStatus.reason ?? ""
            let disruptionText = mostSevereStatus.disruption?.description ?? ""
            
            var fullText = statusText
            if !reasonText.isEmpty {
                fullText += "\nReason: \(reasonText)"
            }
            if !disruptionText.isEmpty {
                fullText += "\nDisruption: \(disruptionText)"
            }
            
            statusLabel.text = fullText
            statusLabel.font = .systemFont(ofSize: 14)
            statusLabel.textColor = mostSevereStatus.statusSeverity > 5 ? .systemRed : .label
        }
        
        let stackView = UIStackView(arrangedSubviews: [lineNameLabel, statusLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        return container
    }

    // MARK: - Weather Updates
    
    func updateWeatherInfo(condition: String) {
        self.currentWeather = condition
    }
}

// MARK: - JourneyProgressDelegate Extension
extension RouteSummaryViewController: JourneyProgressDelegate {
    func journeyProgressDidUpdate(
        overallProgress: Double,
        phaseProgress: Double,
        currentCatchStatus: CatchStatus,
        delta: TimeInterval,
        uncertainty: TimeInterval,
        phase: ProgressPhase
    ) {
        // --- 1. Update Main Progress Bar (Person Dot Position) ---
        let clampedOverallProgress = min(max(overallProgress, 0), 1)
        if progressBarBackground.bounds.width > 0 {
            let startPadding: CGFloat = 4
            let personDotEffectiveWidth = personDot.intrinsicContentSize.width > 0 ? personDot.intrinsicContentSize.width : 28
            let platformEmojiEffectiveWidth = platformEmoji.intrinsicContentSize.width > 0 ? platformEmoji.intrinsicContentSize.width : 22
            let platformEmojiTrailingPadding: CGFloat = 8
            
            let endPointForDotLeadingEdge = progressBarBackground.bounds.width - platformEmojiTrailingPadding - platformEmojiEffectiveWidth - personDotEffectiveWidth
            let actualTravelableWidth = max(0, endPointForDotLeadingEdge - startPadding)
            
            let leadingConstant = startPadding + (actualTravelableWidth * CGFloat(clampedOverallProgress))
            personDotLeadingConstraint?.constant = leadingConstant
        }

        // --- 2. Visual Cue for Reaching Station (TfL Logo Pulsing on main progress bar) ---
        if clampedOverallProgress >= stationPositionRatio &&
           !self.hasReachedStationVisualCue &&
           phase == .walkToStation && 
           stationPositionRatio > 0 && stationPositionRatio < 1 {
            self.hasReachedStationVisualCue = true
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred()
            UIView.animate(withDuration: 0.3, animations: {
                self.tflLogoImageView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }) { _ in
                UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                    self.tflLogoImageView.transform = .identity
                })
            }
        }
        
        // --- 3. Animate Main Progress Bar Dot Movement ---
        if self.progressBarBackground.window != nil {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: {
                self.progressBarBackground.layoutIfNeeded()
            })
        } else {
            self.progressBarBackground.layoutIfNeeded()
        }
        
        // --- 4. Update Delta Time Label with Catch Status ---
        let timeText = String(format: "%.0fs", abs(delta))
        let uncertaintyText = String(format: "±%.0fs", uncertainty)
        let statusDescription: String
        if currentCatchStatus == .easy || currentCatchStatus == .hurry {
            statusDescription = "\(currentCatchStatus.displayText) · \(timeText) buffer"
        } else if currentCatchStatus == .tough {
            statusDescription = "\(currentCatchStatus.displayText) · \(timeText) \(delta < 0 ? "late" : "margin")"
        } else { 
            statusDescription = "\(currentCatchStatus.displayText) by \(timeText)"
        }
        
        // --- 5. Update Delta Time Label ---
        deltaTimeLabel.text = statusDescription
        deltaTimeLabel.textColor = currentCatchStatus.displayColor
        
        // --- 6. Haptic Feedback for Status Changes ---
        if let previousStatus = previousCatchStatus, previousStatus != currentCatchStatus {
            let improvement = (previousStatus == .tough && (currentCatchStatus == .hurry || currentCatchStatus == .easy)) ||
                              (previousStatus == .hurry && currentCatchStatus == .easy)
            let degradation = (previousStatus == .easy && (currentCatchStatus == .hurry || currentCatchStatus == .tough)) ||
                              (previousStatus == .hurry && currentCatchStatus == .tough) ||
                              (previousStatus != .missed && currentCatchStatus == .missed)
            if improvement {
                let feedbackGenerator = UINotificationFeedbackGenerator(); feedbackGenerator.prepare(); feedbackGenerator.notificationOccurred(.success)
            } else if degradation {
                let feedbackGenerator = UINotificationFeedbackGenerator(); feedbackGenerator.prepare(); feedbackGenerator.notificationOccurred(.warning)
            }
        }
        self.previousCatchStatus = currentCatchStatus
    }
    
    func journeyPhaseDidChange(_ phase: ProgressPhase) {
        print("RouteSummaryVC: Journey phase changed to: \(phase)")
        
        // 1. De-highlight previously active card
        if let oldActiveCard = self.activeJourneySegmentCard {
            UIView.animate(withDuration: 0.3, animations: {
                oldActiveCard.transform = .identity
                oldActiveCard.backgroundColor = .systemBackground
                oldActiveCard.layer.shadowOpacity = 0.08
                oldActiveCard.layer.borderColor = UIColor.clear.cgColor
                oldActiveCard.layer.borderWidth = 0
                
                // Reset text colors
                oldActiveCard.subviews.forEach { view in
                    if let stack = view as? UIStackView {
                        stack.arrangedSubviews.forEach { subview in
                            if let label = subview as? UILabel {
                                label.textColor = label.tag == 1 ? .label : .secondaryLabel // tag 1 for title, others for subtitle
                            }
                        }
                    }
                }
            })
        }
        self.activeJourneySegmentCard = nil
        self.currentActiveTransitLegIndex = nil

        var newActiveCardView: UIView? = nil
        var legIndexOfNewActiveTrainCard: Int? = nil

        // 2. Determine and highlight new active card
        switch phase {
        case .walkToStation:
            self.hasReachedStationVisualCue = false
            self.previousCatchStatus = nil
            startLocationUpdatesIfNeeded()
            newActiveCardView = stackView.arrangedSubviews.first(where: { $0.tag == walkToStationCardTag })
            if newActiveCardView == nil {
                print("Debug: Walk to Station card with tag \(walkToStationCardTag) not found.")
                newActiveCardView = stackView.arrangedSubviews.first
            }
            
        case .stationToPlatform:
            stopLocationUpdates()
            newActiveCardView = stackView.arrangedSubviews.first(where: { $0.tag == stationToPlatformCardTag })
            if newActiveCardView == nil {
                print("Debug: Station to Platform card with tag \(stationToPlatformCardTag) not found.")
            }

        case .onTrain(let legIndex):
            stopLocationUpdates()
            legIndexOfNewActiveTrainCard = legIndex
            if let card = stackView.arrangedSubviews.first(where: { $0.tag == transitCardBaseTag + legIndex }) {
                newActiveCardView = card
            } else {
                print("Error: Could not find active train card for leg \(legIndex) with tag \(transitCardBaseTag + legIndex)")
            }
            
        case .transferWalk(let afterLegIndex):
            startLocationUpdatesIfNeeded()
            if let transferCard = stackView.arrangedSubviews.first(where: { $0.tag == transitCardBaseTag + afterLegIndex + 1 }) {
                newActiveCardView = transferCard
            }

        case .walkToDestination:
            startLocationUpdatesIfNeeded()
            newActiveCardView = stackView.arrangedSubviews.first(where: { $0.tag == walkToDestinationCardTag })
            if newActiveCardView == nil {
                print("Debug: Walk to Destination card with tag \(walkToDestinationCardTag) not found.")
                newActiveCardView = stackView.arrangedSubviews.last
            }

        case .finished:
            stopLocationUpdates()
        }

        // 3. Apply highlight to the new active card (if any)
        if let cardToHighlight = newActiveCardView {
            self.activeJourneySegmentCard = cardToHighlight
            self.currentActiveTransitLegIndex = legIndexOfNewActiveTrainCard
            
            UIView.animate(withDuration: 0.35, delay: 0.05, options: .curveEaseOut, animations: {
                cardToHighlight.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                cardToHighlight.backgroundColor = AppColors.highlightYellow
                cardToHighlight.layer.shadowOpacity = 0.15
                cardToHighlight.layer.shadowRadius = 12
                
                // Update text colors
                cardToHighlight.subviews.forEach { view in
                    if let stack = view as? UIStackView {
                        stack.arrangedSubviews.forEach { subview in
                            if let label = subview as? UILabel {
                                label.textColor = AppColors.highlightText
                            }
                        }
                    }
                }
                
                // Scroll to make the active card visible
                let cardFrameInScrollView = self.scrollView.convert(cardToHighlight.frame, from: self.stackView)
                var visibleRect = cardFrameInScrollView
                visibleRect.origin.y -= 20
                visibleRect.size.height += 40
                self.scrollView.scrollRectToVisible(visibleRect, animated: true)
            })
        }
    }
    
    private func startLocationUpdatesIfNeeded() {
        if CLLocationManager.locationServicesEnabled() {
            switch locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.startUpdatingLocation()
                print("Location updates started.")
            default:
                print("Location access not granted, cannot start updates.")
            }
        }
    }
    
    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        print("Location updates stopped.")
    }
}


class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8) // Adjusted padding
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}

