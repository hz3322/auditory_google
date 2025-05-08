    private func updateEstimatedTime(durationText: String) {
        let speedMultiplier = Double(speedSlider.value)
        var totalMinutes: Double = 0
        print("Duration from API: \(durationText)")
        
        // Convert Chinese format to English format
        let processedText = durationText
            .replacingOccurrences(of: "分钟", with: "min")
            .replacingOccurrences(of: "小时", with: "hour")
        
        let components = processedText.lowercased().components(separatedBy: " ")
        print("Parsed components: \(components)")
        
        var i = 0
        while i < components.count {
            if let value = Double(components[i]) {
                let unit = components[safe: i + 1] ?? ""
                if unit.contains("hour") {
                    totalMinutes += value * 60
                } else if unit.contains("min") {
                    totalMinutes += value
                }
                i += 2
            } else {
                i += 1
            }
        }
        
        guard totalMinutes > 0 else {
            estimatedTimeLabel.text = "Estimated Time: --"
            return
        }
        
        let adjustedMinutes = totalMinutes / speedMultiplier
        let displayText = String(format: "Estimated Time: %.0f min", adjustedMinutes)
        estimatedTimeLabel.text = displayText
    } 