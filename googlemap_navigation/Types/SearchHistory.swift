import Foundation
import CoreLocation

struct SearchHistory: Codable {
    let id: String
    let query: String
    let timestamp: Date
    let coordinate: GeoPoint?
    
    struct GeoPoint: Codable {
        let latitude: Double
        let longitude: Double
        
        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
        
        init(coordinate: CLLocationCoordinate2D) {
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
        }
        
        var toCoordinate: CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
} 