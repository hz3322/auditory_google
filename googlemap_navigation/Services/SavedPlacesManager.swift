import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth         // 如果您计划使用 Firebase Authentication 来区分用户

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
    init(placeholderName: String, isSystemDefault: Bool = true) { // 确保这里的 isSystemDefault 也被设置
        self.id = UUID()
        self.name = placeholderName
        self.address = "Tap to set \(placeholderName)"
        self.latitude = 0 // Invalid coordinates, clearly a placeholder
        self.longitude = 0
        self.isSystemDefault = isSystemDefault // **** 确保这里也使用 isSystemDefault ****
    }
}


class SavedPlacesManager {
    static let shared = SavedPlacesManager()
    private let db = Firestore.firestore()

    //  Firebase Authentication:
    private var currentUserID: String? {
        if let existingID = UserDefaults.standard.string(forKey: "deviceAnonymousUserID_ Firestore") { // 使用一个清晰的键名
                return existingID
            } else {
                let newID = UUID().uuidString
                UserDefaults.standard.set(newID, forKey: "deviceAnonymousUserID_Firestore")
                print("ℹ️ Generated new deviceAnonymousUserID for Firestore: \(newID)")
                return newID
            }
//        return Auth.auth().currentUser?.uid
    }


   
    // 获取用户常用地点集合的引用
    private func frequentPlacesCollectionRef() -> CollectionReference? {
        guard let userID = currentUserID else {
            print("🛑 Error: User ID not available. Cannot access frequent places in Firestore.")
            return nil
        }
        // 结构: users/{userID}/frequent_places/{placeID}
        return db.collection("users").document(userID).collection("frequent_places")
    }

    /// 从 Firestore 加载常用地点列表
    func loadPlaces(completion: @escaping (Result<[SavedPlace], Error>) -> Void) {
        guard let collectionRef = frequentPlacesCollectionRef() else {
            // 如果没有用户ID，或者不希望在无用户时创建默认值，可以返回错误或空数组
            // 为了保持与 UserDefaults 版本的行为一致，我们返回默认的 Home 和 Work 占位符
            let defaultPlaceholders = [
                SavedPlace(placeholderName: "Home", isSystemDefault: true),
                SavedPlace(placeholderName: "Work", isSystemDefault: true)
            ]
            print("ℹ️ No current user ID, returning default placeholders for Home/Work.")
            completion(.success(defaultPlaceholders))
            return
        }

        collectionRef.getDocuments { (querySnapshot, error) in
            if let error = error {
                print("🛑 Error getting documents from Firestore: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            var places = querySnapshot?.documents.compactMap { document -> SavedPlace? in
                // 尝试将 Firestore 文档解码为 SavedPlace 对象
                // 如果解码失败，会打印错误并返回 nil，然后被 compactMap 过滤掉
                do {
                    return try document.data(as: SavedPlace.self)
                } catch {
                    print("🛑 Error decoding SavedPlace from document \(document.documentID): \(error.localizedDescription)")
                    return nil
                }
            } ?? []

            // 确保 Home 和 Work (作为系统默认地点) 存在于列表中
            // 如果 Firestore 中没有，则添加占位符
            var foundHome = false
            var foundWork = false

            for place in places {
                if place.name == "Home" && place.isSystemDefault { foundHome = true }
                if place.name == "Work" && place.isSystemDefault { foundWork = true }
            }


            if !foundHome {
                let homePlaceholder = SavedPlace(placeholderName: "Home", isSystemDefault: true)
                places.insert(homePlaceholder, at: 0)
                // 如果添加了占位符，理论上应该立即将其保存到Firestore，以便下次加载时存在
                // 或者，让用户在点击“Tap to set”后才真正创建Firestore文档
                // 为简单起见，这里我们先在内存中添加，用户设置时会通过 addOrUpdatePlace 保存
                print("ℹ️ 'Home' placeholder added to local list as it was missing.")
            }
            if !foundWork {
                let workPlaceholder = SavedPlace(placeholderName: "Work", isSystemDefault: true)
                let homeIndex = places.firstIndex(where: { $0.name == "Home" && $0.isSystemDefault })
                let insertAtIndex = homeIndex != nil ? homeIndex! + 1 : (places.isEmpty ? 0 : min(1, places.count))
                
                // 避免在已存在 Work 的情况下重复插入占位符
                if !places.contains(where: {$0.name == "Work" && $0.isSystemDefault}) {
                    places.insert(workPlaceholder, at: insertAtIndex)
                    print("ℹ️ 'Work' placeholder added to local list as it was missing.")
                }
            }

            // 排序，确保 Home 和 Work 在最前面 (如果存在)
            places.sort { (p1, p2) -> Bool in
                if p1.isSystemDefault && !p2.isSystemDefault { return true }
                if !p1.isSystemDefault && p2.isSystemDefault { return false }
                if p1.name == "Home" { return true } // Home always first among defaults
                if p2.name == "Home" { return false }
                if p1.name == "Work" { return true } // Work second among defaults
                if p2.name == "Work" { return false }
                return p1.name.lowercased() < p2.name.lowercased() // Alphabetical for others
            }
            
            print("✅ Frequent places loaded successfully from Firestore. Count: \(places.count)")
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
        
        // 使用 SavedPlace 的 id 作为 Firestore 文档的 ID
        let documentRef = collectionRef.document(place.id.uuidString)
        
        do {
            // 将 SavedPlace 对象编码并写入 Firestore
            // setData(from: place, merge: true) 会创建新文档或合并更新现有文档
            try documentRef.setData(from: place, merge: true) { error in
                if let error = error {
                    print("🛑 Error writing document \(place.id.uuidString) (\(place.name)) to Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Document \(place.id.uuidString) (\(place.name)) successfully written/updated in Firestore!")
                }
                completion(error) // 将 Firestore 的错误（或nil）传递回去
            }
        } catch {
            print("🛑 Error encoding SavedPlace '\(place.name)' for Firestore: \(error.localizedDescription)")
            completion(error)
        }
    }

    /// 从 Firestore 删除一个自定义的常用地点（通过ID）
    /// 系统默认的 Home/Work 会被重置为占位符，而不是直接删除文档（除非您希望彻底删除）
    func removePlace(withId id: UUID, isSystemDefault: Bool, defaultName: String, completion: @escaping (Error?) -> Void) {
        guard let collectionRef = frequentPlacesCollectionRef() else {
            let error = NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated or available."])
            print("🛑 \(error.localizedDescription)")
            completion(error)
            return
        }

        let documentRef = collectionRef.document(id.uuidString)

        if isSystemDefault {
            // 对于系统默认地点 (Home/Work)，我们不删除文档，而是将其内容重置为占位符状态
            // 这需要确保占位符的 ID 与之前设置的 Home/Work 的 ID 相同
            print("ℹ️ Resetting system default place '\(defaultName)' to placeholder state.")
            let placeholder = SavedPlace(id: id,
                                         name: defaultName,
                                         address: "Tap to set \(defaultName)", // 占位符地址
                                         coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), // 占位符坐标
                                         isSystemDefault: true)
            addOrUpdatePlace(placeholder, completion: completion) // 使用 addOrUpdatePlace 来覆盖
        } else {
            // 对于自定义地点，直接删除文档
            documentRef.delete { error in
                if let error = error {
                    print("🛑 Error removing document \(id.uuidString) from Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Document \(id.uuidString) successfully removed from Firestore!")
                }
                completion(error)
            }
        }
    }
}
