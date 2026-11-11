import Foundation

/// 保留来源 ID 与坐标，地区展示字段在服务边界统一组装。
struct PlaceSearchAPI {
    let client: OpenMeteoClient
    let endpoint: URL

    func find(_ query: String, language: String) async throws -> [Place] {
        let response: Response = try await client.get(
            endpoint,
            query: [
                URLQueryItem(name: PlacesContract.Query.name, value: query),
                URLQueryItem(
                    name: PlacesContract.Query.language,
                    value: language.components(separatedBy: PlacesContract.languageSeparator).first),
                URLQueryItem(name: PlacesContract.Query.count, value: String(PlacesContract.searchLimit)),
            ])
        return (response.results ?? []).map { record in
            var parts: [String] = []
            for part in [record.country, record.admin1].compactMap({ $0 }) where !part.isEmpty && !parts.contains(part)
            {
                parts.append(part)
            }
            return Place(
                id: record.id, name: record.name, region: parts.joined(separator: PlacesContract.regionSeparator),
                point: Coordinates(latitude: record.latitude, longitude: record.longitude))
        }
    }

    private struct Response: Decodable {
        struct Record: Decodable {
            let id: Int
            let name: String
            let latitude, longitude: Double
            let admin1, country: String?
        }

        let results: [Record]?
    }
}
