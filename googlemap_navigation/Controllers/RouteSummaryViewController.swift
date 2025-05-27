import UIKit
import CoreLocation

class RouteSummaryViewController: UIViewController, CLLocationManagerDelegate {
    
    // MARK: - Properties
    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var totalEstimatedTime: String?
    var walkToStationTime: String?
    var walkToDestinationTime: String?
    var transitInfos: [TransitInfo] = [] // Ensure this is populated with all necessary fields
    var routeDepartureTime: String?
    var routeArrivalTime: String?
    
    var walkToStationTimeSec: Double = 0
    var stationToPlatformTimeSec: Double = 120
    var transferTimesSec: [Double] = []
    var nextTrainArrivalDate: Date = Date() // Critical: Should be the specific train JourneyProgressService tracks
    
    var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
    
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
    

    // Removed unused movingDot, dotCenterYConstraint, timelineMap, stopLabelMap unless re-added for intra-card progress
    
    private var locationManager = CLLocationManager()
    private var progressService: JourneyProgressService? // This service will provide the dynamic CatchStatus
    private let deltaTimeLabel = UILabel() // Displays dynamic catch status and time
    
    // GPS coordinates for the initial walk phase if JourneyProgressService uses them directly
    private var userOriginLocation: CLLocation? // User's actual start (for JourneyProgressService)

    private let sloganLabel: UILabel = {
        let label = UILabel()
        label.text = "Track your journey 👀"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor.systemGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1)
        
