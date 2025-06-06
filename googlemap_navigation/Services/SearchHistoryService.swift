import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

class SearchHistoryService {
    static let shared = SearchHistoryService()
    private let db = Firestore.firestore()
    private let maxHistoryItems = 15
    
    private init() {}
    
    func saveSearch(query: String, coordinate: CLLocationCoordinate2D?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let geoPoint = coordinate.map { SearchHistory.GeoPoint(coordinate: $0) }
        let searchHistory = SearchHistory(
            id: UUID().uuidString,
            query: query,
            timestamp: Date(),
            coordinate: geoPoint
        )
        
        let data: [String: Any] = [
            "id": searchHistory.id,
            "query": searchHistory.query,
            "timestamp": searchHistory.timestamp,
            "latitude": geoPoint?.latitude as Any,
            "longitude": geoPoint?.longitude as Any
        ]
        
        db.collection("users").document(userId)
            .collection("searchHistory")
            .document(searchHistory.id)
            .setData(data) { error in
                if let error = error {
                    print("Error saving search history: \(error.localizedDescription)")
                }
            }
    }
    
    func fetchRecentSearches(completion: @escaping ([SearchHistory]) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        db.collection("users").document(userId)
            .collection("searchHistory")
            .order(by: "timestamp", descending: true)
            .limit(to: maxHistoryItems)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching search history: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let searches = snapshot?.documents.compactMap { document -> SearchHistory? in
                    let data = document.data()
                    guard let id = data["id"] as? String,
                          let query = data["query"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    
                    let coordinate: SearchHistory.GeoPoint?
                    if let latitude = data["latitude"] as? Double,
                       let longitude = data["longitude"] as? Double {
                        coordinate = SearchHistory.GeoPoint(latitude: latitude, longitude: longitude)
                    } else {
                        coordinate = nil
                    }
                    
                    return SearchHistory(id: id, query: query, timestamp: timestamp, coordinate: coordinate)
                } ?? []
                
                completion(searches)
            }
    }
    
    func clearSearchHistory(completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        
        db.collection("users").document(userId)
            .collection("searchHistory")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(error)
                    return
                }
                
                let batch = self.db.batch()
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    completion(error)
                }
            }
    }
} 