import CoreMotion
import CoreLocation

class MotionManager {
    static let shared = MotionManager()
    
    private let pedometer = CMPedometer()
    private var isPedometerAvailable: Bool {
        return CMPedometer.isPedometerEventTrackingAvailable() && CMPedometer.isDistanceAvailable()
    }
    
    // 最小有效速度（米/秒）
    private let minimumValidSpeed: Double = 0.5
    
    // Current speed in meters per second
    private(set) var currentSpeed: Double = 0.0
    
    // 是否处于静止状态
    private(set) var isStationary: Bool = true
    
    // 静止开始时间
    private var stationaryStartTime: Date?
    
    // 最后一次有效速度更新时间
    private var lastValidSpeedUpdate: Date?
    
    // Callback for speed updates
    var onSpeedUpdate: ((Double) -> Void)?
    var onStationaryStateChanged: ((Bool) -> Void)?
    
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
                
                // 检查速度是否有效
                if speedInMetersPerSecond >= self?.minimumValidSpeed ?? 0.5 {
                    self?.currentSpeed = speedInMetersPerSecond
                    self?.lastValidSpeedUpdate = Date()
                    self?.onSpeedUpdate?(speedInMetersPerSecond)
                    
                    // 如果之前是静止状态，现在开始移动
                    if self?.isStationary == true {
                        self?.isStationary = false
                        self?.stationaryStartTime = nil
                        self?.onStationaryStateChanged?(false)
                    }
                } else {
                    // 速度低于阈值，可能处于静止状态
                    if self?.isStationary == false {
                        self?.isStationary = true
                        self?.stationaryStartTime = Date()
                        self?.onStationaryStateChanged?(true)
                    }
                }
            }
        }
    }
    
    func stopTracking() {
        pedometer.stopUpdates()
        currentSpeed = 0.0
        isStationary = true
        stationaryStartTime = nil
        lastValidSpeedUpdate = nil
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
    
    // 获取静止时长
    func getStationaryDuration() -> TimeInterval? {
        guard isStationary, let startTime = stationaryStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    // 获取最后一次有效速度更新的时间
    func getLastValidSpeedUpdateTime() -> Date? {
        return lastValidSpeedUpdate
    }
} 