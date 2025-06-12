import CoreLocation
import AVFoundation

class PacingManager: NSObject {
    
    // MARK: – Properties
    private var metronomeTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var lastLocation: CLLocation?
    private let minimumLocationChangeDistance: CLLocationDistance = 10.0 // Minimum distance change threshold in meters
    
    // Metronome properties
    private var tickCount: Int = 0
    private let maxTicks: Int = 10  // 最多播放10次tick
    private var shouldContinuePacing: Bool = false  // 是否需要继续节拍
    
    // Station information
    var distanceToStation: CLLocationDistance = 0      // in meters
    var timeToDeparture: TimeInterval = 0              // in seconds
    var googleEstimatedTime: TimeInterval = 0          // Google's ETA in seconds
    
    // Location tracking
    var userOriginLocation: CLLocation?                // 用户起始位置
    
    // Speed deviation threshold (percentage)
    private let speedDeviationThreshold: Double = 0.1  // Trigger alert when deviation exceeds 10%
    private var isCurrentlyPacing: Bool = false        // Current pacing state
    
    // Frequency limits (Hz)
    private let minFreq: Double = 0.5  // Slowest 1 time / 2s
    private let maxFreq: Double = 2.0  // Fastest 2 times / s
    
    // Callbacks
    var onSpeedUpdate: ((Double, Double) -> Void)? // (currentSpeed, targetSpeed)
    var onArrivalTimeUpdate: ((TimeInterval) -> Void)? // Updated arrival time
    
    // Motion tracking
    private var currentMotionSpeed: Double = 0.0
    private var isUsingMotionData: Bool = false
    
    // Walking statistics
    private var walkingStartTime: Date?
    private var walkingStats: WalkingStats?
    
    // User speed profile
    private struct UserSpeedProfile {
        var averageSpeed: Double = 0.0
        var speedHistory: [Double] = []
        var lastUpdated: Date = Date()
        
        mutating func updateSpeed(_ newSpeed: Double) {
            speedHistory.append(newSpeed)
            // Keep only last 100 measurements
            if speedHistory.count > 100 {
                speedHistory.removeFirst()
            }
            averageSpeed = speedHistory.reduce(0, +) / Double(speedHistory.count)
            lastUpdated = Date()
        }
        
        func getAdjustedSpeed() -> Double {
            return averageSpeed
        }
        
        // Save walking records to UserDefaults
        func saveWalkingRecords() {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(speedHistory) {
                UserDefaults.standard.set(encoded, forKey: "walkingRecords")
            }
        }
        
        // Load walking records from UserDefaults
        static func loadWalkingRecords() -> [Double] {
            if let data = UserDefaults.standard.data(forKey: "walkingRecords"),
               let records = try? JSONDecoder().decode([Double].self, from: data) {
                return records
            }
            return []
        }
        
        // Calculate average speed from walking records
        static func calculateAverageSpeed(from records: [Double]) -> Double {
            guard !records.isEmpty else { return 0.0 }
            let totalSpeed = records.reduce(0.0) { $0 + $1 }
            return totalSpeed / Double(records.count)
        }
    }
    
    private var userSpeedProfile = UserSpeedProfile()
    
    // MARK: - Walking Statistics
    struct WalkingStats {
        var averageSpeed: Double = 0.0      // meters per second
        var maxSpeed: Double = 0.0          // meters per second
        var minSpeed: Double = Double.infinity  // meters per second
        var totalDistance: Double = 0.0     // meters
        var duration: TimeInterval = 0.0    // seconds
        var speedHistory: [Double] = []     // Array of speed measurements
    }
    
    // MARK: - Walking Record Model
    struct WalkingRecord: Codable {
        let distance: Double          // in meters
        let duration: TimeInterval    // in seconds
        let date: Date
        let weatherCondition: String
        
        var speed: Double {
            return distance / duration
        }
    }
    
