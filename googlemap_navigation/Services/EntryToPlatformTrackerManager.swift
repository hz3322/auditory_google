//
//  EntryToPlatformTracker.swift
//  googlemap_navigation
//
//  Created by 赵韩雪 on 15/05/2025.
//


// EntryToPlatformTracker.swift
// Manager to track user walking time from station entry to platform

import Foundation
import CoreLocation

class EntryToPlatformTrackerManager {
    static let shared = EntryToPlatformTrackerManager()

    private var startTime: Date?
    private var endTime: Date?
    private var currentStation: String?

    private init() {}

    /// Call this when user enters a station
    func startTracking(for station: String) {
        startTime = Date()
        currentStation = station
        print("[EntryToPlatformTracker] Started tracking at \(station) at \(startTime!)")
    }

    /// Call this when user reaches the platform
    func stopTrackingAndSave() {
        guard let start = startTime,
              let station = currentStation else { return }

        endTime = Date()
        let duration = endTime!.timeIntervalSince(start)

        print("[EntryToPlatformTracker] Time from entry to platform at \(station): \(duration) seconds")

        // Save logic – You can replace this with actual database integration
        saveTransferTime(for: station, duration: duration)

        // Reset
        startTime = nil
        endTime = nil
        currentStation = nil
    }

    /// Simulated saving function (replace with your actual DB logic)
    private func saveTransferTime(for station: String, duration: TimeInterval) {
        let rounded = Int(duration)
        print("[EntryToPlatformTracker] Saving \(rounded) seconds for station: \(station)")
        // TODO: Integrate with backend API or local DB
    }

    /// Optional: return default estimate when no user data exists
    func defaultTransferTime() -> Int {
        return 120  // Default 2 minutes
    }
}
