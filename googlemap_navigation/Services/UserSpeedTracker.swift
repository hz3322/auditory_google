import Foundation
import CoreLocation

class UserSpeedTracker: NSObject, CLLocationManagerDelegate {
    static let shared = UserSpeedTracker()

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var lastTimestamp: Date?

    private(set) var currentSpeedMps: Double = 0.0  // 米每秒

    var speedUpdateHandler: ((Double) -> Void)?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1
    }

    func startTracking() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }

        if let lastLoc = lastLocation, let lastTime = lastTimestamp {
            let timeDelta = newLocation.timestamp.timeIntervalSince(lastTime)
            let distance = newLocation.distance(from: lastLoc)

            if timeDelta > 0 {
                currentSpeedMps = distance / timeDelta
                speedUpdateHandler?(currentSpeedMps)
            }
        }

        lastLocation = newLocation
        lastTimestamp = newLocation.timestamp
    }
}
