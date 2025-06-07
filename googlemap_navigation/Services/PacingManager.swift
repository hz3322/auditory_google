import CoreLocation
import AVFoundation

class PacingManager: NSObject {
    
    // MARK: – Properties
    private var metronomeTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var lastLocation: CLLocation?
    private let minimumLocationChangeDistance: CLLocationDistance = 10.0 // Minimum distance change threshold in meters
    
    // Station information
    var distanceToStation: CLLocationDistance = 0      // in meters
    var timeToDeparture: TimeInterval = 0              // in seconds
    
    // Speed deviation threshold (percentage)
    private let speedDeviationThreshold: Double = 0.1  // Trigger alert when deviation exceeds 10%
    private var isCurrentlyPacing: Bool = false        // Current pacing state
    
    // Frequency limits (Hz)
    private let minFreq: Double = 0.5  // Slowest 1 time / 2s
    private let maxFreq: Double = 2.0  // Fastest 2 times / s
    
    // Callbacks
    var onSpeedUpdate: ((Double, Double) -> Void)? // (currentSpeed, targetSpeed)
    var onArrivalTimeUpdate: ((TimeInterval) -> Void)? // Updated arrival time
    
    override init() {
        super.init()
        setupAudioSession()
        setupTickSound()
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
    
    func updateWithNewLocation(_ location: CLLocation) {
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
        let vNow = max(location.speed, 0.5) // Ensure speed is not negative and at least 0.5 m/s
        
        // Calculate target speed
        guard timeToDeparture > 0 else { return }
        let vTarget = distanceToStation / timeToDeparture
        
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
    
    private func startPacing(forSpeedRatio ratio: Double) {
        // Determine alert frequency based on speed ratio
        // ratio > 1 means too fast, need to slow down
        // ratio < 1 means too slow, need to speed up
        let interval: TimeInterval = ratio > 1 ? 1.0 : 0.5 // Slower alert when too fast, faster alert when too slow
        print("⏱️ [PacingManager] Setting alert interval: \(interval) seconds")
        
        // Restart metronome timer
        metronomeTimer?.invalidate()
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playTick()
        }
    }
    
    private func playTick() {
        audioPlayer?.play()
    }
    
    func stopPacing() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }
    
    deinit {
        stopPacing()
    }
} 
