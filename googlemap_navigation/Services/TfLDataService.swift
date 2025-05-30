import Foundation
import CoreLocation

// MARK: - Data Models

/// Represents a single train arrival prediction returned by TfL API
struct TfLArrivalPrediction {
    let id: String?
    let stationName: String?
    let lineId: String?
    let lineName: String?
    let platformName: String?
    let destinationName: String?
    let expectedArrival: Date
    let timeToStation: TimeInterval // Seconds until it reaches the station (naptanId)
}

/// Metadata for a single tube station
struct StationMeta {
    let id: String
    let coord: CLLocationCoordinate2D
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
    
    /// Fetches the sequence of stop names between two coordinates (tube journey only)
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

    /// Loads all tube stations into a dictionary of [Name: StationMeta]
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
    
    /// Finds the nearest station in the supplied [Name: StationMeta] dictionary
    func findNearestStation(to location: CLLocation, from stations: [String: StationMeta]) -> String? {
        let closest = stations.min { lhs, rhs in
            let lhsLoc = CLLocation(latitude: lhs.value.coord.latitude, longitude: lhs.value.coord.longitude)
            let rhsLoc = CLLocation(latitude: rhs.value.coord.latitude, longitude: rhs.value.coord.longitude)
            return location.distance(from: lhsLoc) < location.distance(from: rhsLoc)
        }
        return closest?.key
    }
    
    /// Gets naptanId from station name in supplied [Name: StationMeta] dictionary
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
    
    /// Normalizes station names for consistent lookup (removes "Underground Station", trims whitespace, lowercases)
    func normalizeStationName(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: " underground station", with: "")
            .replacingOccurrences(of: " station", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Caches all [stationName: naptanId] for lookup (used by resolveStationId)
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
                    dict[self.normalizeStationName(name)] = id
                }
            }
            self.stationIdMap = dict
            print("[TfLDataService] TfL StationIdMap Loaded, count = \(dict.count)")
            DispatchQueue.main.async { completion() }
        }.resume()
    }
    
    /// Resolves any (possibly fuzzy) station name to a naptanId, first checking local cache, then using API if needed.
    func resolveStationId(for stationName: String, completion: @escaping (String?) -> Void) {
        let cleanedName = normalizeStationName(stationName)
        if let id = self.stationIdMap[cleanedName] {
            completion(id); return
        }
        for (key, value) in self.stationIdMap {
            if key.contains(cleanedName) {
                completion(value); return
            }
        }
        // As a last resort, query the API live:
        let query = stationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stationName
        let searchUrlStr = "https://api.tfl.gov.uk/StopPoint/Search?query=\(query)&modes=tube&app_key=\(APIKeys.tflAppKey)"
        guard let searchUrl = URL(string: searchUrlStr) else { completion(nil); return }
        URLSession.shared.dataTask(with: searchUrl) { [weak self] data, _, error in
            guard let self = self else { completion(nil); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let matches = json["matches"] as? [[String: Any]],
                  let firstMatch = matches.first,
                  let id = firstMatch["naptanId"] as? String ?? firstMatch["id"] as? String else {
                completion(nil); return
            }
            self.stationIdMap[cleanedName] = id
            completion(id)
        }.resume()
    }

    // MARK: - Arrival Data

    /// Fetches available line IDs for a station by naptanId
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

    /// Fetches all arrivals at a station, optionally filtering by line IDs.
    func fetchAllArrivals(for naptanId: String, relevantLineIds: [String]?, completion: @escaping ([TfLArrivalPrediction]) -> Void) {
        fetchAvailableLines(for: naptanId) { allAvailableLineIdsAtStation in
            let linesToFetch = relevantLineIds ?? allAvailableLineIdsAtStation
            let finalLineIds = relevantLineIds != nil ? allAvailableLineIdsAtStation.filter { linesToFetch.contains($0) } : linesToFetch
            let group = DispatchGroup()
            var allArrivals: [TfLArrivalPrediction] = []
            for lineId in finalLineIds {
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

    /// Fetches all arrival predictions for a given line and station
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
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "TfLDataService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data from API"])))
                return
            }
            do {
                let arrivalsJSON = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                guard let arrivalsArray = arrivalsJSON else {
                    completion(.failure(NSError(domain: "TfLDataService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON array"])))
                    return
                }
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
                completion(.success(predictions))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
