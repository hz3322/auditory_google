import Foundation
import CoreLocation
import GoogleMaps

/// Handles the core route fetching and processing logic.
/// Acts as a singleton for easy access throughout the app.
public final class RouteLogic {
    static let shared = RouteLogic()
    private init() {}
    
    // MARK: - Properties
    
    /// Dictionary to store station coordinates by name.
    var stationCoordinates: [String: CLLocationCoordinate2D] = [:]
    /// Dictionary to store station metadata by name.
    var stationsDict: [String: StationMeta] = [:]
    
    // MARK: - Route Fetching
    
    func fetchRoute(
        from userLocation: CLLocation,
        to destinationCoord: CLLocationCoordinate2D,
        completion: @escaping (
            _ walkSteps: [WalkStep],
            _ transitSegments: [TransitInfo],
            _ totalTime: Double,
            _ routeSteps: [[String: Any]],
            _ walkToStationMin: Double,
            _ walkToDestinationMin: Double
        ) -> Void
    ) {
        TfLDataService.shared.loadAllTubeStations { stationsDict in
            guard let nearestStationName = TfLDataService.shared.findNearestStation(to: userLocation, from: stationsDict),
                  let nearestStationCoord = stationsDict[nearestStationName] else {
                completion([], [], 0.0, [], 0.0, 0.0)
                return
            }
            
            // First fetch weather to get speed factor
            WeatherService.shared.fetchCurrentWeather(at: userLocation.coordinate) { condition, suggestion, gradient in
                // Get the speed factor from the weather condition
                var speedFactor = WeatherCondition.from(weatherId: 800).speedFactor // Default to clear weather
                if let weatherCondition = WeatherCondition(rawValue: condition) {
                    speedFactor = weatherCondition.speedFactor
                }
                
                GoogleMapsService.shared.fetchTransitRoute(
                    from: userLocation.coordinate,
                    to: destinationCoord
                ) { result in
                    switch result {
                    case .success(let steps):
                        let (_, transitMin, walkSteps, segments) = self.calculateRouteTimes(from: steps)
                        let transitSteps = steps.filter { $0["travel_mode"] as? String == "TRANSIT" }
                        var updatedSegments = segments
                        
                        // Use a DispatchGroup to wait for asynchronous tasks
                        let group = DispatchGroup()
                        
                        // Variables to hold calculated walking times
                        var entryWalkMin: Double? = nil
                        var exitWalkMin: Double? = nil
                        
                        let depCoord = nearestStationCoord.coord
                        let arrCoord = segments.last?.arrivalCoordinate ?? destinationCoord
                        
                        let dispatch = DispatchGroup()
                        dispatch.enter()
                        GoogleMapsService.shared.fetchWalkingTime(from: userLocation.coordinate, to: depCoord) { result in
                            // Apply weather speed factor to walking time
                            if let walkingTime = result {
                                entryWalkMin = walkingTime / speedFactor
                            }
                            dispatch.leave()
                        }
                        
                        dispatch.enter()
                        GoogleMapsService.shared.fetchWalkingTime(from: arrCoord, to: destinationCoord) { result in
                            // Apply weather speed factor to walking time
                            if let walkingTime = result {
                                exitWalkMin = walkingTime / speedFactor
                            }
                            dispatch.leave()
                        }
                        
                        for (index, seg) in segments.enumerated() {
                            guard index < transitSteps.count,
                                  let startCoord = GoogleMapsService.shared.extractCoordinate(from: transitSteps[index], key: "start_location"),
                                  let endCoord = GoogleMapsService.shared.extractCoordinate(from: transitSteps[index], key: "end_location") else {
                                continue
                            }
                            
                            updatedSegments[index].arrivalCoordinate = endCoord
                            
                            group.enter()
                            TfLDataService.shared.fetchJourneyPlannerStops(fromCoord: startCoord, toCoord: endCoord) { stops in
                                var updated = seg
                                
                                if stops.contains(where: { $0.lowercased().contains("bus") }) {
                                    updated.stopNames = []
                                    updated.numStops = 0
                                    group.leave()
                                    return
                                }
                                
                                if index == 0 {
                                    var extended = stops
                                    if let first = stops.first, first != seg.departureStation {
                                        extended.insert(seg.departureStation ?? "-", at: 0)
                                    }
                                    updated.stopNames = extended
                                    updated.departureStation = extended.first
                                    updated.arrivalStation = extended.last
                                } else {
                                    if stops.isEmpty {
                                        updated.stopNames = [updatedSegments[index - 1].arrivalStation ?? "-", seg.arrivalStation ?? "-"]
                                    } else {
                                        updated.stopNames = stops
                                        if updatedSegments[index - 1].arrivalStation != nil {
                                            updated.stopNames.insert(updatedSegments[index - 1].arrivalStation!, at: 0)
                                        }
                                    }
                                    updated.departureStation = updated.stopNames.first
                                    updated.arrivalStation = updated.stopNames.last
                                }
                                
                                updated.numStops = max(0, updated.stopNames.count - 1)
                                
                                if let times = updated.durationText?.components(separatedBy: " -"), times.count == 2 {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "HH:mm"
                                    if let start = formatter.date(from: times[0]), let end = formatter.date(from: times[1]) {
                                        let minutes = Int(end.timeIntervalSince(start) / 60)
                                        updated.durationTime = "\(minutes) min"
                                    }
                                }
                                
                                updatedSegments[index] = updated
                                group.leave()
                            }
                        }
                        
                        dispatch.notify(queue: .main) {
                            print("Entry walking time (min):", entryWalkMin ?? -1)
                            print("Exit walking time (min):", exitWalkMin ?? -1)
                            
                            group.notify(queue: .main) {
                                let adjTime = (entryWalkMin ?? 0.0) + (exitWalkMin ?? 0.0) + transitMin
                                completion(
                                    walkSteps,
                                    updatedSegments,
                                    adjTime,
                                    steps,
                                    entryWalkMin ?? 0.0,
                                    exitWalkMin ?? 0.0
                                )
                            }
                        }
                        
                    case .failure(let error):
                        print("[RouteLogic] Failed to fetch route: \(error)")
                        completion([], [], 0.0, [], 0.0, 0.0)
                    }
                }
            }
        }
    }
    
