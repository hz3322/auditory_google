import Foundation
import CoreLocation

public final class GoogleMapsService {
    static let shared = GoogleMapsService()
    private init() {}
    
    func fetchTransitDurationAndArrival(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        completion: @escaping (_ duration: String?, _ arrivalTime: String?, _ departureTime: String?, _ error: Error?) -> Void
    ) {
        let urlStr = "https://maps.googleapis.com/maps/api/directions/json?" +
        "origin=\(from.latitude),\(from.longitude)" +
        "&destination=\(to.latitude),\(to.longitude)" +
        "&mode=transit" +
        "&key=\(APIKeys.googleMaps)"
        
        guard let url = URL(string: urlStr) else {
            completion(nil, nil, nil, NSError(domain: "URL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, nil, nil, error)
                return
            }
            guard let data = data else {
                completion(nil, nil, nil, NSError(domain: "Data", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"]))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let routes = json["routes"] as? [[String: Any]],
                   let firstRoute = routes.first,
                   let legs = firstRoute["legs"] as? [[String: Any]],
                   let leg = legs.first {
                    
                    let durationText = (leg["duration"] as? [String: Any])?["text"] as? String
                    let arrivalTimeText = (leg["arrival_time"] as? [String: Any])?["text"] as? String
                    let departureTimeText = (leg["departure_time"] as? [String: Any])?["text"] as? String
                    completion(durationText, arrivalTimeText, departureTimeText, nil)
                } else {
                    completion(nil, nil, nil, NSError(domain: "JSON", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot parse directions"]))
                }
            } catch {
                completion(nil, nil, nil, error)
            }
        }
        task.resume()
    }
    
    
    func fetchTransitRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        let urlStr = "https://maps.googleapis.com/maps/api/directions/json?origin=\(from.latitude),\(from.longitude)&destination=\(to.latitude),\(to.longitude)&mode=transit&transit_mode=subway|train&region=uk&key=\(APIKeys.googleMaps)"
        
        guard let url = URL(string: urlStr) else {
            completion(.failure(NSError(domain: "GMS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let legs = routes.first?["legs"] as? [[String: Any]],
                  let steps = legs.first?["steps"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "GMS", code: 2, userInfo: [NSLocalizedDescriptionKey: "No routes/steps"])))
                return
            }
            
            // Debug print the transit details
            for step in steps {
                if let transitDetails = step["transit_details"] as? [String: Any] {
                    print("DEBUG - Transit Details:")
                    print("Departure Time: \(transitDetails["departure_time"] ?? "nil")")
                    print("Arrival Time: \(transitDetails["arrival_time"] ?? "nil")")
                    print("Complete Transit Details: \(transitDetails)")
                }
            }
            
            completion(.success(steps))
        }.resume()
    }
    
    func fetchWalkingTime(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        completion: @escaping (Double?) -> Void
    ) {
        let urlStr = "https://maps.googleapis.com/maps/api/directions/json?origin=\(from.latitude),\(from.longitude)&destination=\(to.latitude),\(to.longitude)&mode=walking&key=\(APIKeys.googleMaps)"
        
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let legs = routes.first?["legs"] as? [[String: Any]],
                  let duration = legs.first?["duration"] as? [String: Any],
                  let value = duration["value"] as? Double else {
                completion(nil)
                return
            }
            
            completion(value / 60.0) // Convert to minutes
        }.resume()
    }
    
    func extractCoordinate(from step: [String: Any], key: String) -> CLLocationCoordinate2D? {
        if let location = step[key] as? [String: Any],
           let lat = location["lat"] as? Double,
           let lng = location["lng"] as? Double {
            // Round coordinates to 6 decimal places for better matching
            let roundedLat = round(lat * 1000000) / 1000000
            let roundedLng = round(lng * 1000000) / 1000000
            return CLLocationCoordinate2D(latitude: roundedLat, longitude: roundedLng)
        }
        return nil
    }
}
