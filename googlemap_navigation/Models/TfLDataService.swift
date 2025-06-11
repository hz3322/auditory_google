import Foundation
import CoreLocation


// MARK: - Constants
private let baseURL = "https://api.tfl.gov.uk"
private let apiKey = APIKeys.tflAppKey

// MARK: - Error Types
enum TfLError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case noData
    case serverError(statusCode: Int)
}

// MARK: - Data Models

/// Represents a single train arrival prediction returned by TfL API
struct TfLArrivalPrediction: Decodable {
    let id: String?
    let stationName: String?
    let lineId: String?
    let lineName: String?
    let platformName: String?
    let destinationName: String?
    let expectedArrival: Date
    let timeToStation: TimeInterval // Seconds until it reaches the station (naptanId)
    
    enum CodingKeys: String, CodingKey {
        case id
        case stationName
        case lineId
        case lineName
        case platformName
        case destinationName
        case expectedArrival
        case timeToStation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        stationName = try container.decodeIfPresent(String.self, forKey: .stationName)
        lineId = try container.decodeIfPresent(String.self, forKey: .lineId)
        lineName = try container.decodeIfPresent(String.self, forKey: .lineName)
        platformName = try container.decodeIfPresent(String.self, forKey: .platformName)
        destinationName = try container.decodeIfPresent(String.self, forKey: .destinationName)
        
        let dateString = try container.decode(String.self, forKey: .expectedArrival)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        
        if let date = isoFormatter.date(from: dateString) {
            expectedArrival = date
        } else {
            let legacyFormatter = DateFormatter()
            legacyFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            legacyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = legacyFormatter.date(from: dateString) {
                expectedArrival = date
            } else {
                throw DecodingError.dataCorruptedError(forKey: .expectedArrival, in: container, debugDescription: "Date string does not match format")
            }
        }
        
        timeToStation = try container.decode(TimeInterval.self, forKey: .timeToStation)
    }
    
    // Keep the existing initializer for manual creation
    init(id: String?, stationName: String?, lineId: String?, lineName: String?, platformName: String?, destinationName: String?, expectedArrival: Date, timeToStation: TimeInterval) {
        self.id = id
        self.stationName = stationName
        self.lineId = lineId
        self.lineName = lineName
        self.platformName = platformName
        self.destinationName = destinationName
        self.expectedArrival = expectedArrival
        self.timeToStation = timeToStation
    }
}

/// Metadata for a single tube station
struct StationMeta {
    let id: String
    let coord: CLLocationCoordinate2D
}

// MARK: - Line Status Models
struct TfLLineStatus: Decodable {
    let id: String
    let name: String
    let lineStatuses: [LineStatus]
    let created: Date
    let modified: Date
    
    struct LineStatus: Decodable {
        let id: Int
        let statusSeverity: Int
        let statusSeverityDescription: String
        let reason: String?
        let validityPeriods: [ValidityPeriod]
        let disruption: Disruption?
        
        struct ValidityPeriod: Decodable {
            let fromDate: Date
            let toDate: Date
            let isNow: Bool
        }
        
        struct Disruption: Decodable {
            let category: String
            let categoryDescription: String
            let description: String
            let affectedRoutes: [String]?
            let affectedStops: [String]?
            let closureText: String?
        }
    }
}

// MARK: - Data Service Singleton

/// Centralized TfL API data handler for stations, lines, and arrivals
public final class TfLDataService {
    static let shared = TfLDataService()
    private init() {
        fetchAllTubeStationIds { }
    }
    
