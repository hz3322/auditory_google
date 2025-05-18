import Foundation

struct CatchInfo {
    let platformName: String
    let timeToStation: TimeInterval
    let expectedArrival: String
    var canCatch: Bool
    //TODO:
//    var deltaTime :

    // 改成 static func!
    static func fetchCatchInfos(
        for info: TransitInfo,
        entryToPlatformSec: Double,
        completion: @escaping ([CatchInfo]) -> Void
    ) {
        guard let lineId = RouteLogic.shared.tflLineId(from: info.lineName),
              let departureStation = info.departureStation else {
            completion([]); return
        }

        let stationId = RouteLogic.shared.tflStationId(from: departureStation)
        let urlStr = "https://api.tfl.gov.uk/Line/\(lineId)/Arrivals/\(stationId ?? "")"
        guard let url = URL(string: urlStr) else { completion([]); return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let arrs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                completion([]); return
            }

            let platformTarget = info.departurePlatform ?? ""
            let now = Date()
            var predictions: [CatchInfo] = []
            let formatter = ISO8601DateFormatter()

            let filtered = arrs.filter { dict in
                guard let platform = dict["platformName"] as? String else { return false }
                return platform == platformTarget
            }.sorted { d1, d2 in
                let t1 = (d1["expectedArrival"] as? String).flatMap { formatter.date(from: $0) } ?? Date.distantFuture
                let t2 = (d2["expectedArrival"] as? String).flatMap { formatter.date(from: $0) } ?? Date.distantFuture
                return t1 < t2
            }

            for dict in filtered.prefix(3) {
                guard let expectedArrivalStr = dict["expectedArrival"] as? String,
                      let expectedArrival = formatter.date(from: expectedArrivalStr),
                      let platformName = dict["platformName"] as? String else { continue }

                let secondsUntil = expectedArrival.timeIntervalSince(now)
                let canCatch = secondsUntil > entryToPlatformSec
                let expectedArrivalText = DateFormatter.shortTime.string(from: expectedArrival)
                let catchInfo = CatchInfo(
                    platformName: platformName,
                    timeToStation: entryToPlatformSec,
                    expectedArrival: expectedArrivalText,
                    canCatch: canCatch
                )
                predictions.append(catchInfo)
            }
            DispatchQueue.main.async {
                completion(predictions)
            }
        }.resume()
    }
}

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()
}