    // MARK: - Route Processing
    
    /// Calculates total walking and transit times and extracts detailed step/transit information from raw route steps.
    ///
    /// - Parameter steps: The raw steps data from the routing API.
    /// - Returns: A tuple containing total walking time (minutes), total transit time (minutes), an array of WalkStep, and an array of TransitInfo.
    func calculateRouteTimes(from steps: [[String: Any]]) -> (Double, Double, [WalkStep], [TransitInfo]) {
        var walkMin = 0.0, transitMin = 0.0
        var walkSteps: [WalkStep] = []
        var transitInfos: [TransitInfo] = []
        
        for step in steps {
            guard let mode = step["travel_mode"] as? String else { continue }
            
            if mode == "WALKING" {
                if let sub = step["steps"] as? [[String: Any]] {
                    for s in sub {
                        if let d = s["duration"] as? [String: Any],
                           let dv = d["value"] as? Double,
                           let dt = d["text"] as? String,
                           let dist = s["distance"] as? [String: Any],
                           let distText = dist["text"] as? String,
                           let html = s["html_instructions"] as? String {
                            let cleaned = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            walkSteps.append(WalkStep(instruction: cleaned, distanceText: distText, durationText: dt))
                            walkMin += dv / 60.0
                        }
                    }
                }
            } else if mode == "TRANSIT" {
                if let d = step["duration"] as? [String: Any],
                   let value = d["value"] as? Double {
                    transitMin += value / 60.0
                }
                
                if let td = step["transit_details"] as? [String: Any],
                   let line = td["line"] as? [String: Any],
                   let shortName = line["short_name"] as? String ?? line["name"] as? String,
                   let dep = td["departure_stop"] as? [String: Any],
                   let arr = td["arrival_stop"] as? [String: Any],
                   let depTime = td["departure_time"] as? [String: Any],
                   let arrTime = td["arrival_time"] as? [String: Any] {
                    
                    let durationText = "\(depTime["text"] ?? "") - \(arrTime["text"] ?? "")"
                    let crowd = CrowdLevel(raw: td["crowd_level"] as? String)
                    let delayStatus = line["status"] as? String ?? line["status_description"] as? String
                    
                    let info = TransitInfo(
                        lineName: shortName,
                        departureStation: dep["name"] as? String ?? "-",
                        arrivalStation: arr["name"] as? String ?? "-",
                        durationText: durationText,
                        departurePlatform: td["departure_platform"] as? String,
                        arrivalPlatform: td["arrival_platform"] as? String,
                        departureCoordinate: GoogleMapsService.shared.extractCoordinate(from: step, key: "start_location"),
                        arrivalCoordinate: GoogleMapsService.shared.extractCoordinate(from: step, key: "end_location"),
                        crowdLevel: crowd,
                        numStops: td["num_stops"] as? Int,
                        lineColorHex: line["color"] as? String,
                        delayStatus: delayStatus
                    )
                    transitInfos.append(info)
                }
            }
        }
        return (walkMin, transitMin, walkSteps, transitInfos)
    }
    
