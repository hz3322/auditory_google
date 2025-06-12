import Foundation

class UserSpeedProfile {
    var averageSpeed: Double = 0.0
    var speedHistory: [Double] = []
    var lastUpdated: Date = Date()
    
    init() {
        // Load existing walking records if available
        speedHistory = UserSpeedProfile.loadWalkingRecords()
        if !speedHistory.isEmpty {
            averageSpeed = UserSpeedProfile.calculateAverageSpeed(from: speedHistory)
        }
    }
    
    func updateSpeed(_ newSpeed: Double) {
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