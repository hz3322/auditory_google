import Foundation
import CoreLocation
import UIKit

enum WeatherCondition: String {
    case clear = "Clear ☀️"
    case sunny = "Sunny ☀️"
    case rain = "Rain 🌧"
    case drizzle = "Drizzle 🌦"
    case snow = "Snow ❄️"
    case clouds = "Clouds ☁️"
    case thunderstorm = "Thunderstorm ⛈"
    case mist = "Mist 🌫"
    case fog = "Fog 🌫"
    case haze = "Haze 🌫"
    
    func walkingSuggestion(for temp: Double) -> (text: String, emoji: String) {
        switch self {
        case .clear, .sunny:
            switch temp {
            case 28...:
                return ("You can walk faster", "🏃‍♂️")
            case 18..<28:
                return ("Normal walking pace", "🚶‍♀️")
            case 10..<18:
                return ("You can speed up", "🚶‍♂️")
            default:
                return ("Walk faster to stay warm", "🏃‍♀️")
            }
        case .drizzle:
            return ("Steady pace", "🚶")
        case .rain, .thunderstorm:
            return ("Take it slow", "🐢")
        case .snow:
            return ("Walk carefully", "⛄️")
        case .clouds:
            return ("Normal pace", "🚶")
        case .mist, .fog, .haze:
            return ("Watch your step", "👀")
        }
    }
    
    var speedFactor: Double {
        switch self {
        case .clear, .sunny:
            return 1.0
        case .clouds:
            return 0.95
        case .drizzle, .rain:
            return 0.8
        case .snow:
            return 0.7
        case .thunderstorm:
            return 0.6
        case .mist, .fog, .haze:
            return 0.9
        }
    }
    
    var backgroundGradient: (start: UIColor, end: UIColor) {
        switch self {
        case .clear, .sunny:
            // Green gradient for good weather
            return (
                UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0),
                UIColor(red: 0.1, green: 0.6, blue: 0.1, alpha: 1.0)
            )
        case .clouds:
            // Light blue gradient for cloudy weather
            return (
                UIColor(red: 0.4, green: 0.7, blue: 0.9, alpha: 1.0),
                UIColor(red: 0.3, green: 0.6, blue: 0.8, alpha: 1.0)
            )
        case .drizzle, .rain:
            // Blue gradient for rain
            return (
                UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0),
                UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
            )
        case .snow:
            // Light purple gradient for snow
            return (
                UIColor(red: 0.6, green: 0.5, blue: 0.9, alpha: 1.0),
                UIColor(red: 0.5, green: 0.4, blue: 0.8, alpha: 1.0)
            )
        case .thunderstorm:
            // Red gradient for severe weather
            return (
                UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0),
                UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1.0)
            )
        case .mist, .fog, .haze:
            // Gray gradient for foggy conditions
            return (
                UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0),
                UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            )
        }
    }
    
    static func from(weatherId: Int) -> WeatherCondition {
        switch weatherId {
        case 200...232: return .thunderstorm
        case 300...321: return .drizzle
        case 500...531: return .rain
        case 600...622: return .snow
        case 701...781: return .fog
        case 800: return .clear
        case 801...804: return .clouds
        default: return .clear
        }
    }
}

struct WeatherResponse: Decodable {
    struct Weather: Decodable {
        let id: Int
        let main: String
        let description: String
    }
    let weather: [Weather]
    let main: Main
    
    struct Main: Decodable {
        let temp: Double
    }
}

class WeatherService {
    static let shared = WeatherService()
    private let apiKey: String
    
    private init() {
        self.apiKey = APIKeys.openWeather
    }
    
    func fetchCurrentWeather(
        at coordinate: CLLocationCoordinate2D,
        completion: @escaping (_ condition: String, _ suggestion: String, _ gradient: (start: UIColor, end: UIColor)) -> Void
    ) {
        let urlString = String(
            format: "https://api.openweathermap.org/data/2.5/weather?lat=%.4f&lon=%.4f&units=metric&lang=en&appid=%@",
            coordinate.latitude,
            coordinate.longitude,
            apiKey
        )
        guard let url = URL(string: urlString) else {
            completion("Weather service unavailable", "", WeatherCondition.clear.backgroundGradient)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, resp, err in
            guard
                err == nil,
                let data = data,
                let weatherResp = try? JSONDecoder().decode(WeatherResponse.self, from: data),
                let w = weatherResp.weather.first
            else {
                completion("Weather service unavailable", "", WeatherCondition.clear.backgroundGradient)
                return
            }
            
            // Debug logging
            print("🌤 Weather API Response:")
            print("  - Main condition: \(w.main)")
            print("  - Description: \(w.description)")
            print("  - Weather ID: \(w.id)")
            print("  - Temperature: \(weatherResp.main.temp)°C")
            
            // Get condition based on weather ID
            let condition = WeatherCondition.from(weatherId: w.id)
            let suggestion = condition.walkingSuggestion(for: weatherResp.main.temp)
            print("🔄 Mapped weather ID \(w.id) to condition: \(condition)")
            
            // Return the condition name and suggestion combined in one line with emoji
            completion("\(condition.rawValue) - \(suggestion.text) \(suggestion.emoji)", "", condition.backgroundGradient)
        }.resume()
    }
}
