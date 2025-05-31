import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct SavedPlace: Codable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(id: UUID = UUID(), name: String, address: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

class SavedPlacesManager {
    static let shared = SavedPlacesManager()
    private let db = Firestore.firestore()
    private var cachedPlaces: [SavedPlace]?
    
    private init() {}
    
    func loadPlaces(completion: @escaping (Result<[SavedPlace], Error>) -> Void) {
        // Return cached places if available
        if let cached = cachedPlaces {
            completion(.success(cached))
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "SavedPlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        db.collection("users").document(userId).collection("frequent_places").getDocuments { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let places = documents.compactMap { document -> SavedPlace? in
                guard let name = document.data()["name"] as? String,
                      let address = document.data()["address"] as? String,
                      let latitude = document.data()["latitude"] as? Double,
                      let longitude = document.data()["longitude"] as? Double else {
                    return nil
                }
                
                return SavedPlace(id: UUID(uuidString: document.documentID) ?? UUID(),
                                name: name,
                                address: address,
                                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }
            
            self?.cachedPlaces = places
            completion(.success(places))
        }
    }
    
    func addOrUpdatePlace(_ place: SavedPlace, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "SavedPlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        
        let data: [String: Any] = [
            "name": place.name,
            "address": place.address,
            "latitude": place.latitude,
            "longitude": place.longitude
        ]
        
        db.collection("users").document(userId).collection("frequent_places")
            .document(place.id.uuidString)
            .setData(data) { [weak self] error in
                if let error = error {
                    completion(error)
                    return
                }
                
                // Update cache
                if var cached = self?.cachedPlaces {
                    if let index = cached.firstIndex(where: { $0.id == place.id }) {
                        cached[index] = place
                    } else {
                        cached.append(place)
                    }
                    self?.cachedPlaces = cached
                }
                
                completion(nil)
            }
    }
    
    func removePlace(withId id: UUID, defaultName: String, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "SavedPlacesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        
        db.collection("users").document(userId).collection("frequent_places")
            .document(id.uuidString)
            .delete { [weak self] error in
                if let error = error {
                    completion(error)
                    return
                }
                
                // Update cache
                if var cached = self?.cachedPlaces {
                    cached.removeAll { $0.id == id }
                    self?.cachedPlaces = cached
                }
                
                completion(nil)
            }
    }
    
    func clearCachedData() {
        cachedPlaces = nil
    }
}
