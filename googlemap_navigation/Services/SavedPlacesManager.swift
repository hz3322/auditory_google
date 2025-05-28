import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

struct SavedPlace: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String       // "Home", "Work", "Gym", etc.
    var address: String    // Formatted address string
    var latitude: Double
    var longitude: Double
    var isSystemDefault: Bool = false

    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Initializer for creating new places
    init(id: UUID = UUID(), name: String, address: String, coordinate: CLLocationCoordinate2D, isSystemDefault: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.isSystemDefault = isSystemDefault
    }

    // Placeholder initializer (e.g., for "Set Home Address")
    init(placeholderName: String, isSystemDefault: Bool = true) {
        self.id = UUID()
        self.name = placeholderName
        self.address = "Tap to set \(placeholderName)"
        self.latitude = 0 // Invalid coordinates, clearly a placeholder
        self.longitude = 0
        self.isSystemDefault = isSystemDefault
    }
}


class SavedPlacesManager {
    static let shared = SavedPlacesManager()
    private let db = Firestore.firestore()
    
    // Add a property to store cached places
    private var cachedPlaces: [SavedPlace] = []

    private var currentUserID: String? {
        let uid = Auth.auth().currentUser?.uid
        print("ℹ️ Current user ID: \(uid ?? "nil")")
        return uid
    }

    // Add method to clear cached data
    func clearCachedData() {
        print("🧹 Clearing cached places data")
        cachedPlaces = []
    }

    private func frequentPlacesCollectionRef() -> CollectionReference? {
        guard let userID = currentUserID else {
            print("🛑 Error: User ID not available. Cannot access frequent places in Firestore.")
            return nil
        }
        let collectionRef = db.collection("users").document(userID).collection("frequent_places")
        print("ℹ️ Accessing Firestore collection: users/\(userID)/frequent_places")
        return collectionRef
    }

    /// 从 Firestore 加载常用地点列表
    func loadPlaces(completion: @escaping (Result<[SavedPlace], Error>) -> Void) {
        // If we have cached places and a valid user ID, return them immediately
        if !cachedPlaces.isEmpty, currentUserID != nil {
            print("📦 Returning \(cachedPlaces.count) cached places")
            completion(.success(cachedPlaces))
            return
        }

        guard let collectionRef = frequentPlacesCollectionRef() else {
            print("ℹ️ No current user ID, returning default placeholders for Home/Work.")
            let defaultPlaceholders = [
                SavedPlace(placeholderName: "Home", isSystemDefault: true),
                SavedPlace(placeholderName: "Work", isSystemDefault: true)
            ]
            cachedPlaces = defaultPlaceholders
            completion(.success(defaultPlaceholders))
            return
        }

        print("📥 Loading places from Firestore...")
        collectionRef.getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("🛑 Error getting documents from Firestore: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            print("📦 Retrieved \(querySnapshot?.documents.count ?? 0) documents from Firestore")
            var places = querySnapshot?.documents.compactMap { document -> SavedPlace? in
                do {
                    let place = try document.data(as: SavedPlace.self)
                    print("✅ Successfully decoded place: \(place.name) (ID: \(place.id))")
                    return place
                } catch {
                    print("🛑 Error decoding SavedPlace from document \(document.documentID): \(error.localizedDescription)")
                    return nil
                }
            } ?? []

            var foundHome = false
            var foundWork = false

            for place in places {
                if place.name == "Home" && place.isSystemDefault { foundHome = true }
                if place.name == "Work" && place.isSystemDefault { foundWork = true }
            }

            if !foundHome {
                print("ℹ️ Adding Home placeholder")
                let homePlaceholder = SavedPlace(placeholderName: "Home", isSystemDefault: true)
                places.insert(homePlaceholder, at: 0)
            }
            if !foundWork {
                print("ℹ️ Adding Work placeholder")
                let workPlaceholder = SavedPlace(placeholderName: "Work", isSystemDefault: true)
                let homeIndex = places.firstIndex(where: { $0.name == "Home" && $0.isSystemDefault })
                let insertAtIndex = homeIndex != nil ? homeIndex! + 1 : (places.isEmpty ? 0 : min(1, places.count))
                places.insert(workPlaceholder, at: insertAtIndex)
            }

            // Cache the places
            self.cachedPlaces = places
            
            print("✅ Loaded \(places.count) places total")
            completion(.success(places))
        }
    }

    /// 添加或更新一个常用地点到 Firestore
    func addOrUpdatePlace(_ place: SavedPlace, completion: @escaping (Error?) -> Void) {
        guard let collectionRef = frequentPlacesCollectionRef() else {
            let error = NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated or available."])
            print("🛑 \(error.localizedDescription)")
            completion(error)
            return
        }
        
        let documentRef = collectionRef.document(place.id.uuidString)
        print("📝 Saving place '\(place.name)' (ID: \(place.id)) to Firestore...")
        
        do {
            try documentRef.setData(from: place, merge: true) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🛑 Error writing document \(place.id.uuidString) (\(place.name)) to Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Document \(place.id.uuidString) (\(place.name)) successfully written/updated in Firestore!")
                    // Update cached places
                    if let index = self.cachedPlaces.firstIndex(where: { $0.id == place.id }) {
                        self.cachedPlaces[index] = place
                    } else {
                        self.cachedPlaces.append(place)
                    }
                }
                completion(error)
            }
        } catch {
            print("🛑 Error encoding SavedPlace '\(place.name)' for Firestore: \(error.localizedDescription)")
            completion(error)
        }
    }

    /// 从 Firestore 删除一个自定义的常用地点
    func removePlace(withId id: UUID, isSystemDefault: Bool, defaultName: String, completion: @escaping (Error?) -> Void) {
        guard let collectionRef = frequentPlacesCollectionRef() else {
            let error = NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated or available."])
            print("🛑 \(error.localizedDescription)")
            completion(error)
            return
        }

        let documentRef = collectionRef.document(id.uuidString)
        print("🗑️ Removing place with ID: \(id) from Firestore...")

        if isSystemDefault {
            print("ℹ️ Resetting system default place '\(defaultName)' to placeholder state")
            let placeholder = SavedPlace(id: id,
                                         name: defaultName,
                                         address: "Tap to set \(defaultName)",
                                         coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                         isSystemDefault: true)
            addOrUpdatePlace(placeholder, completion: completion)
        } else {
            documentRef.delete { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🛑 Error removing document \(id.uuidString) from Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Document \(id.uuidString) successfully removed from Firestore!")
                    // Remove from cached places
                    self.cachedPlaces.removeAll { $0.id == id }
                }
                completion(error)
            }
        }
    }
}
