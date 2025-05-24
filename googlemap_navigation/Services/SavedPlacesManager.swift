// SavedPlace.swift
import Foundation
import CoreLocation // For CLLocationCoordinate2D

struct SavedPlace: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String       // "Home", "Work", "Gym", etc.
    var address: String    // Formatted address string
    var latitude: Double
    var longitude: Double
    var isSystemDefault: Bool = false // **** 这个属性名是 isSystemDefault ****

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
    private let frequentPlacesKey = "frequentPlacesKey_v2" 

    private init() {}

    func savePlaces(_ places: [SavedPlace]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(places)
            UserDefaults.standard.set(data, forKey: frequentPlacesKey)
        } catch {
            print("🛑 Error encoding places: \(error.localizedDescription)")
        }
    }

    func loadPlaces() -> [SavedPlace] {
        guard let data = UserDefaults.standard.data(forKey: frequentPlacesKey) else {
            // No saved data, return default placeholders for Home and Work
            return [
                SavedPlace(placeholderName: "Home"),
                SavedPlace(placeholderName: "Work")
            ]
        }
        do {
            let decoder = JSONDecoder()
            var places = try decoder.decode([SavedPlace].self, from: data)
            
            // Ensure Home and Work are present, adding placeholders if missing
            if !places.contains(where: { $0.name == "Home" && $0.isSystemDefault }) {
                places.insert(SavedPlace(placeholderName: "Home"), at: 0)
            }
            if !places.contains(where: { $0.name == "Work" && $0.isSystemDefault }) {
                let homeIndex = places.firstIndex(where: { $0.name == "Home" && $0.isSystemDefault })
                places.insert(SavedPlace(placeholderName: "Work"), at: homeIndex != nil ? homeIndex! + 1 : (places.isEmpty ? 0 : 1) )
            }
            // Remove any old style placeholders if they exist from previous logic
            places.removeAll { $0.address.starts(with: "Set ") && $0.latitude == 0 && $0.longitude == 0 && !$0.isSystemDefault }

            return places
        } catch {
            print("🛑 Error decoding places: \(error.localizedDescription)")
            return [ // Fallback to defaults if decoding fails
                SavedPlace(placeholderName: "Home"),
                SavedPlace(placeholderName: "Work")
            ]
        }
    }

    func addOrUpdatePlace(_ place: SavedPlace) {
        var currentPlaces = loadPlaces() 

        // Try to find an existing place by ID first, this is more robust for updates
        if let index = currentPlaces.firstIndex(where: { $0.id == place.id }) {
            currentPlaces[index] = place // Update existing place by ID
        }
        // If not found by ID, try to find system defaults by name to update them
        else if place.isSystemDefault, let index = currentPlaces.firstIndex(where: { $0.name == place.name && $0.isSystemDefault }) {
            currentPlaces[index] = place // Update existing Home/Work by name
        }
        // If it's a new custom place, or a system default not found by ID or name (e.g. initial setup)
        else {
            if place.isSystemDefault {
                if place.name == "Home" {
                    // If Home placeholder exists, update it; otherwise, add it at the beginning.
                    if let homeIndex = currentPlaces.firstIndex(where: { $0.name == "Home" && $0.isSystemDefault }) {
                        currentPlaces[homeIndex] = place
                    } else {
                        currentPlaces.insert(place, at: 0)
                    }
                } else if place.name == "Work" {
                    // If Work placeholder exists, update it.
                    if let workIndex = currentPlaces.firstIndex(where: { $0.name == "Work" && $0.isSystemDefault }) {
                        currentPlaces[workIndex] = place
                    } else {
                        // Otherwise, add Work after Home if Home exists, or at an appropriate position.
                        let homeIndex = currentPlaces.firstIndex(where: { $0.name == "Home" && $0.isSystemDefault })
                        let insertAtIndex = homeIndex != nil ? homeIndex! + 1 : (currentPlaces.isEmpty ? 0 : min(1, currentPlaces.count))
                        if insertAtIndex < currentPlaces.count && currentPlaces[insertAtIndex].name == "Work" && currentPlaces[insertAtIndex].isSystemDefault {
                            // Avoid inserting if 'Work' already exists at the target position (edge case after home deletion etc.)
                            // This scenario is less likely with ID-based updates above.
                        } else {
                            currentPlaces.insert(place, at: insertAtIndex)
                        }
                    }
                }
            } else {
                // For new custom places, prevent duplicates by custom name
                if !currentPlaces.contains(where: { !$0.isSystemDefault && $0.name.lowercased() == place.name.lowercased() }) {
                    currentPlaces.append(place)
                } else {
                    print("ℹ️ Custom place with name \"\(place.name)\" already exists. Not adding duplicate.")
                    // Optionally, you could decide to update it here if that's the desired behavior.
                }
            }
        }
        savePlaces(currentPlaces)
    }
    func removePlace(withId id: UUID) {
        var currentPlaces = loadPlaces()
        // Prevent removing system default Home/Work by ID, only reset them
        if let index = currentPlaces.firstIndex(where: { $0.id == id }), currentPlaces[index].isSystemDefault {
            print("ℹ️ System default place (\(currentPlaces[index].name)) cannot be removed, resetting instead.")
            currentPlaces[index] = SavedPlace(placeholderName: currentPlaces[index].name, isSystemDefault: true)
        } else {
            currentPlaces.removeAll { $0.id == id && !$0.isSystemDefault }
        }
        savePlaces(currentPlaces)
    }
}
