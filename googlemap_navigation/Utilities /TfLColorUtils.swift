
import UIKit

/// Utility for mapping TfL line IDs to their official colors.
struct TfLColorUtils {
    /// Hex codes for each TfL line (lowercased lineId → "#RRGGBB")
    private static let lineColorMap: [String: String] = [
        "bakerloo":         "#B36305",
        "central":          "#E32017",
        "circle":           "#FFD300",
        "district":         "#00782A",
        "hammersmith-city": "#F3A9BB",
        "jubilee":          "#A0A5A9",
        "metropolitan":     "#9B0056",
        "northern":         "#000000",
        "piccadilly":       "#003688",
        "victoria":         "#0098D4",
        "waterloo-city":    "#95CDBA",
        "dlr":              "#00AFAD",
        "london-overground":"#EE7C0E",
        "tfl-rail":         "#0019A8",
        "elizabeth":        "#6950A1"
        // Add other lines here if needed
    ]

    /// Returns the UIColor for a given TfL lineId.
    /// If the lineId isn’t found, falls back to a default blue.
    static func color(forLineId lineId: String) -> UIColor {
        let key = lineId.lowercased()
        let hexString = lineColorMap[key] ?? "#007AFF"
        return UIColor(hex: hexString)
    }
    
    static func hexString(forLineId lineId: String) -> String {
            return lineColorMap[lineId.lowercased()] ?? "#007AFF"
        }
}

/// Convenience initializer to create a UIColor from a hex string "#RRGGBB".
extension UIColor {
    convenience init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    var isLight: Bool {
        guard let components = cgColor.components, components.count >= 3 else { return false }
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5
    }
}

