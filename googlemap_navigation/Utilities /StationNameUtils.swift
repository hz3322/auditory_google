
import Foundation

struct StationNameUtils {
    static func normalizeStationName(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: " underground station", with: "")
            .replacingOccurrences(of: " station", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
