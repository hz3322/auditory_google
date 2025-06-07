
struct WeatherInfo: Decodable {
  let main: Main
  let weather: [Weather]
  struct Main: Decodable {
    let temp: Double
  }
  struct Weather: Decodable {
    let description: String
    let icon: String
  }
}