    override init() {
        super.init()
        setupAudioSession()
        setupTickSound()
        setupMotionTracking()
        
        // Load walking records and initialize average speed
        userSpeedProfile.speedHistory = UserSpeedProfile.loadWalkingRecords()
        userSpeedProfile.averageSpeed = UserSpeedProfile.calculateAverageSpeed(from: userSpeedProfile.speedHistory)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ [PacingManager] Failed to setup audio session: \(error)")
        }
    }
    
    private func setupTickSound() {
        guard let url = Bundle.main.url(forResource: "tick", withExtension: "wav") else {
            print("⚠️ [PacingManager] Could not find tick.wav sound file")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.5 // Set volume to 50%
        } catch {
            print("⚠️ [PacingManager] Failed to setup audio player: \(error)")
        }
    }
    
    private func setupMotionTracking() {
        MotionManager.shared.onSpeedUpdate = { [weak self] speed in
            self?.currentMotionSpeed = speed
            self?.isUsingMotionData = true
            
            // Update walking statistics
            if var stats = self?.walkingStats {
                stats.speedHistory.append(speed)
                if speed > stats.maxSpeed {
                    stats.maxSpeed = speed
                }
                if speed < stats.minSpeed {
                    stats.minSpeed = speed
                }
                self?.walkingStats = stats
            }
        }
        MotionManager.shared.startTracking()
    }
    
    func updateWithNewLocation(_ location: CLLocation) {
        // 如果是第一次更新位置，设置为起始位置
        if userOriginLocation == nil {
            userOriginLocation = location
        }
        
        // Check if location change is significant enough
        if let lastLocation = lastLocation {
            let distanceChange = location.distance(from: lastLocation)
            if distanceChange < minimumLocationChangeDistance {
                return // Skip if location change is less than 10 meters
            }
        }
        
        // Update last known location
        lastLocation = location
        
        // Get current speed (m/s)
        var vNow: Double
        
        if isUsingMotionData && currentMotionSpeed > 0 {
            // Use motion data if available and valid
            vNow = currentMotionSpeed
            // Update user's speed profile
            userSpeedProfile.updateSpeed(vNow)
        } else {
            // Fallback to GPS speed
            vNow = max(location.speed, 0.5) // Ensure speed is not negative and at least 0.5 m/s
        }
        
        // Calculate target speed using adaptive ETA
        guard timeToDeparture > 0 else { return }
        
        // Get adjusted speed based on user's profile
        let adjustedSpeed = userSpeedProfile.getAdjustedSpeed()
        
        // Calculate adaptive ETA
        let adaptiveETA = calculateAdaptiveETA(
            distance: distanceToStation,
            googleETA: googleEstimatedTime,
            userSpeed: adjustedSpeed
        )
        
        let vTarget = distanceToStation / adaptiveETA
        
        // Calculate new arrival time
        let newArrivalTime = distanceToStation / vNow
        
        // Notify external components
        onSpeedUpdate?(vNow, vTarget)
        onArrivalTimeUpdate?(newArrivalTime)
        
        // Check speed deviation
        let speedRatio = vNow / vTarget
        let deviation = abs(1.0 - speedRatio)
        
        print("📊 [PacingManager] Current speed: \(String(format: "%.2f", vNow))m/s, Target speed: \(String(format: "%.2f", vTarget))m/s")
        print("📊 [PacingManager] Speed ratio: \(String(format: "%.2f", speedRatio)), Deviation: \(String(format: "%.1f", deviation * 100))%")
        print("⏱️ [PacingManager] Estimated arrival time: \(String(format: "%.1f", newArrivalTime)) seconds")
        
        // If speed deviation exceeds threshold
        if deviation >= speedDeviationThreshold {
            if !isCurrentlyPacing {
                // Start new pacing alert
                isCurrentlyPacing = true
                print("🔔 [PacingManager] Starting alert - \(speedRatio > 1 ? "Too fast" : "Too slow")")
                startPacing(forSpeedRatio: speedRatio)
            }
        } else {
            // Speed is back to normal, stop alert
            if isCurrentlyPacing {
                print("✅ [PacingManager] Speed back to normal, stopping alert")
                stopPacing()
                isCurrentlyPacing = false
            }
        }
    }
    
    private func calculateAdaptiveETA(distance: CLLocationDistance, googleETA: TimeInterval, userSpeed: Double) -> TimeInterval {
        // Calculate ETA based on user's speed
        let userBasedETA = distance / userSpeed
        
        // Weight factors (can be adjusted based on data analysis)
        let googleWeight: Double = 0.3  // Trust Google's ETA less
        let userWeight: Double = 0.7    // Trust user's speed more
        
        // Calculate weighted average
        let adaptiveETA = (googleETA * googleWeight) + (userBasedETA * userWeight)
        
        // Ensure ETA is not too optimistic or pessimistic
        let minETA = max(googleETA * 0.8, userBasedETA * 0.8)  // Not too optimistic
        let maxETA = min(googleETA * 1.2, userBasedETA * 1.2)  // Not too pessimistic
        
        return min(max(adaptiveETA, minETA), maxETA)
    }
    
    private func startPacing(forSpeedRatio ratio: Double) {
        // Reset tick count
        tickCount = 0
        shouldContinuePacing = true
        
        // Determine alert frequency based on speed ratio
        // ratio > 1 means too fast, need to slow down
        // ratio < 1 means too slow, need to speed up
        let interval: TimeInterval = ratio > 1 ? 1.0 : 0.5 // Slower alert when too fast, faster alert when too slow
        print("⏱️ [PacingManager] Setting alert interval: \(interval) seconds")
        
        // Restart metronome timer
        metronomeTimer?.invalidate()
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Play tick and increment count
            self.playTick()
            self.tickCount += 1
            
            // Check if we should stop or continue
            if self.tickCount >= self.maxTicks {
                self.metronomeTimer?.invalidate()
                self.metronomeTimer = nil
                
                // If we still need pacing, start a new cycle after a short pause
                if self.shouldContinuePacing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.startPacing(forSpeedRatio: ratio)
                    }
                }
            }
        }
    }
    
    private func playTick() {
        audioPlayer?.play()
    }
    
    func stopPacing() {
        shouldContinuePacing = false  // 确保不会开始新的节拍循环
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        tickCount = 0
        MotionManager.shared.stopTracking()
    }
    
    func startWalkingTracking() {
        walkingStartTime = Date()
        walkingStats = WalkingStats()
        MotionManager.shared.startTracking()
    }
    
    func stopWalkingTracking() -> WalkingStats? {
        guard let startTime = walkingStartTime else { return nil }
        
        // Get final statistics
        MotionManager.shared.getAverageSpeed(from: startTime, to: Date()) { [weak self] averageSpeed in
            if let stats = self?.walkingStats, let avgSpeed = averageSpeed {
                var finalStats = stats
                finalStats.averageSpeed = avgSpeed
                finalStats.duration = Date().timeIntervalSince(startTime)
                
                // Calculate additional metrics
                if !finalStats.speedHistory.isEmpty {
                    finalStats.maxSpeed = finalStats.speedHistory.max() ?? 0
                    finalStats.minSpeed = finalStats.speedHistory.min() ?? 0
                }
                
                // Create and save walking record
                if let lastLocation = self?.lastLocation,
                   let originLocation = self?.userOriginLocation {
                    let distance = lastLocation.distance(from: originLocation)
                    let record = WalkingRecord(
                        distance: distance,
                        duration: finalStats.duration,
                        date: Date(),
                        weatherCondition: "current" // You might want to get this from WeatherService
                    )
                    self?.userSpeedProfile.speedHistory.append(distance / finalStats.duration)
                    self?.userSpeedProfile.saveWalkingRecords()
                }
                
                // Notify about completion
                self?.notifyWalkingStatsUpdated(finalStats)
            }
        }
        
        MotionManager.shared.stopTracking()
        walkingStartTime = nil
        return walkingStats
    }
    
    private func notifyWalkingStatsUpdated(_ stats: WalkingStats) {
        // Convert to more readable format
        let avgSpeedKmh = stats.averageSpeed * 3.6  // Convert m/s to km/h
        let maxSpeedKmh = stats.maxSpeed * 3.6
        let minSpeedKmh = stats.minSpeed * 3.6
        let distanceKm = stats.totalDistance / 1000  // Convert meters to kilometers
        let durationMinutes = stats.duration / 60    // Convert seconds to minutes
        
        print("""
        📊 Walking Statistics:
        - Average Speed: \(String(format: "%.1f", avgSpeedKmh)) km/h
        - Max Speed: \(String(format: "%.1f", maxSpeedKmh)) km/h
        - Min Speed: \(String(format: "%.1f", minSpeedKmh)) km/h
        - Total Distance: \(String(format: "%.2f", distanceKm)) km
        - Duration: \(String(format: "%.1f", durationMinutes)) minutes
        """)
    }
    
    deinit {
        stopPacing()
    }
} 