    // MARK: - Properties
    private var stationIdMap: [String: String] = [:] // For fast station name -> naptanId lookup
    
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        return formatter
    }()
    private let legacyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // MARK: - Journey Planner
    
    // Fetches the sequence of stop names between two coordinates (tube journey only)
    func fetchJourneyPlannerStops(
        fromCoord: CLLocationCoordinate2D,
        toCoord: CLLocationCoordinate2D,
        completion: @escaping ([String]) -> Void
    ) {
        let fromStr = "\(fromCoord.latitude),\(fromCoord.longitude)"
        let toStr = "\(toCoord.latitude),\(toCoord.longitude)"
        let urlStr = "https://api.tfl.gov.uk/Journey/JourneyResults/\(fromStr)/to/\(toStr)?mode=tube&app_key=\(APIKeys.tflAppKey)"
        guard let url = URL(string: urlStr) else { completion([]); return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var result: [String] = []
            defer { DispatchQueue.main.async { completion(result) } }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let journeys = json["journeys"] as? [[String: Any]],
                  let legs = journeys.first?["legs"] as? [[String: Any]] else {
                return
            }
            for leg in legs where (leg["mode"] as? [String: Any])?["id"] as? String == "tube" {
                if let path = leg["path"] as? [String: Any],
                   let stops = path["stopPoints"] as? [[String: Any]] {
                    let names = stops.compactMap { $0["name"] as? String }
                    result.append(contentsOf: names)
                }
            }
        }.resume()
    }

    // MARK: - Station Data / Utilities

    // Loads all tube stations into a dictionary of [Name: StationMeta]
    func loadAllTubeStations(completion: @escaping ([String: StationMeta]) -> Void) {
        let urlStr = "https://api.tfl.gov.uk/StopPoint/Mode/tube"
        guard let url = URL(string: urlStr) else { completion([:]); return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stopPoints = json["stopPoints"] as? [[String: Any]] else {
                completion([:]); return
            }
            var result: [String: StationMeta] = [:]
            for stop in stopPoints {
                if let name = stop["commonName"] as? String,
                   let id = stop["naptanId"] as? String,
                   let lat = stop["lat"] as? CLLocationDegrees,
                   let lon = stop["lon"] as? CLLocationDegrees {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    result[name] = StationMeta(id: id, coord: coord)
                }
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
    
    // Finds the nearest station in the supplied [Name: StationMeta] dictionary
    func findNearestStation(to location: CLLocation, from stations: [String: StationMeta]) -> String? {
        let closest = stations.min { lhs, rhs in
            let lhsLoc = CLLocation(latitude: lhs.value.coord.latitude, longitude: lhs.value.coord.longitude)
            let rhsLoc = CLLocation(latitude: rhs.value.coord.latitude, longitude: rhs.value.coord.longitude)
            return location.distance(from: lhsLoc) < location.distance(from: rhsLoc)
        }
        return closest?.key
    }
    

    // Caches all [stationName: naptanId] for lookup (used by resolveStationId) at the init step
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
                   let id = stop["naptanId"] as? String {
                    dict[StationNameUtils.normalizeStationName(name)] = id
                }
            }
            self.stationIdMap = dict
            print("[TfLDataService] TfL StationIdMap Loaded, count = \(dict.count)")
            DispatchQueue.main.async { completion() }
        }.resume()
    }
    
    // Resolves any (possibly fuzzy) station name to a naptanId, first checking local cache, then using API if needed.
    func resolveStationId(for stationName: String, completion: @escaping (String?) -> Void) {
        let cleanedName = StationNameUtils.normalizeStationName(stationName)
        print("[TfLDataService] Resolving station ID for: \(stationName) (cleaned: \(cleanedName))")
        if let id = self.stationIdMap[cleanedName] {
            print("[TfLDataService] Found station ID in cache: \(id)")
            completion(id); return
        }
        for (key, value) in self.stationIdMap {
            if key.contains(cleanedName) {
                print("[TfLDataService] Found station ID through fuzzy match: \(value)")
                completion(value); return
            }
        }
        // As a last resort, query the API live:
        let query = stationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stationName
        let searchUrlStr = "https://api.tfl.gov.uk/StopPoint/Search?query=\(query)&modes=tube&app_key=\(APIKeys.tflAppKey)"
        print("[TfLDataService] Querying TfL API for station ID: \(searchUrlStr)")
        guard let searchUrl = URL(string: searchUrlStr) else { 
            print("[TfLDataService] Failed to create URL for station search")
            completion(nil); return 
        }
        URLSession.shared.dataTask(with: searchUrl) { [weak self] data, response, error in
            guard let self = self else { completion(nil); return }
            if let error = error {
                print("[TfLDataService] Error fetching station ID: \(error)")
                completion(nil); return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("[TfLDataService] Station search response status: \(httpResponse.statusCode)")
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let matches = json["matches"] as? [[String: Any]],
                  let firstMatch = matches.first,
                  let id = firstMatch["naptanId"] as? String ?? firstMatch["id"] as? String else {
                print("[TfLDataService] Failed to parse station search response")
                completion(nil); return
            }
            print("[TfLDataService] Successfully found station ID from API: \(id)")
            self.stationIdMap[cleanedName] = id
            completion(id)
        }.resume()
    }

    // MARK: - Arrival Data
    // Fetches available line IDs for a station by naptanId
    func fetchAvailableLines(for naptanId: String, completion: @escaping ([String]) -> Void) {
        let urlStr = "https://api.tfl.gov.uk/StopPoint/\(naptanId)"
        print("[TfLDataService] Fetching available lines for station: \(naptanId)")
        guard let url = URL(string: urlStr) else { 
            print("[TfLDataService] Failed to create URL for line fetch")
            completion([]); return 
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("[TfLDataService] Error fetching available lines: \(error)")
                completion([]); return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("[TfLDataService] Line fetch response status: \(httpResponse.statusCode)")
            }
            var result: [String] = []
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lines = json["lines"] as? [[String: Any]] {
                for line in lines {
                    if let id = line["id"] as? String {
                        result.append(id)
                    }
                }
                print("[TfLDataService] Found \(result.count) available lines: \(result) at this station")
            } else {
                print("[TfLDataService] Failed to parse available lines response")
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    // Fetches all arrivals at a station, optionally filtering by line IDs.
    func fetchAllArrivals(for naptanId: String, relevantLineIds: [String]?, completion: @escaping ([TfLArrivalPrediction]) -> Void) {
        fetchAvailableLines(for: naptanId) { allAvailableLineIdsAtStation in
            let linesToFetch = relevantLineIds ?? allAvailableLineIdsAtStation

            let group = DispatchGroup()
            var allArrivals: [TfLArrivalPrediction] = []
            for lineId in linesToFetch {
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

    // Fetches all arrival predictions for a given line and station
    func fetchTrainArrivals(
        lineId: String,
        stationNaptanId: String,
        completion: @escaping (Result<[TfLArrivalPrediction], Error>) -> Void
    ) {
        let urlStr = "https://api.tfl.gov.uk/Line/\(lineId)/Arrivals/\(stationNaptanId)?app_key=\(APIKeys.tflAppKey)"
        print("[TfLDataService] Fetching arrivals for line \(lineId) at station \(stationNaptanId)")
        guard let url = URL(string: urlStr) else {
            print("[TfLDataService] Failed to create URL for arrivals fetch")
            completion(.failure(NSError(domain: "TfLDataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                print("[TfLDataService] Error fetching arrivals: \(error)")
                completion(.failure(error)); return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("[TfLDataService] Arrivals fetch response status: \(httpResponse.statusCode)")
            }
            guard let data = data else {
                print("[TfLDataService] No data received from arrivals API")
                completion(.failure(NSError(domain: "TfLDataService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data from API"])))
                return
            }
            do {
                let arrivalsJSON = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                guard let arrivalsArray = arrivalsJSON else {
                    print("[TfLDataService] Failed to parse arrivals JSON array")
                    completion(.failure(NSError(domain: "TfLDataService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON array"])))
                    return
                }
                print("[TfLDataService] Received \(arrivalsArray.count) arrival predictions")
                var predictions: [TfLArrivalPrediction] = []
                for dict in arrivalsArray {
                    guard let expectedArrivalStr = dict["expectedArrival"] as? String else { continue }
                    let arrivalDate = self.isoFormatter.date(from: expectedArrivalStr) ?? self.legacyDateFormatter.date(from: expectedArrivalStr)
                    guard let finalArrivalDate = arrivalDate else { continue }
                    let prediction = TfLArrivalPrediction(
                        id: dict["id"] as? String,
                        stationName: dict["stationName"] as? String,
                        lineId: dict["lineId"] as? String,
                        lineName: dict["lineName"] as? String,
                        platformName: dict["platformName"] as? String,
                        destinationName: dict["destinationName"] as? String,
                        expectedArrival: finalArrivalDate,
                        timeToStation: (dict["timeToStation"] as? TimeInterval) ?? 0
                    )
                    predictions.append(prediction)
                }
                print("[TfLDataService] Successfully parsed \(predictions.count) arrival predictions")
                completion(.success(predictions))
            } catch {
                print("[TfLDataService] Error parsing arrivals data: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    
    // Utilities function
    // Gets naptanId from station name in supplied [Name: StationMeta] dictionary
    func getStationId(from stationName: String, in stations: [String: StationMeta]) -> String? {
        return stations[stationName]?.id
    }

    /// Converts a pretty tube line name to its TfL ID
    func tflLineId(from lineName: String) -> String? {
        let mapping: [String: String] = [
            "Bakerloo": "bakerloo", "Central": "central", "Circle": "circle", "District": "district",
            "Hammersmith & City": "hammersmith-city", "Jubilee": "jubilee", "Metropolitan": "metropolitan",
            "Northern": "northern", "Piccadilly": "piccadilly", "Victoria": "victoria", "Waterloo & City": "waterloo-city",
            "London Overground": "london-overground", "Elizabeth": "elizabeth", "Elizabeth line": "elizabeth",
            "TfL Rail": "elizabeth", "DLR": "dlr", "Tram": "tram"
        ]
        if let id = mapping[lineName] { return id }
        let lower = lineName.lowercased()
        return mapping.first { $0.key.lowercased() == lower }?.value
    }
    

    func fetchArrivals(forStationId stationId: String, lineId: String? = nil) async throws -> [TfLArrivalPrediction] {
        print("[TfLDataService] Fetching arrivals for station: \(stationId), line: \(lineId ?? "all")")
        
        var urlComponents = URLComponents(string: "\(baseURL)/Line/\(lineId ?? "")/Arrivals/\(stationId)")
        if lineId == nil {
            urlComponents = URLComponents(string: "\(baseURL)/StopPoint/\(stationId)/Arrivals")
        }
        
        guard let url = urlComponents?.url else {
            throw TfLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "app_key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TfLError.invalidResponse
        }
        
        print("[TfLDataService] Arrivals fetch response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw TfLError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let predictions = try JSONDecoder().decode([TfLArrivalPrediction].self, from: data)
        print("[TfLDataService] Received \(predictions.count) arrival predictions at \(stationId)")
        print("[TfLDataService] Successfully parsed \(predictions.count) arrival predictions")
        
        return predictions
    }

    // MARK: - Transfer Time
    
    func fetchTransferTime(
        from station1: String,
        to station2: String,
        completion: @escaping (Double?) -> Void
    ) {
        // If it's the same station, return 0
        if station1 == station2 {
            completion(0)
            return
        }
        
        // Get station IDs
        guard let station1Id = stationIdMap[station1],
              let station2Id = stationIdMap[station2] else {
            print("Could not find station IDs for: \(station1) or \(station2)")
            completion(nil)
            return
        }
        
        // Use the Journey API to get transfer time
        let urlStr = "https://api.tfl.gov.uk/Journey/JourneyResults/\(station1Id)/to/\(station2Id)?mode=tube&app_key=\(APIKeys.tflAppKey)"
        
        guard let url = URL(string: urlStr) else {
            print("Invalid URL for transfer time request")
            completion(nil)
            return
        }
        
        print("Fetching transfer time from TfL API: \(urlStr)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching transfer time: \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Transfer time API response status: \(httpResponse.statusCode)")
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let journeys = json["journeys"] as? [[String: Any]],
                  let firstJourney = journeys.first,
                  let legs = firstJourney["legs"] as? [[String: Any]],
                  let firstLeg = legs.first,
                  let duration = firstLeg["duration"] as? Double else {
                print("Failed to parse transfer time response")
                completion(nil)
                return
            }
            
            print("Successfully parsed transfer time: \(duration) minutes")
            completion(duration)
        }.resume()
    }

    // Add a public method to get station ID
    func getStationId(for stationName: String) -> String? {
        return stationIdMap[stationName]
    }

    // MARK: - Line Status
    func fetchLineStatus(lineId: String) async throws -> TfLLineStatus {
        print("[TfLDataService] Fetching status for line: \(lineId)")
        
        let urlStr = "\(baseURL)/Line/\(lineId)/Status"
        guard let url = URL(string: urlStr) else {
            throw TfLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "app_key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TfLError.invalidResponse
        }
        
        print("[TfLDataService] Line status response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw TfLError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        
        // 创建一个自定义的日期解码策略
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // 尝试多种日期格式
        let dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // 尝试 ISO8601 格式
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // 尝试带时区的格式
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            // 尝试不带时区的格式
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        
        decoder.dateDecodingStrategy = dateDecodingStrategy
        
        let status = try decoder.decode([TfLLineStatus].self, from: data).first
        guard let lineStatus = status else {
            throw TfLError.noData
        }
        
        print("[TfLDataService] Successfully fetched status for line: \(lineId)")
        return lineStatus
    }

    // 获取所有线路的状态
    func fetchAllLineStatuses() async throws -> [String: TfLLineStatus] {
        let lineIds = [
            "bakerloo", "central", "circle", "district",
            "hammersmith-city", "jubilee", "metropolitan",
            "northern", "piccadilly", "victoria", "waterloo-city",
            "london-overground", "elizabeth", "dlr", "tram"
        ]
        
        var statuses: [String: TfLLineStatus] = [:]
        
        for lineId in lineIds {
            do {
                let status = try await fetchLineStatus(lineId: lineId)
                statuses[lineId] = status
                print("[DEBUG] Line Status for \(lineId):")
                print("  - Name: \(status.name)")
                print("  - Statuses:")
                for lineStatus in status.lineStatuses {
                    print("    * Severity: \(lineStatus.statusSeverity)")
                    print("    * Description: \(lineStatus.statusSeverityDescription)")
                    if let reason = lineStatus.reason {
                        print("    * Reason: \(reason)")
                    }
                }
                print("  - Created: \(status.created)")
                print("  - Modified: \(status.modified)")
                print("-------------------")
            } catch {
                print("[TfLDataService] Error fetching status for line \(lineId): \(error)")
            }
        }
        
        return statuses
    }

}
