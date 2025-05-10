import Foundation
import CoreLocation
import GoogleMaps


public final class RouteLogic {
        static let shared = RouteLogic()
        private init() {}
        
        func fetchRoute(from: CLLocationCoordinate2D,
                        to: CLLocationCoordinate2D,
                        speedMultiplier: Double,
                        completion: @escaping (_ walkSteps: [WalkStep], _ transitInfos: [TransitInfo], _ adjustedTime: Double, _ stepsRaw: [[String: Any]]) -> Void) {
            
            let urlStr = "https://maps.googleapis.com/maps/api/directions/json?origin=\(from.latitude),\(from.longitude)&destination=\(to.latitude),\(to.longitude)&mode=transit&transit_mode=subway|train&region=uk&key=AIzaSyDbJBDCkUpNgE2nb0yz8J454wGgvaZggSE"
            guard let url = URL(string: urlStr) else { return }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let routes = json["routes"] as? [[String: Any]],
                      let legs = routes.first?["legs"] as? [[String: Any]],
                      let steps = legs.first?["steps"] as? [[String: Any]] else {
                    print("❌ Failed to parse Google Directions API response")
                    return
                }
                
                let (walkMin, transitMin, walkSteps, segments) = self.calculateRouteTimes(from: steps)
                let adjustedTime = (walkMin / speedMultiplier) + transitMin
                
                let group = DispatchGroup()
                var updatedSegments = segments
                
                for (index, seg) in segments.enumerated() {
                    group.enter()
                    self.fetchStopNames(for: seg) { updated in
                        updatedSegments[index] = updated
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(walkSteps, updatedSegments, adjustedTime, steps)
                }
            }.resume()
        }
        
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
                        let info = TransitInfo(
                            lineName: shortName,
                            departureStation: dep["name"] as? String ?? "-",
                            arrivalStation: arr["name"] as? String ?? "-",
                            durationText: durationText,
                            platform: td["departure_platform"] as? String,
                            crowdLevel: td["crowd_level"] as? String,
                            numStops: td["num_stops"] as? Int,
                            lineColorHex: line["color"] as? String
                        )
                        transitInfos.append(info)
                    }
                }
            }
            return (walkMin, transitMin, walkSteps, transitInfos)
        }
        
        func fetchStopNames(for transit: TransitInfo, completion: @escaping (TransitInfo) -> Void) {
            if let lineId = RouteLogic.shared.tflLineId(from: transit.lineName),
               let url = URL(string: "https://api.tfl.gov.uk/Line/\(lineId)/Route/Sequence/inbound") {
                
                var request = URLRequest(url: url)
                request.setValue("0bc9522b0b77427eb20e858550d6a072", forHTTPHeaderField: "app_key")
                
                URLSession.shared.dataTask(with: request) { data, _, _ in
                    guard let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let sequences = json["stopPointSequences"] as? [[String: Any]],
                          let stops = sequences.first?["stopPoint"] as? [[String: Any]] else {
                        DispatchQueue.main.async { completion(transit) }
                        return
                    }
                    
                    let names = stops.compactMap { $0["name"] as? String }
                    
                    if let start = names.firstIndex(where: { $0.contains(transit.departureStation) }),
                       let end = names.firstIndex(where: { $0.contains(transit.arrivalStation) }) {
                        let sliced = names[min(start, end)...max(start, end)]
                        var updated = transit
                        updated.stopNames = Array(sliced)
                        DispatchQueue.main.async { completion(updated) }
                    } else {
                        var fallback = transit
                        fallback.stopNames = [transit.departureStation, transit.arrivalStation]
                        DispatchQueue.main.async { completion(fallback) }
                    }
                }.resume()
            } else {
                var fallback = transit
                fallback.stopNames = [transit.departureStation, transit.arrivalStation]
                DispatchQueue.main.async { completion(fallback) }
            }
        }
        
        func tflLineId(from lineName: String) -> String? {
            let mapping: [String: String] = [
                "Bakerloo": "bakerloo",
                "Central": "central",
                "Circle": "circle",
                "District": "district",
                "Hammersmith & City": "hammersmith-city",
                "Jubilee": "jubilee",
                "Metropolitan": "metropolitan",
                "Northern": "northern",
                "Piccadilly": "piccadilly",
                "Victoria": "victoria",
                "Waterloo & City": "waterloo-city",
                "London Overground": "london-overground",
                "Elizabeth": "elizabeth",
                "Elizabeth line": "elizabeth",
                "TfL Rail": "elizabeth",
                "DLR": "dlr",
                "Tram": "tram"
            ]
            
            if let id = mapping[lineName] {
                return id
            }
            let lowercasedName = lineName.lowercased()
            for (key, value) in mapping {
                if key.lowercased() == lowercasedName {
                    return value
                }
            }
            return nil
        }
    
    func navigateToSummary(from viewController: UIViewController, transitInfos: [TransitInfo], walkSteps: [WalkStep], estimated: String?) {
        let summaryVC = RouteSummaryViewController()
        summaryVC.totalEstimatedTime = estimated
        summaryVC.walkToStationTime = walkSteps.first?.durationText
        summaryVC.walkToDestinationTime = walkSteps.last?.durationText
        summaryVC.transitInfos = transitInfos
        viewController.navigationController?.pushViewController(summaryVC, animated: true)
    }
}

