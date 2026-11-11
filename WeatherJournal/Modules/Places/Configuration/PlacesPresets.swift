import Foundation

/// 空关键词时展示原型预置地区，沿用 Open-Meteo 来源 ID，使在线搜索与预置收藏去重一致。
enum PlacesPresets {
    private struct Entry {
        let id: Int
        let nameKey: String
        let regionKey: String
        let point: Coordinates
    }

    // ID 与坐标于 2026-11-11 从 Open-Meteo Geocoding API 核对；这些值属于生产预置数据。
    private static let entries: [Entry] = [
        Entry(
            id: 1_819_607, nameKey: "Kowloon City", regionKey: "Hong Kong · Kowloon",
            point: Coordinates(latitude: 22.33047, longitude: 114.19222)),
        Entry(
            id: 1_795_565, nameKey: "Shenzhen", regionKey: "China · Guangdong",
            point: Coordinates(latitude: 22.54554, longitude: 114.0683)),
        Entry(
            id: 1_819_729, nameKey: "Hong Kong", regionKey: "Hong Kong",
            point: Coordinates(latitude: 22.27832, longitude: 114.17469)),
        Entry(
            id: 1_816_670, nameKey: "Beijing", regionKey: "China · Beijing",
            point: Coordinates(latitude: 39.9075, longitude: 116.39723)),
        Entry(
            id: 1_796_236, nameKey: "Shanghai", regionKey: "China · Shanghai",
            point: Coordinates(latitude: 31.22222, longitude: 121.45806)),
        Entry(
            id: 1_809_858, nameKey: "Guangzhou", regionKey: "China · Guangdong",
            point: Coordinates(latitude: 23.11667, longitude: 113.25)),
    ]

    static func items(language: String) -> [Place] {
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return entries.map { entry in
            Place(
                id: entry.id,
                name: bundle.localizedString(forKey: entry.nameKey, value: nil, table: nil),
                region: bundle.localizedString(forKey: entry.regionKey, value: nil, table: nil),
                point: entry.point)
        }
    }
}