    // MARK: - Navigation
    
    /// Navigates to the Route Summary screen with the calculated route details.
    /// It prepares the data and pushes the view controller onto the navigation stack.
    ///
    /// - Parameters:
    ///   - viewController: The view controller initiating the navigation.
    ///   - transitInfos: The calculated transit segments.
    ///   - walkSteps: The calculated walking steps.
    ///   - estimated: The total estimated time as a formatted string.
    ///   - walkToStationMin: Estimated walking time to the first station in minutes.
    ///   - walkToDestinationMin: Estimated walking time from the last station to the destination in minutes.
    ///   - currentWeather: The current weather condition.
    ///   - weatherSpeedFactor: The weather-adjusted speed factor.
    func navigateToSummary(
        from viewController: UIViewController,
        transitInfos: [TransitInfo],
        walkSteps: [WalkStep],
        estimated: String?,
        walkToStationMin: Double,
        walkToDestinationMin: Double,
        currentWeather: String?,
        weatherSpeedFactor: Double
    ) {
        let summaryVC = RouteSummaryViewController()
        summaryVC.totalEstimatedTime = estimated
        summaryVC.walkToStationTime = String(format: "%.0f min", walkToStationMin)
        summaryVC.walkToDestinationTime = String(format: "%.0f min", walkToDestinationMin)
        summaryVC.currentWeather = currentWeather
        summaryVC.weatherSpeedFactor = weatherSpeedFactor
        
        if let durationText = transitInfos.first?.durationText {
            let parts = durationText.components(separatedBy: " -")
            if parts.count == 2 {
                summaryVC.routeDepartureTime = parts[0]
                summaryVC.routeArrivalTime = parts[1]
            }
        }
        
        summaryVC.transitInfos = transitInfos
        viewController.navigationController?.pushViewController(summaryVC, animated: true)
    }
}

// MARK: - Data Models

/// Represents a single train arrival prediction returned by TfL API
// struct TfLArrivalPrediction {
//     let id: String?
//     let stationName: String?
//     let lineId: String?
//     let lineName: String?
//     let platformName: String?
//     let destinationName: String?
//     let expectedArrival: Date
//     let timeToStation: TimeInterval // Seconds until it reaches the station (naptanId)
// }

// /// Metadata for a single tube station
// struct StationMeta {
//     let id: String
//     let coord: CLLocationCoordinate2D
// }

// I will also remove the duplicate CrowdLevel definition.
// enum CrowdLevel: String, Codable {
//     case low = "Low"
//     case medium = "Medium"
//     case high = "High"
//     case unknown
    
//     init(raw: String?) {
//         guard let rawValue = raw else { self = .unknown; return }
//         self = CrowdLevel(rawValue: rawValue) ?? .unknown
//     }
// }

// I will also remove the duplicate WalkStep definition.
// struct WalkStep {
//     let instruction: String
//     let distanceText: String
//     let durationText: String
// }

// I will also remove the duplicate TransitInfo definition.
// struct TransitInfo: Equatable {
//     let lineName: String
//     let departureStation: String?
//     let arrivalStation: String?
//     let durationText: String
//     let departurePlatform: String?
//     let arrivalPlatform: String?
//     let departureCoordinate: CLLocationCoordinate2D
//     let arrivalCoordinate: CLLocationCoordinate2D
//     let crowdLevel: CrowdLevel
//     let numStops: Int?
//     let lineColorHex: String?
//     let delayStatus: String?
// }


