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

    private func fetchRoute() {
        guard let url = URL(string: "http://localhost:3000/route") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "origin": "\(originLat),\(originLng)",
            "destination": "\(destinationLat),\(destinationLng)"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error serializing parameters: \(error)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching route: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let routes = json["routes"] as? [[String: Any]],
                   let firstRoute = routes.first,
                   let legs = firstRoute["legs"] as? [[String: Any]],
                   let firstLeg = legs.first {
                    
                    // Extract and convert duration text
                    if let durationText = firstLeg["duration"] as? [String: Any],
                       let text = durationText["text"] as? String {
                        // Convert Chinese format to English format
                        let processedText = text
                            .replacingOccurrences(of: "分钟", with: "min")
                            .replacingOccurrences(of: "小时", with: "hour")
                        
                        DispatchQueue.main.async {
                            self.updateEstimatedTime(durationText: processedText)
                        }
                    }
                    
                    if let steps = firstLeg["steps"] as? [[String: Any]] {
                        let instructions = steps.compactMap { step -> String? in
                            guard let instruction = step["html_instructions"] as? String else { return nil }
                            // Convert Chinese format to English format
                            return instruction
                                .replacingOccurrences(of: "分钟", with: "min")
                                .replacingOccurrences(of: "小时", with: "hour")
                        }
                        
                        DispatchQueue.main.async {
                            self.instructions = instructions
                            self.instructionLabel.text = instructions.first ?? "No instructions available"
                        }
                    }
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
        
        task.resume()
    } 