import Foundation

struct TfLArrivalPrediction {
    let id: String? // Prediction ID
    let stationName: String?
    let lineId: String?
    let lineName: String?
    let platformName: String?
    let destinationName: String?
    let expectedArrival: Date // Already parsed Date
    let timeToStation: TimeInterval // Seconds until it reaches the station (naptanId)
}


class TfLDataService {
    static let shared = TfLDataService()
    private init() {
        fetchAllTubeStationIds { }
    }

    private var stationIdMap: [String: String] = [:] // Cache for station names to NaptanIDs
    private let isoFormatter: ISO8601DateFormatter = { // Robust ISO8601 parser
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        return formatter
    }()
    private let legacyDateFormatter: DateFormatter = { // Fallback for slightly different date formats
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // Common TfL format without fractional seconds
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Assume UTC if not specified by Z
        return formatter
    }()

    // fetch avaliable lines for the user depature station
    func fetchAvailableLines(for naptanId: String, completion: @escaping ([String]) -> Void) {
        let urlStr = "https://api.tfl.gov.uk/StopPoint/\(naptanId)"
        guard let url = URL(string: urlStr) else { completion([]); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var result: [String] = []
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lines = json["lines"] as? [[String: Any]] {
                for line in lines {
                    if let id = line["id"] as? String {
                        result.append(id)
                    }
                }
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
    
    func fetchAllArrivals(for naptanId: String, completion: @escaping ([TfLArrivalPrediction]) -> Void) {
        fetchAvailableLines(for: naptanId) { lineIds in
            let group = DispatchGroup()
            var allArrivals: [TfLArrivalPrediction] = []
            for lineId in lineIds {
                group.enter()
                TfLDataService.shared.fetchTrainArrivals(lineId: lineId, stationNaptanId: naptanId) { result in
                    if case .success(let arrivals) = result {
                        allArrivals.append(contentsOf: arrivals)
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion(allArrivals)
            }
        }
    }
    
    
    func fetchAllTubeStationIds(completion: @escaping () -> Void) {
        let urlStr = "https://api.tfl.gov.uk/StopPoint/Mode/tube"
        guard let url = URL(string: urlStr) else { completion(); return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { completion(); return }
            var dict: [String: String] = [:]
            if let error = error {
                print("[TfLDataService] Error fetching all station IDs: \(error.localizedDescription)")
                completion(); return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stops = json["stopPoints"] as? [[String: Any]] else {
                print("[TfLDataService] Failed to parse all station IDs JSON.")
                completion(); return
            }
            for stop in stops {
                if let name = stop["commonName"] as? String,
                   let id = stop["naptanId"] as? String { // Use naptanId for arrivals
                    dict[name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] = id // Store lowercased for easier lookup
                }
            }
            self.stationIdMap = dict
            print("[TfLDataService] TfL StationIdMap Loaded, count = \(dict.count)")
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    

    // Enhanced tflStationId: Uses pre-fetched map, can be extended with API search later if needed.
    func resolveStationId(for stationName: String, completion: @escaping (String?) -> Void) {
        let cleanedName = stationName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Try exact match from pre-fetched map
        if let id = self.stationIdMap[cleanedName] {
            print("[TfLDataService] Found station ID in cache for '\(stationName)': \(id)")
            completion(id)
            return
        }
        
        // 2. Try fuzzy match from pre-fetched map (your existing logic)
        for (key, value) in self.stationIdMap {
            if key.contains(cleanedName) { // commonName might be "Oxford Circus Underground Station"
                print("[TfLDataService] Found station ID via fuzzy cache match for '\(stationName)': \(value)")
                completion(value)
                return
            }
        }

        // 3. OPTIONAL Fallback: API Search (similar to your StationIdResolver)
        // This makes an extra API call if not found in the pre-fetched list.
        print("[TfLDataService] Station ID for '\(stationName)' not in cache, attempting API search...")
        let query = stationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stationName
        let searchUrlStr = "https://api.tfl.gov.uk/StopPoint/Search?query=\(query)&modes=tube&app_key=\(APIKeys.tflAppKey)"
        guard let searchUrl = URL(string: searchUrlStr) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: searchUrl) { [weak self] data, _, error in
            guard let self = self else { completion(nil); return }
            if let error = error {
                print("[TfLDataService] Station search API error for '\(stationName)': \(error.localizedDescription)")
                completion(nil); return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let matches = json["matches"] as? [[String: Any]],
                  let firstMatch = matches.first,
                  let id = firstMatch["id"] as? String else { // TfL search often returns 'id' which might be Naptan or other
                print("[TfLDataService] Could not find station ID via API search for '\(stationName)' or parse result.")
                completion(nil)
                return
            }
            print("[TfLDataService] Found station ID via API search for '\(stationName)': \(id). Caching it.")
            // Cache this result (Naptan ID is usually preferred for arrivals, check what 'id' is here)
            // The search might return a different type of ID than naptanId. Be careful.
            // For arrivals, you need the Naptan ID. The search endpoint might give a StopPoint ID.
            // You might need to adjust based on what the search actually returns or stick to your pre-fetched naptanId list.
            // For now, let's assume the 'id' from search is usable, but verify this.
            // If the search returns 'naptanId', use that.
            let naptanId = firstMatch["naptanId"] as? String ?? id // Prefer naptanId
            self.stationIdMap[cleanedName] = naptanId // Cache it
            completion(naptanId)
        }.resume()
    }


   
    func fetchTrainArrivals(
        lineId: String,
        stationNaptanId: String,
        completion: @escaping (Result<[TfLArrivalPrediction], Error>) -> Void
    ) {
        let urlStr = "https://api.tfl.gov.uk/Line/\(lineId)/Arrivals/\(stationNaptanId)?app_key=\(APIKeys.tflAppKey)"
        guard let url = URL(string: urlStr) else {
            completion(.failure(NSError(domain: "TfLDataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        print("[TfLDataService] Fetching arrivals from: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("[TfLDataService] API Error fetching arrivals: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "TfLDataService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data from API"])))
                return
            }
            if let raw = String(data: data, encoding: .utf8) {
                 print("[TfLDataService] Raw Arrivals API Response: \(raw.prefix(500)) ...")
            }

            do {
                let arrivalsJSON = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                guard let arrivalsArray = arrivalsJSON else {
                    print("[TfLDataService] Failed to parse arrivals JSON into array.")
                    completion(.failure(NSError(domain: "TfLDataService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON array"])))
                    return
                }
                
                var predictions: [TfLArrivalPrediction] = []
                for dict in arrivalsArray {
                    guard let expectedArrivalStr = dict["expectedArrival"] as? String else {
                        print("[TfLDataService] Skipped arrival: Missing expectedArrival string.")
                        continue
                    }
                    
                    // Try robust ISO8601 parsing first, then fallback
                    let arrivalDate = self.isoFormatter.date(from: expectedArrivalStr) ?? self.legacyDateFormatter.date(from: expectedArrivalStr)

                    guard let finalArrivalDate = arrivalDate else {
                        print("[TfLDataService] Skipped arrival: Could not parse date '\(expectedArrivalStr)'")
                        continue
                    }
                    
                    let prediction = TfLArrivalPrediction(
                        id: dict["id"] as? String,
                        stationName: dict["stationName"] as? String,
                        lineId: dict["lineId"] as? String,
                        lineName: dict["lineName"] as? String,
                        platformName: dict["platformName"] as? String,
                        destinationName: dict["destinationName"] as? String,
                        expectedArrival: finalArrivalDate,
                        timeToStation: (dict["timeToStation"] as? TimeInterval) ?? 0 // In seconds
                    )
                    predictions.append(prediction)
                }
                print("[TfLDataService] Successfully parsed \(predictions.count) arrival predictions.")
                completion(.success(predictions))
            } catch {
                print("[TfLDataService] JSON Deserialization Error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
}
