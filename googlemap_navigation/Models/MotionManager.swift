import CoreMotion
import CoreLocation

class MotionManager {
    static let shared = MotionManager()
    
    private let pedometer = CMPedometer()
    private var isPedometerAvailable: Bool {
        return CMPedometer.isPedometerEventTrackingAvailable() && CMPedometer.isDistanceAvailable()
    }
    
    // Current speed in meters per second
    private(set) var currentSpeed: Double = 0.0
    
    // Callback for speed updates
    var onSpeedUpdate: ((Double) -> Void)?
    
    private init() {}
    
    func startTracking() {
        guard isPedometerAvailable else {
            print("⚠️ Pedometer is not available on this device")
            return
        }
        
        // Start pedometer updates
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let data = data, error == nil else {
                print("⚠️ Error getting pedometer data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Calculate current speed (m/s)
            if let currentPace = data.currentPace {
                // currentPace is in seconds per meter, so we need to convert to meters per second
                let speedInMetersPerSecond = 1.0 / currentPace.doubleValue
                self?.currentSpeed = speedInMetersPerSecond
                self?.onSpeedUpdate?(speedInMetersPerSecond)
            }
        }
    }
    
    func stopTracking() {
        pedometer.stopUpdates()
        currentSpeed = 0.0
    }
    
    // Get average speed over a time period
    func getAverageSpeed(from startDate: Date, to endDate: Date, completion: @escaping (Double?) -> Void) {
        pedometer.queryPedometerData(from: startDate, to: endDate) { data, error in
            guard let data = data, error == nil else {
                print("⚠️ Error getting pedometer data: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            let timeInterval = endDate.timeIntervalSince(startDate)
            if let distance = data.distance?.doubleValue, timeInterval > 0 {
                let averageSpeed = distance / timeInterval // meters per second
                completion(averageSpeed)
            } else {
                completion(nil)
            }
        }
    }
} 