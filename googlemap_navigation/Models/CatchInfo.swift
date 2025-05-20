import Foundation


struct CatchInfo {
    let timeToStation: TimeInterval
    let expectedArrival: String
    let expectedArrivalDate: Date
    let canCatch: Bool
    let timeLeftToCatch: TimeInterval

    static func fetchCatchInfos(
        for info: TransitInfo,
        entryToPlatformSec: Double,
        completion: @escaping ([CatchInfo]) -> Void
    ) {
        print("[DEBUG] Requested line: \(info.lineName), station: \(info.departureStation ?? "nil")")
        guard let lineId = RouteLogic.shared.tflLineId(from: info.lineName),
              let departureStation = info.departureStation else {
            print("[DEBUG] Missing lineId or departureStation")
            completion([])
            return
        }

        // STEP 1: Resolve Station ID asynchronously!
        StationIdResolver.shared.tflStationId(from: departureStation) { stationId in
            guard let stationId = stationId else {
                print("[DEBUG] Could not resolve stationId for \(departureStation)")
                completion([])
                return
            }
            let urlStr = "https://api.tfl.gov.uk/Line/\(lineId)/Arrivals/\(stationId)?app_key=0bc9522b0b77427eb20e858550d6a072"
            guard let url = URL(string: urlStr) else {
                print("[DEBUG] Invalid URL: \(urlStr)")
                completion([])
                return
            }
            print("[DEBUG] TFL Arrivals URL: \(url.absoluteString)")

            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data else {
                    print("[DEBUG] No data from TFL API")
                    completion([])
                    return
                }
                if let raw = String(data: data, encoding: .utf8) {
                    print("[DEBUG] Raw API Response: \(raw.prefix(300)) ...")
                }
                guard let arrs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    print("[DEBUG] Failed to parse JSON")
                    completion([])
                    return
                }
                print("[DEBUG] Parsed \(arrs.count) arrival predictions from API.")
                let now = Date()
                let isoFormatter = ISO8601DateFormatter()
                var predictions: [CatchInfo] = []
                for dict in arrs {
                    guard let expectedArrivalStr = dict["expectedArrival"] as? String else {
                        print("[DEBUG] Skipped: No expectedArrival in \(dict)")
                        continue
                    }
                    guard let expectedArrivalDate = isoFormatter.date(from: expectedArrivalStr) else {
                        print("[DEBUG] Skipped: Could not parse date '\(expectedArrivalStr)'")
                        continue
                    }
                    let secondsUntil = expectedArrivalDate.timeIntervalSince(now)
                    let timeLeftToCatch = secondsUntil - entryToPlatformSec
                    let canCatch = timeLeftToCatch > 0
                    let expectedArrivalText = DateFormatter.shortTime.string(from: expectedArrivalDate)
                    print("[DEBUG] Train: arrival \(expectedArrivalText), secondsUntil \(Int(secondsUntil)), timeLeftToCatch \(Int(timeLeftToCatch)), canCatch \(canCatch)")
                    let catchInfo = CatchInfo(
                        timeToStation: entryToPlatformSec,
                        expectedArrival: expectedArrivalText,
                        expectedArrivalDate: expectedArrivalDate,
                        canCatch: canCatch,
                        timeLeftToCatch: timeLeftToCatch
                    )
                    predictions.append(catchInfo)
                }
                let catchable = predictions.filter { $0.canCatch }
                print("[DEBUG] Catchable train count: \(catchable.count)")
                let top3 = catchable.sorted { $0.expectedArrivalDate < $1.expectedArrivalDate }.prefix(3)
                if top3.isEmpty {
                    print("[DEBUG] No catchable trains found after filtering.")
                }
                DispatchQueue.main.async {
                    completion(Array(top3))
                }
            }.resume()
        }
    }
}

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()
}

class StationIdResolver {
    static let shared = StationIdResolver()
    private var cache: [String: String] = [:] // [lowercasedName: id]

    func tflStationId(from stationName: String, completion: @escaping (String?) -> Void) {
        let key = stationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let cachedId = cache[key] {
            completion(cachedId)
            return
        }
        let query = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let urlStr = "https://api.tfl.gov.uk/StopPoint/Search?query=\(query)&modes=tube"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let matches = json["matches"] as? [[String: Any]],
                let first = matches.first,
                let id = first["id"] as? String
            else {
                completion(nil)
                return
            }
            self.cache[key] = id
            completion(id)
        }.resume()
    }
}
