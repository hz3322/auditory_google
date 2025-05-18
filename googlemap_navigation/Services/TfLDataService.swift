import Foundation

// 建议加到 RouteLogic 或新建 TfLDataService
class TfLDataService {
    static let shared = TfLDataService()
    private init() {}

    private(set) var stationIdMap: [String: String] = [:]

    func fetchAllTubeStationIds(completion: @escaping () -> Void) {
        let urlStr = "https://api.tfl.gov.uk/StopPoint/Mode/tube"
        guard let url = URL(string: urlStr) else { completion(); return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            var dict: [String: String] = [:]
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stops = json["stopPoints"] as? [[String: Any]] else {
                completion(); return
            }
            for stop in stops {
                if let name = stop["commonName"] as? String,
                   let id = stop["naptanId"] as? String {
                    dict[name] = id
                }
            }
            self.stationIdMap = dict
            print("TfL StationIdMap Loaded, count = \(dict.count)")
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }

    func tflStationId(from stationName: String) -> String? {
        // 支持 fuzzy 查找，比如 "Oxford Circus Underground Station" 这种
        if let id = stationIdMap[stationName] { return id }
        // 模糊匹配
        let key = stationIdMap.keys.first { $0.lowercased().contains(stationName.lowercased()) }
        return key.flatMap { stationIdMap[$0] }
    }
}