        self.title = "Journey Summary"
        navigationController?.navigationBar.tintColor = AppColors.accentBlue
        
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(backButtonTapped))
        navigationItem.leftBarButtonItem = backButton
        
        setupProgressBar()
        setupLayout()
        
        // Ensure all data (walkToStationTimeSec, nextTrainArrivalDate, transitInfos etc.)
        // is fully loaded and correct BEFORE calling populateSummary and setupProgressService.
        // If transitInfos is fetched asynchronously, call these after data is ready.
        populateSummary()
        setupProgressService()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        // Location updates are typically started/stopped by JourneyProgressService or by journeyPhaseDidChange
    }
    
    @objc private func backButtonTapped() {
        progressService?.stop()
        navigationController?.popViewController(animated: true)
    }

    deinit {
        progressService?.stop() // Important to stop the service to prevent leaks/crashes
        print("RouteSummaryViewController deinitialized")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Position TfL logo once progressBarBackground has valid bounds and times are set.
        if tflLogoImageView.superview != nil &&
           tflLogoImageView.constraints.isEmpty && // Only set constraints once
           progressBarBackground.bounds.width > 0 &&
           (walkToStationTimeSec + stationToPlatformTimeSec > 0) { // Ensure times are valid
            positionTflLogo()
        }
    }
    
    // MARK: - UI Setup
    private func setupProgressBar() {
        view.addSubview(sloganLabel)
        
        progressBarCard.backgroundColor = .systemBackground // Adapts to light/dark mode
        progressBarCard.layer.cornerRadius = 18
        progressBarCard.layer.shadowColor = UIColor.black.cgColor
        progressBarCard.layer.shadowOpacity = 0.06
        progressBarCard.layer.shadowRadius = 10
        progressBarCard.layer.shadowOffset = CGSize(width: 0, height: 3)
        progressBarCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBarCard)

        NSLayoutConstraint.activate([
            sloganLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sloganLabel.bottomAnchor.constraint(equalTo: progressBarCard.topAnchor, constant: -12),
            progressBarCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 45),
            progressBarCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressBarCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressBarCard.heightAnchor.constraint(equalToConstant: 72)
        ])
        
        progressBarBackground.backgroundColor = UIColor.secondarySystemBackground // Adapts
        progressBarBackground.layer.cornerRadius = progressBarBackground.heightAnchor.constraint(equalToConstant: 28).constant / 2 // Pill shape
        progressBarBackground.translatesAutoresizingMaskIntoConstraints = false
        progressBarCard.addSubview(progressBarBackground)
        
        NSLayoutConstraint.activate([
            progressBarBackground.centerYAnchor.constraint(equalTo: progressBarCard.centerYAnchor),
            progressBarBackground.leadingAnchor.constraint(equalTo: progressBarCard.leadingAnchor, constant: 18),
            progressBarBackground.trailingAnchor.constraint(equalTo: progressBarCard.trailingAnchor, constant: -18),
            progressBarBackground.heightAnchor.constraint(equalToConstant: 28)
        ])

        tflLogoImageView.image = UIImage(named: "london-underground") // Ensure asset exists
        tflLogoImageView.contentMode = .scaleAspectFit
        tflLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(tflLogoImageView)

        platformEmoji.text = "🚇"
        platformEmoji.font = .systemFont(ofSize: 22)
        platformEmoji.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(platformEmoji)
        
        NSLayoutConstraint.activate([
            platformEmoji.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            platformEmoji.trailingAnchor.constraint(equalTo: progressBarBackground.trailingAnchor, constant: -8)
        ])

        personDot.text = "🧑"
        personDot.font = .systemFont(ofSize: 25)
        personDot.translatesAutoresizingMaskIntoConstraints = false
        progressBarBackground.addSubview(personDot)
        
        personDotLeadingConstraint = personDot.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor, constant: 4)
        personDotLeadingConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            personDot.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            // Width/Height can be omitted if intrinsicContentSize of emoji is sufficient, or set explicitly
            // personDot.widthAnchor.constraint(equalToConstant: 28),
            // personDot.heightAnchor.constraint(equalToConstant: 28)
        ])

        deltaTimeLabel.font = .systemFont(ofSize: 14, weight: .semibold) // Adjusted size
        deltaTimeLabel.textAlignment = .center
        deltaTimeLabel.numberOfLines = 0 // Allow wrapping if text gets long
        deltaTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(deltaTimeLabel)

        NSLayoutConstraint.activate([
            deltaTimeLabel.topAnchor.constraint(equalTo: progressBarCard.bottomAnchor, constant: 12), // Increased spacing
            deltaTimeLabel.centerXAnchor.constraint(equalTo: progressBarCard.centerXAnchor),
            deltaTimeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), // Allow full width
            deltaTimeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func positionTflLogo() {
        guard progressBarBackground.bounds.width > 0 else {
            print("Warning: progressBarBackground has no width for positionTflLogo.")
            return
        }
        let totalPreTrainTime = walkToStationTimeSec + stationToPlatformTimeSec
        // Ensure totalPreTrainTime is positive to prevent division by zero or incorrect ratio
        guard totalPreTrainTime > 0 else {
            // Default position if times are zero, e.g., center or hide
            tflLogoImageView.isHidden = true // Or set a default centerX constraint
            print("Warning: totalPreTrainTime is zero, cannot calculate stationPositionRatio accurately.")
            return
        }
        tflLogoImageView.isHidden = false
        stationPositionRatio = CGFloat(walkToStationTimeSec / totalPreTrainTime)


        let startPadding: CGFloat = 4 // From leading of progressBarBackground to where personDot can start
        let tflLogoWidth: CGFloat = 22
        // Effective widths of start/end icons for calculation
        let personDotEffectiveWidth = personDot.intrinsicContentSize.width > 0 ? personDot.intrinsicContentSize.width : 28
        let platformEmojiEffectiveWidth = platformEmoji.intrinsicContentSize.width > 0 ? platformEmoji.intrinsicContentSize.width : 22
        let platformEmojiTrailingPadding: CGFloat = 8

        // This is the width available for the *center* of the personDot to travel
        let travelableWidthForPersonDotCenter = progressBarBackground.bounds.width - startPadding - (personDotEffectiveWidth / 2) - (platformEmojiEffectiveWidth / 2) - platformEmojiTrailingPadding
        
        // Position TfL logo's center relative to the start of this travelable width
        let logoCenterOffsetWithinTravelable = travelableWidthForPersonDotCenter * stationPositionRatio

        NSLayoutConstraint.activate([
            tflLogoImageView.centerYAnchor.constraint(equalTo: progressBarBackground.centerYAnchor),
            tflLogoImageView.centerXAnchor.constraint(equalTo: progressBarBackground.leadingAnchor, constant: startPadding + (personDotEffectiveWidth / 2) + logoCenterOffsetWithinTravelable),
            tflLogoImageView.widthAnchor.constraint(equalToConstant: tflLogoWidth),
            tflLogoImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
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
    
    private func setupProgressService() {
        // Ensure userOriginLocation is available if your service needs it for the initial walk.
        // It might be set from a previous screen or fetched here.
        // For now, we assume it's either set or JourneyProgressService can handle it being nil.

        guard let firstTransitInfo = transitInfos.first,
              let departureStationName = firstTransitInfo.departureStation,
              let stationData = stationCoordinates[departureStationName]
        else {
            print("Error: Cannot setup ProgressService - missing transit info (departureStation) or stationCoordinates for \(transitInfos.first?.departureStation ?? "Unknown Station").")
            deltaTimeLabel.text = "Route data incomplete."
            deltaTimeLabel.textColor = .systemRed
            return
        }
        
        let stationLocationForService = CLLocation(latitude: stationData.latitude, longitude: stationData.longitude)

        // Make sure nextTrainArrivalDate is correctly set for the *first* train the user is aiming for.
        // This might come from CatchInfo.fetchCatchInfos or another source.
        // If `transitInfos` has multiple legs, `nextTrainArrivalDate` should correspond to the *first relevant train*.
        
        let service = JourneyProgressService(
            walkToStationSec: walkToStationTimeSec,
            stationToPlatformSec: stationToPlatformTimeSec,
            transferTimesSec: transferTimesSec, // Ensure this is correctly populated
            trainArrival: nextTrainArrivalDate, // CRITICAL: This date is what the service tracks against
            originLocation: userOriginLocation, // Can be nil if service handles it
            stationLocation: stationLocationForService
        )
        service.delegate = self
        service.start() // This will begin delegate callbacks
        self.progressService = service
    }
    
    // MARK: - Summary Content & Animations
    private func populateSummary() {
        // Check if stationCoordinates are loaded before setting up progress service
        guard !stationCoordinates.isEmpty else {
            print("[RouteSummaryVC] stationCoordinates not loaded yet. Delaying populateSummary.")
            // Consider adding an observer or re-calling this method when stationCoordinates are set.
            // For now, we'll let the error label appear.
            // addErrorLabel("Station data not available.", to: stackView)
            return
        }

        // Setup progress service ONLY after station data is loaded
        setupProgressService()

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var viewsToAdd: [UIView] = []

        if let walkStartText = walkToStationTime, !walkStartText.isEmpty {
            viewsToAdd.append(makeCard(title: "🚶 Walk to Station", subtitle: walkStartText))
        }
        
        for (index, transitLegInfo) in transitInfos.enumerated() {
            viewsToAdd.append(makeCard(title: "🚉 Station to Platform", subtitle: "Approx. 2 minutes"))

            let catchSectionView = UIStackView()
            catchSectionView.axis = .vertical
            catchSectionView.spacing = 10
            
            let catchTitleLabel = UILabel()
            catchTitleLabel.text = "🚦 Next Available Trains"
            catchTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
            catchTitleLabel.textColor = AppColors.accentBlue
            catchSectionView.addArrangedSubview(catchTitleLabel)
            
            let catchTrainCard = makeCard(customView: catchSectionView, internalPadding: 12)
            viewsToAdd.append(catchTrainCard)
            
            // Ensure lineName and departureStation are not nil before proceeding
            guard let departureStationName = transitLegInfo.departureStation else {
                 let errorLabel = UILabel()
                 errorLabel.text = "Train line/station info missing."
                 errorLabel.font = .systemFont(ofSize: 14); errorLabel.textColor = .secondaryLabel
                 catchSectionView.addArrangedSubview(errorLabel)
                 // Add an error label or handle the missing info gracefully
                 continue // Skip this transit leg if info is missing
             }

            let lineName = transitLegInfo.lineName
            let timeNeededAtStationToReachPlatformSec: Double = self.stationToPlatformTimeSec
            
            // 1. Resolve Station ID
            TfLDataService.shared.resolveStationId(for: departureStationName) { [weak self, weak catchSectionView, weak catchTrainCard] stationNaptanId in
                guard let self = self, let naptanId = stationNaptanId, let strongCatchSectionView = catchSectionView else {
                    DispatchQueue.main.async {
                        self?.addErrorLabel("Station ID not found for \(departureStationName).", to: catchSectionView)
                        catchTrainCard?.layoutIfNeeded()
                    }
                    return
                }

                guard let lineId = RouteLogic.shared.tflLineId(from: lineName) else {
                     DispatchQueue.main.async {
                        self.addErrorLabel("Line ID not found for \(lineName).", to: strongCatchSectionView)
                        catchTrainCard?.layoutIfNeeded()
                    }
                    return
                }
                
                // 2. Fetch Arrivals
                TfLDataService.shared.fetchTrainArrivals(lineId: lineId, stationNaptanId: naptanId) { result in
                    DispatchQueue.main.async {
                        // Clear previous rows (except title) before adding new ones
                        strongCatchSectionView.arrangedSubviews.filter { !($0 is UILabel && ($0 as? UILabel)?.text == catchTitleLabel.text) }.forEach { $0.removeFromSuperview() }

                        switch result {
                        case .success(let tflPredictions):
                            if tflPredictions.isEmpty {
                                self.addErrorLabel("No upcoming train data available.", to: strongCatchSectionView)
                            } else {
                                let now = Date()
                                var catchInfos: [CatchInfo] = []
                                for prediction in tflPredictions {
                                    // Use the expectedArrivalDate from the prediction which is already parsed
                                    let secondsUntilTrainArrival = prediction.expectedArrival.timeIntervalSince(now)
                                    let timeLeftToCatch = secondsUntilTrainArrival - timeNeededAtStationToReachPlatformSec
                                    let status = CatchInfo.determineInitialCatchStatus(timeLeftToCatch: timeLeftToCatch)
                                    
                                    let catchInfo = CatchInfo(
                                        timeToStation: timeNeededAtStationToReachPlatformSec,
                                        // Use the formatted expectedArrival string directly from CatchInfo
                                        expectedArrival: RouteSummaryViewController.shortTimeFormatter.string(from: prediction.expectedArrival),
                                        expectedArrivalDate: prediction.expectedArrival,
                                        timeLeftToCatch: timeLeftToCatch,
                                        catchStatus: status
                                    )
                                    catchInfos.append(catchInfo)
                                }

                                let relevantCatchInfos = catchInfos.filter { $0.catchStatus != .missed }.sorted { $0.expectedArrivalDate < $1.expectedArrivalDate }
                                var top3 = Array(relevantCatchInfos.prefix(3))
                                if top3.isEmpty && !catchInfos.isEmpty {
                                     top3 = Array(catchInfos.sorted { $0.expectedArrivalDate < $1.expectedArrivalDate }.prefix(3))
                                }

                                // CRITICAL: Update nextTrainArrivalDate for the JourneyProgressService
                                // This should be done for the first leg (index == 0)
                                if index == 0 {
                                    if let firstTrainToAimFor = top3.first(where: { $0.catchStatus != .missed }) ?? top3.first {
                                        self.nextTrainArrivalDate = firstTrainToAimFor.expectedArrivalDate
                                        print("[RouteSummaryVC] Updated nextTrainArrivalDate for tracking: \(self.nextTrainArrivalDate)")
                                        // If progressService is already running and you want to update its target:
                                        // self.progressService?.updateTargetTrainArrival(self.nextTrainArrivalDate) // (Method needs to exist in service)
                                        // Or, ensure setupProgressService is called *after* this is set.
                                        self.setupProgressService() // Call setupProgressService after nextTrainArrivalDate is set for the first leg
                                    } else {
                                        print("[RouteSummaryVC] No valid trains to set nextTrainArrivalDate for index 0.")
                                        // Handle case where there are no trains at all for the first leg.
                                        // Perhaps JourneyProgressService should not start, or show a specific message.
                                    }
                                }

                                var animatedRows: [UIView] = []
                                for singleCatchInfo in top3 {
                                    // Use the formatted expectedArrival string directly from CatchInfo
                                    let row = CatchInfoRowView(info: singleCatchInfo) // Assumes CatchInfoRowView is correctly implemented
                                    row.alpha = 0
                                    strongCatchSectionView.addArrangedSubview(row)
                                    animatedRows.append(row)
                                }
                                
                                UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
                                    catchTrainCard?.layoutIfNeeded()
                                })
                                for (rowIndex, rowView) in animatedRows.enumerated() {
                                    UIView.animate(withDuration: 0.3, delay: 0.1 + Double(rowIndex) * 0.08, options: .curveEaseOut, animations: {
                                        rowView.alpha = 1
                                    })
                                }
                            }
                        case .failure(let error):
                            print("[RouteSummaryVC] Error fetching train arrivals for \(lineName) at \(departureStationName): \(error.localizedDescription)")
                            self.addErrorLabel("Could not load train times.", to: strongCatchSectionView)
                        }
                        catchTrainCard?.layoutIfNeeded()
                    }
                }
            }
            
            // Check for transfer leg and add transfer card if necessary
            if index < transitInfos.count - 1 {
                 viewsToAdd.append(makeCard(title: "🚶‍♀️ Transfer", subtitle: "Est. Transfer Time")) // Placeholder subtitle
             }
             
            viewsToAdd.append(makeTransitCard(info: transitLegInfo, isTransfer: index > 0))
            


        }
        
        if let walkEndText = walkToDestinationTime, !walkEndText.isEmpty {
            viewsToAdd.append(makeCard(title: "🏁 Walk to Destination", subtitle: walkEndText))
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
        // ... (implementation from previous response, using .systemBackground and .label/.secondaryLabel for text) ...
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        
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
    
    private func makeTransitCard(info: TransitInfo, isTransfer: Bool) -> UIView {
        // ... (implementation from previous response, using .systemBackground and adaptive text colors) ...
        // This is the version with the accent bar.
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.translatesAutoresizingMaskIntoConstraints = false

        let accentColor = UIColor(hex: info.lineColorHex ?? "#007AFF")

        let accentBar = UIView()
        accentBar.backgroundColor = accentColor
        accentBar.layer.cornerRadius = 3
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accentBar)

        let timeline = TimelineView() // Ensure TimelineView is defined
        timeline.lineColor = UIColor.systemGray3 // Adjusted for better visibility on systemBackground
        timeline.translatesAutoresizingMaskIntoConstraints = false
        
        let lineBadgeLabel = PaddingLabel() // Ensure PaddingLabel is defined
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
        startLabel.tag = 999
        // stopLabelMap[info.departureStation ?? ""] = startLabel // Uncomment if stopLabelMap is used

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
        let stops = info.stopNames ?? []
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
        // stopLabelMap[info.arrivalStation ?? ""] = endLabel // Uncomment if stopLabelMap is used

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

    // MARK: - Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Pass location to JourneyProgressService. It should handle the logic.
        // Make sure JourneyProgressService has a method like this:
        // self.progressService?.updateUserLocation(location)
        // This method in JourneyProgressService would then recalculate predicted times and CatchStatus.
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
}

// MARK: - JourneyProgressDelegate Extension
extension RouteSummaryViewController: JourneyProgressDelegate {
    func journeyProgressDidUpdate(
        overallProgress: Double,
        phaseProgress: Double,
        currentCatchStatus: CatchStatus,
        delta: TimeInterval, // This is time_until_train_arrival_at_platform
        uncertainty: TimeInterval,
        phase: ProgressPhase
    ) {
        // --- Update Main Progress Bar (Person Dot) ---
        let clampedOverallProgress = min(max(overallProgress, 0), 1)
        if progressBarBackground.bounds.width > 0 { // Ensure layout has occurred
            let startPadding: CGFloat = 4
            let personDotEffectiveWidth = personDot.intrinsicContentSize.width > 0 ? personDot.intrinsicContentSize.width : 28
            let platformEmojiEffectiveWidth = platformEmoji.intrinsicContentSize.width > 0 ? platformEmoji.intrinsicContentSize.width : 22
            let platformEmojiTrailingPadding: CGFloat = 8
            
            let availableWidthForDotTravel = progressBarBackground.bounds.width - startPadding - personDotEffectiveWidth - platformEmojiTrailingPadding - platformEmojiEffectiveWidth
            
            let leadingConstant = startPadding + (availableWidthForDotTravel * CGFloat(clampedOverallProgress))
            personDotLeadingConstraint?.constant = leadingConstant
        }

        // --- Visual Cue for Reaching Station on Progress Bar ---
        if clampedOverallProgress >= stationPositionRatio &&
           !self.hasReachedStationVisualCue &&
           phase == .walkToStation && // Only cue during the walk
           stationPositionRatio > 0 && stationPositionRatio < 1 { // Ensure ratio is valid
            
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
        
        // Animate Progress Bar Dot Movement
        if self.progressBarBackground.window != nil { // Only animate if view is visible
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: {
                self.progressBarBackground.layoutIfNeeded()
            })
        } else {
            self.progressBarBackground.layoutIfNeeded() // Update immediately if not visible
        }
        
        // --- Update Delta Time Label with Catch Status ---
        let timeText = String(format: "%.0fs", abs(delta)) // Use absolute for display, status indicates if late
        let uncertaintyText = String(format: "±%.0fs", uncertainty)
        
        let statusString: String
        if currentCatchStatus == .easy || currentCatchStatus == .hurry {
            statusString = "\(currentCatchStatus.displayText) · \(timeText) buffer"
        } else if currentCatchStatus == .tough {
            statusString = "\(currentCatchStatus.displayText) · \(timeText) \(delta < 0 ? "late" : "left")"
        } else { // MISSED
            statusString = "\(currentCatchStatus.displayText) · by \(timeText)"
        }

        let fullText = "\(statusString) (\(uncertaintyText))"
        
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // Apply color to the whole string first
        attributedString.addAttribute(.foregroundColor, value: currentCatchStatus.displayColor, range: NSRange(location: 0, length: attributedString.length))
        
        // Optionally, add icon
        if let iconName = currentCatchStatus.systemIconName, let iconImage = UIImage(systemName: iconName) {
            let imageAttachment = NSTextAttachment()
            let tintedImage = iconImage.withTintColor(currentCatchStatus.displayColor, renderingMode: .alwaysOriginal)
            imageAttachment.image = tintedImage
            let imageSize = deltaTimeLabel.font.pointSize
            imageAttachment.bounds = CGRect(x: 0, y: -2, width: imageSize, height: imageSize) // Adjust y for vertical alignment
            
            let imageAttrString = NSAttributedString(attachment: imageAttachment)
            attributedString.insert(imageAttrString, at: 0)
            attributedString.insert(NSAttributedString(string: " "), at: 1) // Space after icon
        }
        deltaTimeLabel.attributedText = attributedString

        // --- Haptic Feedback for Significant Status Changes ---
        if let previousStatus = previousCatchStatus, previousStatus != currentCatchStatus {
            // Only provide haptic if it's a significant improvement or degradation
            let improvement = (previousStatus == .tough && (currentCatchStatus == .hurry || currentCatchStatus == .easy)) ||
                              (previousStatus == .hurry && currentCatchStatus == .easy)
            let degradation = (previousStatus == .easy && (currentCatchStatus == .hurry || currentCatchStatus == .tough)) ||
                              (previousStatus == .hurry && currentCatchStatus == .tough) ||
                              (previousStatus != .missed && currentCatchStatus == .missed) // Becoming missed

            if improvement {
                let feedbackGenerator = UINotificationFeedbackGenerator()
                feedbackGenerator.prepare()
                feedbackGenerator.notificationOccurred(.success)
            } else if degradation {
                let feedbackGenerator = UINotificationFeedbackGenerator()
                feedbackGenerator.prepare()
                feedbackGenerator.notificationOccurred(.warning)
            }
        }
        self.previousCatchStatus = currentCatchStatus
    }
    
    func journeyPhaseDidChange(_ phase: ProgressPhase) {
        print("RouteSummaryVC: Journey phase changed to: \(phase)")
        if phase == .walkToStation {
            self.hasReachedStationVisualCue = false // Reset for next walk segment if any
            self.previousCatchStatus = nil // Reset for haptics
            if CLLocationManager.locationServicesEnabled() {
                switch locationManager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    locationManager.startUpdatingLocation()
                    print("Location updates started for walkToStation phase.")
                default:
                    print("Location access not granted, cannot start updates for walkToStation.")
                }
            }
        } else {
            locationManager.stopUpdatingLocation() // Stop GPS if not in a walking phase that needs it
            print("Location updates stopped for phase: \(phase).")
        }
        
        // TODO: Implement highlighting of the current journey segment card in the stackView
        // This would involve:
        // 1. Identifying which card in `stackView.arrangedSubviews` corresponds to the current `phase`.
        // 2. Animating visual changes (e.g., scale, shadow, border) to highlight it and de-highlight others.
    }
}

// MARK: - Timeline View (Keep as is)
class TimelineView: UIView {
    var lineColor: UIColor = .white {
        didSet { setNeedsDisplay() }
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

// MARK: - Color Extension (Keep as is)
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    var isLight: Bool {
        guard let components = cgColor.components, components.count >= 3 else { return false }
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5
    }
}

// MARK: - PaddingLabel (Keep as is)
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
